"""Иконки: фрукты, ягоды, овощи, грибы, зелень."""
import math
from iconlib import *  # noqa: F401,F403


def leaf(I, x, y, k, rot, c='#4f9a33'):
    with I.at(x, y, k, rot):
        I.p('M0 0C4 -8 14 -10 22 -8C16 -1 8 3 0 0Z', I.rg(c, .45, .3))
        I.line('M1 -.5Q10 -5 20 -7.5', dk(c, .3), 1, .7)


def stem(I, d, c='#6b4a2a', w=3):
    I.line(d, c, w)


def dots(I, cx, cy, rx, ry, n, r, color, op=None, seed=1):
    """Точки внутри эллипса (семечки, крапинки) — детерминированно."""
    for i in range(n):
        a = i * 2.39996 + seed
        t = math.sqrt((i + .5) / n)
        I.c(cx + math.cos(a) * rx * t, cy + math.sin(a) * ry * t, r, color, op)


# ---------- жалобы владельца: всё было дыней 🍈 / апельсином / персиком / лимоном / драконом ----------
@icon('guava', 'Guava')
def ic_guava(I):
    I.shadow(rx=46)
    I.e(80, 66, 30, 32, I.rg('#9cc94a', .45, .35), rot=15)
    I.c(96, 40, 3, '#6a7b2a')
    I.hl(70, 48, 9, 6)
    I.e(52, 82, 34, 28, I.rg('#8fbf3e', .3, .35), rot=-10)
    I.e(52, 80, 30, 24, I.rg('#f37f86', .35, .2), rot=-10)
    I.e(52, 80, 15, 12, '#f8c7b6', rot=-10)
    dots(I, 52, 80, 11, 8, 14, 1.4, '#f6e6c6')
    I.hl(40, 70, 7, 4, -20, .5)


@icon('passion_fruit', 'Passion Fruit')
def ic_passion(I):
    I.shadow(rx=46)
    I.c(80, 60, 30, I.rg('#6b2a52', .4, .4))
    dots(I, 80, 60, 26, 26, 24, 1, '#c78bb0', .5)
    I.hl(68, 44, 10, 6)
    I.e(50, 84, 32, 25, I.rg('#5e2148', .3, .35))
    I.e(50, 82, 28, 21, '#f3e4c8')
    I.e(50, 82, 24, 17, I.rg('#f4b81c', .45, .25))
    dots(I, 50, 82, 19, 13, 22, 2, '#2b1b10')
    dots(I, 49, 81, 19, 13, 22, .8, '#fff4c0', .8, seed=1.1)
    I.hl(38, 74, 7, 4, -20, .5)


def lychee_ball(I, cx, cy, r):
    I.c(cx, cy, r, I.rg('#d8344a', .4, .35))
    for i in range(int(r * 1.6)):
        a, t = i * 2.39996, math.sqrt((i + .5) / (r * 1.6))
        I.c(cx + math.cos(a) * r * .9 * t, cy + math.sin(a) * r * .9 * t, r * .14, '#f06a6e', .55)
    I.hl(cx - r * .4, cy - r * .45, r * .3, r * .2)


@icon('lychee', 'Lychee')
def ic_lychee(I):
    I.shadow(rx=48)
    stem(I, 'M70 30Q76 18 88 14', '#6b5a2a', 2.5)
    lychee_ball(I, 82, 58, 24)
    lychee_ball(I, 44, 54, 20)
    I.p('M44 112C30 112 26 98 30 86C38 92 50 92 60 86C64 98 58 112 44 112Z', I.rg('#cf2f44', .35, .3))
    I.e(46, 84, 17, 18, I.rg('#f7f3ea', .55, .15))
    I.e(46, 84, 17, 18, '#dfe9e6', .25)
    I.hl(40, 76, 6, 4, -30, .9)


@icon('persimmon', 'Persimmon')
def ic_persimmon(I):
    I.shadow(rx=46)
    I.e(64, 72, 44, 36, I.rg('#f27a12', .45, .35))
    I.p('M64 40Q60 72 66 106', 'none')
    I.line('M60 42Q54 72 62 106', '#d55e0a', 2, .45)
    I.hl(44, 54, 12, 7)
    for a in (-140, -50, 40, 130):
        with I.at(64, 40, 1, a):
            I.p('M0 0C6 -6 16 -6 20 -2C16 3 6 4 0 0Z', I.rg('#6f8a2c', .35, .35))
    I.c(64, 40, 5, '#5c4a22')
    stem(I, 'M64 38Q63 32 66 28', '#5c4a22', 3)


