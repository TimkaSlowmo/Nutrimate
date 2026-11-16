"""Маленькая библиотека для рисования иконок продуктов NutriMate в стиле «объёмный глянцевый эмодзи»:
мягкие градиенты, блик слева сверху, мягкая тень снизу, без чёрных обводок, лёгкий ракурс 3/4.
Каждая иконка — компактный SVG 128×128 (общие градиенты на bbox объекта, без фильтров —
одинаково рендерится cairosvg, resvg, браузером и Flutter).

    I = Icon(); I.shadow(); I.p('M…', I.rg('#e33')); I.hl(50, 40, 10, 6); I.svg()
Шаблоны упаковок (bottle, jar, can, sachet, box, …) принимают «эмблему» — функцию (I) → рисует
символ продукта вокруг (0, 0) в квадрате ±12; её помещают на этикетку через I.at(x, y, k)."""
from contextlib import contextmanager


def _rgb(c):
    c = c.lstrip('#')
    if len(c) == 3: c = ''.join(x * 2 for x in c)
    return [int(c[i:i + 2], 16) for i in (0, 2, 4)]


def _hex(v):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(x))) for x in v)


def mix(a, b, t):
    a, b = _rgb(a), _rgb(b)
    return _hex([x + (y - x) * t for x, y in zip(a, b)])


def lt(c, t=.4): return mix(c, '#ffffff', t)
def dk(c, t=.3): return mix(c, '#000000', t)


def f(x):
    """Короткая запись числа."""
    s = ('%.1f' % x).rstrip('0').rstrip('.')
    return s if s != '-0' else '0'


class Icon:
    def __init__(self):
        self.defs, self.els = {}, []

    # ---- градиенты (id зависят от цвета → переиспользуются) ----
    def rg(self, c, light=.5, shade=.35, fx=.33, fy=.28):
        """Объём «шар»: свет слева сверху, тень справа снизу — для любой формы (bbox)."""
        i = 'r%s%d%d' % (c[1:], light * 10, shade * 10)
        self.defs.setdefault(i, f'<radialGradient id="{i}" cx="{fx + .07}" cy="{fy + .07}" fx="{fx}" fy="{fy}" r=".8">'
                                f'<stop offset="0" stop-color="{lt(c, light)}"/><stop offset=".5" stop-color="{c}"/>'
                                f'<stop offset="1" stop-color="{dk(c, shade)}"/></radialGradient>')
        return f'url(#{i})'

    def cyl(self, c, light=.45, shade=.4):
        """Объём «цилиндр» (бутылки, банки): блик у левого края, тень справа."""
        i = 'c%s%d%d' % (c[1:], light * 10, shade * 10)
        self.defs.setdefault(i, f'<linearGradient id="{i}"><stop offset="0" stop-color="{dk(c, .12)}"/>'
                                f'<stop offset=".22" stop-color="{lt(c, light)}"/><stop offset=".55" stop-color="{c}"/>'
                                f'<stop offset="1" stop-color="{dk(c, shade)}"/></linearGradient>')
        return f'url(#{i})'

    def vg(self, top, bottom):
        i = 'v%s%s' % (top[1:], bottom[1:])
        self.defs.setdefault(i, f'<linearGradient id="{i}" x2="0" y2="1"><stop offset="0" stop-color="{top}"/>'
                                f'<stop offset="1" stop-color="{bottom}"/></linearGradient>')
        return f'url(#{i})'

    # ---- примитивы ----
    def add(self, x):
        self.els.append(x)

    def p(self, d, fill, op=None, extra=''):
        self.add(f'<path d="{d}" fill="{fill}"' + (f' opacity="{op}"' if op is not None else '') + extra + '/>')

    def e(self, cx, cy, rx, ry, fill, op=None, rot=None):
        t = f' transform="rotate({f(rot)} {f(cx)} {f(cy)})"' if rot else ''
        self.add(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="{fill}"'
                 + (f' opacity="{op}"' if op is not None else '') + t + '/>')

    def c(self, cx, cy, r, fill, op=None):
        self.add(f'<circle cx="{f(cx)}" cy="{f(cy)}" r="{f(r)}" fill="{fill}"' + (f' opacity="{op}"' if op is not None else '') + '/>')

    def r(self, x, y, w, h, rx, fill, op=None):
        self.add(f'<rect x="{f(x)}" y="{f(y)}" width="{f(w)}" height="{f(h)}" rx="{f(rx)}" fill="{fill}"'
                 + (f' opacity="{op}"' if op is not None else '') + '/>')

    def line(self, d, color, w=2, op=None, cap='round'):
        self.add(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{f(w)}" stroke-linecap="{cap}" stroke-linejoin="round"'
                 + (f' opacity="{op}"' if op is not None else '') + '/>')

    @contextmanager
    def at(self, x, y, k=1.0, rot=0):
        self.add(f'<g transform="translate({f(x)} {f(y)})' + (f' rotate({f(rot)})' if rot else '') + (f' scale({f(k)})' if k != 1 else '') + '">')
        yield
        self.add('</g>')

    @contextmanager
    def clip(self, d):
        """Всё внутри рисуется только в пределах контура d (полоски, пятна на рыбе и т. п.)."""
        i = 'k%d' % len(self.defs)
        self.defs[i] = f'<clipPath id="{i}"><path d="{d}"/></clipPath>'
        self.add(f'<g clip-path="url(#{i})">')
        yield
        self.add('</g>')

    # ---- свет и тень ----
    def shadow(self, cx=64, cy=113, rx=40, ry=7, op=.32):
        self.defs.setdefault('sh', '<radialGradient id="sh"><stop offset="0" stop-color="#000" stop-opacity=".55"/>'
                                   '<stop offset=".6" stop-color="#000" stop-opacity=".25"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>')
        self.add(f'<ellipse cx="{f(cx)}" cy="{f(cy)}" rx="{f(rx)}" ry="{f(ry)}" fill="url(#sh)" opacity="{op * 2:.2g}"/>')

    def hl(self, cx, cy, rx, ry, rot=-35, op=.75):
        """Мягкий блик (белое пятно, тающее к краям)."""
        self.defs.setdefault('hl', '<radialGradient id="hl"><stop offset="0" stop-color="#fff" stop-opacity=".95"/>'
                                   '<stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>')
        self.e(cx, cy, rx, ry, 'url(#hl)', op, rot)

    def svg(self):
        d = ''.join(self.defs[k] for k in sorted(self.defs))
        return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">' + (f'<defs>{d}</defs>' if d else '')
                + ''.join(self.els) + '</svg>')


