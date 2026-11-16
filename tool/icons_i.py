"""Иконки: сырое мясо и птица (было 48 × 🥩, 20 × 🍗)."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots


def chunk(I, meat, fat='#f6efe2', marble=0, rot=0):
    """Кусок сырого мяса 3/4 с жировой каймой."""
    I.shadow(rx=46)
    with I.at(64, 66, 1, rot):
        I.p('M-44 4C-46 -14 -26 -28 -2 -28C24 -28 46 -18 44 0C46 18 24 30 0 30C-26 30 -42 20 -44 4Z', dk(meat, .3))
        top = 'M-44 -2C-46 -20 -26 -32 -2 -32C24 -32 46 -22 44 -6C46 12 24 24 0 24C-26 24 -42 14 -44 -2Z'
        I.p(top, I.rg(meat, .35, .3))
        with I.clip(top):
            I.p('M-46 -6C-40 -24 -20 -34 0 -34C20 -34 40 -26 46 -10L40 -8C34 -22 18 -28 0 -28C-18 -28 -36 -20 -40 -4Z', fat)
            for i in range(marble):
                x, y = -30 + (i * 23) % 60, -14 + (i * 13) % 30
                I.line(f'M{x} {y}q6 -3 10 1t9 -2', lt(fat, .1), 1.6, .85)
        I.hl(-16, -14, 12, 4, -10, .45)


def tray(I, mince, tray_c='#2f2f36'):
    """Фарш в лотке."""
    I.shadow(rx=50)
    I.p('M12 62L22 100Q24 106 32 106H96Q104 106 106 100L116 62Z', I.vg(lt(tray_c, .1), dk(tray_c, .2)))
    I.e(64, 62, 52, 14, dk(tray_c, .1))
    I.p('M20 64C26 46 46 40 64 40C82 40 102 46 108 64C96 72 32 72 20 64Z', I.rg(mince, .35, .3))
    for i in range(40):
        a, t = i * 2.39996, math.sqrt((i + .5) / 40)
        x, y = 64 + math.cos(a) * 40 * t, 58 + math.sin(a) * 9 * t - (1 - t) * 8
        I.line(f'M{f(x - 2)} {f(y)}q2 -2 4 0', lt(mince, .35) if i % 2 else dk(mince, .2), 1.3, .8)
    I.p('M12 62H116L112 66H16Z', lt(tray_c, .25), .6)


@icon('beef', 'Beef')
def ic_beef(I):
    chunk(I, '#b8202c', marble=3)


@icon('pork', 'Pork')
def ic_pork(I):
    chunk(I, '#e8808a', fat='#fbf6ee', marble=1, rot=-8)


@icon('veal', 'Veal')
def ic_veal(I):
    chunk(I, '#e8a0a0', fat='#fbf8f2', rot=6)


@icon('ground_beef', 'Ground Beef')
def ic_ground_beef(I):
    tray(I, '#c42a34')


@icon('minced_pork', 'Minced Pork')
def ic_minced_pork(I):
    tray(I, '#e88a90', '#f2f2f2')


@icon('ground_turkey', 'Ground Turkey')
def ic_ground_turkey(I):
    tray(I, '#e8b0a0', '#3a6fc8')


@icon('ground_chicken', 'Ground Chicken')
def ic_ground_chicken(I):
    tray(I, '#f2c4b0', '#f2c43a')


@icon('ground_lamb', 'Ground Lamb')
def ic_ground_lamb(I):
    tray(I, '#a8303a', '#3a8a4a')


@icon('steak', 'Steak')
def ic_steak(I):  # T-bone
    I.shadow(rx=48)
    I.p('M16 66C14 44 40 30 66 32C96 32 116 46 112 68C110 90 84 102 60 98C34 96 18 86 16 66Z', '#f6efe2')
    I.p('M22 66C20 48 42 36 66 38C92 38 108 50 106 68C104 86 82 94 60 92C38 90 24 82 22 66Z', I.rg('#b8202c', .35, .3))
    I.p('M64 36L70 40V92L64 94L58 92V40Z', I.rg('#f4ecd8', .4, .2))
    I.p('M64 60H100V68H64Z', '#f4ecd8')
    for x, y in ((40, 56), (44, 76), (84, 50), (88, 80)):
        I.line(f'M{x} {y}q5 -3 9 1', '#f2d8d0', 1.4, .8)
    I.hl(40, 48, 10, 4, -15, .45)


@icon('beef_ribeye', 'Beef Ribeye')
def ic_ribeye(I):
    chunk(I, '#c02430', fat='#f8f0e0', marble=9, rot=-4)
    I.e(64, 60, 10, 6, '#f8f0e0', .9)


@icon('liver', 'Liver')
def ic_liver(I):
    I.shadow(rx=46)
    I.p('M14 64C12 44 40 34 64 40C82 30 112 40 114 60C116 84 90 96 66 90C42 98 16 88 14 64Z', I.rg('#7a1e24', .45, .4))
    I.line('M64 42Q60 66 66 90', '#5a1018', 2, .5)
    I.hl(38, 52, 14, 5, -15, .7)
    I.hl(88, 50, 10, 4, -10, .6)


@icon('chicken_liver', 'Chicken Liver')
def ic_chicken_liver(I):
    I.shadow(rx=46)
    for x, y, r in ((42, 70, -20), (82, 66, 20), (62, 88, 0)):
        with I.at(x, y, 1, r):
            I.p('M-20 0C-20 -12 -8 -14 0 -8C8 -14 20 -12 20 0C20 12 6 16 0 12C-6 16 -20 12 -20 0Z', I.rg('#8a2a24', .5, .4))
            I.hl(-8, -5, 5, 2.5, -15, .8)


@icon('beef_tongue', 'Beef Tongue')
def ic_tongue(I):
    I.shadow(rx=48)
    I.p('M14 70C14 52 40 46 70 50C92 52 114 58 114 72C114 86 92 92 70 92C40 94 14 88 14 70Z', I.rg('#d8848a', .4, .3))
    dots(I, 70, 66, 36, 10, 30, 1.2, '#c06870', .6)
    I.p('M14 70C14 60 20 54 28 52C22 60 22 80 28 88C20 86 14 80 14 70Z', '#b85a64')
    I.hl(60, 58, 18, 4, -4, .5)


@icon('lamb_chops', 'Lamb Chops')
def ic_lamb_chops(I):
    I.shadow(rx=48)
    for x, rot in ((44, -18), (64, -2), (84, 14)):
        with I.at(x, 76, 1, rot):
            I.p('M-3 -24L-2 -54Q0 -58 2 -54L3 -24Z', I.cyl('#f4ecd8', .45, .25))
            I.p('M-14 -8C-16 -22 -6 -28 0 -28C8 -28 16 -22 14 -8C14 8 8 20 0 20C-8 20 -14 8 -14 -8Z', '#f6efe2')
            I.p('M-11 -6C-12 -18 -4 -23 0 -23C6 -23 12 -18 11 -6C11 6 6 15 0 15C-6 15 -11 6 -11 -6Z', I.rg('#c0303a', .4, .3))


@icon('pork_chops', 'Pork Chops')
def ic_pork_chops(I):
    I.shadow(rx=48)
    I.p('M14 70C14 48 40 36 66 38C94 38 114 52 112 70C110 90 86 98 62 96C36 96 14 90 14 70Z', '#fbf6ee')
    I.p('M20 70C20 52 42 44 66 44C90 44 106 56 104 70C102 86 82 90 62 90C40 90 20 86 20 70Z', I.rg('#e8848e', .4, .3))
    I.p('M30 54C40 50 50 52 52 60C52 70 40 74 30 70C24 66 24 58 30 54Z', I.rg('#f4ecd8', .5, .2))
    I.hl(56, 54, 14, 4, -10, .5)


@icon('chicken_breast', 'Chicken Breast')
def ic_chicken_breast(I):
    I.shadow(rx=48)
    for x, y, r in ((52, 66, -15), (78, 82, 10)):
        with I.at(x, y, 1, r):
            I.p('M-36 6C-38 -10 -20 -22 6 -20C26 -18 40 -6 38 6C36 16 16 22 -4 18C-20 16 -34 14 -36 6Z', I.rg('#f4b8b0', .4, .25))
            I.line('M-28 2Q0 -6 30 2', '#e89a92', 1.4, .6)
            I.hl(-8, -10, 14, 3.5, -5, .55)


@icon('chicken_thighs', 'Chicken Thighs')
def ic_chicken_thighs(I):
    I.shadow(rx=48)
    for x, y, r in ((44, 70, -10), (84, 72, 15)):
        with I.at(x, y, 1, r):
            I.p('M-22 -4C-24 -20 -6 -26 6 -24C20 -22 26 -10 22 4C20 18 6 24 -6 22C-18 20 -22 10 -22 -4Z', I.rg('#f2c4a8', .4, .3))
            I.p('M-20 -6C-12 -16 8 -18 20 -8C14 -2 -8 0 -20 -6Z', '#f8dcc8', .7)
            dots(I, 0, 2, 14, 14, 10, 1, '#e8a888', .6)


@icon('chicken_wings', 'Chicken Wings')
def ic_chicken_wings(I):
    I.shadow(rx=48)
    for x, y, r in ((46, 64, -20), (82, 80, 25)):
        with I.at(x, y, 1, r):
            I.p('M-30 -6C-30 -16 -16 -16 -6 -12L4 -8C10 -16 22 -18 30 -10C34 0 24 10 12 8L-6 10C-18 12 -30 6 -30 -6Z', I.rg('#f2c4a0', .4, .3))
            I.line('M-6 -10Q0 0 -4 10', '#e0a07a', 1.4, .7)
            dots(I, -14, -2, 12, 5, 8, .9, '#e0a888', .6)


@icon('chicken_drumsticks', 'Chicken Drumsticks')
def ic_drumsticks(I):
    I.shadow(rx=48)
    for x, y, r in ((50, 62, -30), (80, 74, 20)):
        with I.at(x, y, 1, r):
            I.p('M-4 18L-3 40Q0 44 3 40L4 18Z', I.cyl('#f4ecd8', .45, .25))
            I.c(-4, 42, 4, '#f4ecd8'); I.c(4, 42, 4, '#f4ecd8')
            I.p('M0 -30C16 -30 20 -10 14 6C10 16 6 22 0 22C-6 22 -10 16 -14 6C-20 -10 -16 -30 0 -30Z', I.rg('#f2c0a0', .45, .3))
            dots(I, 0, -6, 10, 18, 12, 1, '#e0a080', .6)


@icon('whole_chicken', 'Whole Chicken')
def ic_whole_chicken(I):
    I.shadow(rx=50)
    I.p('M20 70C18 48 40 36 64 38C90 38 110 50 108 72C106 94 84 104 62 102C38 102 22 92 20 70Z', I.rg('#f2c8a8', .45, .3))
    for x, r in ((30, -40), (98, 40)):
        with I.at(x, 56, 1, r):
            I.p('M-8 0C-10 -14 10 -14 8 0C6 6 -6 6 -8 0Z', I.rg('#f2c0a0', .45, .3))
            I.c(-2, -14, 3.5, '#f4ecd8'); I.c(3, -14, 3.5, '#f4ecd8')
    I.line('M44 52Q64 60 84 52', '#e0a888', 1.6, .6)
    dots(I, 64, 76, 30, 16, 30, 1, '#e4b090', .6)
    I.hl(46, 52, 14, 5, -12, .55)


@icon('sausages', 'Sausages')
def ic_sausages(I):
    I.shadow(rx=50)
    for y, x, rot in ((52, 60, -10), (72, 66, -6), (92, 62, -2)):
        with I.at(x, y, 1, rot):
            I.p('M-40 -8C-48 -8 -48 8 -40 8H40C48 8 48 -8 40 -8Z', I.rg('#e0907a', .45, .3))
            I.line('M-46 0L-52 -3M46 0L52 -3', '#d8b090', 2)
            I.hl(-10, -4, 22, 2, 0, .6)
