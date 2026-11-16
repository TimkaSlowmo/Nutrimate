"""Иконки: упаковки — соусы, пасты, порошки, выпечка-ингредиенты, напитки."""
from iconlib import *  # noqa: F401,F403


# ---------- эмблемы ----------
def em_root(I):  # корень хрена
    I.p('M-3 -8C2 -9 6 -6 5 -2L2 11C1 13 -1 13 -1 11L-5 -3C-6 -6 -6 -8 -3 -8Z', I.rg('#e9dcc2', .5, .3))
    I.line('M-2 -2L2 -1M-1 3L2 4', '#b9a27c', .9)
    I.p('M-3 -8C-8 -12 -10 -9 -12 -12C-7 -14 -4 -12 -3 -8Z', '#5d9e3a')
    I.p('M0 -9C0 -14 3 -14 4 -16C6 -12 4 -10 0 -9Z', '#4b8a2e')


def em_powder(c, spoon=False):
    def d(I):
        I.p('M-12 8C-9 -2 -4 -7 0 -7C4 -7 9 -2 12 8Z', I.rg(c, .45, .3))
        I.e(0, 8, 12, 2.5, dk(c, .15))
        if spoon:
            I.e(6, -6, 5, 3, I.rg('#d6dbe0', .5, .3), rot=-20)
    return d


def em_hazelnut(I):
    I.p('M0 -11C6 -11 10 -5 10 2C10 8 5 11 0 11C-5 11 -10 8 -10 2C-10 -5 -6 -11 0 -11Z', I.rg('#a8682f', .45, .35))
    I.p('M-10 1C-6 4 6 4 10 1C10 -2 9 -5 7 -7C3 -5 -3 -5 -7 -7C-9 -5 -10 -2 -10 1Z', '#d8b47c', .55)
    I.p('M-3 -11Q0 -14 3 -11Z', '#6e3f19')


def em_swirl(c):
    def d(I):
        I.p('M-11 6C-11 -2 -4 -6 2 -6C8 -6 11 -2 9 1C7 4 2 3 1 0C-1 -4 -7 0 -5 4C-3 8 6 9 11 6C10 10 4 12 -1 12C-7 12 -11 10 -11 6Z', I.rg(c, .5, .3))
    return d


def em_egg(I):
    I.p('M0 -11C5 -11 8 -3 8 3C8 8 4 11 0 11C-4 11 -8 8 -8 3C-8 -3 -5 -11 0 -11Z', I.rg('#fbf4e6', .5, .25))
    I.c(1, 4, 4, I.rg('#f5b621', .5, .25))


def em_seeds(c, n=7):
    def d(I):
        import math
        for i in range(n):
            a = i * 2.4
            r = 3 + (i % 3) * 3
            I.c(math.cos(a) * r, math.sin(a) * r * .8, 2.6, I.rg(c, .55, .3))
    return d


def em_flame(I):
    I.p('M0 -12C4 -6 9 -3 9 4C9 9 5 12 0 12C-5 12 -9 9 -9 4C-9 -1 -5 -3 -4 -8C-2 -4 -1 -3 0 -12Z', I.rg('#f28a1c', .5, .25))
    I.p('M0 1C2 3 4 5 4 7C4 10 2 11 0 11C-2 11 -4 10 -4 7C-4 5 -2 4 0 1Z', '#ffd44a')


def em_pickle(I):
    I.e(0, 0, 11, 6, I.rg('#6e9a35', .45, .35), rot=-25)
    for x, y in ((-5, 2), (0, -1), (5, -4), (-2, -3), (3, 2)):
        I.c(x, y, 1, '#9cc25a')


def em_soybean(I):
    for x, y in ((-5, 3), (4, 4), (0, -4)):
        I.e(x, y, 5, 4.2, I.rg('#e3c46e', .5, .3))
        I.e(x - 1.5, y - 1.5, 1.5, 1, '#fff', .55)