# ======================= упаковки =======================
GLASS = '#d9eef2'
METAL = '#b9c0c8'
GOLD = '#d8a640'


def bottle(I, liquid, cap, label=None, emblem=None, w=24, neck=8, top=14, shoulder=46, cap_h=12, glass_hl=True, label_y=(64, 98)):
    """Бутылка соуса/масла/уксуса. w — полуширина корпуса, neck — полуширина горлышка."""
    x0, x1 = 64 - w, 64 + w
    I.shadow(rx=w + 14)
    I.p(f'M{x0} {shoulder + 12}C{x0} {shoulder} {64 - neck} {shoulder - 2} {64 - neck} {shoulder - 12}V{top + cap_h - 2}H{64 + neck}'
        f'V{shoulder - 12}C{64 + neck} {shoulder - 2} {x1} {shoulder} {x1} {shoulder + 12}V106Q{x1} 113 {x1 - 7} 113H{x0 + 7}Q{x0} 113 {x0} 106Z',
        I.cyl(liquid, .35, .45))
    if label:
        I.p(f'M{x0} {label_y[0]}H{x1}V{label_y[1]}H{x0}Z', I.cyl(label, .35, .3))
    if glass_hl:
        I.r(x0 + 4, shoulder + 6, 4, 104 - shoulder - 6, 2, '#fff', .35)
        I.r(64 - neck + 2, top + cap_h, 2.5, shoulder - top - cap_h - 6, 1.2, '#fff', .4)
    I.r(64 - neck - 2, top, 2 * neck + 4, cap_h, 3, I.cyl(cap, .4, .4))
    I.e(64, top + 1, neck + 1.5, 2, lt(cap, .35))
    if emblem:
        with I.at(64, (label_y[0] + label_y[1]) / 2, 1.25):
            emblem(I)


def squeeze(I, body, cap, emblem=None, label=None):
    """Мягкая бутылка-дозатор (кетчуп, горчица, майонез, шрирача)."""
    I.shadow(rx=36)
    I.p('M40 54Q40 44 52 44H76Q88 44 88 54V104Q88 113 78 113H50Q40 113 40 104Z', I.cyl(body, .45, .4))
    if label:
        I.p('M40 66H88V98H40Z', I.cyl(label, .35, .25))
    I.p('M50 45L55 27H73L78 45Z', I.cyl(cap, .45, .4))
    I.r(60, 14, 8, 15, 3, I.cyl(cap, .4, .45))
    I.r(45, 52, 4, 46, 2, '#fff', .4)
    if emblem:
        with I.at(64, 82, 1.25): emblem(I)


