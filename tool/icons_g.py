"""Иконки новых продуктов (набор данных 16.11) — у каждого сразу своя иконка."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf
from icons_c import fish
from icons_a import em_sesame


def tube(I, body, cap, emblem=None, rot=-30):
    """Тюбик (пасты: анчоусы, хариса)."""
    I.shadow(rx=46)
    with I.at(64, 64, 1, rot):
        I.p('M-42 -14H24L40 -5V5L24 14H-42Q-46 0 -42 -14Z', I.cyl(body, .45, .35))
        I.p('M-44 -15H-36V15H-44Z', dk(body, .2))
        for x in (-43, -40, -37):
            I.line(f'M{x} -14V14', dk(body, .35), .8, .6)
        I.r(40, -7, 11, 14, 3, I.cyl(cap, .4, .3))
        I.r(-30, -10, 46, 3, 1.5, '#fff', .4)
        if emblem:
            with I.at(-6, 2, 1): emblem(I)


def sack(I, color, emblem=None, band=None):
    """Бумажный пакет с мукой."""
    I.shadow(rx=40)
    I.p('M34 34L40 26H88L94 34V106Q94 112 88 112H40Q34 112 34 106Z', I.rg(color, .35, .25))
    I.p('M34 34L40 26H88L94 34Z', dk(color, .12))
    I.p('M40 26L44 18H84L88 26Z', lt(color, .1))
    I.line('M44 18L48 26M64 18V26M84 18L80 26', dk(color, .2), 1, .6)
    if band: I.p('M34 92H94V102H34Z', band)
    I.hl(44, 50, 6, 14, -6, .4)
    if emblem:
        with I.at(64, 66, 1.5): emblem(I)


def em_apple(I):
    I.p('M0 -6C6 -12 12 -6 11 2C10 9 5 12 0 10C-5 12 -10 9 -11 2C-12 -6 -6 -12 0 -6Z', I.rg('#e0302c', .5, .3))
    I.line('M0 -6Q0 -10 2 -12', '#5a3a1e', 1.5)
    I.p('M2 -9C5 -13 9 -12 10 -11C7 -8 4 -8 2 -9Z', '#4f9a33')


def em_grape(I):
    for x, y in ((-5, -5), (2, -5), (-2, 1), (5, 1), (1, 7), (-6, 2)):
        I.c(x, y, 3.6, I.rg('#7a3a8a', .5, .3))
    I.p('M1 -9L3 -13L6 -12Z', '#4f9a33')


def em_oat_g(I):
    for x, y, r in ((-6, 2, -30), (0, -3, 0), (6, 2, 30), (0, 8, 0)):
        I.e(x, y, 3, 6, I.rg('#e2c27e', .5, .3), rot=r)
    I.line('M0 12V-12', '#b8964f', 1.2)


def em_rose(I):
    I.c(0, 0, 9, I.rg('#e0507a', .45, .3))
    I.line('M-4 -2Q0 -7 4 -2Q2 4 -3 2Q-2 -1 1 -1', '#a8284e', 1.4)
    I.p('M-2 9C-8 12 -12 10 -12 8C-8 6 -4 6 -2 9Z', '#4f9a33')


def em_elderflower(I):
    for i in range(14):
        a, t = i * 2.39996, math.sqrt((i + .5) / 14)
        I.c(math.cos(a) * 9 * t, math.sin(a) * 7 * t - 2, 2.4, I.rg('#fbf8e6', .5, .25))
        I.c(math.cos(a) * 9 * t, math.sin(a) * 7 * t - 2, .7, '#e8c84a')
    I.line('M0 5V12M0 7L-5 3M0 7L5 3', '#6a8a3a', 1)


def em_anchovy(I):
    I.p('M-12 0C-6 -5 6 -5 9 -1L13 -5V5L9 1C6 5 -6 5 -12 0Z', I.rg('#4a6f8a', .5, .3))
    I.line('M-10 0H8', '#c9d8e2', 1, .8)
    I.c(-9, -1, .9, '#111')


# ---------------- овощи, зелень, грибы ----------------
@icon('cucamelon', 'Cucamelon')
def ic_cucamelon(I):
    I.shadow(rx=44)
    for x, y, rot in ((42, 64, -30), (70, 54, 20), (90, 78, -10), (56, 90, 40)):
        with I.at(x, y, 1, rot):
            body = 'M0 -15C9 -15 12 -6 12 0C12 8 8 15 0 15C-8 15 -12 8 -12 0C-12 -6 -9 -15 0 -15Z'
            I.p(body, I.rg('#a8d070', .45, .35))
            with I.clip(body):
                for k in (-9, -3, 3, 9):
                    I.line(f'M{k} -16Q{k * 1.6} 0 {k} 16', '#3f7a2a', 2.2, .85)
                dots(I, 0, 0, 10, 13, 10, 1, '#d8eeb0', .6)
            I.hl(-4, -7, 3, 5, -10, .7)
    I.e(56, 90, 1, 1, 'none')


@icon('white_truffle', 'White Truffle')
def ic_white_truffle(I):
    I.shadow(rx=44)
    I.p('M30 70C26 52 40 38 58 40C66 30 86 34 92 46C104 50 106 70 96 80C92 96 72 100 60 94C46 100 30 92 30 70Z', I.rg('#d8c08a', .45, .4))
    dots(I, 64, 66, 30, 24, 40, 2.2, '#c2a46a', .6)
    dots(I, 64, 66, 30, 24, 40, 1, '#ead8a8', .7, seed=2)
    I.hl(48, 52, 9, 5)
    for x, y in ((84, 100), (100, 92)):
        I.e(x, y, 11, 6, I.rg('#efe3c4', .4, .2))
        I.line(f'M{x - 7} {y}Q{x} {y - 4} {x + 7} {y + 1}M{x - 6} {y + 2}Q{x} {y - 1} {x + 6} {y + 3}', '#c9ac72', .9, .7)


@icon('snow_fungus', 'Snow Fungus')
def ic_snow_fungus(I):
    I.shadow(rx=40)
    I.c(64, 68, 34, I.rg('#efe2b8', .4, .3))
    for i in range(16):
        a, t = i * 2.39996, math.sqrt((i + .5) / 16)
        x, y = 64 + math.cos(a) * 26 * t, 68 + math.sin(a) * 26 * t
        with I.at(x, y, 1, i * 37):
            I.p('M-10 4C-12 -6 -2 -12 4 -8C10 -10 12 -2 8 4C4 2 -4 8 -10 4Z', I.rg('#f8efd2', .5, .3))
            I.line('M-8 3C-4 0 2 2 7 2', '#d8c48a', 1, .6)
    I.hl(50, 50, 8, 5)


@icon('lemon_thyme', 'Lemon Thyme')
def ic_lemon_thyme(I):
    I.shadow(rx=40)
    for x0, rot in ((48, -20), (62, -2)):
        with I.at(x0, 108, 1, rot):
            I.line('M0 0Q-2 -40 2 -82', '#8a6a46', 1.6)
            for k in range(16):
                s = 1 if k % 2 else -1
                with I.at(s * 3.6, -12 - k * 4.4, 1, s * -30):
                    I.e(0, 0, 3.4, 2.1, '#e9d44a')
                    I.e(0, 0, 2.4, 1.3, '#6f9a48')
    I.p('M74 100A22 22 0 0 1 118 100Z', '#e8c41a')
    I.p('M77 100A19 19 0 0 1 115 100Z', '#fbf3c8')
    I.p('M80 100A16 16 0 0 1 112 100Z', I.rg('#f8e050', .4, .2))
    for a in (200, 240, 280, 320):
        x = 96 + 16 * math.cos(math.radians(a)); y = 100 + 16 * math.sin(math.radians(a))
        I.line(f'M96 100L{f(x)} {f(y)}', '#fbf3c8', 1.6)


@icon('fenugreek_leaves', 'Fenugreek Leaves')
def ic_fenugreek_leaves(I):
    I.shadow(rx=36)
    tips = ((40, 40), (56, 28), (74, 30), (90, 44), (46, 60), (82, 62), (64, 48))
    for x, y in tips:
        I.line(f'M64 106Q{(x + 64) / 2} {(y + 106) / 2 + 6} {x} {y}', '#9cc06a', 1.6)
    for x, y in tips:
        for a in (-50, 0, 50):
            with I.at(x, y, 1, a):
                I.e(0, -7, 4.2, 7.5, I.rg('#5aa83a', .5, .3))
    I.r(56, 96, 16, 8, 3, I.cyl('#d8b44a', .4, .3))


@icon('edible_flowers', 'Edible Flowers')
def ic_edible_flowers(I):
    I.shadow(rx=46)

    def flower(x, y, k, petal, center, n=5, inner=None):
        with I.at(x, y, k):
            for i in range(n):
                with I.at(0, 0, 1, i * 360 / n):
                    I.e(0, -11, 9, 11, I.rg(petal, .45, .3))
                    if inner: I.e(0, -6, 4, 5, inner, .8)
            I.c(0, 0, 5, I.rg(center, .5, .3))
    leaf(I, 30, 100, 1.1, -30, '#4f9a33')
    leaf(I, 100, 98, 1.0, -150, '#5aa63a')
    flower(42, 72, 1.15, '#f08a1a', '#e8b01a', 5, '#d8401a')  # настурция
    flower(86, 62, 1.05, '#8a4ac8', '#f6d01a', 5, '#f2e46a')   # анютины глазки
    flower(66, 96, .85, '#f6f2ec', '#f2b81a', 8)              # ромашка


# ---------------- фрукты ----------------
@icon('cacao_fruit', 'Cacao Fruit')
def ic_cacao_fruit(I):
    I.shadow(rx=46)
    with I.at(80, 58, 1, 35):
        body = 'M0 -40C16 -38 22 -14 20 8C18 28 8 40 0 42C-8 40 -18 28 -20 8C-22 -14 -16 -38 0 -40Z'
        I.p(body, I.rg('#e8a01a', .45, .35))
        with I.clip(body):
            for k in (-14, -7, 0, 7, 14):
                I.line(f'M{k} -42Q{k * 1.5} 0 {k} 44', '#c8701a', 2, .6)
    I.e(44, 88, 28, 20, '#d8901a', rot=-15)
    I.e(44, 87, 24, 16, I.rg('#fbf6ea', .4, .15), rot=-15)
    for x, y in ((34, 84), (44, 80), (54, 84), (38, 92), (50, 92)):
        I.e(x, y, 5, 3.5, I.rg('#f4ecdc', .5, .25))
        I.e(x + 1, y + 1, 3, 2, '#b8946a', .5)


# ---------------- бакалея ----------------
@icon('msg', 'MSG')
def ic_msg(I):
    I.shadow(rx=40)
    I.p('M34 30H94L96 104Q96 112 88 112H40Q32 112 32 104Z', I.cyl('#e9eef2', .5, .2), .85)
    I.p('M34 30H94V42H34Z', '#d8302c')
    I.p('M34 24' + ''.join(f'L{36 + 4 * i} {21 if i % 2 == 0 else 24}' for i in range(15)) + 'L94 24V30H34Z', '#e84a3a')
    for i in range(26):
        a, t = i * 2.39996, math.sqrt((i + .5) / 26)
        x, y = 64 + math.cos(a) * 24 * t, 80 + math.sin(a) * 22 * t
        with I.at(x, y, 1, (i * 53) % 180):
            I.r(-5, -1.2, 10, 2.4, 1, '#fbfdff')
            I.r(-4, -1.2, 4, 1, .5, '#cfe0ea')
    with I.at(64, 54, 1.0):
        I.p('M-12 -1H12C12 7 6 10 0 10C-6 10 -12 7 -12 -1Z', I.rg('#f3ede2', .4, .25))
        I.e(0, -1, 12, 3, '#e8a24a')
    I.r(38, 46, 4, 54, 2, '#fff', .5)


@icon('cream_of_tartar', 'Cream of Tartar')
def ic_cream_of_tartar(I):
    shaker(I, '#fbfbf6', '#7a3a8a', em_grape, fill=.8, label='#f2e8f4')


@icon('sprinkles', 'Sprinkles')
def ic_sprinkles(I):
    I.shadow(rx=36)
    I.p('M38 50Q38 46 42 46H86Q90 46 90 50V106Q90 112 84 112H44Q38 112 38 106Z', I.cyl(GLASS, .4, .25), .6)
    cols = ('#f2506a', '#3fa8e8', '#f8d23a', '#5ac85a', '#b86ad8', '#fb8a2a', '#fbfbfb')
    for i in range(46):
        a, t = i * 2.39996, math.sqrt((i + .5) / 46)
        x, y = 64 + math.cos(a) * 21 * t, 84 + math.sin(a) * 22 * t
        with I.at(x, y, 1, (i * 67) % 180):
            I.r(-3.5, -1.3, 7, 2.6, 1.3, cols[i % 7])
    I.r(42, 52, 4, 52, 2, '#fff', .45)
    I.r(36, 28, 56, 20, 5, I.cyl('#f2506a', .45, .4))
    I.e(64, 29.5, 26, 2.5, '#f8a0b0')
    for x, y, c, r in ((22, 108, 0, 30), (106, 104, 1, -40), (112, 112, 2, 10), (28, 98, 3, 70)):
        with I.at(x, y, 1, r): I.r(-3.5, -1.3, 7, 2.6, 1.3, cols[c])


@icon('pectin', 'Pectin')
def ic_pectin(I):
    box(I, '#3f9a4a', em_apple, band='#f2c43a')


@icon('sweet_relish', 'Sweet Relish')
def ic_sweet_relish(I):
    jar(I, '#7ab83a', '#d8302c', None, None)
    for i in range(30):
        a, t = i * 2.39996, math.sqrt((i + .5) / 30)
        x, y = 64 + math.cos(a) * 22 * t, 80 + math.sin(a) * 26 * t
        I.r(x - 2, y - 2, 4.5, 4, 1, ('#4f8a24', '#a8d860', '#e8d84a')[i % 3])
    I.r(40, 50, 4, 54, 2, '#fff', .45)


@icon('anchovy_paste', 'Anchovy Paste')
def ic_anchovy_paste(I):
    tube(I, '#2f6fa8', '#f2f2ee', em_anchovy)


@icon('shortcrust_pastry', 'Shortcrust Pastry')
def ic_shortcrust(I):
    I.shadow(rx=48, cy=104)
    n = 26
    outer = ''.join(f'{"M" if i == 0 else "L"}{f(64 + (48 + 3 * (i % 2)) * math.cos(i * math.tau / n))} {f(80 + (17 + 1.2 * (i % 2)) * math.sin(i * math.tau / n))}' for i in range(n)) + 'Z'
    I.p('M14 80V88C14 100 38 106 64 106C90 106 114 100 114 88V80Z', I.vg('#e8b860', '#c88a3a'))
    I.p(outer, I.rg('#f2cc7a', .35, .25))
    I.e(64, 81, 40, 13, I.rg('#e6b45e', .2, .25))
    I.e(64, 83, 36, 10, '#f0c878')
    dots(I, 64, 83, 30, 8, 10, 1.2, '#c88a3a', .5)
    # раскатанный пласт сзади
    I.p('M60 50C70 40 100 38 112 46L106 60C94 54 76 56 66 62Z', I.rg('#f4dca8', .35, .2))
    I.e(112, 52, 5, 8, '#e8c88a')


@icon('ice_cream_cones', 'Ice Cream Cones')
def ic_cones(I):
    I.shadow(rx=36)
    for k, (x, y) in enumerate(((50, 34), (64, 30), (78, 34))):
        cone = f'M{x - 15} {y}H{x + 15}L{x + 1} {y + 74}Q{x} {y + 77} {x - 1} {y + 74}Z'
        I.p(cone, I.cyl('#e0a454', .4, .35))
        with I.clip(cone):
            for t in range(0, 90, 8):
                I.line(f'M{x - 20} {y + t}l40 22M{x + 20} {y + t}l-40 22', '#b8783a', 1.3, .7)
        I.e(x, y, 15, 4, '#c8884a')
        I.e(x, y, 12, 2.6, '#a86a32')


@icon('ladyfingers', 'Ladyfingers')
def ic_ladyfingers(I):
    I.shadow(rx=46)
    for y, x, rot in ((48, 66, -14), (66, 62, -8), (84, 66, -2)):
        with I.at(x, y, 1, rot):
            d = 'M-44 0C-44 -12 -30 -12 -24 -9C-10 -5 10 -5 24 -9C30 -12 44 -12 44 0C44 12 30 12 24 9C10 5 -10 5 -24 9C-30 12 -44 12 -44 0Z'
            I.p(d, I.vg('#f2c46a', '#d8963a'))
            I.p('M-40 -2C-38 -9 -28 -9 -22 -7C-8 -3 10 -3 24 -7C30 -9 40 -9 40 -2C30 -4 10 0 0 0C-10 0 -30 -4 -40 -2Z', '#f8dc98', .8)
            dots(I, 0, -3, 36, 4, 22, .9, '#fffaf0', .9)


@icon('oat_flour', 'Oat Flour')
def ic_oat_flour(I):
    sack(I, '#efe1c0', em_oat_g, band='#6aa83a')


@icon('black_sesame_paste', 'Black Sesame Paste')
def ic_black_sesame_paste(I):
    def em(I):
        for x, y, r in ((-6, -2, 30), (-1, -6, -20), (4, -1, 50), (-3, 4, -40), (6, 6, 10), (1, 2, 80)):
            I.e(x, y, 2.8, 1.6, '#1f1f22', rot=r)
    jar(I, '#2a2a2e', '#d8b46a', '#f4ecdc', em)


@icon('rose_water', 'Rose Water')
def ic_rose_water(I):
    bottle(I, '#f6b8c8', '#c8a040', '#fbf4f2', em_rose, w=20, neck=6, top=16, shoulder=54, label_y=(68, 98))


@icon('elderflower_cordial', 'Elderflower Cordial')
def ic_elderflower(I):
    bottle(I, '#e6e08a', '#6a8a3a', '#fbfaf2', em_elderflower, w=21, neck=7)


@icon('grape_leaves', 'Grape Leaves')
def ic_grape_leaves(I):
    jar(I, '#7a8a3a', '#c8a040', None, None)
    for y in (58, 72, 86, 100):
        for x in (46, 60, 74, 84):
            if x < 88: I.e(x, y, 7, 5, I.rg('#5a6a2a', .45, .35))
    I.r(40, 50, 4, 54, 2, '#fff', .45)
    with I.at(84, 92, 1.0, -20):  # виноградный лист перед банкой
        I.p('M0 22L-6 10L-22 10L-16 0L-26 -10L-12 -10L-10 -24L0 -14L10 -24L12 -10L26 -10L16 0L22 10L6 10Z', I.rg('#5f9a3a', .45, .3))
        I.line('M0 22V-14M0 4L-16 -6M0 4L16 -6', '#3f7a24', 1.2, .7)


@icon('pickled_radish', 'Pickled Radish')
def ic_pickled_radish(I):
    I.shadow(rx=46)
    with I.at(84, 58, 1, 30):
        I.p('M-14 -40H14V36Q0 44 -14 36Z', I.cyl('#f6d21a', .45, .3))
        I.e(0, -40, 14, 5, '#f8e070')
    for x, y, rot in ((32, 92, -10), (50, 98, 0), (68, 96, 12)):
        with I.at(x, y, 1, rot):
            I.p('M-14 4A14 14 0 0 1 14 4Z', I.rg('#f8d82a', .45, .25))
            I.p('M-14 4H14V8H-14Z', '#e0b80e')


# ---------------- рыба и морепродукты ----------------
@icon('salt_cod', 'Salt Cod')
def ic_salt_cod(I):
    I.shadow(rx=46)
    d = 'M14 60L82 30Q96 26 104 34L116 52Q118 60 110 64L44 98Q34 102 28 94L12 70Q10 64 14 60Z'
    I.p(d, '#b8b0a0')
    I.p('M16 56L82 26Q96 22 104 30L114 48Q116 56 108 60L44 94Q34 98 28 90L14 66Q12 60 16 56Z', I.rg('#f4efe4', .3, .2))
    for x, y in ((40, 64), (60, 56), (80, 46), (54, 74), (74, 64), (92, 52)):
        I.line(f'M{x} {y}q8 -6 16 -2', '#d8cfbe', 1.4, .8)
    dots(I, 64, 60, 38, 20, 34, 1.1, '#ffffff', .9)
    I.p('M104 30L118 18L120 40Z', '#9a9080')


@icon('smoked_trout', 'Smoked Trout')
def ic_smoked_trout(I):
    def p(I):
        I.p('M20 66Q60 58 96 64Q60 72 20 70Z', '#e88a5a', .6)
        dots(I, 64, 54, 30, 9, 26, 1.2, '#4a2a14', .7)
    fish(I, '#9a4e1c', '#e8a860', '#7a3e18', depth=.95, pattern=p)


@icon('smoked_oysters', 'Smoked Oysters')
def ic_smoked_oysters(I):
    I.shadow(rx=46, cy=104)
    I.p('M14 76V86C14 96 36 102 64 102C92 102 114 96 114 86V76Z', I.cyl('#c9a040', .45, .4))
    I.e(64, 76, 50, 16, I.rg('#d8b04a', .4, .3))
    I.e(64, 76, 45, 13, I.rg('#7a5420', .3, .3))
    for x, y in ((40, 74), (60, 70), (82, 74), (50, 82), (74, 82)):
        I.e(x, y, 11, 6.5, I.rg('#9a6a30', .5, .35), rot=(x * 7) % 40 - 20)
        I.line(f'M{x - 7} {y}q7 -4 14 0', '#6a4214', 1, .6)
    I.p('M24 66C30 46 70 36 104 44L106 50C76 44 40 52 30 68Z', I.rg('#e0c060', .45, .3))
    I.hl(48, 66, 10, 2.5, -10, .6)


@icon('kamaboko', 'Kamaboko')
def ic_kamaboko(I):
    I.shadow(rx=48)
    I.p('M14 84L70 100L114 84L60 70Z', I.rg('#c89a5a', .35, .3))
    I.p('M14 84L70 100V106L14 90Z', '#a8783a')
    I.p('M70 100L114 84V90L70 106Z', '#8a6230')
    I.p('M22 82C22 58 48 46 66 48C84 50 100 62 100 82L66 90Z', I.rg('#f2809a', .45, .3))
    I.p('M28 82C28 64 48 54 64 56C80 58 94 68 94 82L66 89Z', I.rg('#fbf8f4', .35, .15))
    I.p('M100 82L66 90V98L104 88Z', '#f0e8e4')
    with I.at(104, 60, 1, 10):
        I.c(0, 0, 13, '#f2809a')
        I.c(0, 0, 10, I.rg('#fbf8f4', .35, .15))
        I.line('M-6 -2Q-2 -6 2 -2T8 0', '#f2809a', 1.6)


@icon('fried_tofu', 'Fried Tofu')
def ic_fried_tofu(I):
    I.shadow(rx=46)
    for x, y in ((40, 64), (78, 58), (58, 86)):
        I.p(f'M{x - 20} {y - 6}L{x} {y - 15}L{x + 20} {y - 6}L{x} {y + 3}Z', I.rg('#e8a83a', .4, .25))
        I.p(f'M{x - 20} {y - 6}L{x} {y + 3}V{y + 20}L{x - 20} {y + 11}Z', I.vg('#d8902a', '#c07a20'))
        I.p(f'M{x + 20} {y - 6}L{x} {y + 3}V{y + 20}L{x + 20} {y + 11}Z', I.vg('#c88224', '#a8681a'))
        dots(I, x, y - 6, 12, 5, 6, 1, '#f6cf7a', .6)
    with I.at(96, 96, .9): em_sesame(I)


@icon('chickpea_pasta', 'Chickpea Pasta')
def ic_chickpea_pasta(I):
    I.shadow(rx=46)
    for x, y, rot in ((42, 66, -30), (70, 56, 20), (80, 84, -60)):
        with I.at(x, y, 1, rot):
            for k in range(6):
                yy = -20 + k * 7.5
                I.p(f'M-9 {yy}C-4 {yy - 6} 6 {yy - 2} 9 {yy + 3}C4 {yy + 9} -6 {yy + 5} -9 {yy}Z', I.rg('#ecc66a', .45, .3))
    for x, y in ((38, 96), (54, 100)):
        I.c(x, y, 8, I.rg('#e0b46a', .5, .3))
        I.p(f'M{x - 2} {y - 8}Q{x - 6} {y - 2} {x - 1} {y}', 'none')
        I.line(f'M{x} {y - 8}Q{x - 4} {y - 3} {x} {y + 1}', '#b8884a', 1, .7)
