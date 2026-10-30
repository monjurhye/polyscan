"""Builds the training text for one language from Leipzig Wikipedia sentence corpora.

Drops every sentence that shares five words in a row with the evaluation text (UDHR), so
the evaluation measures text the model has never seen.
  python prepare_text.py <lang> <out.txt>
"""
import glob, io, os, random, re, sys, tarfile, unicodedata, urllib.request

CORPORA = {
    'div': ['div_wikipedia_2021_10K', 'div_wikipedia_2016_10K'],
    'urd': ['urd_wikipedia_2021_100K'],
}
# Letters of the language's script; a sentence must be mostly these.
SCRIPT = {'div': r'[ހ-޿]', 'urd': r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]'}

lang, out = sys.argv[1], sys.argv[2]
here = os.path.dirname(os.path.abspath(__file__))


def words(s):
    # Split on spaces and punctuation only: \w+ would also split at vowel marks.
    s = unicodedata.normalize('NFC', s)
    return ''.join(' ' if unicodedata.category(c)[0] in 'PZ' else c for c in s).split()


held_out = set()
for f in glob.glob(os.path.join(here, 'eval', 'truth', f'{lang}~*.txt')):
    w = words(open(f, encoding='utf-8').read())
    held_out |= {tuple(w[i:i + 5]) for i in range(len(w) - 4)}

sentences, dropped = set(), 0
for name in CORPORA[lang]:
    url = f'https://downloads.wortschatz-leipzig.de/corpora/{name}.tar.gz'
    data = urllib.request.urlopen(url, timeout=120).read()
    with tarfile.open(fileobj=io.BytesIO(data)) as tar:
        member = next(m for m in tar.getmembers() if m.name.endswith('-sentences.txt'))
        for line in io.TextIOWrapper(tar.extractfile(member), encoding='utf-8'):
            s = re.sub(r'\s+', ' ', line.split('\t', 1)[-1]).strip()
            # Bidi controls appear in Wikipedia text but never on paper.
            s = re.sub('[‎‏‪-‮⁦-⁩]', '', s)
            letters = re.findall(r'\w', s)
            if not 15 <= len(s) <= 160 or not letters:
                continue
            if len(re.findall(SCRIPT[lang], s)) < 0.8 * len(letters):
                continue
            w = words(s)
            if any(tuple(w[i:i + 5]) in held_out for i in range(len(w) - 4)):
                dropped += 1
                continue
            sentences.add(s)

sentences = sorted(sentences)
random.Random(1).shuffle(sentences)
open(out, 'w', encoding='utf-8').write('\n'.join(sentences) + '\n')
print(f'{lang}: {len(sentences)} sentences, {sum(map(len, sentences))} chars, {dropped} dropped as evaluation overlap')