def jar(I, content, lid, label=None, emblem=None, glass=True, lid_top=30):
    """Широкая банка с крышкой (паста, джем, спред, хрен)."""
    I.shadow(rx=40)
    I.p('M36 48Q36 44 40 44H88Q92 44 92 48V104Q92 113 83 113H45Q36 113 36 104Z', I.cyl(content, .35, .4))
    if glass:
        I.r(40, 50, 4, 54, 2, '#fff', .4)
    if label:
        I.p('M36 62H92V98H36Z', I.cyl(label, .35, .25))
    I.r(33, lid_top, 62, 17, 4, I.cyl(lid, .45, .4))
    I.e(64, lid_top + 1.5, 29, 2.5, lt(lid, .4))
    for x in (40, 48, 56, 64, 72, 80, 88):
        I.r(x - .6, lid_top + 5, 1.2, 10, .6, dk(lid, .25), .35)
    if emblem:
        with I.at(64, 80, 1.3): emblem(I)


def tub(I, body, lid, emblem=None, band=None):
    """Пластиковая баночка (мисо, сметана, творожный сыр)."""
    I.shadow(rx=42)
    I.p('M30 54H98L92 105Q91 112 84 112H44Q37 112 36 105Z', I.cyl(body, .45, .3))
    if band:
        I.p('M31.5 66H96.5L94 90H34Z', I.cyl(band, .3, .25))
    I.p('M26 44Q26 40 32 40H96Q102 40 102 44V52Q102 56 96 56H32Q26 56 26 52Z', I.cyl(lid, .45, .35))
    I.e(64, 41.5, 36, 4, lt(lid, .45))
    I.r(36, 60, 4, 40, 2, '#fff', .35)
    if emblem:
        with I.at(64, 80, 1.35): emblem(I)


def can(I, label, emblem=None, top=METAL, band=None, h=(34, 106), rx=28):
    """Консервная банка."""
    t, b = h
    x0, x1 = 64 - rx, 64 + rx
    I.shadow(rx=rx + 10, cy=b + 6)
    I.p(f'M{x0} {t}V{b}A{rx} 7 0 0 0 {x1} {b}V{t}Z', I.cyl(top, .5, .4))
    I.p(f'M{x0} {t + 9}V{b - 7}A{rx} 7 0 0 0 {x1} {b - 7}V{t + 9}A{rx} 7 0 0 1 {x0} {t + 9}Z', I.cyl(label, .4, .35))
    if band:
        I.p(f'M{x0} {b - 20}V{b - 10}A{rx} 7 0 0 0 {x1} {b - 10}V{b - 20}A{rx} 7 0 0 1 {x0} {b - 20}Z', I.cyl(band, .35, .35))
    I.e(64, t, rx, 7, I.rg(lt(top, .1), .5, .25))
    I.e(64, t, rx - 4, 5, dk(top, .12), .5)
    I.e(64, t + .8, rx - 5, 4, lt(top, .25))
    I.r(x0 + 4, t + 12, 3.5, b - t - 24, 1.7, '#fff', .35)
    if emblem:
        with I.at(64, (t + b) / 2 + 3, 1.35): emblem(I)


def sachet(I, color, emblem=None, top=None, window=None):
    """Пакетик (желатин, разрыхлитель, ванильный сахар, дрожжи)."""
    top = top or dk(color, .2)
    I.shadow(rx=38)
    I.p('M34 30Q34 26 38 26H90Q94 26 94 30V104Q94 110 88 110H40Q34 110 34 104Z', I.rg(color, .45, .25))
    I.p('M34 24H94V36H34Z', I.vg(lt(top, .15), dk(top, .1)))
    I.p('M34 24' + ''.join(f'L{36 + 4 * i} {21 if i % 2 == 0 else 24}' for i in range(15)) + 'L94 24Z', lt(top, .15))
    I.p('M34 104' + ''.join(f'L{36 + 4 * i} {113 if i % 2 == 0 else 110}' for i in range(15)) + 'L94 110Z', dk(color, .15))
    if window:
        I.r(44, 82, 40, 16, 6, window)
        I.r(46, 84, 18, 4, 2, '#fff', .5)
    I.hl(46, 48, 9, 16, -10, .45)
    if emblem:
        with I.at(64, 64 if window else 70, 1.55): emblem(I)