def em_sesame(I):
    for x, y, r in ((-6, -2, 30), (-1, -6, -20), (4, -1, 50), (-3, 4, -40), (6, 6, 10), (1, 2, 80)):
        I.e(x, y, 2.6, 1.5, '#f2e3bd', rot=r)


def em_plum(I):
    I.c(0, 2, 9, I.rg('#7a2340', .5, .35))
    I.line('M0 -7Q1 -10 4 -12', '#5a3b1e', 1.6)
    I.p('M2 -9C5 -13 10 -11 11 -10C8 -7 5 -8 2 -9Z', '#4f8f31')


def em_liver(I):
    I.p('M-12 0C-12 -7 -4 -9 2 -7C7 -9 12 -6 12 0C12 6 4 9 -2 7C-8 8 -12 5 -12 0Z', I.rg('#8f3a2e', .45, .35))


def em_sachet_cube(I):
    em_cube('#e9b45c')(I)


def em_seaweed_strips(I):
    for x in (-7, -2, 3, 8):
        I.r(x - 1.6, -10, 3.2, 20, 1.5, '#f6f2df', .95)
    I.p('M-12 10C-8 4 -10 -2 -6 -8C-4 -2 -6 4 -9 11Z', '#3e8a5e')


def em_granules(I):
    import math
    for i in range(16):
        a, r = i * 2.4, (i % 4) * 3
        I.e(math.cos(a) * r, math.sin(a) * r * .7, 2.2, 1.4, I.rg('#c9a15d', .5, .3), rot=i * 25)


def em_tea_leaf(I):
    I.p('M-10 8C-10 -4 0 -11 11 -11C11 1 3 9 -10 8Z', I.rg('#6aa337', .45, .3))
    I.line('M-8 6Q0 -1 8 -8', '#3f6e1d', 1, .8)


# ---------- порошки и выпечка (жалобы владельца: всё было ложкой 🥄) ----------
@icon('gelatin', 'Gelatin')
def ic_gelatin(I):
    sachet(I, '#f3e3c4', em_cube('#e8a43c'), top='#c97b2a')
    for x, y in ((80, 100), (90, 106)):
        with I.at(x, y, .8): em_cube('#e8a43c')(I)


@icon('baking_powder', 'Baking Powder')
def ic_baking_powder(I):
    can(I, '#d8312f', em_bubbles('#fff'), top='#e7e7e7', band='#f4f1e8', h=(40, 106))


@icon('baking_soda', 'Baking Soda')
def ic_baking_soda(I):
    box(I, '#f2a516', em_powder('#fbfbf7'), band='#d23b2a')


@icon('vanilla_sugar', 'Vanilla Sugar')
def ic_vanilla_sugar(I):
    sachet(I, '#fbf6ea', em_vanilla, top='#9a6bb5', window='#f2ead7')


@icon('vanilla_extract', 'Vanilla Extract')
def ic_vanilla_extract(I):
    bottle(I, '#6b3612', '#2a2a2a', '#f3ead3', em_vanilla, w=17, neck=6, top=22, shoulder=56, label_y=(68, 98))


@icon('agar_agar', 'Agar-Agar')
def ic_agar(I):
    sachet(I, '#3f9a8c', em_seaweed_strips, top='#2c6f66')


@icon('yeast', 'Yeast')
def ic_yeast(I):
    sachet(I, '#e8b13a', em_granules, top='#b6402c', window='#d9b876')


@icon('cream_soup_base', 'Cream Soup Base')
def ic_cream_soup(I):
    sachet(I, '#2f7d3e', em_bowl('#f1dfa3'), top='#f0c330')


