"""Иконки: рыба, сыр, молочное."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf


# ======================= рыба (было 77 × 🐟) =======================
def fish(I, back, belly, fin=None, depth=1.0, length=1.0, pattern=None, tail='fork', eye=True, head=None, barbels=False,
         snout=0):
    """Целая рыба сбоку, голова слева. depth — высота тела, length — длина, pattern(I) рисует узор внутри тела."""
    fin = fin or dk(back, .1)
    h = 20 * depth
    x0, x1 = 64 - 46 * length, 64 + 30 * length
    body = (f'M{f(x0 - snout)} 64C{f(x0 + 6)} {f(64 - h * 1.1)} {f(x1 - 30)} {f(64 - h * 1.3)} {f(x1)} {f(64 - h * .25)}'
            f'C{f(x1 + 4)} 64 {f(x1 + 4)} 64 {f(x1)} {f(64 + h * .25)}C{f(x1 - 30)} {f(64 + h * 1.25)} {f(x0 + 6)} {f(64 + h)} {f(x0 - snout)} 64Z')
    I.shadow(cy=108, rx=46, ry=6)
    # хвост
    t0 = x1 - 2
    if tail == 'fork':
        I.p(f'M{f(t0)} 62L{f(t0 + 20)} 40Q{f(t0 + 14)} 64 {f(t0 + 20)} 88L{f(t0)} 66Z', I.rg(fin, .35, .3))
    else:
        I.p(f'M{f(t0)} 62L{f(t0 + 18)} 44Q{f(t0 + 24)} 64 {f(t0 + 18)} 84L{f(t0)} 66Z', I.rg(fin, .35, .3))
    # спинной плавник
    I.p(f'M{f(x0 + 30 * length)} {f(64 - h * 1.05)}Q{f(x0 + 44 * length)} {f(64 - h * 1.9)} {f(x0 + 60 * length)} {f(64 - h * 1.12)}Z', fin)
    I.p(f'M{f(x0 + 36 * length)} {f(64 + h * .95)}Q{f(x0 + 46 * length)} {f(64 + h * 1.6)} {f(x0 + 54 * length)} {f(64 + h * .95)}Z', fin)
    I.p(body, I.vg(back, belly))
    with I.clip(body):
        I.e(64, 64 + h * .9, 60, h * .7, lt(belly, .2), .45)
        if pattern: pattern(I)
        if head: I.p(f'M{f(x0 - 2)} 40V90H{f(x0 + 22 * length)}Q{f(x0 + 28 * length)} 64 {f(x0 + 22 * length)} 40Z', head, .6)
    I.line(f'M{f(x0 + 20 * length)} {f(64 - h * .7)}Q{f(x0 + 26 * length)} 64 {f(x0 + 20 * length)} {f(64 + h * .7)}', dk(back, .25), 1.6, .5)
    I.p(f'M{f(x0 + 26 * length)} 68Q{f(x0 + 36 * length)} 70 {f(x0 + 40 * length)} 76Q{f(x0 + 30 * length)} 76 {f(x0 + 26 * length)} 68Z', fin, .8)
    if barbels:
        I.line(f'M{f(x0 + 2)} 66Q{f(x0 - 6)} 74 {f(x0 - 10)} 82M{f(x0 + 4)} 62Q{f(x0 - 8)} 58 {f(x0 - 14)} 60', dk(back, .2), 1.4)
    if eye:
        ex = x0 + 9 * length
        I.c(ex, 60, 4.2, '#f4f1ea')
        I.c(ex, 60, 2.8, '#1b1b22')
        I.c(ex - 1, 59, 1, '#fff')
    I.hl(x0 + 34 * length, 64 - h * .7, 16 * length, 3.5, -4, .55)


@icon('salmon', 'Salmon')
def ic_salmon(I):  # стейк лосося — так продают и узнают
    I.shadow(rx=46)
    d = 'M24 62C24 38 50 24 74 28C98 32 110 52 106 74C102 96 80 106 60 100C46 96 42 86 52 78C40 84 24 80 24 62Z'
    I.p(d, '#c9ccd2')
    I.p('M28 62C28 42 50 30 72 33C94 36 104 54 101 73C98 92 80 100 62 96C50 93 47 86 55 80C42 86 28 78 28 62Z', I.rg('#f27a4c', .4, .25))
    for a in (-60, -20, 20, 60, 100):
        with I.at(66, 64, 1, a):
            I.line('M4 0Q14 -6 30 -2', '#fbd3bf', 2, .8)
    I.c(66, 64, 4, '#fbd3bf')
    I.hl(46, 46, 10, 5)


@icon('cod', 'Cod')
def ic_cod(I):
    fish(I, '#7d7a52', '#eeeadb', '#6e6a45', depth=1.0, barbels=True,
         pattern=lambda I: dots(I, 62, 56, 30, 10, 26, 1.3, '#5b5838', .5))


@icon('herring', 'Herring')
def ic_herring(I):
    fish(I, '#2e5f86', '#e9eef2', '#5b7e9a', depth=.8, length=1.05)


@icon('mackerel', 'Mackerel')
def ic_mackerel(I):
    def stripes(I):
        for i in range(8):
            x = 36 + i * 7
            I.line(f'M{x} 44Q{x + 5} 50 {x + 1} 58', '#123c2e', 2.2, .8)
    fish(I, '#2f7d6e', '#eef1ee', '#3f6f62', depth=.85, pattern=stripes)


@icon('trout', 'Trout')
def ic_trout(I):
    def p(I):
        I.p('M20 66Q60 58 96 64Q60 72 20 70Z', '#e9727f', .7)
        dots(I, 64, 54, 30, 9, 30, 1.2, '#2b2a24', .8)
    fish(I, '#6e7f4e', '#f0ead8', '#7a8758', depth=.95, pattern=p)


@icon('tilapia', 'Tilapia')
def ic_tilapia(I):
    def bars(I):
        for x in (40, 52, 64, 76):
            I.r(x, 40, 5, 48, 2, '#5b6470', .25)
    fish(I, '#7d8794', '#e6e8ea', '#a3586a', depth=1.35, length=.92, pattern=bars, tail='round')


@icon('carp', 'Carp')
def ic_carp(I):
    def scales(I):
        for row in range(4):
            for i in range(8):
                x, y = 34 + i * 8 + (row % 2) * 4, 50 + row * 7
                I.line(f'M{x} {y}Q{x + 4} {y + 4} {x + 8} {y}', '#7a5418', 1.2, .5)
    fish(I, '#a8792a', '#f2dc9a', '#9a5a22', depth=1.2, barbels=True, pattern=scales)


@icon('pike', 'Pike')
def ic_pike(I):
    fish(I, '#4f6b2e', '#e8e8c8', '#6a7a36', depth=.65, length=1.12, snout=6,
         pattern=lambda I: dots(I, 64, 60, 36, 9, 34, 1.6, '#d6d58a', .7))


@icon('catfish', 'Catfish')
def ic_catfish(I):
    fish(I, '#545a5f', '#c9c3b6', '#4a4f53', depth=.85, barbels=True, tail='round',
         pattern=lambda I: dots(I, 64, 56, 30, 10, 20, 2, '#3e4246', .5))


@icon('sea_bass', 'Sea Bass')
def ic_sea_bass(I):
    fish(I, '#4a5866', '#e8ecef', '#5a6874', depth=1.0,
         pattern=lambda I: I.line('M22 62Q60 56 96 62', '#2f3a44', 1.4, .6))


@icon('pollock', 'Pollock')
def ic_pollock(I):
    fish(I, '#5a6b3e', '#dfe3d6', '#4e5d36', depth=.9,
         pattern=lambda I: I.line('M24 58Q60 50 96 60', '#c9ceb8', 2, .7))


@icon('anchovies', 'Anchovies')
def ic_anchovies(I):
    I.shadow(rx=46)
    for y, x, rot in ((44, 60, -8), (64, 66, 4), (84, 58, -4)):
        with I.at(x, y, 1, rot):
            body = 'M-40 0C-30 -9 20 -10 34 -2L44 -9Q42 0 44 9L34 2C20 10 -30 9 -40 0Z'
            I.p(body, I.vg('#3d6f8a', '#e5ecef'))
            I.line('M-34 0H32', '#b9c9d4', 2, .8)
            I.c(-33, -2, 2, '#1b1b22')
            I.hl(-6, -4, 12, 2, 0, .5)


@icon('fresh_sardines', 'Fresh Sardines')
def ic_sardines(I):
    I.shadow(rx=46)
    for y, x, rot, k in ((50, 58, -12, .62), (76, 68, 6, .62)):
        with I.at(x, y, k, rot):
            body = 'M-50 0C-36 -18 26 -20 40 -4L58 -16Q54 0 58 16L40 4C26 20 -36 18 -50 0Z'
            I.p(body, I.vg('#2f6f9a', '#eef2f4'))
            with I.clip(body):
                dots(I, -20, -4, 6, 3, 4, 2.4, '#16354a', .7)
            I.c(-40, -3, 3.5, '#1b1b22'); I.c(-41, -4, 1, '#fff')
            I.hl(-4, -8, 22, 3.5, 0, .55)


@icon('smoked_salmon', 'Smoked Salmon')
def ic_smoked_salmon(I):
    I.shadow(rx=46)
    I.e(64, 92, 50, 14, I.rg('#f4efe6', .3, .2))
    for i, (x, y, r) in enumerate(((38, 66, -10), (62, 72, 5), (86, 64, 15))):
        with I.at(x, y, 1, r):
            I.p('M-20 14C-24 0 -16 -18 0 -20C14 -18 22 -2 18 14C8 22 -10 22 -20 14Z', I.rg('#f0703f', .45, .3))
            for k in (-8, 0, 8):
                I.line(f'M{k - 6} -12Q{k} 0 {k - 4} 14', '#fbc7ad', 1.6, .8)
    leaf(I, 88, 92, .8, -20, '#4a9a3a')


@icon('tuna_steak', 'Tuna Steak')
def ic_tuna_steak(I):
    I.shadow(rx=46)
    I.p('M18 70L44 48Q50 44 58 44H100Q108 44 106 52L90 80Q86 86 78 86H24Q14 86 18 70Z', '#7e1e25')
    I.p('M18 66L44 44Q50 40 58 40H100Q108 40 106 48L90 76Q86 82 78 82H24Q14 82 18 66Z', I.rg('#c42a3b', .4, .3))
    for x in (46, 62, 78):
        I.line(f'M{x} 46Q{x - 10} 60 {x - 4} 78', '#e45a66', 1.6, .6)
    I.hl(48, 52, 12, 4, -10, .55)


@icon('dried_fish', 'Dried Fish')
def ic_dried_fish(I):
    fish(I, '#a7741f', '#e8c47c', '#8a5a18', depth=.75,
         pattern=lambda I: I.line('M24 60Q60 52 96 60', '#f3d68f', 2.2, .7))


@icon('eel', 'Eel')
def ic_eel(I):
    I.shadow(rx=50)
    d = 'M14 58C24 44 40 46 52 58C62 68 76 72 88 62C98 54 108 56 116 64C108 62 100 66 92 72C78 84 60 80 48 70C38 62 28 58 18 66Z'
    I.p(d, I.vg('#3d4a3a', '#b9b48a'))
    I.c(20, 58, 2.4, '#1b1b22')
    I.hl(40, 52, 10, 2.5, 20, .5)


# ======================= сыр (было 65 × 🧀) =======================
def wedge(I, paste, rind, holes=0, veins=None, top_rind=False, specks=None):
    """Клин сыра 3/4: верх (срез), передняя грань, корка сзади."""
    I.shadow(rx=46, cy=110)
    A, B, C = (16, 80), (68, 38), (112, 54)
    A2, C2 = (16, 102), (112, 84)
    I.p(f'M{A[0]} {A[1]}L{B[0]} {B[1]}Q92 40 {C[0]} {C[1]}V{C2[1]}L{A2[0]} {A2[1]}Z', rind)
    I.p(f'M{A[0]} {A[1]}L{C[0]} {C[1]}V{C2[1]}L{A2[0]} {A2[1]}Z', I.vg(paste, dk(paste, .12)))
    I.p(f'M{A[0]} {A[1]}L{B[0]} {B[1]}Q92 40 {C[0]} {C[1]}Z', I.rg(lt(paste, .1) if not top_rind else rind, .35, .1))
    if top_rind:
        I.p('M22 78L68 42Q90 44 104 56Z', I.rg(paste, .35, .1))
    I.p(f'M{B[0]} {B[1]}Q92 40 {C[0]} {C[1]}V{C[1] + 4}Q92 44 {B[0]} {B[1] + 3}Z', dk(rind, .1))
    for i in range(holes):
        x = 30 + (i * 37) % 76; y = 86 + (i * 13) % 12 - (x - 16) * .22
        I.e(x, y, 4 + i % 3, 3 + i % 2, dk(paste, .2))
        I.e(x, y + .8, 3 + i % 3, 2 + i % 2, dk(paste, .3))
    for i in range(holes // 2):
        x = 52 + (i * 23) % 44; y = 56 + (i * 11) % 10
        I.e(x, y, 3.5, 2, dk(paste, .22))
    if veins:
        for i in range(9):
            x = 26 + (i * 29) % 82; y = 88 - (x - 16) * .22 + (i * 7) % 12
            I.line(f'M{x} {y}l{4 + i % 3} {-3 + i % 4}l3 2', veins, 2, .85)
        for i in range(6):
            x = 50 + (i * 17) % 50; y = 50 + (i * 9) % 14
            I.line(f'M{x} {y}l5 -2l2 3', veins, 1.8, .8)
    if specks:
        dots(I, 64, 90, 40, 8, 30, 1, specks, .6)
    I.hl(56, 50, 12, 3, -18, .6)


@icon('cheddar', 'Cheddar Cheese')
def ic_cheddar(I):
    wedge(I, '#f39a1e', '#c66a10')


@icon('swiss_cheese', 'Swiss Cheese')
def ic_swiss(I):
    wedge(I, '#f6d65a', '#e6b93a', holes=7)


@icon('emmental', 'Emmental')
def ic_emmental(I):
    # прямоугольный брусок с крупными «глазками» (не клин, как у Swiss Cheese)
    I.shadow(rx=46)
    I.p('M18 58L70 44L110 56L58 72Z', I.rg('#f6e9a6', .3, .1))
    I.p('M18 58L58 72V104L18 88Z', I.vg('#f1dc84', '#e2c86a'))
    I.p('M58 72L110 56V88L58 104Z', I.vg('#e6cc6a', '#d2b456'))
    for x, y, r in ((30, 72, 6), (46, 88, 7), (36, 92, 3.5), (74, 76, 7), (96, 72, 5), (88, 90, 4)):
        I.e(x, y, r, r * .8, '#c9a944'); I.e(x + .6, y + .8, r * .8, r * .6, '#b8973a')
    for x, y in ((54, 56, ), (80, 54)):
        I.e(x, y, 6, 2.5, '#d8bd5a')
    I.p('M18 58L70 44L110 56V60L70 48L18 62Z', '#c99a3a', .6)
    I.hl(44, 56, 12, 3, -14, .6)


@icon('blue_cheese', 'Blue Cheese')
def ic_blue(I):
    wedge(I, '#f2eedc', '#d9d3bd', veins='#41658f')


@icon('gorgonzola', 'Gorgonzola')
def ic_gorgonzola(I):
    wedge(I, '#f4e7b0', '#c9a96a', veins='#4d7d5e')


@icon('parmesan', 'Parmesan')
def ic_parmesan(I):
    wedge(I, '#f3dd96', '#c99a3a', specks='#fff6d0')


@icon('gouda', 'Gouda')
def ic_gouda(I):
    I.shadow(rx=48)
    I.p('M14 64V84C14 98 36 106 64 106C92 106 114 98 114 84V64Z', I.cyl('#d8282a', .4, .35))
    I.e(64, 64, 50, 18, I.rg('#e23a33', .4, .3))
    I.p('M64 64L100 52Q112 58 114 64V84Q113 90 106 94L64 84Z', '#f6c638')
    I.p('M64 64L100 52Q112 58 114 64L72 70Z', lt('#f6c638', .25))
    I.p('M64 64V84L106 94V74Z', I.vg('#f2c030', '#e0a820'))
    I.hl(40, 56, 14, 4, -8, .55)


@icon('brie', 'Brie')
def ic_brie(I):
    wedge(I, '#f7ebc0', '#fbf8f1', top_rind=True)
    I.p('M16 80L112 54V60L16 86Z', '#f6e7a8', .9)


@icon('camembert', 'Camembert')
def ic_camembert(I):
    I.shadow(rx=46)
    I.p('M20 66V82C20 94 40 100 64 100C88 100 108 94 108 82V66Z', I.cyl('#f7f3ea', .3, .2))
    I.e(64, 66, 44, 14, I.rg('#fbf8f2', .3, .15))
    dots(I, 64, 66, 38, 11, 30, 1.2, '#e6dfcd', .7)
    I.p('M64 66L98 76V92L64 84Z', '#f4dc8c')
    I.p('M64 66L98 76Q104 72 106 68Z', '#fbf8f2')
    I.hl(44, 60, 12, 3, -6, .6)


@icon('mozzarella', 'Mozzarella')
def ic_mozzarella(I):
    I.shadow(rx=44)
    I.c(56, 70, 34, I.rg('#fbfaf5', .3, .18))
    I.c(90, 84, 18, I.rg('#f8f6ef', .3, .18))
    I.hl(44, 52, 12, 7)
    leaf(I, 70, 44, 1.1, -30, '#3f9a3a')
    leaf(I, 70, 44, .9, -110, '#4fae44')


@icon('feta', 'Feta')
def ic_feta(I):
    I.shadow(rx=46)
    I.p('M22 56L58 40L106 52L70 70Z', I.rg('#fdfcf6', .2, .1))
    I.p('M22 56L70 70V100L22 84Z', I.vg('#f6f4ec', '#e3dfd2'))
    I.p('M70 70L106 52V84L70 100Z', I.vg('#e9e6dc', '#d3cfc1'))
    for x, y in ((34, 70), (48, 80), (40, 88), (58, 86), (82, 76), (94, 66)):
        I.c(x, y, 1.6, '#d2cdbe')
    for x, y in ((50, 50), (64, 56), (78, 52), (60, 46)):
        I.c(x, y, 1.6, '#5e8a3a')
    I.hl(44, 50, 10, 3, -20, .6)


@icon('cream_cheese', 'Cream Cheese')
def ic_cream_cheese(I):
    tub(I, '#e9f1f8', '#3f8fd0', None)
    I.p('M44 82C44 70 56 64 64 68C70 62 84 68 84 80C78 86 50 88 44 82Z', I.rg('#fbfaf6', .2, .15))
    I.p('M60 66Q66 58 72 62', '#fbfaf6')


@icon('cottage_cheese', 'Cottage Cheese')
def ic_cottage(I):
    I.shadow(rx=44)
    I.p('M18 66H110Q108 98 64 106Q20 98 18 66Z', I.cyl('#5a8fc8', .4, .3))
    I.e(64, 66, 46, 12, '#3f74ad')
    for i in range(26):
        a, t = i * 2.39996, math.sqrt((i + .5) / 26)
        x, y = 64 + math.cos(a) * 38 * t, 64 + math.sin(a) * 9 * t - (1 - t) * 10
        I.c(x, y, 5.5, I.rg('#fbfaf3', .2, .18))
    I.hl(30, 76, 4, 10, 0, .5)


@icon('processed_cheese', 'Processed Cheese')
def ic_processed(I):
    I.shadow(rx=46)
    # круглая коробочка плавленых сырков-треугольников, один развёрнут
    I.p('M16 70V86C16 98 38 106 64 106C90 106 112 98 112 86V70Z', I.cyl('#3f86c9', .4, .35))
    I.e(64, 70, 48, 16, '#d9dde2')
    for a in range(0, 360, 60):
        x2, y2 = 64 + 46 * math.cos(math.radians(a)), 70 + 15 * math.sin(math.radians(a))
        I.line(f'M64 70L{f(x2)} {f(y2)}', '#a9b0b8', 1.4)
    I.p('M64 70L110 70A46 15 0 0 1 87 83Z', '#e8ebef')
    with I.at(54, 52, 1, -12):
        I.p('M-26 -6L22 -10L0 22Z', '#f6dc7a')
        I.p('M-26 -12L22 -16V-10L-26 -6Z', '#e9c95c')
        I.p('M-26 -12L22 -16L0 16Z', I.rg('#f8e396', .3, .15))
    I.hl(30, 80, 4, 8, 0, .5)


@icon('ricotta', 'Ricotta')
def ic_ricotta(I):
    I.shadow(rx=44)
    I.p('M24 66L32 104H96L104 66Z', I.cyl('#e8ddc6', .35, .3))
    for y in (74, 84, 94):
        for x in range(30, 100, 7):
            I.c(x + (y % 2) * 3, y, 1.4, '#c8b994')
    I.p('M22 66C26 46 46 38 64 40C84 38 102 46 106 66Z', I.rg('#fdfcf7', .2, .1))
    dots(I, 64, 54, 32, 8, 18, 1.4, '#efeadc')
    I.hl(46, 50, 10, 4, -10, .6)


@icon('goat_cheese', 'Goat Cheese')
def ic_goat_cheese(I):
    I.shadow(rx=46)
    I.p('M24 62H92V92H24Z', I.vg('#fbfaf5', '#e6e3da'))
    I.e(24, 77, 8, 15, I.rg('#f6f4ec', .3, .2))
    I.e(92, 77, 9, 15, I.rg('#fbfbf6', .3, .15))
    dots(I, 92, 77, 6, 12, 10, 1.2, '#e3decf')
    I.hl(44, 66, 14, 3, 0, .7)
    leaf(I, 70, 58, .9, -20, '#5a8a3a')


@icon('halloumi', 'Halloumi')
def ic_halloumi(I):
    I.shadow(rx=46)
    I.p('M18 62L74 46L110 62L54 80Z', I.rg('#f8f0d8', .2, .1))
    I.p('M18 62L54 80V96L18 78Z', '#efe4c3')
    I.p('M54 80L110 62V78L54 96Z', '#e1d3ad')
    for k in range(4):
        I.line(f'M{30 + k * 14} {58 - k * 3}L{58 + k * 14} {72 - k * 3}', '#9a6a2a', 3.5, .7)


@icon('mascarpone', 'Mascarpone')
def ic_mascarpone(I):
    tub(I, '#f7f4ea', '#e9e2cf', None, band='#2e6b47')
    I.p('M50 77C54 69 60 66 64 66C70 66 76 70 78 77Z', I.rg('#fbf6e3', .3, .15))
    I.e(64, 77, 14, 2.5, '#e9dfbf')
    I.p('M62 66Q66 60 70 63', '#fbf6e3')


@icon('burrata', 'Burrata')
def ic_burrata(I):
    I.shadow(rx=44)
    I.p('M24 78C24 54 44 40 64 40C84 40 104 54 104 78C104 98 86 108 64 108C42 108 24 98 24 78Z', I.rg('#fbfaf3', .25, .15))
    I.p('M52 42Q64 30 76 42Q70 46 64 45Q58 46 52 42Z', '#f1eee2')
    I.p('M56 70C62 80 80 84 92 76C90 92 74 100 60 96C50 92 48 80 56 70Z', I.rg('#f6eccd', .3, .1))
    I.hl(44, 58, 10, 6)


@icon('paneer', 'Paneer')
def ic_paneer(I):
    I.shadow(rx=46)
    for x, y in ((40, 62), (76, 58), (58, 84)):
        I.p(f'M{x - 18} {y - 6}L{x} {y - 14}L{x + 18} {y - 6}L{x} {y + 2}Z', I.rg('#fbf7ea', .2, .1))
        I.p(f'M{x - 18} {y - 6}L{x} {y + 2}V{y + 18}L{x - 18} {y + 10}Z', '#efe8d4')
        I.p(f'M{x + 18} {y - 6}L{x} {y + 2}V{y + 18}L{x + 18} {y + 10}Z', '#ddd4bc')
    leaf(I, 88, 92, .7, -40, '#3f9a3a')


@icon('string_cheese', 'String Cheese')
def ic_string_cheese(I):
    I.shadow(rx=46)
    with I.at(64, 64, 1, -35):
        I.r(-44, -10, 70, 20, 10, I.vg('#fbfaf3', '#e6e1d2'))
        for y in (-5, 0, 5):
            I.line(f'M-40 {y}H22', '#ebe6d6', 1.2, .9)
        I.p('M26 -10Q40 -12 46 -20M26 0Q42 2 50 -4M26 10Q40 14 44 22', 'none')
        I.line('M24 -8Q38 -12 46 -20', '#f6f3ea', 6)
        I.line('M24 1Q40 2 50 -2', '#f6f3ea', 6)
        I.line('M24 8Q38 14 44 22', '#f6f3ea', 6)
        I.hl(-14, -5, 22, 2.5, 0, .7)
