"""Иконки: фрукты и ягоды, у которых эмодзи изображал другой плод (малина = виноград, финики = пальма …)."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf, stem


def drupes(I, cx, cy, rx, ry, c, r=5.5, n=None):
    """Ягода из шариков-костянок (малина, ежевика, шелковица)."""
    pts = []
    for row in range(-3, 4):
        y = cy + row * r * 1.45
        w = rx * math.sqrt(max(0, 1 - (row * r * 1.45 / ry) ** 2))
        k = max(1, int(w * 2 / (r * 1.7)))
        for i in range(k):
            x = cx - w + (i + .5) * 2 * w / k + (row % 2) * .8
            pts.append((x, y))
    for x, y in sorted(pts, key=lambda p: p[1]):
        I.c(x, y, r, I.rg(c, .55, .35))
        I.c(x - r * .35, y - r * .35, r * .28, '#fff', .55)


def round_fruit(I, cx, cy, rx, ry, c, light=.45, shade=.35, rot=0):
    I.e(cx, cy, rx, ry, I.rg(c, light, shade), rot=rot)
    I.hl(cx - rx * .4, cy - ry * .45, rx * .28, ry * .18)


def citrus_half(I, cx, cy, r, peel, pith, flesh, n=10):
    I.c(cx, cy, r, peel)
    I.c(cx, cy, r - 2.5, pith)
    I.c(cx, cy, r - 5, I.rg(flesh, .35, .2))
    for i in range(n):
        a = math.radians(i * 360 / n)
        I.line(f'M{f(cx)} {f(cy)}L{f(cx + (r - 5) * math.cos(a))} {f(cy + (r - 5) * math.sin(a))}', pith, 1.6)
    I.c(cx, cy, 2.5, pith)


@icon('raspberry', 'Raspberry')
def ic_raspberry(I):
    I.shadow(rx=40)
    for x, y in ((44, 70), (82, 64)):
        drupes(I, x, y, 20, 24, '#e0284a', 5.2)
    leaf(I, 70, 34, 1.0, -150, '#4f9a33')
    leaf(I, 56, 36, .9, -40, '#5aa63a')


@icon('golden_raspberries', 'Golden Raspberries')
def ic_golden_raspberry(I):
    I.shadow(rx=40)
    for x, y in ((44, 70), (82, 64)):
        drupes(I, x, y, 20, 24, '#f2b62a', 5.2)
    leaf(I, 70, 34, 1.0, -150, '#4f9a33')


@icon('blackberry', 'Blackberry')
def ic_blackberry(I):
    I.shadow(rx=40)
    for x, y in ((46, 72), (82, 66)):
        drupes(I, x, y, 18, 24, '#2a1630', 5.0)
    I.p('M74 40L84 34L94 40L86 44Z', '#4f8a33')


@icon('mulberry', 'Mulberry')
def ic_mulberry(I):
    I.shadow(rx=40)
    for x, y, rot in ((48, 70, -20), (82, 66, 20)):
        drupes(I, x, y, 12, 28, '#4a1838', 4.2)
        stem(I, f'M{x} {y - 30}Q{x + 2} {y - 38} {x + 8} {y - 42}', '#7a9a3a', 2.2)


@icon('gooseberry', 'Gooseberry')
def ic_gooseberry(I):
    I.shadow(rx=44)
    for x, y, r in ((42, 72, 22), (84, 70, 22), (62, 92, 18)):
        I.c(x, y, r, I.rg('#9ccc5a', .5, .3))
        for k in range(-2, 3):
            I.line(f'M{x + k * r * .3} {y - r * .9}Q{x + k * r * .5} {y} {x + k * r * .3} {y + r * .9}', '#e8f4c8', 1.1, .7)
        I.hl(x - r * .4, y - r * .4, r * .3, r * .18)
    stem(I, 'M42 50Q44 42 50 38', '#8a6a3a', 2)


def currant_sprig(I, c, light=.55):
    I.shadow(rx=40)
    I.line('M30 22Q60 34 70 70Q74 86 76 100', '#5a7a2a', 2.4)
    for x, y, r in ((40, 40, 9), (54, 50, 10), (66, 62, 10.5), (50, 70, 10), (72, 80, 11), (60, 92, 10.5), (82, 98, 10), (86, 70, 9.5)):
        I.c(x, y, r, I.rg(c, light, .35))
        I.c(x - r * .35, y - r * .35, r * .25, '#fff', .7)
    leaf(I, 30, 24, 1.1, -170, '#4f9a33')


@icon('black_currant', 'Black Currant')
def ic_black_currant(I):
    currant_sprig(I, '#2a1a3a', .45)


@icon('red_currant', 'Red Currant')
def ic_red_currant(I):
    currant_sprig(I, '#e0202c', .6)


@icon('white_currant', 'White Currant')
def ic_white_currant(I):
    currant_sprig(I, '#efe6b8', .5)


@icon('cranberry', 'Cranberry')
def ic_cranberry(I):
    I.shadow(rx=44)
    for x, y, r in ((40, 70, 17), (66, 62, 18), (90, 72, 16), (52, 92, 17), (80, 94, 16)):
        I.e(x, y, r, r * .9, I.rg('#b8102a', .5, .35))
        I.c(x, y - r * .8, 1.5, '#5a2a1a')
        I.hl(x - r * .35, y - r * .35, r * .3, r * .18)


@icon('lingonberry', 'Lingonberry')
def ic_lingonberry(I):
    I.shadow(rx=40)
    I.line('M26 96Q50 70 96 40', '#7a5a2a', 2)
    for x, y in ((36, 92), (52, 74), (70, 60), (86, 48)):
        for s in (-1, 1):
            I.e(x + s * 8, y + s * 6, 7, 3.8, I.rg('#2f7a33', .5, .3), rot=-35)
    for x, y in ((50, 92), (64, 86), (58, 100), (76, 94), (70, 76), (84, 82)):
        I.c(x, y, 7.5, I.rg('#d8202c', .55, .35))
        I.c(x - 2.5, y - 2.5, 1.8, '#fff', .7)


@icon('goji', 'Goji Berries')
def ic_goji(I):
    I.shadow(rx=44)
    for i in range(16):
        a, t = i * 2.39996, math.sqrt((i + .5) / 16)
        x, y = 64 + math.cos(a) * 36 * t, 88 + math.sin(a) * 14 * t - (1 - t) * 24
        with I.at(x, y, 1, (i * 47) % 180):
            I.e(0, 0, 9, 4.5, I.rg('#e0401c', .5, .35))
            I.line('M-6 -1Q0 1 6 -1', '#b8260e', .8, .6)


@icon('plum', 'Plum')
def ic_plum(I):
    I.shadow(rx=44)
    round_fruit(I, 84, 64, 26, 28, '#5a2a6a')
    I.line('M84 38Q82 64 86 90', '#3e1a4a', 1.5, .5)
    I.p('M28 104C16 92 18 64 38 58C52 54 64 64 64 80C64 96 50 112 28 104Z', '#5a2a6a')
    I.p('M30 100C20 90 22 68 38 63C50 60 59 68 59 80C59 94 48 106 30 100Z', I.rg('#f3c43a', .4, .2))
    I.e(40, 82, 7, 10, I.rg('#c27a3a', .4, .3), rot=-20)
    stem(I, 'M84 38Q86 30 92 26', '#6a4a2a', 2.5)
    leaf(I, 88, 32, .9, -30, '#4f9a33')


@icon('apricot', 'Apricot')
def ic_apricot(I):
    I.shadow(rx=44)
    round_fruit(I, 82, 64, 26, 26, '#f59a2a')
    I.e(90, 62, 10, 12, '#e8562a', .35)
    I.line('M80 40Q72 64 80 88', '#d8781a', 1.6, .5)
    I.p('M24 100C14 86 20 64 40 62C56 60 64 72 62 86C60 102 40 112 24 100Z', '#f08a24')
    I.p('M27 97C19 85 24 67 40 66C53 65 59 75 57 87C55 100 39 107 27 97Z', I.rg('#fbb44a', .35, .2))
    I.e(40, 84, 8, 11, I.rg('#a85a2a', .4, .3), rot=-15)
    leaf(I, 82, 38, .9, -40, '#4f9a33')


@icon('dates', 'Dates')
def ic_dates(I):
    I.shadow(rx=44)
    for x, y, rot in ((40, 72, -30), (84, 70, 25), (62, 90, 80)):
        with I.at(x, y, 1, rot):
            I.e(0, 0, 11, 22, I.rg('#7a3a12', .4, .4))
            for k in (-8, 0, 8):
                I.line(f'M-8 {k}q8 4 16 -2', '#5a2a0e', 1.2, .6)
            I.hl(-4, -10, 3, 7, 0, .8)


@icon('medjool_dates', 'Medjool Dates')
def ic_medjool(I):
    I.shadow(rx=44)
    for x, y, rot in ((46, 70, -20), (80, 76, 30)):
        with I.at(x, y, 1, rot):
            I.e(0, 0, 15, 28, I.rg('#5a2410', .35, .4))
            for k in (-14, -4, 6, 16):
                I.line(f'M-11 {k}q11 6 22 -3', '#3e180a', 1.4, .6)
            I.hl(-5, -14, 4, 9, 0, .7)
    with I.at(52, 50, 1, -20):
        I.r(-4, -32, 8, 8, 2, '#d8b46a')


@icon('rosehip', 'Rosehip')
def ic_rosehip(I):
    I.shadow(rx=44)
    for x, y, rot in ((44, 72, -20), (82, 66, 22)):
        with I.at(x, y, 1, rot):
            I.e(0, 0, 15, 22, I.rg('#e0401c', .5, .35))
            for a in (-40, -15, 15, 40):
                with I.at(0, -20, 1, a): I.p('M0 0L-2 -12L2 -12Z', '#3a2a1a')
            I.hl(-5, -8, 4, 7, 0, .8)


@icon('rose_hips', 'Rose Hips')
def ic_rose_hips(I):  # сушёные — в мешочке
    I.shadow(rx=44)
    I.p('M28 70C24 50 40 44 64 44C88 44 104 50 100 70L96 100Q94 110 84 110H44Q34 110 32 100Z', I.rg('#d8c49a', .35, .3))
    I.e(64, 50, 34, 8, '#8a6a3a')
    for i in range(12):
        a, t = i * 2.39996, math.sqrt((i + .5) / 12)
        x, y = 64 + math.cos(a) * 26 * t, 46 + math.sin(a) * 5 * t - (1 - t) * 8
        I.e(x, y, 6, 4.5, I.rg('#b8301a', .45, .35), rot=i * 30)


@icon('tangerine', 'Tangerine')
def ic_tangerine(I):
    I.shadow(rx=46)
    round_fruit(I, 78, 64, 30, 26, '#f88a12')
    dots(I, 78, 64, 26, 22, 30, .8, '#ffb85a', .6)
    leaf(I, 76, 40, 1.1, -60, '#3f8f2a')
    for i, rot in enumerate((-30, 0, 30)):
        with I.at(40, 92, 1, rot):
            I.p('M0 0C-10 -6 -10 -26 0 -32C8 -26 8 -6 0 0Z', I.rg('#fca43a', .4, .25))
            I.line('M0 -2Q-3 -16 0 -30', '#fde3b8', 1, .7)


@icon('clementine', 'Clementine')
def ic_clementine(I):
    I.shadow(rx=46)
    for x, y, r in ((44, 70, 24), (84, 72, 24)):
        round_fruit(I, x, y, r, r * .92, '#f5741a')
        dots(I, x, y, r * .8, r * .7, 20, .7, '#ffa65a', .6)
    leaf(I, 60, 46, 1.2, -60, '#2f7f2a')
    leaf(I, 62, 46, 1.0, -130, '#3f8f2a')


@icon('grapefruit', 'Grapefruit')
def ic_grapefruit(I):
    I.shadow(rx=46)
    round_fruit(I, 82, 56, 30, 30, '#f2a64a')
    citrus_half(I, 48, 84, 30, '#f0a24a', '#fde9d6', '#f05a5a', 11)


@icon('blood_orange', 'Blood Orange')
def ic_blood_orange(I):
    I.shadow(rx=46)
    round_fruit(I, 82, 56, 28, 28, '#e8641c')
    I.e(94, 60, 12, 14, '#b8241c', .35)
    citrus_half(I, 48, 84, 28, '#e05a1c', '#f8d8c8', '#9a0e1e', 10)


@icon('pomelo', 'Pomelo')
def ic_pomelo(I):
    I.shadow(rx=46)
    round_fruit(I, 80, 58, 34, 32, '#c8d84a')
    citrus_half(I, 46, 86, 28, '#b8cc3a', '#fbf4e0', '#f6c8b8', 12)
    I.c(46, 86, 21, 'none')


@icon('kumquat', 'Kumquat')
def ic_kumquat(I):
    I.shadow(rx=44)
    for x, y, rot in ((44, 76, -20), (66, 64, 10), (88, 80, 30)):
        round_fruit(I, x, y, 13, 18, '#f7901a', rot=rot)
        dots(I, x, y, 9, 13, 10, .6, '#ffc07a', .6)
    leaf(I, 66, 44, 1.1, -70, '#2f7f2a')


@icon('papaya', 'Papaya')
def ic_papaya(I):
    I.shadow(rx=46)
    with I.at(64, 66, 1, -30):
        I.p('M0 -44C18 -44 26 -24 26 0C26 28 14 44 0 44C-14 44 -26 28 -26 0C-26 -24 -18 -44 0 -44Z', '#6aa83a')
        I.p('M0 -40C15 -40 22 -22 22 0C22 25 12 40 0 40C-12 40 -22 25 -22 0C-22 -22 -15 -40 0 -40Z', I.rg('#f8862a', .4, .25))
        I.p('M0 -20C8 -20 10 -6 10 6C10 22 5 30 0 30C-5 30 -10 22 -10 6C-10 -6 -8 -20 0 -20Z', '#f05a1a', .5)
        dots(I, 0, 6, 7, 20, 18, 2.2, '#1f1a16')


@icon('black_sapote', 'Black Sapote')
def ic_black_sapote(I):
    I.shadow(rx=46)
    round_fruit(I, 82, 60, 28, 24, '#5f8a2a')
    I.p('M70 38L82 32L94 38L82 42Z', '#7a6a2a')
    I.e(46, 86, 30, 22, '#4f7a24')
    I.e(46, 85, 26, 18, I.rg('#3a2014', .3, .3))
    I.p('M30 82C36 76 46 86 56 80C62 76 66 84 70 84', 'none')
    I.line('M28 84C36 78 46 88 56 82C62 78 66 86 70 86', '#5a3424', 3, .6)
    I.hl(36, 78, 6, 3, -15, .4)


@icon('canistel', 'Canistel')
def ic_canistel(I):
    I.shadow(rx=46)
    with I.at(80, 60, 1, 25):
        I.p('M0 -30C18 -30 24 -10 22 10C20 26 10 32 0 32C-10 32 -20 26 -22 10C-24 -10 -18 -30 0 -30Z', I.rg('#f2b21a', .5, .3))
        I.p('M0 -30L-3 -36H3Z', '#6a4a2a')
    I.e(46, 86, 26, 20, '#e8a514')
    I.e(46, 85, 22, 16, I.rg('#f8c84a', .35, .2))
    I.e(46, 85, 6, 9, I.rg('#5a3a1e', .4, .3))


@icon('salak', 'Salak')
def ic_salak(I):
    I.shadow(rx=44)
    for x, y in ((80, 58),):
        with I.at(x, y):
            I.p('M0 -32C18 -24 24 4 18 18C12 30 -12 30 -18 18C-24 4 -18 -24 0 -32Z', I.rg('#6a3a1e', .4, .35))
            for row in range(5):
                for i in range(-2, 3):
                    I.p(f'M{i * 7 + (row % 2) * 3.5 - 3} {-20 + row * 9}l3 -5l3 5Z', '#8a5230', .8)
    I.e(44, 86, 18, 22, I.rg('#f4ead2', .4, .2))
    I.line('M44 66V106', '#e0d2ae', 1.4)
    I.line('M44 66Q34 86 44 106', '#e0d2ae', 1.2)


@icon('jackfruit', 'Jackfruit')
def ic_jackfruit(I):
    I.shadow(rx=50)
    with I.at(64, 64, 1, -20):
        I.e(0, 0, 50, 34, I.rg('#9cad3a', .4, .35))
        for row in range(-3, 4):
            for i in range(-6, 7):
                x, y = i * 7 + (row % 2) * 3.5, row * 8
                if (x / 48) ** 2 + (y / 32) ** 2 < 1:
                    I.c(x, y, 1.6, '#c8d460', .8)
        I.p('M-50 0L-58 -4V4Z', '#6a5a2a')
    I.p('M60 96C60 84 74 80 80 88C86 80 100 86 98 98C94 106 66 106 60 96Z', I.rg('#f8c42a', .4, .25))


@icon('durian', 'Durian')
def ic_durian(I):
    I.shadow(rx=46)
    I.e(64, 66, 40, 38, I.rg('#9aa83a', .4, .35))
    for row in range(-4, 5):
        for i in range(-5, 6):
            x, y = 64 + i * 8 + (row % 2) * 4, 66 + row * 8
            if ((x - 64) / 40) ** 2 + ((y - 66) / 38) ** 2 < .95:
                I.p(f'M{x - 3.5} {y + 3}L{x} {y - 5}L{x + 3.5} {y + 3}Z', I.rg('#7a8a2a', .55, .3))
    I.r(60, 22, 8, 12, 3, I.cyl('#6a5a2a', .4, .3))
    I.hl(48, 46, 10, 6, -30, .5)


@icon('rambutan', 'Rambutan')
def ic_rambutan(I):
    I.shadow(rx=44)
    for cx, cy, r in ((80, 60, 24), (46, 78, 24)):
        hair = {'#2f9a3a': '', '#d8282a': ''}
        for i in range(22):
            a = i * math.tau / 22
            x1, y1 = cx + r * .9 * math.cos(a), cy + r * .9 * math.sin(a)
            x2, y2 = cx + (r + 10) * math.cos(a + .3), cy + (r + 10) * math.sin(a + .3)
            hair['#2f9a3a' if i % 3 == 0 else '#d8282a'] += f'M{f(x1)} {f(y1)}Q{f((x1 + x2) / 2 + 3)} {f((y1 + y2) / 2)} {f(x2)} {f(y2)}'
        for c, d in hair.items(): I.line(d, c, 2.2)
        I.c(cx, cy, r, I.rg('#d8282a', .45, .35))
        I.line(''.join(f'M{f(cx + r * .6 * math.cos(i * 2.4))} {f(cy + r * .6 * math.sin(i * 2.4))}l3 -3' for i in range(14)), '#f2a03a', 1.4, .8)
    I.e(46, 86, 13, 14, I.rg('#f4f2ea', .5, .15))


@icon('mangosteen', 'Mangosteen')
def ic_mangosteen(I):
    I.shadow(rx=46)
    round_fruit(I, 80, 64, 30, 28, '#4a1838')
    for a in range(0, 360, 72):
        with I.at(80, 38, 1, a): I.e(0, -5, 5, 8, I.rg('#5a7a2a', .4, .3))
    I.c(44, 88, 24, '#5a1a40')
    I.c(44, 88, 20, '#c0466a')
    for a in range(0, 360, 60):
        with I.at(44, 88, 1, a):
            I.p('M0 0C-6 -4 -6 -14 0 -16C6 -14 6 -4 0 0Z', I.rg('#fbf7ef', .4, .15))


@icon('feijoa', 'Feijoa')
def ic_feijoa(I):
    I.shadow(rx=46)
    with I.at(80, 58, 1, 20):
        I.e(0, 0, 20, 30, I.rg('#4f8a33', .45, .35))
        for a in range(0, 360, 90):
            with I.at(0, 28, 1, a): I.p('M0 0L-2 6H2Z', '#3a5a22')
    I.e(44, 88, 24, 20, '#4f8a33')
    I.e(44, 87, 20, 16, I.rg('#efe8c8', .4, .2))
    for a in range(0, 360, 90):
        with I.at(44, 87, 1, a + 45):
            I.p('M0 0C-4 -3 -5 -9 0 -12C5 -9 4 -3 0 0Z', '#d9cfa0')


@icon('kiwano', 'Kiwano')
def ic_kiwano(I):
    I.shadow(rx=46)
    with I.at(64, 66, 1, -25):
        I.e(0, 0, 44, 28, I.rg('#f2a21a', .5, .35))
        for row in range(-2, 3):
            for i in range(-4, 5):
                x, y = i * 9 + (row % 2) * 4.5, row * 9
                if (x / 42) ** 2 + (y / 26) ** 2 < .9:
                    I.p(f'M{x - 3} {y + 2}L{x + 1} {y - 7}L{x + 3} {y + 2}Z', I.rg('#f8d06a', .5, .3))
        I.p('M-30 -6Q0 -24 32 -8', 'none')
        dots(I, 0, 0, 40, 24, 30, 1, '#5a8a2a', .35)


@icon('cherimoya', 'Cherimoya')
def ic_cherimoya(I):
    I.shadow(rx=46)
    I.p('M64 26C88 26 100 46 98 70C96 94 82 108 64 108C46 108 32 94 30 70C28 46 40 26 64 26Z', I.rg('#8ab84a', .45, .35))
    for row in range(5):
        for i in range(-3, 4):
            x, y = 64 + i * 12 + (row % 2) * 6, 40 + row * 14
            if abs(x - 64) < 32 - abs(row - 2) * 3:
                I.p(f'M{x - 5} {y + 4}Q{x} {y - 6} {x + 5} {y + 4}', 'none')
                I.line(f'M{x - 5} {y + 4}Q{x} {y - 4} {x + 5} {y + 4}', '#5a8a2a', 1.4, .7)
    I.r(61, 18, 6, 10, 2, '#6a5a2a')
    I.hl(48, 46, 8, 5)


@icon('soursop', 'Soursop')
def ic_soursop(I):
    I.shadow(rx=46)
    with I.at(64, 66, 1, 20):
        I.p('M0 -42C22 -40 30 -14 28 10C26 32 14 44 0 44C-14 44 -28 30 -28 4C-28 -20 -18 -42 0 -42Z', I.rg('#3f8a33', .45, .35))
        for i in range(30):
            a, t = i * 2.39996, math.sqrt((i + .5) / 30)
            x, y = math.cos(a) * 24 * t, math.sin(a) * 38 * t
            I.p(f'M{f(x - 1.5)} {f(y)}Q{f(x + 2)} {f(y - 5)} {f(x + 4)} {f(y - 4)}', 'none')
            I.line(f'M{f(x)} {f(y)}l3 -4', '#b8d87a', 1.6, .9)


@icon('longan', 'Longan')
def ic_longan(I):
    I.shadow(rx=44)
    I.line('M64 16Q60 30 50 40M64 16Q70 32 82 42M64 16V50', '#7a6a3a', 2)
    for x, y in ((44, 60), (82, 60), (62, 72), (46, 92), (80, 92)):
        I.c(x, y, 15, I.rg('#c8a46a', .45, .35))
        dots(I, x, y, 11, 11, 8, .8, '#a8844a', .6)
    I.c(62, 98, 13, I.rg('#f4f0e6', .5, .15))
    I.c(62, 98, 4, I.rg('#2a1a12', .4, .3))


@icon('jujube', 'Jujube')
def ic_jujube(I):
    I.shadow(rx=44)
    for x, y, rot, c in ((44, 70, -20, '#9a2a1a'), (84, 66, 20, '#b8541a'), (64, 92, 70, '#a3361a')):
        round_fruit(I, x, y, 15, 20, c, rot=rot)
        I.e(x + 5, y + 5, 8, 10, '#d8b45a', .45, rot=rot)
    leaf(I, 64, 40, 1, -60, '#4f9a33')


@icon('prickly_pear', 'Prickly Pear')
def ic_prickly_pear(I):
    I.shadow(rx=46)
    with I.at(80, 60, 1, 20):
        I.e(0, 0, 20, 28, I.rg('#d8285a', .45, .35))
        dots(I, 0, 0, 16, 24, 14, 1.4, '#f6c84a', .9)
    I.e(46, 88, 24, 20, '#c8285a')
    I.e(46, 87, 20, 16, I.rg('#e8346a', .35, .2))
    dots(I, 46, 87, 15, 12, 24, 1.3, '#3a1a20')


@icon('amla', 'Amla')
def ic_amla(I):
    I.shadow(rx=44)
    for x, y, r in ((44, 74, 22), (84, 70, 20), (64, 94, 16)):
        I.c(x, y, r, I.rg('#b8d06a', .5, .3))
        for a in (-60, -20, 20, 60):
            with I.at(x, y, 1, a): I.line(f'M0 {-r * .9}Q{r * .2} 0 0 {r * .9}', '#e6f0b8', 1.2, .8)
        I.hl(x - r * .4, y - r * .4, r * .3, r * .18)


@icon('granadilla', 'Granadilla')
def ic_granadilla(I):
    I.shadow(rx=46)
    round_fruit(I, 80, 58, 28, 30, '#f2a21a')
    dots(I, 80, 58, 24, 26, 18, 1, '#fbe8b0', .7)
    I.line('M80 28Q82 18 90 14', '#7a8a3a', 3)
    I.c(44, 88, 24, '#e89416')
    I.c(44, 88, 20, '#fbf4e2')
    I.c(44, 88, 17, I.rg('#c8c8b0', .4, .2))
    dots(I, 44, 88, 13, 13, 18, 2.2, '#2a2a22')
    dots(I, 43, 87, 13, 13, 18, 1.2, '#e6e2c8', .8, seed=1.2)


@icon('sea_buckthorn', 'Sea Buckthorn')
def ic_sea_buckthorn(I):
    I.shadow(rx=44)
    I.line('M20 100Q60 70 108 30', '#7a6a4a', 3)
    for x, y in ((30, 92), (46, 80), (62, 68), (78, 56), (94, 44)):
        for s in (-1, 1):
            I.e(x + s * 10, y - 12 * (s > 0) + 4, 12, 2.6, I.rg('#8a9a7a', .5, .3), rot=-50 if s > 0 else -20)
    for x, y in ((36, 90), (44, 98), (50, 84), (58, 92), (64, 76), (72, 84), (80, 66), (86, 74)):
        I.e(x, y, 5.5, 4.8, I.rg('#f5980f', .55, .3))
        I.c(x - 1.8, y - 1.8, 1.3, '#fff', .7)


@icon('raisins', 'Raisins')
def ic_raisins(I):
    I.shadow(rx=44)
    for i in range(16):
        a, t = i * 2.39996, math.sqrt((i + .5) / 16)
        x, y = 64 + math.cos(a) * 36 * t, 88 + math.sin(a) * 14 * t - (1 - t) * 24
        with I.at(x, y, 1, (i * 61) % 180):
            I.p('M-8 0C-8 -6 -2 -7 0 -6C3 -8 8 -5 8 0C8 6 2 7 0 6C-3 8 -8 5 -8 0Z', I.rg('#4a2018', .45, .4))
            I.line('M-5 -1Q0 2 5 -1', '#6e3a2a', 1, .7)


@icon('sultanas', 'Sultanas')
def ic_sultanas(I):
    I.shadow(rx=44)
    for i in range(16):
        a, t = i * 2.39996, math.sqrt((i + .5) / 16)
        x, y = 64 + math.cos(a) * 36 * t, 88 + math.sin(a) * 14 * t - (1 - t) * 24
        with I.at(x, y, 1, (i * 61) % 180):
            I.p('M-8 0C-8 -6 -2 -7 0 -6C3 -8 8 -5 8 0C8 6 2 7 0 6C-3 8 -8 5 -8 0Z', I.rg('#c88a2a', .5, .35))
            I.line('M-5 -1Q0 2 5 -1', '#9a6018', 1, .7)


@icon('quince', 'Quince')
def ic_quince(I):
    I.shadow(rx=44)
    I.p('M64 24C76 24 80 34 86 42C100 52 104 72 98 88C92 104 78 110 64 110C50 110 36 104 30 88C24 72 28 52 42 42C48 34 52 24 64 24Z', I.rg('#e8c42a', .45, .3))
    dots(I, 64, 60, 20, 20, 12, 2.5, '#f2e2a0', .4)
    stem(I, 'M64 24Q64 18 68 14', '#6a4a2a', 3)
    leaf(I, 68, 18, 1.1, -20, '#5a9a3a')
    I.hl(46, 56, 8, 12, -20)