@icon('cocoa_powder', 'Cocoa Powder')
def ic_cocoa(I):
    can(I, '#7a3f1e', None, top='#c9a67a', h=(40, 106))
    I.e(64, 40, 24, 5, I.rg('#6b3516', .35, .3))
    I.p('M50 40C54 33 60 30 64 30C70 30 76 34 79 40Z', I.rg('#7a3f1e', .4, .3))
    I.p('M70 34L96 10Q100 8 101 12L76 38Z', I.cyl('#d3d8de', .5, .35))
    I.e(72, 36, 7, 4, I.rg('#d3d8de', .5, .3), rot=-40)
    with I.at(64, 80, 1.3): em_powder('#8a4b25')(I)


@icon('chocolate_spread', 'Chocolate Spread')
def ic_choc_spread(I):
    jar(I, '#5a2c14', '#e9e3d8', '#f6eedd', em_swirl('#5e2d14'))


@icon('choc_hazelnut_spread', 'Chocolate Hazelnut Spread')
def ic_choc_hazel(I):
    jar(I, '#6a3518', '#f4f0e8', '#d63c2e', em_hazelnut)


# ---------- соусы и пасты (жалоба: всё было одной банкой томатов 🥫) ----------
@icon('horseradish_sauce', 'Horseradish Sauce')
def ic_horseradish_sauce(I):
    jar(I, '#f1ead6', '#3e8a3a', '#fbf8ef', em_root)


@icon('garlic_sauce', 'Garlic Sauce')
def ic_garlic_sauce(I):
    squeeze(I, '#f6f1e6', '#8e6bb8', em_garlic)


@icon('fish_sauce', 'Fish Sauce')
def ic_fish_sauce(I):
    bottle(I, '#b8621a', '#c4262e', '#f3e7c6', em_fish('#3b83b8', '#bfe0f0'))


@icon('oyster_sauce', 'Oyster Sauce')
def ic_oyster_sauce(I):
    bottle(I, '#3a1c10', '#b8902f', '#c9302c', em_oyster, w=26, neck=10, top=20, shoulder=50, cap_h=11)


@icon('hoisin_sauce', 'Hoisin Sauce')
def ic_hoisin(I):
    jar(I, '#4b1a14', '#c7262b', '#efd27a', em_plum)


@icon('miso_paste', 'Miso Paste')
def ic_miso(I):
    tub(I, '#f6efe1', '#c88a3c', None, band='#b5452d')
    I.p('M46 79C50 70 58 67 64 67C70 67 78 70 82 79Z', I.rg('#c9893a', .45, .3))
    I.e(64, 79, 18, 3, '#a96d2a')
    for x, y in ((58, 73), (66, 71), (71, 75)):
        I.e(x, y, 2.4, 1.7, '#e0b86a')


@icon('soy_sauce', 'Soy Sauce')
def ic_soy(I):
    bottle(I, '#2a120a', '#d62a2a', '#f7f2e8', em_soybean, w=22, neck=7)


@icon('ketchup', 'Ketchup')
def ic_ketchup(I):
    squeeze(I, '#d8231f', '#f4efe8', em_tomato, label='#fbf6ec')


@icon('spicy_ketchup', 'Spicy Ketchup')
def ic_spicy_ketchup(I):
    squeeze(I, '#b5161a', '#2d2d2d', em_chili, label='#ffd23d')


@icon('mayonnaise', 'Mayonnaise')
def ic_mayo(I):
    squeeze(I, '#f7efd9', '#2f6fb7', em_egg, label='#3b7fcc')


@icon('mustard', 'Mustard')
def ic_mustard(I):
    squeeze(I, '#f2c21b', '#d23a2a', em_seeds('#c58a1a', 6))


@icon('dijon_mustard', 'Dijon Mustard')
def ic_dijon(I):
    jar(I, '#d4a72c', '#1f3e73', '#f5efe0', em_drop('#d6a52b'))


