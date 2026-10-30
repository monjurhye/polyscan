"""Renders training pages with text2image and turns them into .lstmf files.

Each job renders a different slice of the text in one font, size, exposure and letter
spacing; every page is also saved as a degraded copy (blur, lost resolution, noise, uneven
light, JPEG) so the model learns phone photos, not only crisp print.
  python make_data.py <lang> <text.txt> <out_dir> <lines_per_job> "<font>" ["<font>" ...]
"""
import concurrent.futures, io, itertools, os, random, shutil, subprocess, sys, unicodedata
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
    os.makedirs(f'{out}/fc{i}', exist_ok=True)
    sh('text2image', *[f'--fonts_dir={here}/fonts', f'--fontconfig_tmpdir={out}/fc{i}', f'--font={font}',
                    f'--text={base}.txt', f'--outputbase={base}', f'--ptsize={size}', f'--exposure={exposure}',
                    f'--char_spacing={spacing}', '--strip_unrenderable_words', '--max_pages=0',
                    '--xsize=2550', '--ysize=3300', '--margin=100', '--resolution=300'])
    shutil.rmtree(f'{out}/fc{i}', ignore_errors=True)
    # Split text2image's multi-page TIFF into single pages (box lines end with the page
    # number), add a degraded copy of each, and make one .lstmf per page. A page Tesseract
    # rejects (for example "Empty page") is skipped rather than failing the whole run.
    # A vowel mark gets its own box from text2image. Trained like that, the Dhivehi model
    # wrote each mark before its letter (2026-10-29), so marks join their letter's box.
    boxes = {}
    for line in open(base + '.box', encoding='utf-8'):
        head, page = line.rstrip('\n').rsplit(' ', 1)
        text, *box = head.rsplit(' ', 4)
        page_boxes = boxes.setdefault(int(page), [])
        if text and unicodedata.category(text[0]) == 'Mn' and page_boxes:
            prev, l, b, r, t = page_boxes[-1]
            l2, b2, r2, t2 = map(int, box)
            page_boxes[-1] = [prev + text, min(l, l2), min(b, b2), max(r, r2), max(t, t2)]
        else:
            page_boxes.append([text, *map(int, box)])
    boxes = {p: [' '.join(map(str, b)) + ' 0\n' for b in bs] for p, bs in boxes.items()}
    made, failed = [], 0
    for p, page in enumerate(ImageSequence.Iterator(Image.open(base + '.tif'))):
        if p not in boxes:
            continue
        page = page.convert('L')
        for b, img in ((f'{base}p{p}', page), (f'{base}p{p}d', degrade_page(page, rnd))):
            img.save(b + '.tif', compression='tiff_lzw')  # text2image's Group 4 needs 1-bit pixels
            open(b + '.box', 'w', encoding='utf-8').writelines(boxes[p])
            try:
                sh('tesseract', b + '.tif', b, 'lstm.train')
                if os.path.getsize(b + '.lstmf') > 0:
                    made.append(b + '.lstmf')
                    continue
            except (RuntimeError, OSError):
                pass
            failed += 1
    return made, failed


with concurrent.futures.ThreadPoolExecutor(os.cpu_count()) as pool:
    results = list(pool.map(run, range(len(jobs))))
files = [f for made, _ in results for f in made]
failed = sum(n for _, n in results)
if failed > len(files) / 10:
    sys.exit(f'{failed} pages failed and only {len(files)} worked')

# One page pair in twenty is held out to watch the error rate during training.
evals = [f for i, f in enumerate(files) if (i // 2) % 20 == 0]
open(os.path.join(out, 'train.txt'), 'w').write('\n'.join(f for f in files if f not in evals) + '\n')
open(os.path.join(out, 'eval.txt'), 'w').write('\n'.join(evals) + '\n')
print(f'{lang}: {len(jobs)} jobs, {len(files)} pages ({len(evals)} held out, {failed} skipped)')
