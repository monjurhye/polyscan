"""eval/clean/<key>.png -> <out>/<key>-{clean,phone,shadow}.png: the same phone and shadow
conditions as the language tests (smaller, blurred, noisy JPEG; uneven light)."""
import os, sys, numpy as np
from io import BytesIO
from PIL import Image, ImageFilter

src, out = sys.argv[1], sys.argv[2]
np.random.seed(7)
os.makedirs(out, exist_ok=True)


def jpeg(img, q):
    b = BytesIO(); img.save(b, 'JPEG', quality=q); b.seek(0); return Image.open(b).convert('RGB')


def rgb(a):
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).convert('RGB')


for f in sorted(os.listdir(src)):
    key = f[:-4]
    page = Image.open(os.path.join(src, f)).convert('L')
    page.convert('RGB').save(os.path.join(out, f'{key}-clean.png'))
    small = page.resize((1400, int(page.height * 1400 / page.width)), Image.LANCZOS).filter(ImageFilter.GaussianBlur(0.8))
    a = np.asarray(small, float)
    jpeg(rgb(a * 0.93 + 8 + np.random.normal(0, 5, a.shape)), 70).save(os.path.join(out, f'{key}-phone.png'))
    h, w = a.shape
    yy, xx = np.mgrid[0:h, 0:w]
    grad = 1 - 0.55 * (xx / w * 0.8 + yy / h * 0.2)
    blob = np.exp(-(((xx - w * 0.55) / (w * 0.22)) ** 2 + ((yy - h * 0.4) / (h * 0.3)) ** 2))
    jpeg(rgb(a * grad * (1 - 0.45 * blob) + np.random.normal(0, 6, a.shape)), 70).save(os.path.join(out, f'{key}-shadow.png'))
print(len(os.listdir(out)), 'degraded images')
