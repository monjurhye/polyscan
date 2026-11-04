"""Makes the Play Store icon (512x512) and feature graphic (1024x500) from assets/icon/icon.png."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "store" / "play"
OUT.mkdir(parents=True, exist_ok=True)
source = Image.open(ROOT / "assets" / "icon" / "icon.png").convert("RGB")
source.resize((512, 512), Image.LANCZOS).save(OUT / "icon-512.png")

W, H = 1024, 500
top, bottom = (0x46, 0x68, 0xFF), (0x20, 0x33, 0xB0)
graphic = Image.new("RGB", (W, H))
draw = ImageDraw.Draw(graphic)
for y in range(H):
    t = y / (H - 1)
    draw.line([(0, y), (W, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))

# The icon's page and scan line, without its square background edge.
page = source.resize((400, 400), Image.LANCZOS)
mask = Image.new("L", page.size, 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, 399, 399), 72, fill=255)
graphic.paste(page, (60, 50), mask)

font = lambda size: ImageFont.truetype(str(ROOT / "assets" / "fonts" / "NotoSans.ttf"), size)
heading = font(84)
try:
    heading.set_variation_by_axes([700, 100])
except Exception:
    pass
draw.text((510, 130), "Polyscan", font=heading, fill="white")
draw.text((512, 245), "Scan paper. Read its text", font=font(40), fill="white")
draw.text((512, 297), "offline in 100+ languages.", font=font(40), fill="white")
graphic.save(OUT / "feature-graphic-1024x500.png")
