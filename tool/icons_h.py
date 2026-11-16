"""Иконки: грибы (31 × 🍄), бобовые (42 × 🫘), крупы (39 × 🌾), паста (31 × 🍝), масла и уксусы, сахар."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf
from icons_a import em_sesame
from icons_g import em_apple, em_grape


def heap(I, n, draw, cx=64, cy=90, rx=38, ry=13, h=26, bowl=None):
    """Горка из n элементов; draw(I, x, y, i) рисует один. bowl — цвет миски (или None)."""
    if bowl:
        I.shadow(rx=46, cy=108)
        I.p(f'M18 84H110Q108 108 82 112H46Q20 108 18 84Z', I.cyl(bowl, .4, .3))
        I.e(64, 84, 46, 10, dk(bowl, .25))
    else:
        I.shadow(rx=rx + 6)
    pts = []
    for i in range(n):
        a, t = i * 2.39996, math.sqrt((i + .5) / n)
        pts.append((cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t - (1 - t) * h, i))
    for x, y, i in sorted(pts, key=lambda p: p[1]):
        draw(I, x, y, i)


# ======================= грибы =======================
def mushroom(I, x, y, k, cap, stem='#f2ead8', shape='dome', rot=0, gills=None):
    with I.at(x, y, k, rot):
        I.p('M-8 0C-9 14 -10 26 -6 32Q0 35 6 32C10 26 9 14 8 0Z', I.cyl(stem, .45, .3))
        if shape == 'dome':
            I.p('M-26 2C-26 -20 -12 -30 0 -30C12 -30 26 -20 26 2Q0 8 -26 2Z', I.rg(cap, .45, .35))
        elif shape == 'flat':
            I.p('M-30 0C-28 -12 -14 -18 0 -18C14 -18 28 -12 30 0Q0 6 -30 0Z', I.rg(cap, .45, .35))
            if gills: I.p('M-28 1Q0 8 28 1Q0 12 -28 1Z', gills)
        elif shape == 'bun':
            I.p('M-24 4C-30 -14 -16 -28 0 -28C16 -28 30 -14 24 4Q0 10 -24 4Z', I.rg(cap, .45, .35))
        I.hl(-9, -16, 7, 4, -20, .6)


@icon('champignons', 'Champignons')
def ic_champignons(I):
    I.shadow(rx=44)
    mushroom(I, 84, 62, .95, '#f4efe6', rot=10)
    mushroom(I, 46, 72, 1.1, '#f7f3ec', rot=-8)


@icon('porcini', 'Porcini Mushrooms')
def ic_porcini(I):
    I.shadow(rx=44)
    with I.at(64, 62, 1.2):
        I.p('M-12 0C-18 14 -16 30 -6 34Q0 36 6 34C16 30 18 14 12 0Z', I.cyl('#efe2c4', .45, .3))
        I.p('M-26 4C-30 -14 -16 -28 0 -28C16 -28 30 -14 26 4Q0 10 -26 4Z', I.rg('#8a4a1e', .45, .35))
        I.p('M-25 4Q0 10 25 4Q0 14 -25 4Z', '#e8d8a0')
        I.hl(-9, -16, 7, 4, -20, .6)


@icon('chanterelles', 'Chanterelles')
def ic_chanterelles(I):
    I.shadow(rx=44)
    for x, y, k, r in ((44, 70, 1.0, -15), (82, 66, 1.05, 12), (64, 86, .85, 0)):
        with I.at(x, y, k, r):
            I.p('M-24 -14C-20 -22 20 -22 24 -14C20 -8 10 -2 6 4L5 28Q0 31 -5 28L-6 4C-10 -2 -20 -8 -24 -14Z', I.rg('#f2a81c', .5, .35))
            I.e(0, -15, 22, 5, '#f8c84a')
            I.line('M-14 -10Q-6 6 -4 20M0 -9V24M14 -10Q6 6 4 20', '#d8861a', 1.2, .6)


@icon('enoki', 'Enoki Mushrooms')
def ic_enoki(I):
    I.shadow(rx=36)
    for i in range(13):
        x = 50 + i * 2.3
        x2 = 64 + (i - 6) * 5.2
        y2 = 30 + abs(i - 6) * 2.2
        I.line(f'M{f(x)} 104Q{f((x + x2) / 2)} 70 {f(x2)} {f(y2)}', '#f2eedf', 2.6)
    for i in range(13):
        x2 = 64 + (i - 6) * 5.2
        y2 = 30 + abs(i - 6) * 2.2
        I.e(x2, y2 - 2, 3.6, 3, I.rg('#f4e8c4', .5, .3))
    I.p('M46 92H82L80 108Q64 112 48 108Z', I.cyl('#c9b07a', .4, .3))


@icon('oyster_mushrooms', 'Oyster Mushrooms')
def ic_oyster_mushrooms(I):
    I.shadow(rx=44)
    for x, y, k, r in ((50, 76, 1.1, -20), (78, 64, 1.0, 15), (70, 92, .85, 30)):
        with I.at(x, y, k, r):
            I.p('M-30 -6C-28 -24 22 -26 28 -8C30 4 14 12 4 14L2 22H-4L-6 14C-18 12 -32 6 -30 -6Z', I.rg('#9aa0a8', .45, .3))
            I.line('M-20 -4Q-2 8 0 18M0 -10V18M18 -6Q4 6 2 18', '#d8dce0', 1.2, .7)


@icon('shiitake', 'Shiitake Mushrooms')
def ic_shiitake(I):
    I.shadow(rx=44)
    for x, y, k, r in ((82, 62, .95, 12), (46, 74, 1.1, -10)):
        mushroom(I, x, y, k, '#6a3a1c', '#efe2c6', 'flat', r)
        with I.at(x, y, k, r):
            for a, b in ((-18, -8), (-4, -14), (10, -10), (18, -4), (-10, -4)):
                I.line(f'M{a} {b}l5 -2', '#c9a47a', 1.4, .8)


@icon('morels', 'Morels')
def ic_morels(I):
    I.shadow(rx=44)
    for x, y, k, r in ((46, 64, 1.0, -12), (82, 66, .95, 14)):
        with I.at(x, y, k, r):
            I.p('M-7 20V36Q0 39 7 36V20Z', I.cyl('#efe2c4', .45, .3))
            body = 'M0 -34C12 -30 16 -8 15 8C14 18 8 22 0 22C-8 22 -14 18 -15 8C-16 -8 -12 -30 0 -34Z'
            I.p(body, I.rg('#8a6a3e', .4, .4))
            with I.clip(body):
                for row in range(7):
                    for i in range(-2, 3):
                        I.e(i * 7 + (row % 2) * 3.5, -26 + row * 7.5, 3, 3.2, '#4a3418', .8)


@icon('king_oyster', 'King Oyster Mushrooms')
def ic_king_oyster(I):
    I.shadow(rx=40)
    for x, r in ((50, -14), (78, 12)):
        with I.at(x, 64, 1, r):
            I.p('M-11 -20C-14 0 -14 26 -9 40Q0 44 9 40C14 26 14 0 11 -20Z', I.cyl('#f4efe2', .45, .25))
            I.p('M-18 -18C-18 -30 18 -30 18 -18Q0 -12 -18 -18Z', I.rg('#a8885a', .45, .35))
            I.hl(-6, 0, 2.5, 14, 0, .6)


@icon('portobello', 'Portobello')
def ic_portobello(I):
    I.shadow(rx=48)
    with I.at(64, 66, 1.25):
        I.p('M-8 4C-9 16 -9 24 -6 28Q0 30 6 28C9 24 9 16 8 4Z', I.cyl('#efe6d4', .45, .3))
        I.p('M-38 4C-36 -14 -18 -22 0 -22C18 -22 36 -14 38 4Q0 12 -38 4Z', I.rg('#7a5a3e', .45, .35))
        I.p('M-36 5Q0 12 36 5Q0 18 -36 5Z', '#4a2e1e')
        for k in range(-5, 6):
            I.line(f'M{k * 6} 9l{k} 4', '#2e1a10', .8, .7)
        I.hl(-12, -12, 9, 4, -15, .55)


# ======================= бобовые =======================
def bean(c, rx, ry, eye=None, kidney=False):
    def d(I, x, y, i):
        with I.at(x, y, 1, (i * 47) % 180):
            if kidney:
                I.p(f'M{-rx} 0C{-rx} {-ry * 1.2} {rx} {-ry * 1.2} {rx} 0C{rx} {ry} {rx * .3} {ry * .9} 0 {ry * .4}C{-rx * .3} {ry * .9} {-rx} {ry} {-rx} 0Z', I.rg(c, .5, .3))
            else:
                I.e(0, 0, rx, ry, I.rg(c, .5, .3))
            if eye: I.e(0, ry * .55, rx * .3, ry * .22, eye)
    return d


@icon('red_lentils', 'Red Lentils')
def ic_red_lentils(I):
    heap(I, 48, lambda I, x, y, i: I.e(x, y, 4.2, 3, I.rg('#f0743a', .5, .3)), bowl='#f2ede4')


@icon('green_lentils', 'Green Lentils')
def ic_green_lentils(I):
    heap(I, 48, lambda I, x, y, i: I.e(x, y, 4.4, 3.1, I.rg('#7a8a4a', .5, .3)), bowl='#f2ede4')


@icon('lentils', 'Lentils')
def ic_lentils(I):
    heap(I, 48, lambda I, x, y, i: I.e(x, y, 4.4, 3.1, I.rg('#a8743a', .5, .3)), bowl='#8a5a34')


@icon('chickpeas', 'Chickpeas')
def ic_chickpeas(I):
    def d(I, x, y, i):
        I.c(x, y, 7.5, I.rg('#e8c27a', .5, .3))
        I.p(f'M{f(x + 1)} {f(y - 7.5)}Q{f(x + 4)} {f(y - 10)} {f(x + 6)} {f(y - 6)}', '#e8c27a')
        I.line(f'M{f(x)} {f(y - 7)}Q{f(x - 3)} {f(y - 1)} {f(x + 1)} {f(y + 2)}', '#c29a52', 1, .7)
    heap(I, 22, d)


@icon('kidney_beans', 'Kidney Beans')
def ic_kidney(I):
    heap(I, 18, bean('#8a1a24', 10, 5.5, kidney=True))


@icon('black_beans', 'Black Beans')
def ic_black_beans(I):
    heap(I, 26, bean('#24202a', 7, 4.5, eye='#f2f2f2'))


@icon('white_beans', 'White Beans')
def ic_white_beans(I):
    heap(I, 20, bean('#f2ead2', 9, 5.5))


@icon('split_peas', 'Split Peas')
def ic_split_peas(I):
    def d(I, x, y, i):
        I.c(x, y, 5, I.rg('#b8c83a', .5, .3))
        I.line(f'M{f(x - 4)} {f(y)}H{f(x + 4)}', '#8a9a1e', .9, .6)
    heap(I, 34, d, bowl='#f2ede4')


@icon('mung_beans', 'Mung Beans')
def ic_mung(I):
    heap(I, 44, lambda I, x, y, i: I.e(x, y, 4, 3, I.rg('#4f9a3a', .5, .3), rot=(i * 41) % 180), bowl='#f2ede4')


@icon('soybeans', 'Soybeans')
def ic_soybeans(I):
    heap(I, 26, bean('#e6c46a', 7, 6))


# ======================= крупы =======================
@icon('buckwheat', 'Buckwheat')
def ic_buckwheat(I):
    def d(I, x, y, i):
        with I.at(x, y, 1, (i * 53) % 360):
            I.p('M0 -5L4.5 3.5H-4.5Z', I.rg('#9a5a2a', .5, .3))
    heap(I, 56, d, bowl='#f2ede4')


@icon('quinoa', 'Quinoa')
def ic_quinoa(I):
    heap(I, 70, lambda I, x, y, i: I.c(x, y, 2.6, I.rg(('#f2e2b8', '#e8cc8a', '#c8503a')[0 if i % 9 else 2] if i % 3 else '#e8cc8a', .5, .3)), bowl='#4a6a8a', rx=36, ry=8, h=18, cy=84)


@icon('couscous', 'Couscous')
def ic_couscous(I):
    heap(I, 80, lambda I, x, y, i: I.c(x, y, 2.2, ('#f2cc6a', '#e8b850', '#f8dc8a')[i % 3]), bowl='#2f6fa8', rx=36, ry=8, h=18, cy=84)
    I.hl(56, 72, 8, 3, -10, .5)


@icon('bulgur', 'Bulgur')
def ic_bulgur(I):
    def d(I, x, y, i):
        I.p(f'M{f(x - 3)} {f(y - 2)}l6 -.5l-.5 5l-5 -.5Z', ('#c8964a', '#b8823a', '#d8aa5e')[i % 3])
    heap(I, 64, d, bowl='#7a4a2a', rx=36, ry=8, h=18, cy=84)


@icon('pearl_barley', 'Pearl Barley')
def ic_pearl_barley(I):
    def d(I, x, y, i):
        I.e(x, y, 4, 3, I.rg('#efe2c2', .5, .3))
        I.e(x, y, 2.6, .6, '#b8a070')
    heap(I, 40, d, bowl='#6a8a4a')


@icon('millet', 'Millet')
def ic_millet(I):
    heap(I, 70, lambda I, x, y, i: I.c(x, y, 2.6, I.rg('#f2c41a', .55, .3)), bowl='#f2ede4', rx=36, ry=8, h=18, cy=84)


@icon('semolina', 'Semolina')
def ic_semolina(I):
    I.shadow(rx=46, cy=108)
    I.p('M18 84H110Q108 108 82 112H46Q20 108 18 84Z', I.cyl('#f2ede4', .4, .3))
    I.e(64, 84, 46, 10, '#d8d0c0')
    I.p('M24 84C34 66 52 60 64 60C78 60 94 66 104 84Z', I.rg('#f6e2a8', .4, .2))
    dots(I, 64, 76, 34, 10, 40, .9, '#e0c47a', .8)


@icon('flour', 'Flour')
def ic_flour(I):
    from icons_g import sack
    def em(I):
        I.line('M0 12V-12', '#c89a3a', 1.4)
        for y in (-8, -3, 2):
            I.e(-3, y, 2.5, 4.5, '#e2b85a', rot=-30); I.e(3, y, 2.5, 4.5, '#e2b85a', rot=30)
        I.e(0, -12, 2, 3.5, '#e2b85a')
    sack(I, '#f6f2ea', em, band='#3a6fc8')


@icon('whole_wheat_flour', 'Whole Wheat Flour')
def ic_ww_flour(I):
    from icons_g import sack
    def em(I):
        I.line('M0 12V-12', '#8a5a2a', 1.4)
        for y in (-8, -3, 2):
            I.e(-3, y, 2.5, 4.5, '#a8743a', rot=-30); I.e(3, y, 2.5, 4.5, '#a8743a', rot=30)
    sack(I, '#d8b48a', em, band='#6a3a1e')


# ======================= паста =======================
@icon('spaghetti', 'Spaghetti')
def ic_spaghetti(I):
    I.shadow(rx=44)
    with I.at(64, 64, 1, -35):
        for i in range(14):
            y = -10 + i * 1.6
            I.line(f'M-48 {f(y)}H48', ('#f2cc6a', '#e8b84a')[i % 2], 1.8)
        I.r(-8, -13, 16, 28, 3, I.cyl('#2f6fa8', .4, .3))
        I.r(-8, -13, 16, 5, 2, '#f2f2ee', .9)


@icon('penne', 'Penne')
def ic_penne(I):
    def d(I, x, y, i):
        with I.at(x, y, 1, (i * 47) % 180 - 90):
            I.p('M-12 -4L10 -6L14 4L-8 6Z', I.rg('#f2c45a', .45, .3))
            I.line('M-9 -2L11 -4M-8 2L12 0', '#d8a03a', .8, .7)
            I.e(12, -1, 2, 5, '#c88a2a', rot=-20)
    heap(I, 11, d, h=30)


@icon('fusilli', 'Fusilli')
def ic_fusilli(I):
    I.shadow(rx=44)
    for x, y, rot in ((40, 66, -40), (68, 56, 15), (84, 84, -70), (54, 92, 30)):
        with I.at(x, y, 1, rot):
            for k in range(6):
                yy = -20 + k * 7.5
                I.p(f'M-9 {yy}C-4 {yy - 6} 6 {yy - 2} 9 {yy + 3}C4 {yy + 9} -6 {yy + 5} -9 {yy}Z', I.rg('#f6c43a', .45, .3))


@icon('farfalle', 'Farfalle')
def ic_farfalle(I):
    def d(I, x, y, i):
        with I.at(x, y, .9, (i * 37) % 60 - 30):
            I.p('M0 0L-16 -10Q-18 0 -16 10Z', I.rg('#f2c45a', .45, .3))
            I.p('M0 0L16 -10Q18 0 16 10Z', I.rg('#f2c45a', .45, .3))
            I.e(0, 0, 3.5, 5, '#d8a03a')
    heap(I, 9, d, h=30, rx=34)


@icon('lasagna_sheets', 'Lasagna Sheets')
def ic_lasagna(I):
    I.shadow(rx=46)
    for k in range(4):
        y = 52 + k * 11
        edge = f'M20 {y}' + ''.join(f'L{20 + j * 5} {y + (2 if j % 2 else -2)}' for j in range(1, 18))
        I.p(edge + f'L104 {y - 18}L36 {y - 22}Z', I.rg('#f2cc6a', .35, .25))
        I.p(edge + f'V{y + 5}H20Z', '#d8a84a')


@icon('macaroni', 'Macaroni')
def ic_macaroni(I):
    def d(I, x, y, i):
        with I.at(x, y, 1, (i * 61) % 360):
            I.line('M-8 4Q-8 -8 6 -8', '#f2c45a', 7)
            I.line('M-8 4Q-8 -8 6 -8', '#f8dc8a', 2, .7)
            I.e(6, -8, 2, 3.5, '#c88a2a')
    heap(I, 16, d, h=28)


@icon('rigatoni', 'Rigatoni')
def ic_rigatoni(I):
    def d(I, x, y, i):
        with I.at(x, y, 1, (i * 47) % 180 - 90):
            I.p('M-12 -6H10V6H-12Z', I.cyl('#f0c050', .45, .3))
            I.line(''.join(f'M{k} -6V6' for k in range(-10, 10, 4)), '#d09a30', .9, .7)
            I.e(10, 0, 3, 6, '#f6d47a'); I.e(10, 0, 1.8, 4, '#b8802a')
    heap(I, 12, d, h=28)


@icon('tagliatelle', 'Tagliatelle')
def ic_tagliatelle(I):
    I.shadow(rx=44)
    for x, y in ((44, 76), (84, 76), (64, 60)):
        for r, c in ((18, '#e8b84a'), (13, '#f2c85a'), (8, '#f6d47a')):
            I.add(f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r * .7:.1f}" fill="none" stroke="{c}" stroke-width="5"/>')
        I.hl(x - 8, y - 8, 5, 2.5, -20, .6)


# ======================= масла, уксусы =======================
def em_olive(I):
    I.line('M-10 8Q0 0 10 -10', '#5a7a2a', 1.4)
    I.e(-3, 3, 4, 5.5, I.rg('#6a7a1e', .5, .3), rot=30)
    I.e(5, -2, 3.5, 5, I.rg('#3a2a3e', .5, .3), rot=30)
    I.e(4, -8, 6, 2, '#6a9a3a', rot=-40)


def em_sunflower(I):
    for a in range(0, 360, 30):
        with I.at(0, 0, 1, a): I.e(0, -8, 3, 5.5, '#f8c81a')
    I.c(0, 0, 6, I.rg('#6a3a1a', .4, .3))


@icon('olive_oil', 'Olive Oil')
def ic_olive_oil(I):
    bottle(I, '#a8a020', '#2f5a2a', '#f4efdc', em_olive, w=19, neck=6, top=12, shoulder=50, label_y=(64, 98))


@icon('sunflower_oil', 'Sunflower Oil')
def ic_sunflower_oil(I):
    bottle(I, '#f2c41a', '#f2d23a', '#3f8a3a', em_sunflower, w=22, neck=9, top=16, shoulder=44, label_y=(62, 96))


@icon('vegetable_oil', 'Vegetable Oil')
def ic_vegetable_oil(I):
    bottle(I, '#f2d85a', '#d8302c', '#fbf6e6', em_drop('#f2c81a'), w=22, neck=9, top=16, shoulder=44, label_y=(62, 96))


@icon('sesame_oil', 'Sesame Oil')
def ic_sesame_oil(I):
    bottle(I, '#a8581a', '#c8a040', '#f6e6c0', em_sesame, w=17, neck=6, top=22, shoulder=56, label_y=(68, 98))


@icon('vinegar', 'Vinegar')
def ic_vinegar(I):
    bottle(I, '#eef4f2', '#f2f2ee', '#3a8fd0', em_drop('#eef6fb'), w=18, neck=6, top=14, shoulder=52, label_y=(66, 96))


@icon('balsamic', 'Balsamic Vinegar')
def ic_balsamic(I):
    bottle(I, '#2a0e14', '#1a1a1a', '#e8d8b0', em_grape, w=17, neck=6, top=12, shoulder=54, label_y=(68, 96))


@icon('apple_cider_vinegar', 'Apple Cider Vinegar')
def ic_acv(I):
    bottle(I, '#d89a3a', '#f2f2ee', '#fbf3e0', em_apple, w=20, neck=7, top=14, shoulder=50)


@icon('rice_vinegar', 'Rice Vinegar')
def ic_rice_vinegar(I):
    def em(I):
        for x, y, r in ((-4, -4, -20), (3, -5, 15), (-1, 3, 70), (5, 3, -40), (-6, 4, 40)):
            I.e(x, y, 2.4, 4.2, I.rg('#fbf8ee', .5, .25), rot=r)
    bottle(I, '#f4ecd2', '#c8302c', '#c8302c', em, w=20, neck=7)


# ======================= сахар =======================
@icon('sugar', 'Sugar')
def ic_sugar(I):
    I.shadow(rx=46)
    for x, y in ((36, 80), (62, 86), (88, 78), (48, 58), (76, 60)):
        I.p(f'M{x - 12} {y - 6}L{x} {y - 12}L{x + 12} {y - 6}L{x} {y}Z', I.rg('#ffffff', .2, .08))
        I.p(f'M{x - 12} {y - 6}L{x} {y}V{y + 14}L{x - 12} {y + 8}Z', '#eef0f2')
        I.p(f'M{x + 12} {y - 6}L{x} {y}V{y + 14}L{x + 12} {y + 8}Z', '#d8dce2')
        dots(I, x, y + 4, 9, 6, 6, .7, '#c9ced6', .7)


@icon('brown_sugar', 'Brown Sugar')
def ic_brown_sugar(I):
    heap(I, 60, lambda I, x, y, i: I.c(x, y, 2.6, ('#a8642a', '#c07a36', '#8a4e1e')[i % 3]), bowl='#f2ede4', rx=36, ry=8, h=20, cy=84)


@icon('powdered_sugar', 'Powdered Sugar')
def ic_powdered_sugar(I):
    I.shadow(rx=46, cy=108)
    I.p('M18 84H110Q108 108 82 112H46Q20 108 18 84Z', I.cyl('#3a6fc8', .4, .3))
    I.e(64, 84, 46, 10, '#2a5aa8')
    I.p('M22 84C32 60 52 50 64 50C78 50 96 60 106 84Z', I.rg('#ffffff', .2, .12))
    I.p('M70 30L96 20L100 28L74 38Z', I.cyl('#c9ced6', .5, .3))
    I.c(62, 36, 12, 'none')
    I.add('<circle cx="62" cy="36" r="12" fill="none" stroke="#b8bec6" stroke-width="3"/>')
    dots(I, 62, 46, 10, 6, 10, 1, '#ffffff', .9)
