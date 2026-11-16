"""Иконки: молочное и растительное молоко (было 55 × 🥛)."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf
from icons_a import em_soybean, em_egg


def em_oat(I):
    for x, y, r in ((-6, 2, -30), (0, -3, 0), (6, 2, 30), (0, 8, 0)):
        I.e(x, y, 3, 6, I.rg('#e2c27e', .5, .3), rot=r)
    I.line('M0 12V-12', '#b8964f', 1.2)


def em_almond(I):
    I.p('M0 -11C6 -6 8 2 6 7C4 11 -4 11 -6 7C-8 2 -6 -6 0 -11Z', I.rg('#c27a3c', .45, .3))
    I.line('M-2 -5Q-3 2 -1 8M2 -6Q2 1 3 6', '#9a5a26', .9, .7)


def em_coconut(I):
    I.c(0, 0, 11, I.rg('#7a4a26', .35, .3))
    I.c(0, 0, 8.5, '#fbf8ef')
    I.c(0, 0, 6, '#eef3f4')
    I.hl(-4, -4, 3, 2, -30, .8)


def em_cocoa_bean(I):
    I.e(0, 0, 7, 11, I.rg('#7b3b1c', .45, .35), rot=30)
    I.line('M-5 8Q0 0 5 -8', '#4c2010', 1.2, .8)


def em_strawberry(I):
    I.p('M0 -6C7 -8 11 -3 10 3C9 8 4 12 0 12C-4 12 -9 8 -10 3C-11 -3 -7 -8 0 -6Z', I.rg('#e5303c', .5, .3))
    dots(I, 0, 3, 7, 7, 10, .8, '#ffe58a')
    I.p('M0 -6L-6 -10L-2 -7L0 -12L2 -7L6 -10Z', '#3f8f2a')


def em_honey(I):
    I.p('M0 -12C4 -5 8 -1 8 4C8 9 4 12 0 12C-4 12 -8 9 -8 4C-8 -1 -4 -5 0 -12Z', I.rg('#f0a81c', .5, .3))


def milk_bottle(I, liquid, cap, label=None, emblem=None, glass=True):
    I.shadow(rx=34)
    d = 'M42 52C42 42 50 40 50 32V24H78V32C78 40 86 42 86 52V104Q86 113 77 113H51Q42 113 42 104Z'
    I.p(d, I.cyl(liquid, .4, .25))
    if glass:
        I.p(d, I.cyl(GLASS, .5, .2), .25)
    if label:
        I.p('M42 66H86V96H42Z', I.cyl(label, .35, .25))
    I.r(48, 14, 32, 13, 4, I.cyl(cap, .45, .4))
    I.e(64, 15, 14, 2, lt(cap, .4))
    I.r(46, 54, 4, 46, 2, '#fff', .5)
    if emblem:
        with I.at(64, 81, 1.2): emblem(I)


def cup_pot(I, body, band, top, filling, emblem=None, spoon=False):
    """Стаканчик йогурта, открытый, с содержимым."""
    I.shadow(rx=40)
    I.p('M30 50H98L90 106Q89 112 82 112H46Q39 112 38 106Z', I.cyl(body, .4, .3))
    if band: I.p('M31.5 62H96.5L94 88H34Z', I.cyl(band, .3, .25))
    I.e(64, 50, 34, 9, lt(top, .2))
    I.e(64, 51, 30, 7, I.rg(filling, .35, .15))
    I.r(36, 58, 4, 44, 2, '#fff', .4)
    if spoon:
        I.p('M70 48L96 18Q99 15 101 18Q102 20 99 23L74 52Z', I.cyl('#d3d8de', .5, .35))
    if emblem:
        with I.at(64, 77, 1.3): emblem(I)


@icon('milk', 'Milk')
def ic_milk(I):
    milk_bottle(I, '#fbfbf8', '#2f74c8')
    I.p('M50 24H78V20Q64 16 50 20Z', '#2f74c8')


@icon('whole_milk', 'Whole Milk')
def ic_whole_milk(I):
    carton(I, '#f7f5ef', em_drop('#ffffff'), cap='#d32f2f')
    I.p('M32 98H76V108H32Z', '#d32f2f')


@icon('skim_milk', 'Skim Milk')
def ic_skim_milk(I):
    carton(I, '#eef5fb', em_drop('#eaf3fb'), cap='#3aa0d8')
    I.p('M32 98H76V108H32Z', '#3aa0d8')


@icon('lactose_free_milk', 'Lactose-Free Milk')
def ic_lf_milk(I):
    carton(I, '#f2f7ee', em_drop('#ffffff'), cap='#5aae4a')
    I.p('M32 98H76V108H32Z', '#5aae4a')


@icon('kefir', 'Kefir')
def ic_kefir(I):
    milk_bottle(I, '#f8f8f2', '#2e9a54', label='#2e9a54', emblem=em_drop('#ffffff'), glass=False)


@icon('ryazhenka', 'Ryazhenka')
def ic_ryazhenka(I):
    milk_bottle(I, '#e9c9a3', '#9a5a2a')


@icon('baked_milk', 'Baked Milk')
def ic_baked_milk(I):
    milk_bottle(I, '#f1dfc4', '#c27a2c', label='#c27a2c', emblem=em_drop('#f3e2c8'))


@icon('chocolate_milk', 'Chocolate Milk')
def ic_choc_milk(I):
    milk_bottle(I, '#8a5230', '#5a2c14', label='#f3e7d6', emblem=em_cocoa_bean)


@icon('goat_milk', 'Goat Milk')
def ic_goat_milk(I):
    carton(I, '#f7f5ef', None, cap='#8a6a3a')
    with I.at(54, 84, 1.3):  # козья голова-силуэт
        I.p('M-8 -6C-8 -12 8 -12 8 -6C8 2 4 10 0 12C-4 10 -8 2 -8 -6Z', I.rg('#f1ebde', .3, .3))
        I.p('M-6 -9C-12 -14 -14 -10 -14 -6M6 -9C12 -14 14 -10 14 -6', 'none')
        I.line('M-5 -9Q-10 -16 -12 -10M5 -9Q10 -16 12 -10', '#8a6a3a', 2)
        I.c(-3.5, -4, 1.2, '#2b2b2b'); I.c(3.5, -4, 1.2, '#2b2b2b')
        I.p('M-2 10L0 16L2 10Z', '#c9b99a')


@icon('yogurt', 'Yogurt')
def ic_yogurt(I):
    cup_pot(I, '#f5f7fb', '#5aa0dc', '#f7f7f2', '#fbfbf7', spoon=True)


@icon('greek_yogurt', 'Greek Yogurt')
def ic_greek(I):
    cup_pot(I, '#fbfbf8', '#1f5aa8', '#f7f7f2', '#fbfbf7')
    I.p('M46 50C50 40 60 38 66 42C72 38 82 42 82 50Z', I.rg('#fbfbf6', .2, .15))
    I.line('M50 46Q58 52 66 44T80 48', '#f0a81c', 3)


@icon('fruit_yogurt', 'Fruit Yogurt')
def ic_fruit_yogurt(I):
    cup_pot(I, '#fbf2f4', '#e5506a', '#f7e3e8', '#f6c2cf', emblem=em_strawberry)


@icon('vanilla_yogurt', 'Vanilla Yogurt')
def ic_vanilla_yogurt(I):
    from icons_a import em_vanilla as _v
    cup_pot(I, '#fbf6e8', '#e8c35a', '#f7f0d8', '#f6ead0', emblem=_v)


@icon('drinking_yogurt', 'Drinking Yogurt')
def ic_drinking_yogurt(I):
    milk_bottle(I, '#f6d7e0', '#e5506a', label='#fbfbf6', emblem=em_strawberry, glass=False)


@icon('sour_cream', 'Sour Cream')
def ic_sour_cream(I):
    tub(I, '#fbfaf5', '#f2b31d', None, band='#f2b31d')
    I.p('M46 46C50 34 60 30 66 34C74 30 84 36 82 46Z', I.rg('#fbfbf6', .2, .15))
    I.p('M62 34Q66 24 72 28Q68 30 66 36Z', '#fbfbf6')


@icon('heavy_cream', 'Heavy Cream')
def ic_heavy_cream(I):
    carton(I, '#f7f3e6', em_drop('#fbf8ee'), side='#d9d1bb', cap='#c79a2e')
    I.p('M32 98H76V108H32Z', '#c79a2e')


@icon('light_cream', 'Light Cream')
def ic_light_cream(I):
    I.shadow(rx=40)
    I.p('M34 58H94L88 106Q87 112 80 112H48Q41 112 40 106Z', I.cyl('#f2f6fa', .4, .3))
    I.e(64, 58, 30, 8, '#dfe6ee')
    I.e(64, 58, 26, 6, I.rg('#fdfbf3', .2, .1))
    I.p('M86 62Q104 64 100 80Q96 92 84 92', 'none')
    I.line('M90 64Q104 66 100 80Q97 90 86 92', '#e3e9f0', 6)
    I.line('M34 58Q30 54 26 56', '#f2f6fa', 6)
    I.r(40, 64, 4, 36, 2, '#fff', .5)


@icon('whipped_cream', 'Whipped Cream')
def ic_whipped(I):
    I.shadow(rx=30)
    I.p('M44 50H84V106Q84 112 78 112H50Q44 112 44 106Z', I.cyl('#d9dde2', .5, .4))
    I.r(44, 60, 40, 36, 0, I.cyl('#3a7fd0', .35, .3))
    I.r(50, 38, 28, 14, 4, I.cyl('#f2f2f2', .4, .3))
    I.p('M62 38L66 26H70L72 38Z', '#e9e9e9')
    for i, (x, y, r) in enumerate(((52, 22, 9), (66, 18, 10), (80, 22, 8), (64, 8, 7))):
        I.c(x, y, r, I.rg('#fbfbf6', .2, .2))
    with I.at(64, 78, 1.1): em_drop('#ffffff')(I)


@icon('oat_milk', 'Oat Milk')
def ic_oat_milk(I):
    carton(I, '#efe3c8', em_oat, side='#cdb88d', cap='#b48a3a')


@icon('soy_milk', 'Soy Milk')
def ic_soy_milk(I):
    carton(I, '#e6f1d8', em_soybean, side='#b9d09a', cap='#4f9a3a')


@icon('almond_milk', 'Almond Milk')
def ic_almond_milk(I):
    carton(I, '#e6eef8', em_almond, side='#b8c9e0', cap='#2f5ea8')


@icon('coconut_milk', 'Coconut Milk')
def ic_coconut_milk(I):
    carton(I, '#f4f8f8', em_coconut, side='#c9d8d8', cap='#2f8f7a')


@icon('canned_coconut_milk', 'Canned Coconut Milk')
def ic_canned_coconut_milk(I):
    can(I, '#2f8f7a', em_coconut, band='#f4f1e6')


@icon('condensed_milk', 'Condensed Milk')
def ic_condensed(I):
    can(I, '#2a64b8', None, band='#f4f1e8', h=(40, 104))
    with I.at(64, 72, 1.3): em_drop('#fbf6e6')(I)


@icon('evaporated_milk', 'Evaporated Milk')
def ic_evaporated(I):
    can(I, '#c8302c', None, band='#f4f1e8', h=(40, 104))
    with I.at(64, 72, 1.3): em_drop('#ffffff')(I)


@icon('buttermilk', 'Buttermilk')
def ic_buttermilk(I):
    carton(I, '#fbf3d6', em_drop('#fbf6e2'), side='#e3cf96', cap='#e3a51d')
    I.p('M32 98H76V108H32Z', '#e3a51d')


@icon('skyr', 'Skyr')
def ic_skyr(I):
    cup_pot(I, '#eaf2fb', '#22408a', '#f2f4f8', '#fbfbf8')
    I.p('M50 48C54 42 60 40 64 42C70 40 76 42 78 48Z', '#fbfbf8')
    for x, y in ((56, 46), (66, 44), (72, 47)):
        I.c(x, y, 3, I.rg('#3e3a8a', .5, .3))


@icon('creme_fraiche', 'Creme Fraiche')
def ic_creme_fraiche(I):
    tub(I, '#fbf8ef', '#1f3e73', None, band='#e8dcc0')
    I.p('M48 46C52 38 60 36 66 38C74 36 82 40 80 46Z', I.rg('#fbf8ef', .2, .15))


@icon('butter', 'Butter')
def ic_butter(I):
    I.shadow(rx=46)
    I.p('M16 74L64 56L112 70L64 90Z', I.rg('#f5f6f8', .2, .15))
    I.p('M16 74L64 90V98L16 82Z', '#d9dde2')
    I.p('M64 90L112 70V78L64 98Z', '#c3c8cf')
    I.p('M30 66L66 52L98 62L62 78Z', I.rg('#fbe08a', .35, .1))
    I.p('M30 66L62 78V88L30 76Z', '#f3cf62')
    I.p('M62 78L98 62V72L62 88Z', '#e6bd4c')
    I.p('M44 64L64 72', 'none')
    I.line('M44 64Q58 62 72 66', '#fdeeb8', 2.5, .9)
    I.hl(52, 60, 10, 2.5, -15, .7)
