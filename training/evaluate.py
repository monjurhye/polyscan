"""Character accuracy of one or more models on the evaluation pages.
  python evaluate.py <lang> <images_dir> <name>=<tessdata_dir> [<name>=<tessdata_dir> ...]
Images are named <lang>~<font>~<page>-<condition>.jpg; truth is eval/truth/<lang>~<font>~<page>.txt.
Prints one line per font and condition, and a total per model (average over all pages)."""
import concurrent.futures, glob, json, os, re, subprocess, sys, unicodedata
from collections import defaultdict
from rapidfuzz.distance import Levenshtein

lang, images, models = sys.argv[1], sys.argv[2], [m.split('=', 1) for m in sys.argv[3:]]
here = os.path.dirname(os.path.abspath(__file__))


def norm(s):
    return re.sub(r'\s+', '', unicodedata.normalize('NFKC', s))


def score(args):
    name, tessdata, path = args
    key, cond = os.path.basename(path)[:-4].rsplit('-', 1)
    got = subprocess.run(['tesseract', path, 'stdout', '-l', lang, '--tessdata-dir', tessdata],
                         capture_output=True, text=True, encoding='utf-8').stdout
    truth = norm(open(os.path.join(here, 'eval', 'truth', key + '.txt'), encoding='utf-8').read())
    acc = max(0.0, 1 - Levenshtein.distance(truth, norm(got)) / len(truth)) * 100
    return name, key, cond, acc


tasks = [(n, t, p) for n, t in models for p in sorted(glob.glob(os.path.join(images, f'{lang}~*.jpg')))]
with concurrent.futures.ThreadPoolExecutor(os.cpu_count()) as pool:
    results = list(pool.map(score, tasks))

groups = defaultdict(list)
for name, key, cond, acc in results:
    font = key.split('~')[1]
    groups[(font, cond)].append((name, acc))
    groups[('all', 'all')].append((name, acc))

lines = []
for (font, cond), rows in sorted(groups.items()):
    avg = {n: sum(a for m, a in rows if m == n) / max(1, sum(m == n for m, _ in rows)) for n, _ in models}
    lines.append(f'{lang} {font:9} {cond:6} ' + '  '.join(f'{n} {avg[n]:5.1f}%' for n, _ in models))
print('\n'.join(lines))
json.dump([dict(zip(('model', 'page', 'condition', 'accuracy'), r)) for r in results],
          open(f'eval-{lang}.json', 'w'), indent=0)