def box(I, front, emblem=None, side=None, top=None, band=None):
    """Картонная коробка 3/4 (сода, чай, крахмал)."""
    side = side or dk(front, .25)
    top = top or lt(front, .25)
    I.shadow(cx=66, rx=42)
    I.p('M30 44H80V112H30Z', I.vg(lt(front, .08), dk(front, .08)))
    I.p('M80 44L98 34V102L80 112Z', I.vg(side, dk(side, .1)))
    I.p('M30 44L48 34H98L80 44Z', top)
    if band:
        I.p('M30 92H80V104H30Z', band)
        I.p('M80 92L98 82V94L80 104Z', dk(band, .25))
    I.hl(40, 54, 6, 10, -10, .35)
    if emblem:
        with I.at(55, 72, 1.5): emblem(I)


def pouch(I, color, emblem=None, window=None):
    """Дой-пак (порошки: какао, баобаб, лукума)."""
    I.shadow(rx=40)
    I.p('M36 30Q36 26 40 26H88Q92 26 92 30L97 104Q97 112 89 112H39Q31 112 31 104Z', I.rg(color, .4, .3))
    I.p('M36 36H92', 'none')
    I.line('M37 37H91', dk(color, .2), 2, .6)
    I.c(86, 31, 2, dk(color, .35))
    if window:
        I.p('M44 80H84L86 100H42Z', window)
        I.p('M45 82H62L61 86H45Z', '#fff', .45)
    I.hl(46, 50, 8, 16, -10, .4)
    if emblem:
        with I.at(64, 60 if window else 70, 1.5): emblem(I)


def shaker(I, powder, cap, emblem=None, fill=.85, label=None):
    """Стеклянная баночка для специй с порошком."""
    I.shadow(rx=30)
    I.p('M42 50Q42 46 46 46H82Q86 46 86 50V106Q86 112 80 112H48Q42 112 42 106Z', I.cyl(GLASS, .4, .25), .65)
    yt = 112 - 62 * fill
    I.p(f'M43 {yt}H85V106Q85 111 80 111H48Q43 111 43 106Z', I.cyl(powder, .3, .35))
    for i, x in enumerate(range(47, 84, 7)):
        I.c(x, yt + 1 + (i % 2), 3.2, lt(powder, .1))
    if label:
        I.p('M42 70H86V96H42Z', I.cyl(label, .3, .25))
    I.r(46, 52, 3.5, 52, 1.7, '#fff', .45)
    I.r(40, 28, 48, 20, 5, I.cyl(cap, .45, .4))
    I.e(64, 29.5, 22, 2.5, lt(cap, .4))
    if emblem:
        with I.at(64, 83, 1.1): emblem(I)


def carton(I, color, emblem=None, side=None, cap=None):
    """Пакет с «крышей» (молоко, сливки, сок)."""
    side = side or dk(color, .22)
    I.shadow(cx=66, rx=40)
    I.p('M32 50H76V112H32Z', I.vg(lt(color, .05), dk(color, .06)))
    I.p('M76 50L96 42V104L76 112Z', I.vg(side, dk(side, .1)))
    I.p('M32 50L54 30L76 50Z', lt(color, .12))
    I.p('M54 30L74 22L96 42L76 50Z', dk(color, .1))
    I.p('M51 30L71 22V17L51 25Z', lt(color, .2))
    if cap:
        I.e(64, 40, 6, 3, dk(cap, .2)); I.r(58, 33, 12, 7, 3, I.cyl(cap, .4, .4))
    I.hl(41, 62, 5, 10, -10, .35)
    if emblem:
        with I.at(54, 84, 1.45): emblem(I)


def glass_cup(I, liquid, handle=True, saucer='#f4efe6', glass=GLASS):
    """Стеклянная чашка с чаем/напитком на блюдце."""
    I.e(62, 104, 46, 10, dk(saucer, .25), .5)
    I.e(62, 101, 46, 10, I.rg(saucer, .4, .2))
    I.e(62, 99, 30, 5, dk(saucer, .1))
    if handle:
        I.line('M88 62Q104 62 102 76Q100 88 84 88', lt(glass, .2), 7, .8)
    I.p('M28 52H96Q96 88 76 98H48Q28 88 28 52Z', I.cyl(glass, .4, .25), .55)
    I.p('M30 60H94Q93 87 75 96H49Q31 87 30 60Z', I.cyl(liquid, .3, .35))
    I.e(62, 60, 32, 6, lt(liquid, .15))
    I.e(62, 60, 26, 4, dk(liquid, .1), .6)
    I.e(62, 52, 34, 6.5, 'none')
    I.add(f'<ellipse cx="62" cy="52" rx="34" ry="6" fill="none" stroke="{lt(glass, .3)}" stroke-width="2" opacity=".8"/>')
    I.r(34, 62, 4, 22, 2, '#fff', .5)


