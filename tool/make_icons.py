"""Генератор собственных 3D-глянцевых иконок NutriMate (оригинальные рисунки, в стиле Fluent 3D).
Запуск: python3 tool/make_icons.py  -> assets/icons/p/<slug>.png (128 px)."""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 512  # рисуем крупно, потом уменьшаем
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'icons', 'p')

def rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def mix(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def shaded(mask, light, dark, cx=0.35, cy=0.3):
    """Заливка формы радиальным градиентом (свет сверху-слева) + блик + мягкая тень по краю."""
    bbox = mask.getbbox()
    x0, y0, x1, y1 = bbox; w, h = x1 - x0, y1 - y0
    grad = Image.new('RGB', (S, S))
    px = grad.load()
    lx, ly = x0 + w * cx, y0 + h * cy
    r = math.hypot(w, h) * 0.85
    L, D = rgb(light), rgb(dark)
    for y in range(y0, y1):
        for x in range(x0, x1):
            t = min(1, math.hypot(x - lx, y - ly) / r)
            px[x, y] = mix(L, D, t ** 1.2)
    layer = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    layer.paste(grad, (0, 0), mask)
    # затемнение по краю (объём)
    edge = ImageChops.subtract(mask, mask.filter(ImageFilter.MinFilter(9)).filter(ImageFilter.GaussianBlur(14)))
    dk = Image.new('RGBA', (S, S), D + (0,)); dk.putalpha(edge.point(lambda v: int(v * 0.45)))
    layer = Image.alpha_composite(layer, dk)
    return layer

def highlight(layer, mask, box, alpha=150):
    hl = Image.new('L', (S, S), 0)
    ImageDraw.Draw(hl).ellipse(box, fill=alpha)
    hl = hl.filter(ImageFilter.GaussianBlur(10))
    hl = ImageChops.multiply(hl, mask)
    white = Image.new('RGBA', (S, S), (255, 255, 255, 0)); white.putalpha(hl)
    return Image.alpha_composite(layer, white)

def blob(shape, light, dark, hl=None, **kw):
    m = Image.new('L', (S, S), 0); shape(ImageDraw.Draw(m))
    lay = shaded(m, light, dark, **kw)
    if hl: lay = highlight(lay, m, hl)
    return lay

def leaf(cx, cy, length, width, angle, light='#9BE15D', dark='#2E8B3E'):
    m = Image.new('L', (S, S), 0)
    pts = []
    for i in range(41):
        t = i / 40; along = t * length; off = math.sin(t * math.pi) * width / 2
        pts.append((along, off))
    pts += [(a, -o) for a, o in reversed(pts)]
    ca, sa = math.cos(angle), math.sin(angle)
    ImageDraw.Draw(m).polygon([(cx + a * ca - o * sa, cy + a * sa + o * ca) for a, o in pts], fill=255)
    lay = shaded(m, light, dark, 0.3, 0.2)
    return lay

def compose(*layers, shadow=True):
    out = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    for l in layers: out = Image.alpha_composite(out, l)
    if shadow:
        a = out.split()[3]
        sh = Image.new('RGBA', (S, S), (60, 20, 20, 0)); sh.putalpha(a.point(lambda v: int(v * 0.22)).filter(ImageFilter.GaussianBlur(10)))
        base = Image.new('RGBA', (S, S), (0, 0, 0, 0)); base.paste(sh, (6, 12), sh)
        out = Image.alpha_composite(base, out)
    return out

def save(img, slug):
    os.makedirs(OUT, exist_ok=True)
    img = img.resize((128, 128), Image.LANCZOS)
    img.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(os.path.join(OUT, slug + '.png'), optimize=True)

def ellipse(b): return lambda d: d.ellipse(b, fill=255)
def poly(p): return lambda d: d.polygon(p, fill=255)
def rrect(b, r): return lambda d: d.rounded_rectangle(b, r, fill=255)

def root(slug, light, dark, body, tail, leaves=3, tip='#FFFFFF'):
    ls = [leaf(256, body[1] + 20, 150, 60, -math.pi / 2 + (i - (leaves - 1) / 2) * 0.45) for i in range(leaves)]
    t = blob(poly(tail), light, dark)
    b = blob(ellipse(body), light, dark, hl=(body[0] + 50, body[1] + 35, body[0] + 150, body[1] + 110))
    save(compose(*ls, t, b), slug)

def make():
    # Редис: розово-красный шарик с белым кончиком
    root('radish', '#FF6F91', '#C2185B', (126, 170, 386, 420), [(236, 400), (276, 400), (256, 490)])
    # Свёкла: тёмно-бордовая
    root('beetroot', '#B0306A', '#4A0E2E', (116, 160, 396, 430), [(236, 410), (276, 410), (258, 500)])
    # Репа: белая с фиолетовой шапкой
    m = Image.new('L', (S, S), 0); ImageDraw.Draw(m).ellipse((116, 170, 396, 430), fill=255)
    top = Image.new('L', (S, S), 0); ImageDraw.Draw(top).rectangle((0, 0, S, 270), fill=255)
    purple = shaded(ImageChops.multiply(m, top.filter(ImageFilter.GaussianBlur(30))), '#C38DE0', '#6B2A8C')
    white = shaded(m, '#FFFFFF', '#CFC6BC')
    body = Image.alpha_composite(white, purple); body = highlight(body, m, (170, 205, 270, 280))
    save(compose(*[leaf(256, 190, 140, 60, -math.pi / 2 + k * 0.45) for k in (-1, 0, 1)], blob(poly([(236, 410), (276, 410), (256, 490)]), '#FFFFFF', '#CFC6BC'), body), 'turnip')
    # Дайкон: длинный белый корень по диагонали
    m = Image.new('L', (S, S), 0); d = ImageDraw.Draw(m)
    d.polygon([(165, 205), (235, 165), (450, 440), (425, 465)], fill=255); d.ellipse((140, 150, 250, 260), fill=255)
    dk = highlight(shaded(m, '#FFFFFF', '#C9C2B6'), m, (175, 175, 250, 235))
    save(compose(leaf(195, 190, 150, 70, -2.4), leaf(195, 190, 150, 70, -1.9), leaf(195, 190, 140, 60, -1.4), dk), 'daikon')
    # Гранат: красный шар с короной
    crown = blob(poly([(210, 120), (230, 60), (256, 105), (282, 60), (302, 120)]), '#E5486A', '#8E1030')
    g = blob(ellipse((96, 100, 416, 430)), '#FF5A6E', '#9A0F2E', hl=(150, 140, 260, 220))
    save(compose(g, crown), 'pomegranate')
    # Карамбола: жёлтая звезда
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5; r = 210 if i % 2 == 0 else 95
        pts.append((256 + r * math.cos(a), 270 + r * math.sin(a)))
    save(compose(blob(poly(pts), '#FFF27A', '#E0A100', hl=(180, 150, 280, 230))), 'star_fruit')
    # Тофу: белый кубик (три грани)
    def cube(slug, top, left, right):
        a = blob(poly([(256, 90), (446, 180), (256, 270), (66, 180)]), *top)
        b = blob(poly([(66, 180), (256, 270), (256, 450), (66, 360)]), *left)
        c = blob(poly([(256, 270), (446, 180), (446, 360), (256, 450)]), *right)
        save(compose(b, c, a), slug)
    cube('tofu', ('#FFFFFF', '#E8E1D2'), ('#EFE8DA', '#CFC5B2'), ('#E2D9C6', '#B8AD97'))
    cube('silken_tofu', ('#FFFDF5', '#F1ECDF'), ('#F7F2E6', '#DCD3C1'), ('#EEE7D8', '#C8BEAA'))
    cube('smoked_tofu', ('#E3B573', '#B07A35'), ('#C99550', '#8A5A22'), ('#B07D3C', '#6E4418'))
    cube('tempeh', ('#F0D9A8', '#C9A562'), ('#D9BC82', '#A88447'), ('#C8A86C', '#8E6C34'))
    # Чёрная икра: горка тёмных шариков в баночке
    tin = blob(ellipse((76, 230, 436, 420)), '#E9EDF2', '#8B96A3')
    beads = [blob(ellipse((x - 38, y - 38, x + 38, y + 38)), '#5A6470', '#0D1014', hl=(x - 24, y - 26, x - 4, y - 8)) for x, y in
             [(170, 290), (240, 280), (310, 285), (200, 240), (270, 235), (340, 250), (150, 250), (235, 195), (300, 200)]]
    save(compose(tin, *beads), 'black_caviar')
    # Курт: горка белых шариков
    balls = [blob(ellipse((x - 70, y - 70, x + 70, y + 70)), '#FFFFFF', '#CEC3AE', hl=(x - 45, y - 48, x - 5, y - 15)) for x, y in
             [(150, 370), (256, 380), (362, 370), (200, 270), (312, 270), (256, 170)]]
    save(compose(*balls), 'kurt')
    # Баурсаки: золотистые пышки
    bs = [blob(rrect((x - 85, y - 70, x + 85, y + 70), 55), '#FFD27A', '#B5651D', hl=(x - 55, y - 50, x + 5, y - 15)) for x, y in
          [(160, 360), (350, 360), (255, 250), (170, 160), (345, 165)]]
    save(compose(*bs), 'baursak')
    # Иримшик: оранжево-коричневые кусочки
    ir = [blob(rrect((x - 80, y - 60, x + 80, y + 60), 26), '#F6B26B', '#A45A16', hl=(x - 55, y - 45, x - 5, y - 15)) for x, y in
          [(170, 340), (340, 340), (255, 220)]]
    save(compose(*ir), 'irimshik')
    # Казы: колечко конской колбасы
    m = Image.new('L', (S, S), 0); d = ImageDraw.Draw(m); d.ellipse((76, 96, 436, 456), fill=255); d.ellipse((186, 206, 326, 346), fill=0)
    kz = highlight(shaded(m, '#C0504D', '#5E1414'), m, (130, 130, 230, 200))
    fat = blob(ellipse((116, 130, 170, 184)), '#FFF6EC', '#D9C7B1')
    save(compose(kz, fat), 'kazy')

if __name__ == '__main__':
    make()