@icon('lime', 'Lime')
def ic_lime(I):
    I.shadow(rx=46)
    I.e(76, 60, 32, 28, I.rg('#5fae2c', .4, .35), rot=-15)
    I.c(104, 52, 2.5, '#3f7a1c')
    dots(I, 76, 60, 26, 22, 30, .8, '#8fd04f', .5)
    I.hl(64, 44, 10, 6)
    # долька
    I.p('M20 92A34 34 0 0 0 88 92Z', '#4c9a24')
    I.p('M24 92A30 30 0 0 0 84 92Z', '#eef6c8')
    I.p('M27 92A27 27 0 0 0 81 92Z', I.rg('#b6dd5a', .5, .2))
    for a in (20, 52, 84, 116, 148):
        x = 54 + 27 * math.cos(math.radians(a)); y = 92 + 27 * math.sin(math.radians(a))
        I.line(f'M54 92L{f(x)} {f(y)}', '#eef6c8', 2)
    I.c(54, 92, 3, '#eef6c8')


@icon('prunes', 'Prunes')
def ic_prunes(I):
    I.shadow(rx=46)
    for cx, cy, rot in ((44, 74, -20), (84, 72, 25), (64, 92, 5)):
        I.e(cx, cy, 22, 16, I.rg('#3d1a2c', .35, .4), rot=rot)
        for k in (-8, 0, 8):
            with I.at(cx, cy, 1, rot):
                I.line(f'M{k - 10} {-4 + abs(k) / 3}Q{k} {2} {k + 8} {-5}', '#5e3348', 1.6, .7)
        I.hl(cx - 8, cy - 7, 6, 3, rot - 20, .8)


def dragon(I, skin, tip, flesh, seeds='#1f1a1a'):
    I.shadow(rx=46)
    I.e(80, 58, 28, 36, I.rg(skin, .4, .35), rot=20)
    for x, y, r in ((62, 36, -60), (96, 30, 40), (104, 64, 80), (60, 70, -100), (82, 86, 150), (78, 50, -10)):
        with I.at(x, y, 1, r):
            I.p('M0 6C-3 -2 -2 -8 2 -14C4 -8 6 -2 4 6Z', I.rg(tip, .4, .3))
    I.hl(66, 40, 8, 5)
    I.e(46, 86, 30, 22, skin, rot=-10)
    I.e(46, 85, 26, 18, I.rg(flesh, .5, .15), rot=-10)
    dots(I, 46, 85, 22, 14, 40, 1.1, seeds)
    I.hl(36, 78, 7, 4, -20, .6)


@icon('dragon_fruit', 'Dragon Fruit')
def ic_dragon(I):
    dragon(I, '#e0306f', '#8bc34a', '#fbfaf6')


@icon('yellow_dragon_fruit', 'Yellow Dragon Fruit')
def ic_dragon_yellow(I):
    dragon(I, '#f2c51c', '#d6b21a', '#fbfaf6')


@icon('fig', 'Fig')
def ic_fig(I):
    I.shadow(rx=46)
    I.p('M82 22C86 22 88 30 92 36C104 50 108 66 100 80C92 92 72 92 64 80C56 66 64 48 74 36C78 30 78 22 82 22Z', I.rg('#6e2f5e', .4, .35))
    I.hl(76, 50, 6, 10, -20)
    stem(I, 'M82 22Q82 16 86 12', '#6a7a2a', 3)
    I.p('M40 50C44 50 46 56 50 60C62 72 64 88 56 100C48 110 28 110 20 100C12 88 20 72 30 60C34 56 36 50 40 50Z', '#6e2f5e')
    I.p('M40 57C44 60 46 64 50 67C58 76 58 88 52 96C46 104 32 104 26 96C20 88 22 76 30 67C34 64 36 60 40 57Z', '#f3e3c4')
    I.p('M40 64C46 70 52 76 52 86C52 94 46 98 38 98C30 98 26 92 28 84C30 76 36 70 40 64Z', I.rg('#d8344a', .4, .25))
    dots(I, 40, 84, 9, 10, 22, 1, '#f7d78a')
