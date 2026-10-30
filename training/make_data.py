"""Renders training pages with text2image and turns them into .lstmf files.

Each job renders a different slice of the text in one font, size, exposure and letter
spacing; every page is also saved as a degraded copy (blur, lost resolution, noise, uneven
light, JPEG) so the model learns phone photos, not only crisp print.
  python make_data.py <lang> <text.txt> <out_dir> <lines_per_job> "<font>" ["<font>" ...]
"""
import concurrent.futures, io, itertools, os, random, shutil, subprocess, sys
import numpy as np
from PIL import Image, ImageFilter, ImageSequence

lang, text_file, out, per_job, fonts = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5:]
here = os.path.dirname(os.path.abspath(__file__))
os.makedirs(out, exist_ok=True)
lines = open(text_file, encoding='utf-8').read().splitlines()

jobs = list(itertools.product(fonts, (9, 11, 13, 16, 20), (-1, 0, 1), (0.0, 0.05)))
random.Random(2).shuffle(jobs)


def degrade_page(img, rnd):
    w, h = img.size
    s = rnd.uniform(0.45, 0.9)
    img = img.resize((int(w * s), int(h * s)), Image.BILINEAR).resize((w, h), Image.BILINEAR)
    img = img.filter(ImageFilter.GaussianBlur(rnd.uniform(0.3, 1.3)))
    a = np.asarray(img, float)
    lo, hi = rnd.uniform(0, 70), rnd.uniform(185, 255)
    a = lo + a / 255 * (hi - lo)
    if rnd.random() < 0.5:
        yy, xx = np.mgrid[0:h, 0:w]
        a = a * (1 - rnd.uniform(0.1, 0.4) * (xx / w if rnd.random() < 0.5 else yy / h))
    a += np.random.default_rng(rnd.randrange(1 << 30)).normal(0, rnd.uniform(2, 12), a.shape)
    b = io.BytesIO()
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(b, 'JPEG', quality=rnd.randint(40, 85))
    b.seek(0)
    return Image.open(b).convert('L')


def degrade(path, rnd):
    # text2image writes one multi-page TIFF; the box file refers to its page numbers.
    pages = [degrade_page(p.convert('L'), rnd) for p in ImageSequence.Iterator(Image.open(path))]
    pages[0].save(path, save_all=True, append_images=pages[1:])


def sh(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode:
        raise RuntimeError(f'{cmd[0]} failed ({r.returncode}): {r.stderr[-1500:]}')


def run(i):
    font, size, exposure, spacing = jobs[i]
    rnd = random.Random(i)
    start = (i * per_job) % len(lines)
    chunk = (lines + lines)[start:start + per_job]
    base = os.path.join(out, f'{lang}.{i:03d}')
    open(base + '.txt', 'w', encoding='utf-8').write('\n'.join(chunk) + '\n')
    sh('text2image', *[f'--fonts_dir={here}/fonts', f'--fontconfig_tmpdir={out}/fc{i}', f'--font={font}',
                    f'--text={base}.txt', f'--outputbase={base}', f'--ptsize={size}', f'--exposure={exposure}',
                    f'--char_spacing={spacing}', '--strip_unrenderable_words', '--max_pages=0',
                    '--xsize=2550', '--ysize=3300', '--margin=100', '--resolution=300'])
    shutil.rmtree(f'{out}/fc{i}', ignore_errors=True)
    shutil.copy(base + '.tif', base + 'd.tif')
    shutil.copy(base + '.box', base + 'd.box')
    degrade(base + 'd.tif', rnd)
    made = []
    for b in (base, base + 'd'):
        sh('tesseract', b + '.tif', b, 'lstm.train')
        made.append(b + '.lstmf')
    return made


with concurrent.futures.ThreadPoolExecutor(os.cpu_count()) as pool:
    files = [f for made in pool.map(run, range(len(jobs))) for f in made]

# One job in twenty is held out to watch the error rate during training.
evals = [f for i, f in enumerate(files) if (i // 2) % 20 == 0]
open(os.path.join(out, 'train.txt'), 'w').write('\n'.join(f for f in files if f not in evals) + '\n')
open(os.path.join(out, 'eval.txt'), 'w').write('\n'.join(evals) + '\n')
print(f'{lang}: {len(jobs)} jobs, {len(files)} lstmf files ({len(evals)} held out)')
