"""Рисует тестовые «фото» еды для проверки распознавания (свои картинки, без чужих лицензий).
python3 tool/make_test_photos.py → server/fixtures/bananas.jpg, apples.jpg"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'server', 'fixtures')
W, H = 768, 576
random.seed(7)

def table():
    im = Image.new('RGB', (W, H), (150, 105, 70)); d = ImageDraw.Draw(im)
    for y in range(0, H, 3):
        c = 140 + int(18 * math.sin(y / 23.0) + random.randint(-6, 6))
        d.line([(0, y), (W, y)], fill=(c, int(c * .70), int(c * .46)), width=3)
    for _ in range(60):
        x = random.randint(0, W); y = random.randint(0, H)
        d.arc([x - 80, y - 6, x + 80, y + 6], 0, 180, fill=(110, 75, 48), width=1)
    return im.filter(ImageFilter.GaussianBlur(1.2))

def shade(layer, mask, light, dark, lx, ly, r):
    g = Image.new('RGB', (W, H)); px = g.load(); bb = mask.getbbox()
    for y in range(bb[1], bb[3]):
        for x in range(bb[0], bb[2]):
            t = min(1, math.hypot(x - lx, y - ly) / r)
            px[x, y] = tuple(int(light[i] + (dark[i] - light[i]) * t ** 1.3) for i in range(3))
    layer.paste(g, (0, 0), mask)

def shadow(im, mask, dx=14, dy=18):
    sh = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sh.paste((40, 22, 10, 120), (dx, dy), mask)
    return Image.alpha_composite(im.convert('RGBA'), sh.filter(ImageFilter.GaussianBlur(14)))

def banana(sx, sy, ang, L=330, bend=0.55, th=46):
    """Банан: изогнутая толстая дуга от черешка (sx, sy) в направлении ang."""
    m = Image.new('L', (W, H), 0); d = ImageDraw.Draw(m)
    up, lo = [], []
    a0 = math.radians(ang)
    for i in range(41):
        t = i / 40
        a = a0 + bend * (t - .5) * 1.6
        x = sx + L * t * math.cos(a0) + 0; y = sy + L * t * math.sin(a0) - 90 * math.sin(math.pi * t) * bend
        w = th * (math.sin(math.pi * min(1, t * 1.05)) ** .6) * (0.35 if t < .08 else 1) + 4
        nx, ny = -math.sin(a), math.cos(a)
        up.append((x + nx * w / 2, y + ny * w / 2)); lo.append((x - nx * w / 2, y - ny * w / 2))
    d.polygon(up + lo[::-1], fill=255)
    return m, (up[-1][0] + lo[-1][0]) / 2, (up[-1][1] + lo[-1][1]) / 2

def bananas():
    im = table()
    sx, sy = 230, 330
    specs = [(-28, 360), (-14, 380), (0, 390), (14, 375), (28, 350)]
    bs = [banana(sx, sy, a, L) for a, L in specs]
    allm = Image.new('L', (W, H), 0)
    for m, _, _ in bs: allm.paste(255, (0, 0), m)
    im = shadow(im, allm)
    for i, (m, tx, ty) in enumerate(bs):
        edge = Image.new('RGBA', (W, H), (0, 0, 0, 0)); edge.paste((150, 110, 20, 255), (0, 0), m.filter(ImageFilter.MaxFilter(5)))
        im = Image.alpha_composite(im, edge)
        lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); shade(lay, m, (255, 236, 110), (205, 160, 25), sx + 150, sy - 120, 330)
        im = Image.alpha_composite(im, lay)
        d = ImageDraw.Draw(im); d.ellipse([tx - 7, ty - 7, tx + 7, ty + 7], fill=(60, 45, 20))
        for _ in range(4):  # веснушки спелости
            bb = m.getbbox(); x = random.randint(bb[0] + 60, bb[2] - 30); y = random.randint(bb[1], bb[3])
            if m.getpixel((x, y)) > 0: d.ellipse([x - 2, y - 2, x + 2, y + 2], fill=(140, 100, 30))
    d = ImageDraw.Draw(im)
    d.polygon([(sx - 40, sy - 18), (sx + 10, sy - 26), (sx + 14, sy + 18), (sx - 40, sy + 14)], fill=(110, 140, 50))
    d.ellipse([sx - 52, sy - 20, sx - 30, sy + 16], fill=(80, 70, 35))
    return im.convert('RGB').filter(ImageFilter.GaussianBlur(.6))

def apples():
    im = table()
    for (cx, cy, r) in [(250, 300, 120), (480, 320, 115), (370, 190, 105)]:
        m = Image.new('L', (W, H), 0); ImageDraw.Draw(m).ellipse([cx - r, cy - r * .92, cx + r, cy + r], fill=255)
        im = shadow(im, m)
        lay = Image.new('RGBA', (W, H), (0, 0, 0, 0)); shade(lay, m, (250, 90, 80), (120, 10, 20), cx - r * .45, cy - r * .5, r * 1.7)
        im = Image.alpha_composite(im, lay); d = ImageDraw.Draw(im)
        d.line([(cx, cy - r * .85), (cx + 10, cy - r * 1.15)], fill=(90, 60, 30), width=9)
        d.ellipse([cx + 8, cy - r * 1.2, cx + 60, cy - r * .98], fill=(70, 150, 50))
        d.ellipse([cx - r * .55, cy - r * .6, cx - r * .25, cy - r * .35], fill=(255, 210, 200))
    return im.convert('RGB').filter(ImageFilter.GaussianBlur(.7))

if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    bananas().save(os.path.join(OUT, 'bananas.jpg'), quality=82)
    apples().save(os.path.join(OUT, 'apples.jpg'), quality=82)
    print('ok')