# ======================= эмблемы для этикеток (вокруг 0,0; ±12) =======================
def em_fish(c='#5b8fb0', belly=None):
    def d(I):
        I.p('M-11 0C-6 -8 6 -8 9 0C6 8 -6 8 -11 0Z', I.rg(c, .5, .3))
        if belly: I.p('M-9 1C-4 6 5 6 8 1Z', belly, .8)
        I.p('M8 0L14 -6V6Z', dk(c, .1))
        I.c(-6, -1.5, 1.4, '#1d1d2b')
        I.c(-6.4, -2, .5, '#fff')
    return d


def em_oyster(I):
    I.p('M-12 4C-12 -8 12 -8 12 4C6 9 -6 9 -12 4Z', I.rg('#8d8a86', .5, .3))
    for x in (-7, -3, 1, 5):
        I.line(f'M{x} -5Q{x + 1} 0 {x} 5', '#5f5b57', 1, .6)
    I.c(0, 2, 3.4, I.rg('#f6f2ec', .6, .2))


def em_garlic(I):
    I.p('M0 -12C2 -8 3 -7 6 -5C12 -1 11 9 4 11H-4C-11 9 -12 -1 -6 -5C-3 -7 -2 -8 0 -12Z', I.rg('#f4eee4', .6, .25))
    I.line('M0 -6Q-3 2 -2 10M0 -6Q4 2 3 10', '#cfc2ad', 1.1)


def em_chili(I):
    I.p('M-9 -5C-4 -2 2 -3 6 -6C10 -2 8 6 0 9C-6 11 -11 9 -12 7C-6 7 -2 4 -9 -5Z', I.rg('#e0252b', .5, .3))
    I.p('M5 -6C6 -9 8 -11 11 -11', 'none')
    I.line('M5 -6Q7 -10 11 -11', '#3c8d2f', 2.4)


def em_leaf(c='#5aa63a'):
    def d(I):
        I.p('M-10 8C-10 -4 0 -11 11 -11C11 1 3 9 -10 8Z', I.rg(c, .45, .3))
        I.line('M-8 6Q0 -1 8 -8', dk(c, .3), 1, .8)
    return d


def em_drop(c):
    def d(I):
        I.p('M0 -12C4 -5 8 -1 8 4C8 9 4 12 0 12C-4 12 -8 9 -8 4C-8 -1 -4 -5 0 -12Z', I.rg(c, .5, .3))
        I.e(-3, 3, 1.8, 3, '#fff', .6)
    return d


def em_bowl(c, steam=True):
    def d(I):
        I.p('M-12 -1H12C12 7 6 11 0 11C-6 11 -12 7 -12 -1Z', I.rg('#f3ede2', .4, .25))
        I.e(0, -1, 12, 3, c)
        if steam:
            I.line('M-4 -5Q-6 -8 -4 -11M3 -5Q1 -8 3 -11', '#ffffff', 1.4, .8)
    return d


def em_bean(c):
    def d(I):
        for x, y, r in ((-5, 2, -20), (5, -2, 25)):
            I.e(x, y, 6, 4.2, I.rg(c, .5, .3), rot=r)
    return d


def em_tomato(I):
    I.c(0, 2, 9.5, I.rg('#e63a2b', .5, .3))
    I.p('M0 -8L3 -4L7 -6L4 -2L-4 -2L-7 -6L-3 -4Z', '#3f8f2a')


def em_cube(c):
    def d(I):
        I.p('M-8 -4L0 -8L8 -4L0 0Z', lt(c, .35))
        I.p('M-8 -4L0 0V10L-8 6Z', c)
        I.p('M8 -4L0 0V10L8 6Z', dk(c, .2))
        I.e(-4, -2, 2, 1, '#fff', .7)
    return d


def em_bubbles(c='#ffffff'):
    def d(I):
        for x, y, r in ((-5, 4, 5), (5, 0, 4), (0, -7, 3), (8, 8, 2.5)):
            I.c(x, y, r, c, .85)
            I.c(x - r * .35, y - r * .35, r * .3, '#fff')
    return d


# ======================= реестр иконок =======================
REG = []


def icon(slug, *products):
    """@icon('fish_sauce', 'Fish Sauce') — регистрирует рисунок для продукта(ов)."""
    def deco(fn):
        REG.append((slug, products, fn))
        return fn
    return deco


def em_vanilla(I):
    I.line('M-10 9Q0 -2 11 -11', '#3a2212', 3)
    I.line('M-7 10Q2 0 12 -8', '#4e2e18', 2.4)
    for a, b in ((-2, -6), (3, -9), (-6, -8)):
        pass
    I.c(-4, -6, 4, I.rg('#f7f0d2', .5, .2))
    I.c(-4, -6, 1.5, '#e8c448')