@icon('grainy_mustard', 'Grainy Mustard')
def ic_grainy(I):
    jar(I, '#c79a3a', '#7b5130', None, None)
    import math
    for i in range(40):
        a, r = i * 2.4, 4 + (i * 7) % 24
        x, y = 64 + math.cos(a) * r, 80 + math.sin(a) * r * .9
        if 38 < x < 90 and 48 < y < 110: I.c(x, y, 2.3, I.rg('#9c6a22', .55, .3))
    I.r(40, 50, 4, 54, 2, '#fff', .4)


@icon('tomato_paste', 'Tomato Paste')
def ic_tomato_paste(I):
    can(I, '#d72f22', em_tomato, band='#2f8a35', h=(46, 104), rx=26)


@icon('bbq_sauce', 'BBQ Sauce')
def ic_bbq(I):
    bottle(I, '#5a1d0f', '#262626', '#e9a23b', em_flame, w=23, neck=9)


@icon('worcestershire', 'Worcestershire Sauce')
def ic_worcester(I):
    bottle(I, '#3b1b0f', '#d8d0c0', '#e2b56b', em_drop('#5a2a14'), w=16, neck=6, top=14, shoulder=52, label_y=(58, 104))
    for y in (62, 100):
        I.r(48, y, 32, 1.2, .5, '#8c5a24', .7)


@icon('teriyaki', 'Teriyaki Sauce')
def ic_teriyaki(I):
    bottle(I, '#4a2210', '#e8e2d6', '#2b2b2b', em_sesame, w=21, neck=8)


@icon('tartar_sauce', 'Tartar Sauce')
def ic_tartar(I):
    jar(I, '#f2ecd8', '#2f8fbf', '#fbf8f0', em_pickle)


@icon('liver_pate', 'Liver Pate')
def ic_pate(I):
    I.shadow(rx=44, cy=104)
    I.e(64, 92, 44, 14, I.rg('#c6ccd2', .45, .35))
    I.p('M20 80V92A44 14 0 0 0 108 92V80Z', I.cyl('#b9c0c8', .5, .4))
    I.e(64, 80, 44, 14, I.rg('#d6dbe0', .4, .3))
    I.e(64, 80, 39, 11, I.rg('#b07058', .45, .35))
    I.p('M40 78C48 71 60 76 68 72C76 68 86 74 90 80C80 82 70 79 62 82C54 85 46 82 40 78Z', '#c9876b', .7)
    I.p('M64 72C60 60 66 48 76 44C74 54 70 60 64 72Z', '#4f8f31')
    I.p('M66 70C72 62 80 60 88 62C82 66 76 70 66 70Z', '#3e7d27')
    I.hl(46, 76, 8, 3, -5, .5)


@icon('canned_tuna', 'Canned Tuna')
def ic_canned_tuna(I):
    can(I, '#1f6aa5', em_fish('#3a6f9a', '#c9dceb'), band='#f2c94a', h=(56, 100), rx=34)


# ---------- чай (жалоба: чёрный чай = чашка зелёного) ----------
@icon('black_tea', 'Black Tea')
def ic_black_tea(I):
    glass_cup(I, '#8a2a0c')
    I.line('M70 56Q78 40 88 34', '#e8e1d2', 1.2)
    I.r(86, 24, 14, 13, 2, '#d8352a')
    I.r(88, 27, 10, 2, 1, '#fff', .6)


@icon('green_tea', 'Green Tea')
def ic_green_tea(I):
    I.shadow(rx=38, cy=110)
    I.p('M28 50H100Q100 86 82 104H46Q28 86 28 50Z', I.cyl('#f3f1ea', .45, .3))
    I.p('M34 92H94Q90 99 84 104H44Q38 99 34 92Z', '#5e9a5a', .6)
    I.e(64, 50, 36, 8, '#e6e2d6')
    I.e(64, 51, 32, 6.5, I.rg('#b5c23a', .4, .25))
    I.r(36, 58, 4, 26, 2, '#fff', .55)
    with I.at(98, 34, .9, 20): em_tea_leaf(I)
