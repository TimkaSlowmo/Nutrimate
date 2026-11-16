"""Иконки: свежая зелень (было 94 × 🌿), специи, острые перцы (58 × 🌶️), листовые овощи (56 × 🥬)."""
import math
from iconlib import *  # noqa: F401,F403
from icons_b import dots, leaf


def bunch_tie(I, x=64, y=96, c='#c9a46a'):
    I.r(x - 8, y - 4, 16, 8, 3, I.cyl(c, .4, .3))


# ======================= свежая зелень =======================
@icon('dill', 'Dill')
def ic_dill(I):
    I.shadow(rx=30)
    for sx, ang in ((-10, -18), (0, 0), (10, 16)):
        x2, y2 = 64 + sx + 30 * math.sin(math.radians(ang)), 24
        I.line(f'M{64 + sx / 3} 112Q{64 + sx} 70 {f(x2)} {y2}', '#6fa83a', 2.4)
        for k in range(7):
            t = .15 + k * .11
            yy = 112 - (112 - y2) * t - 6
            xx = 64 + sx / 3 + (x2 - 64 - sx / 3) * t * t
            for s in (-1, 1):
                I.line(f'M{f(xx)} {f(yy)}q{s * 6} -4 {s * 14} -10M{f(xx + s * 6)} {f(yy - 4)}q{s * 2} -6 {s * 2} -12', '#4f9a33', 1.3, .95)
    bunch_tie(I, 64, 100)


def flat_leaf(I, x, y, k, rot, c):
    """Лист петрушки/кинзы: трёхлопастной зубчатый."""
    with I.at(x, y, k, rot):
        I.p('M0 0C-6 -4 -10 -10 -8 -16C-5 -14 -4 -18 -1 -20C0 -16 2 -18 4 -20C6 -16 8 -16 10 -14C10 -8 6 -3 0 0Z', I.rg(c, .45, .3))
        I.line('M0 0L-4 -14M0 0L1 -17M0 0L6 -13', dk(c, .25), .8, .7)


@icon('parsley', 'Parsley')
def ic_parsley(I):
    I.shadow(rx=30)
    pts = ((46, 40, -30), (64, 28, 0), (82, 40, 30), (54, 52, -15), (74, 52, 18), (40, 60, -50), (88, 60, 50))
    for x, y, r in pts:
        I.line(f'M64 100Q{(x + 64) / 2} {(y + 100) / 2} {x} {y}', '#6aa83a', 2)
    for x, y, r in pts:
        flat_leaf(I, x, y + 4, 1.05, r, '#3e8f2a')
    bunch_tie(I)


@icon('cilantro', 'Cilantro')
def ic_cilantro(I):
    I.shadow(rx=30)
    pts = ((44, 44), (62, 30), (82, 42), (52, 58), (76, 58), (36, 66), (92, 66))
    for x, y in pts:
        I.line(f'M64 104Q{(x + 64) / 2} {(y + 104) / 2} {x} {y}', '#8cc055', 1.8)
    for i, (x, y) in enumerate(pts):
        with I.at(x, y, 1, i * 40):
            for a in (0, 120, 240):
                with I.at(0, 0, 1, a):
                    I.p('M0 0C-6 -2 -8 -8 -5 -12C-2 -14 2 -14 5 -12C8 -8 6 -2 0 0Z', I.rg('#5fae3a', .45, .3))
    I.p('M60 104L64 116L68 104Z', '#e8e2c8')


@icon('basil', 'Basil')
def ic_basil(I):
    # веточка: пары крупных выпуклых овальных листьев, сверху — молодая розетка
    I.shadow(rx=40)
    I.line('M64 114Q62 80 64 34', '#4a8a2a', 4)

    def bl(x, y, k, rot, c):
        with I.at(x, y, k, rot):
            I.p('M0 0C6 -12 22 -16 34 -10C38 -4 34 6 24 10C14 13 4 8 0 0Z', I.rg(c, .55, .35))
            I.p('M4 0C10 -8 22 -11 31 -8C24 -6 12 -4 4 0Z', '#fff', .25)
            I.line('M1 0Q16 -3 33 -8', dk(c, .28), 1.2, .7)
    bl(64, 92, 1.15, 15, '#2f8a2a'); bl(64, 92, 1.15, 165, '#2a8026')
    bl(64, 64, 1.0, 5, '#36962e'); bl(64, 64, 1.0, 175, '#33902c')
    I.p('M64 42C56 36 54 24 62 14C70 22 72 34 64 42Z', I.rg('#4fae3a', .5, .3))
    I.p('M64 44C56 42 46 38 42 30C52 28 60 34 64 44ZM64 44C72 42 82 38 86 30C76 28 68 34 64 44Z', I.rg('#46a334', .5, .3))


@icon('mint', 'Mint')
def ic_mint(I):
    I.shadow(rx=34)
    I.line('M64 112Q62 70 64 30', '#5a8f3a', 3)
    for y, k in ((94, 1.15), (72, 1.0), (52, .85)):
        for s in (1, -1):
            with I.at(64, y, k):
                d = f'M0 0C{s * 4} -10 {s * 16} -16 {s * 26} -14C{s * 24} -4 {s * 12} 4 0 0Z'
                I.p(d, I.rg('#4dbb5a', .5, .3))
                for t in (8, 14, 20):
                    I.line(f'M{s * t} {-t * .45}l{s * 2} -5M{s * t} {-t * .45}l{s * 1} 4', '#2e8a3c', .9, .6)
    I.p('M64 36C58 30 58 20 64 14C70 20 70 30 64 36Z', I.rg('#5cc866', .5, .3))


@icon('rosemary', 'Rosemary')
def ic_rosemary(I):
    I.shadow(rx=34)
    for x0, rot in ((56, -12), (70, 10)):
        with I.at(x0, 108, 1, rot):
            I.line('M0 0Q2 -40 0 -84', '#7a5a36', 2.6)
            for k in range(13):
                y = -10 - k * 6
                for s in (-1, 1):
                    I.e(s * 6, y, 7, 1.8, I.rg('#4e7a52', .5, .3), rot=s * -35)


@icon('thyme', 'Thyme')
def ic_thyme(I):
    I.shadow(rx=32)
    for x0, rot in ((50, -20), (64, 0), (78, 18)):
        with I.at(x0 + 14 * (x0 - 64) / 14 * 0, 110, 1, rot):
            I.line('M0 0Q-2 -40 2 -80', '#8a6a46', 1.6)
            for k in range(16):
                y = -12 - k * 4.4
                s = 1 if k % 2 else -1
                I.e(s * 3.4, y, 3, 1.8, I.rg('#6f8f58', .5, .3), rot=s * -30)


@icon('chives', 'Chives')
def ic_chives(I):
    I.shadow(rx=30)
    for i in range(9):
        x = 50 + i * 3.5
        I.line(f'M{f(x)} 110Q{f(x + (i - 4) * 2)} 60 {f(x + (i - 4) * 6)} {20 + abs(i - 4) * 4}', '#3f9a33' if i % 2 else '#56b043', 3)
    I.c(84, 22, 8, I.rg('#b067c9', .5, .3))
    dots(I, 84, 22, 6, 6, 9, 1.4, '#d6a2ea')
    bunch_tie(I, 64, 96, '#e0b04a')


@icon('sage', 'Sage')
def ic_sage(I):
    I.shadow(rx=34)
    I.line('M64 112V36', '#7f8f6a', 2.6)
    for y, s, k in ((96, 1, 1.1), (88, -1, 1.1), (70, 1, .95), (62, -1, .95), (46, 1, .8)):
        with I.at(64, y, k, s * -30):
            I.e(s * 16, 0, 17, 7, I.rg('#8aa58a', .5, .3))
            I.line(f'M0 0H{s * 28}', '#6f8a6f', 1, .6)
            dots(I, s * 16, 0, 12, 4, 10, .7, '#c3d3c3', .6)
    I.e(64, 34, 6, 12, I.rg('#8aa58a', .5, .3))


@icon('bay_leaf', 'Bay Leaf')
def ic_bay(I):
    I.shadow(rx=40)
    for x, y, r, c in ((48, 66, -50, '#7d8a3a'), (72, 62, -15, '#8a9443'), (64, 82, 25, '#6f7d34')):
        with I.at(x, y, 1, r):
            I.p('M0 -34C10 -22 12 0 0 34C-12 0 -10 -22 0 -34Z', I.rg(c, .45, .35))
            I.line('M0 -30V30', lt(c, .3), 1.2, .8)
            for t in (-18, -6, 6, 18):
                I.line(f'M0 {t}l6 -6M0 {t}l-6 -6', lt(c, .25), .7, .6)


@icon('tarragon', 'Tarragon')
def ic_tarragon(I):
    I.shadow(rx=32)
    I.line('M64 112Q64 70 62 22', '#6a8f3a', 2.4)
    for k in range(10):
        y = 100 - k * 8
        s = 1 if k % 2 else -1
        with I.at(64, y, 1, s * (-40 + k * 2) + (0 if s > 0 else 180)):
            I.e(14, 0, 15, 2.6, I.rg('#4f9a3a', .5, .3))


@icon('lemongrass', 'Lemongrass')
def ic_lemongrass(I):
    I.shadow(rx=40)
    for i, (x, rot) in enumerate(((50, -24), (64, -10), (78, 4))):
        with I.at(x, 104, 1, rot):
            I.p('M-5 0C-6 -16 -4 -40 -2 -70H2C4 -40 6 -16 5 0Q0 6 -5 0Z', I.vg('#a9c96a', '#efe9c8'))
            I.p('M-2 -70L-6 -92M2 -70L5 -88', 'none')
            I.line('M-1 -68L-4 -88M1 -68L3 -86', '#7fa84a', 2.4)


@icon('rhubarb', 'Rhubarb')
def ic_rhubarb(I):
    I.shadow(rx=40)
    for x, rot in ((52, -22), (64, -6), (76, 10)):
        with I.at(x, 110, 1, rot):
            I.p('M-5 0V-60Q0 -64 5 -60V0Q0 4 -5 0Z', I.cyl('#d8344a', .45, .35))
            I.line('M-1 -4V-58', '#f08a8a', 1.2, .6)
    I.p('M40 50C26 40 30 18 50 16C56 6 76 6 82 16C102 16 106 38 92 48C84 56 50 58 40 50Z', I.rg('#4f9a33', .45, .35))
    I.line('M64 50V18M64 40L48 28M64 36L82 26', '#2f6e1c', 1.4, .7)


@icon('fennel', 'Fennel')
def ic_fennel(I):
    I.shadow(rx=40)
    for x, rot in ((52, -20), (64, 0), (76, 20)):
        with I.at(x, 70, 1, rot):
            I.p('M-4 0V-40H4V0Z', I.cyl('#a9cf6a', .4, .3))
    for x, y in ((40, 26), (64, 20), (88, 26)):
        for k in range(6):
            I.line(f'M{x} {y + 8}l{(k - 2.5) * 4} -12', '#5fae3a', 1.2)
    I.p('M24 88C24 66 44 60 64 62C84 60 104 66 104 88C104 104 86 112 64 112C42 112 24 104 24 88Z', I.rg('#e6f0c8', .4, .25))
    I.line('M44 70Q40 90 48 108M84 70Q88 90 80 108M64 64V112', '#c9d9a0', 1.6, .7)
    I.hl(40, 80, 6, 10, -10, .6)


@icon('artichoke', 'Artichoke')
def ic_artichoke(I):
    # шар из широких чешуйчатых листьев, шире в середине, с фиолетовыми кончиками
    I.shadow(rx=40)
    I.r(59, 98, 10, 16, 4, I.cyl('#6f8f4a', .4, .3))
    I.e(64, 68, 38, 36, I.rg('#5f8a4a', .3, .4))
    rows = []
    for j, y in enumerate((36, 48, 60, 72, 84, 96)):
        half = math.sqrt(max(0, 38 ** 2 - (y - 64) ** 2)) * .92
        n = max(1, round(2 * half / 17))
        w = 2 * half / n / 1.5
        rows.append((y + 4, [(-half + (i + .5) * 2 * half / n) / (w * 1.05) for i in range(n)], w,
                     ('#90bf74', '#84b468', '#78a85e', '#6c9c54', '#62904c', '#5a8446')[j]))
    for y, xs, w, c in rows:
        for i in xs:
            x = 64 + i * w * 1.05
            I.p(f'M{f(x - w * .75)} {y + 8}C{f(x - w * .8)} {y - 6} {f(x - 3)} {y - 12} {f(x)} {y - 14}C{f(x + 3)} {y - 12} {f(x + w * .8)} {y - 6} {f(x + w * .75)} {y + 8}Z',
                I.rg(c, .45, .3))
            I.p(f'M{f(x - 3)} {y - 11}Q{f(x)} {y - 16} {f(x + 3)} {y - 11}Q{f(x)} {y - 9} {f(x - 3)} {y - 11}Z', '#8a4a7a', .85)
    I.hl(48, 50, 6, 10, -15, .45)


@icon('horseradish', 'Horseradish')
def ic_horseradish(I):
    I.shadow(rx=40)
    with I.at(66, 70, 1, 35):
        I.p('M-9 -40C-3 -46 5 -46 9 -40L6 40Q0 52 -6 40Z', I.rg('#e7d9b8', .5, .35))
        for t in (-26, -10, 6, 22):
            I.line(f'M-7 {t}q4 3 12 0', '#c2ab7f', 1.2, .7)
    for rot, c in ((-30, '#4f9a33'), (0, '#5aa63a'), (30, '#468f2e')):
        with I.at(91, 35, 1, rot + 30):
            I.p('M0 0C-8 -8 -8 -26 0 -32C8 -26 8 -8 0 0Z', I.rg(c, .45, .3))


@icon('wasabi', 'Wasabi')
def ic_wasabi(I):
    # тюбик + горка пасты
    I.shadow(rx=44)
    with I.at(70, 58, 1, 30):
        I.p('M-14 -40H14V26L8 36H-8L-14 26Z', I.cyl('#e9eef0', .4, .3))
        I.p('M-14 -40H14V-34H-14Z', '#c9d0d4')
        I.p('M-14 -20H14V14H-14Z', I.cyl('#6ea83a', .35, .3))
        I.r(-6, 36, 12, 10, 3, I.cyl('#3f7a2a', .4, .3))
    I.p('M20 104C22 92 30 84 38 86C44 80 54 86 54 96C56 104 46 108 36 108C26 108 20 108 20 104Z', I.rg('#8cbf3a', .4, .3))
    I.p('M34 86Q38 76 44 80Q40 82 38 88Z', '#9ccc48')


@icon('sorrel', 'Sorrel')
def ic_sorrel(I):
    I.shadow(rx=36)
    for x, y, r, k in ((48, 70, -25, 1.0), (64, 64, 0, 1.1), (80, 70, 25, 1.0)):
        with I.at(x, y, k, r):
            I.line('M0 40V0', '#a8344a', 2.2)
            I.p('M0 4C-10 -4 -12 -26 -6 -40L0 -36L6 -40C12 -26 10 -4 0 4Z', I.rg('#4fa03a', .45, .3))
            I.line('M0 2V-34', '#2f6e1c', 1, .6)
    bunch_tie(I, 64, 104, '#d8b44a')


# ======================= специи =======================
@icon('cinnamon', 'Cinnamon')
def ic_cinnamon(I):
    I.shadow(rx=44)
    for x, y, rot in ((50, 66, -28), (66, 74, -18), (78, 62, -36)):
        with I.at(x, y, 1, rot):
            I.p('M-34 -7H34V7H-34Z', I.cyl('#a4582a', .45, .35))
            I.e(34, 0, 3, 7, '#7a3e1c')
            I.p('M31 -6C36 -6 36 6 31 6C33 4 33 -4 31 -6Z', '#d08a54')
            I.line('M-28 -2H26', '#c87a46', 1, .6)
    I.p('M20 102C30 92 56 92 64 102Z', I.rg('#b8682e', .4, .3))


@icon('star_anise', 'Star Anise')
def ic_star_anise(I):
    I.shadow(rx=40)
    for a in range(0, 360, 45):
        with I.at(64, 64, 1, a):
            I.p('M0 -4C-7 -14 -6 -36 0 -42C6 -36 7 -14 0 -4Z', I.rg('#8a4220', .45, .35))
            I.p('M0 -10C-3 -18 -2 -26 0 -30C2 -26 3 -18 0 -10Z', '#5a2410')
            I.e(0, -22, 2.4, 4, I.rg('#c08a4a', .55, .3))
    I.c(64, 64, 6, I.rg('#6a3418', .4, .3))


@icon('cloves', 'Cloves')
def ic_cloves(I):
    I.shadow(rx=40)
    for x, y, rot in ((40, 62, -30), (62, 56, 10), (84, 64, 40), (50, 84, -60), (76, 86, 70)):
        with I.at(x, y, 1, rot):
            I.p('M-2.5 0L-1.5 26Q0 30 1.5 26L2.5 0Z', I.cyl('#6a3418', .4, .3))
            I.c(0, -3, 6.5, I.rg('#7a3c1c', .45, .35))
            for a in range(0, 360, 90):
                with I.at(0, -3, 1, a): I.e(0, -4.5, 2.6, 2.6, '#8f4c26')


@icon('nutmeg', 'Nutmeg')
def ic_nutmeg(I):
    I.shadow(rx=44)
    I.e(44, 70, 24, 20, I.rg('#9a6a46', .45, .35), rot=-20)
    for k in range(6):
        I.line(f'M{28 + k * 6} {56 + k}Q{36 + k * 6} 70 {28 + k * 6} {84 + k}', '#7a4e30', 1.2, .5)
    I.hl(36, 60, 6, 4)
    I.e(86, 80, 22, 18, '#8a5a36', rot=15)
    I.e(86, 80, 19, 15, I.rg('#d9b48a', .3, .2), rot=15)
    for k in range(10):
        a = k * .63
        I.line(f'M86 80L{f(86 + 16 * math.cos(a))} {f(80 + 13 * math.sin(a))}', '#8a5a36', 1.6, .7)


@icon('black_pepper', 'Black Pepper')
def ic_black_pepper(I):
    I.shadow(rx=44)
    for i in range(34):
        a, t = i * 2.39996, math.sqrt((i + .5) / 34)
        x, y = 64 + math.cos(a) * 38 * t, 86 + math.sin(a) * 14 * t - (1 - t) * 26
        I.c(x, y, 5.6, I.rg('#3b3330', .5, .3))
        I.c(x - 1.6, y - 1.8, 1.2, '#8a7f78', .8)


@icon('saffron', 'Saffron')
def ic_saffron(I):
    I.shadow(rx=40, cy=106)
    I.e(64, 92, 40, 13, I.rg('#f4efe6', .3, .2))
    I.e(64, 90, 32, 9, '#e6dfd2')
    for i in range(14):
        x = 40 + (i * 17) % 48; y = 86 + (i * 5) % 8
        rot = (i * 47) % 180
        with I.at(x, y, 1, rot):
            I.p('M-9 -1.2L9 -2.4Q11 0 9 2.4L-9 1.2Z', I.rg('#d8261c', .45, .3))
    with I.at(84, 44, 1, 30):
        I.p('M0 0C-6 -10 -2 -24 0 -30C2 -24 6 -10 0 0Z', I.rg('#a77bd0', .45, .3))
        I.p('M0 0C-14 -6 -18 -18 -16 -24C-8 -18 -2 -10 0 0ZM0 0C14 -6 18 -18 16 -24C8 -18 2 -10 0 0Z', I.rg('#9a6ac4', .45, .35))
        I.line('M0 -2L-4 -18M0 -2L4 -18', '#e8331f', 1.6)


@icon('cardamom', 'Cardamom')
def ic_cardamom(I):
    I.shadow(rx=40)
    for x, y, rot in ((44, 66, -30), (66, 58, 20), (82, 80, -60), (54, 88, 50)):
        with I.at(x, y, 1, rot):
            I.p('M0 -18C8 -12 9 8 0 18C-9 8 -8 -12 0 -18Z', I.rg('#8aa858', .5, .35))
            I.line('M0 -16V16M-4 -10Q-6 0 -4 10M4 -10Q6 0 4 10', '#6a8a3e', .9, .6)
    with I.at(54, 88, 1, 50):
        I.p('M0 -12C5 -8 5 6 0 12C-5 6 -5 -8 0 -12Z', '#3a2a1c')


@icon('paprika', 'Paprika')
def ic_paprika(I):
    from icons_a import em_powder
    shaker(I, '#d8341f', '#c42a1a', None, fill=.8)
    with I.at(64, 84, 1.0):
        I.p('M-8 -8C-2 -12 6 -10 8 -6C10 2 6 10 0 12C-6 10 -10 2 -8 -8Z', I.rg('#e8321e', .5, .3))
        I.line('M0 -10Q2 -14 6 -15', '#3f8f2a', 2)


@icon('turmeric', 'Turmeric')
def ic_turmeric(I):
    I.shadow(rx=46)
    I.p('M22 74H90Q90 98 70 104H42Q22 98 22 74Z', I.cyl('#f4efe6', .4, .25))
    I.e(56, 74, 34, 8, '#e3dccd')
    I.p('M28 74C36 60 50 54 56 54C64 54 78 60 84 74Z', I.rg('#f0a90f', .4, .25))
    I.e(56, 74, 28, 5, '#dc960c')
    with I.at(96, 96, 1, -20):
        I.p('M-16 -4C-14 -10 10 -10 16 -4C20 2 14 8 0 8C-14 8 -20 2 -16 -4Z', I.rg('#b98a52', .45, .35))
        I.e(16, -1, 4, 6, '#f08a10')


@icon('cumin', 'Cumin')
def ic_cumin(I):
    I.shadow(rx=44)
    for i in range(30):
        a, t = i * 2.39996, math.sqrt((i + .5) / 30)
        x, y = 64 + math.cos(a) * 38 * t, 88 + math.sin(a) * 12 * t - (1 - t) * 26
        with I.at(x, y, 1, (i * 53) % 180):
            I.e(0, 0, 6, 2, I.rg('#9a7a4a', .5, .3))
            I.line('M-5 0H5', '#6e5430', .6, .7)


@icon('coriander_seeds', 'Coriander Seeds')
def ic_coriander_seeds(I):
    I.shadow(rx=44)
    for i in range(24):
        a, t = i * 2.39996, math.sqrt((i + .5) / 24)
        x, y = 64 + math.cos(a) * 36 * t, 88 + math.sin(a) * 12 * t - (1 - t) * 24
        I.c(x, y, 6.4, I.rg('#c9a46a', .5, .3))
        I.line(f'M{f(x - 2)} {f(y - 5)}Q{f(x - 4)} {f(y)} {f(x - 2)} {f(y + 5)}', '#9a7a46', .7, .6)


@icon('mustard_seeds', 'Mustard Seeds')
def ic_mustard_seeds(I):
    I.shadow(rx=40, cy=106)
    I.p('M24 76H104Q104 100 82 106H46Q24 100 24 76Z', I.cyl('#6e4a2e', .4, .3))
    I.e(64, 76, 40, 9, '#5a3c22')
    for i in range(40):
        a, t = i * 2.39996, math.sqrt((i + .5) / 40)
        I.c(64 + math.cos(a) * 34 * t, 74 + math.sin(a) * 6 * t - (1 - t) * 10, 3.2, I.rg('#e0b434', .55, .3))


# ======================= острые перцы =======================
def pepper_long(I, c, x, y, k, rot, w=1.0):
    with I.at(x, y, k, rot):
        I.p(f'M0 -40C{f(10 * w)} -40 {f(12 * w)} -26 {f(10 * w)} -10C{f(8 * w)} 12 4 30 -4 42C{f(-2 * w)} 26 {f(-10 * w)} 8 {f(-11 * w)} -12C{f(-12 * w)} -30 {f(-8 * w)} -40 0 -40Z',
            I.rg(c, .5, .35))
        I.p(f'M{f(-9 * w)} -40Q0 -48 {f(9 * w)} -40Q0 -36 {f(-9 * w)} -40Z', '#3f8f2a')
        I.line('M0 -44Q2 -52 8 -56', '#4a8a2a', 3)
        I.hl(-4 * w, -24, 3 * w, 12, 0, .6)


@icon('chili_pepper', 'Chili Pepper')
def ic_chili(I):
    I.shadow(rx=40)
    pepper_long(I, '#e0201c', 64, 64, 1.05, 35, .9)


@icon('jalapeno', 'Jalapeno')
def ic_jalapeno(I):
    I.shadow(rx=40)
    pepper_long(I, '#3f8f2a', 58, 66, 1.0, 25, 1.45)
    I.line('M44 50Q48 46 52 48', '#6fb84a', 1.5, .5)


@icon('habanero', 'Habanero')
def ic_habanero(I):
    I.shadow(rx=40)
    I.p('M64 36C88 34 100 52 96 74C92 92 78 100 66 108C62 98 50 96 40 88C26 76 30 40 64 36Z', I.rg('#f57a10', .5, .35))
    I.line('M54 44Q48 70 58 98M74 42Q80 70 72 100', '#d35a08', 2, .4)
    I.p('M52 40Q64 28 76 40Q64 44 52 40Z', '#3f8f2a')
    I.line('M64 34Q66 22 74 18', '#4a8a2a', 3.5)
    I.hl(48, 54, 6, 10, -20)


@icon('poblano', 'Poblano Pepper')
def ic_poblano(I):
    I.shadow(rx=40)
    pepper_long(I, '#1f5a2a', 64, 66, 1.05, 30, 1.9)


@icon('birds_eye_chili', "Bird's Eye Chili")
def ic_birds_eye(I):
    I.shadow(rx=40)
    for x, rot, c in ((44, -20, '#e01c1c'), (64, 0, '#e8301e'), (84, 20, '#4f9a2a')):
        pepper_long(I, c, x, 72, .7, rot + 180, .5)


@icon('scotch_bonnet', 'Scotch Bonnet')
def ic_scotch_bonnet(I):
    I.shadow(rx=44)
    I.p('M24 76C20 56 40 46 64 46C88 46 108 56 104 76C100 94 84 100 64 100C44 100 28 94 24 76Z', I.rg('#f4b012', .5, .35))
    I.p('M24 76C34 70 40 82 50 78C58 74 70 84 78 78C86 72 96 82 104 76C100 94 84 100 64 100C44 100 28 94 24 76Z', '#e8661c', .55)
    I.p('M36 54Q30 76 44 96M64 48V100M92 54Q98 76 84 96', 'none')
    I.line('M40 54Q34 76 46 96M88 54Q94 76 82 96', '#b81e10', 2, .4)
    I.p('M54 50Q64 40 74 50Q64 54 54 50Z', '#3f8f2a')
    I.line('M64 46Q64 34 72 28', '#4a8a2a', 3.5)
    I.hl(42, 60, 10, 6, -20)


@icon('hot_sauce', 'Hot Sauce')
def ic_hot_sauce(I):
    from icons_a import em_chili
    bottle(I, '#c81e14', '#f2f2ee', '#f6e9c6', em_chili, w=18, neck=6, top=16, shoulder=54, label_y=(66, 98))


@icon('sriracha', 'Sriracha')
def ic_sriracha(I):
    from icons_a import em_garlic
    squeeze(I, '#e0281c', '#2f9a3a', em_garlic)


@icon('tabasco', 'Tabasco')
def ic_tabasco(I):
    I.shadow(rx=24)
    d = 'M52 60C52 52 58 50 58 42V30H70V42C70 50 76 52 76 60V106Q76 112 70 112H58Q52 112 52 106Z'
    I.p(d, I.cyl('#b8160e', .4, .4))
    I.p('M52 74H76V100H52Z', I.cyl('#f2e2b8', .3, .25))
    I.p('M60 86C60 80 68 80 68 86C68 92 64 96 64 96C64 96 60 92 60 86Z', '#c8201a')
    I.r(56, 14, 16, 18, 3, I.cyl('#d9dcdf', .45, .35))
    I.r(55, 60, 3, 40, 1.5, '#fff', .35)


@icon('gochujang', 'Gochujang')
def ic_gochujang(I):
    I.shadow(rx=44)
    I.p('M26 50H102L98 104Q97 112 88 112H40Q31 112 30 104Z', I.cyl('#c8201c', .45, .35))
    I.p('M22 40Q22 36 28 36H100Q106 36 106 40V48Q106 52 100 52H28Q22 52 22 48Z', I.cyl('#a8161a', .45, .35))
    I.e(64, 38, 40, 3.5, '#d84a3a')
    I.p('M46 84C46 74 56 70 64 72C72 70 82 74 82 84C78 90 50 90 46 84Z', I.rg('#9a1e1a', .4, .3))
    I.r(32, 58, 4, 44, 2, '#fff', .35)


@icon('harissa', 'Harissa')
def ic_harissa(I):
    I.shadow(rx=46)
    with I.at(64, 66, 1, -30):
        I.p('M-40 -14H22L40 -4V4L22 14H-40Q-44 0 -40 -14Z', I.cyl('#d23a1a', .4, .35))
        I.p('M-40 -14H-34V14H-40Z', '#a8281a')
        I.r(40, -6, 10, 12, 3, I.cyl('#f2f2ee', .4, .3))
        I.p('M-26 -8H10V8H-26Z', '#f6e3b0')
        I.p('M-12 -4C-4 -6 4 -2 4 2C2 6 -8 6 -12 2C-16 0 -16 -3 -12 -4Z', '#d8201a')


# ======================= листовые овощи =======================
@icon('cabbage', 'Cabbage')
def ic_cabbage(I):
    I.shadow(rx=46)
    I.c(64, 68, 42, I.rg('#8fc25a', .4, .35))
    I.p('M22 70C18 42 40 24 60 26C44 34 34 52 38 76Z', I.rg('#7ab048', .45, .3))
    I.p('M106 70C110 42 88 24 68 26C84 34 94 52 90 76Z', I.rg('#6ea63c', .45, .35))
    I.c(64, 66, 26, I.rg('#cfe6a2', .4, .25))
    I.line('M64 104V44M64 80Q40 70 30 56M64 80Q88 70 98 56', '#e8f4cf', 2.2, .8)
    I.hl(52, 50, 10, 6)


@icon('red_cabbage', 'Red Cabbage')
def ic_red_cabbage(I):
    I.shadow(rx=46)
    I.c(76, 60, 32, I.rg('#7a3a8a', .4, .35))
    I.line('M76 92V36M76 70Q60 62 52 50M76 70Q92 62 100 50', '#b88ac8', 1.8, .7)
    I.e(46, 84, 32, 24, '#6a2a7a')
    I.e(46, 83, 29, 21, '#f3e9f3')
    for k in range(5):
        I.p(f'M{20 + k * 4} {84}Q{46} {66 + k * 4} {72 - k * 4} 84Q46 {100 - k * 4} {20 + k * 4} 84Z', 'none')
        I.add(f'<path d="M{20 + k * 5} 84Q46 {64 + k * 5} {72 - k * 5} 84Q46 {104 - k * 5} {20 + k * 5} 84Z" fill="none" stroke="#7a2e8a" stroke-width="2.4"/>')
    I.hl(66, 42, 8, 5)


@icon('lettuce', 'Lettuce')
def ic_lettuce(I):
    I.shadow(rx=46)
    for x, y, r, c in ((36, 66, -40, '#7cc04a'), (92, 66, 40, '#74b842'), (50, 52, -15, '#8ccf58'), (78, 52, 15, '#86c852'), (64, 72, 0, '#9ed86a')):
        with I.at(x, y, 1, r):
            I.p('M0 40C-22 30 -26 -6 -14 -26C-10 -32 -4 -28 0 -34C4 -28 10 -32 14 -26C26 -6 22 30 0 40Z', I.rg(c, .45, .3))
            I.line('M0 38V-28', lt(c, .45), 2, .8)


@icon('spinach', 'Spinach')
def ic_spinach(I):
    I.shadow(rx=44)
    for x, y, r, c in ((40, 64, -35, '#2f7a2a'), (88, 64, 35, '#2a7026'), (64, 52, 0, '#348a2e'), (52, 78, -12, '#3a8f33'), (78, 78, 14, '#33852e')):
        with I.at(x, y, 1, r):
            I.line('M0 40V14', '#7ab84a', 2.5)
            I.p('M0 16C-16 10 -18 -14 0 -30C18 -14 16 10 0 16Z', I.rg(c, .5, .3))
            I.line('M0 14V-24', '#5aa043', 1.2, .8)


@icon('celery', 'Celery')
def ic_celery(I):
    I.shadow(rx=40)
    for x, rot in ((50, -10), (64, 0), (78, 10)):
        with I.at(x, 110, 1, rot):
            I.p('M-7 0C-8 -24 -6 -50 -5 -64H5C6 -50 8 -24 7 0Q0 4 -7 0Z', I.cyl('#b3d77a', .45, .3))
            I.line('M-2 -4V-60M2 -4V-60', '#8ebd52', 1, .6)
    for x, y in ((40, 34), (58, 26), (76, 28), (90, 38)):
        flat_leaf_c(I, x, y)


def flat_leaf_c(I, x, y):
    with I.at(x, y, .9):
        I.p('M0 10C-10 6 -14 -4 -8 -12C-4 -10 -2 -16 2 -14C6 -16 10 -10 12 -6C14 2 8 8 0 10Z', I.rg('#5aa63a', .45, .3))


@icon('leek', 'Leek')
def ic_leek(I):
    I.shadow(rx=46)
    with I.at(64, 64, 1, 40):
        I.p('M-9 6V44Q0 52 9 44V6Z', I.cyl('#f2f2e2', .4, .2))
        for k in (-8, -3, 2, 7):
            I.line(f'M{k} 48l{k * .3} 4', '#e2dcc2', 1.2)
        I.p('M-9 8V-6H9V8Z', I.vg('#cfe3a0', '#f2f2e2'))
        I.p('M-9 -6L-20 -54Q-12 -56 -6 -40Z', I.rg('#3f8a3a', .4, .3))
        I.p('M-5 -6L0 -60Q8 -56 6 -40L5 -6Z', I.rg('#4f9a3a', .4, .3))
        I.p('M9 -6L22 -50Q14 -54 6 -38Z', I.rg('#2f7a3a', .4, .3))


@icon('arugula', 'Arugula')
def ic_arugula(I):
    I.shadow(rx=40)
    for x, y, r in ((42, 64, -40), (64, 56, 0), (86, 64, 40), (54, 74, -15), (74, 74, 15)):
        with I.at(x, y, 1, r):
            I.line('M0 40V0', '#7aa848', 1.8)
            I.p('M0 0C-6 -4 -10 -8 -8 -14C-4 -12 -2 -14 -2 -18C-6 -20 -8 -26 -4 -30C0 -34 4 -34 6 -30C8 -26 6 -20 2 -18C2 -14 4 -12 8 -14C10 -8 6 -4 0 0Z',
                I.rg('#3f8f2e', .45, .3))


@icon('bok_choy', 'Bok Choy')
def ic_bok_choy(I):
    I.shadow(rx=40)
    for x, rot, c in ((48, -16, '#2f7a2a'), (80, 16, '#2a7026'), (64, 0, '#3a8f33')):
        with I.at(x, 106, 1, rot):
            I.p('M-10 0C-12 -20 -10 -36 -8 -44H8C10 -36 12 -20 10 0Q0 6 -10 0Z', I.cyl('#f2f6e6', .4, .2))
            I.p('M-10 -40C-22 -52 -18 -80 0 -88C18 -80 22 -52 10 -40Q0 -36 -10 -40Z', I.rg(c, .45, .3))
            I.line('M0 -40V-82', '#cfe6b0', 2, .8)


@icon('brussels_sprouts', 'Brussels Sprouts')
def ic_brussels(I):
    I.shadow(rx=46)
    for x, y, r in ((40, 74, 22), (86, 72, 20), (62, 90, 20)):
        I.c(x, y, r, I.rg('#7ab848', .45, .35))
        I.p(f'M{x - r} {y}C{x - r} {y - r} {x} {y - r - 2} {x + r * .3} {y - r * .7}C{x - r * .2} {y - r * .2} {x - r * .4} {y + r * .3} {x - r} {y}Z', '#5f9a36', .7)
        I.p(f'M{x + r} {y + 2}C{x + r} {y - r * .7} {x + r * .2} {y - r} {x - r * .2} {y - r * .8}C{x + r * .4} {y - r * .2} {x + r * .5} {y + r * .4} {x + r} {y + 2}Z', '#9ccc66', .6)
        I.hl(x - r * .4, y - r * .45, r * .3, r * .18)


@icon('kale', 'Kale')
def ic_kale(I):
    I.shadow(rx=40)
    for x, y, r, c in ((48, 64, -20, '#2a5e3a'), (80, 64, 20, '#2f6a40'), (64, 58, 0, '#357548')):
        with I.at(x, 104, 1, r):
            I.line('M0 0V-40', '#8ab87a', 3)
            pts = ''.join(f'L{f(s * (14 + 4 * (k % 2)))} {-24 - k * 8}' for s in (-1,) for k in range(8))
            I.p('M0 -20' + ''.join(f'L{f(-(12 + 6 * (k % 2)))} {-24 - k * 8}' for k in range(8)) + 'L0 -92'
                + ''.join(f'L{f(12 + 6 * (k % 2))} {-24 - (7 - k) * 8}' for k in range(8)) + 'Z', I.rg(c, .45, .3))
            I.line('M0 -20V-86', '#6f9f68', 1.6, .8)


@icon('kohlrabi', 'Kohlrabi')
def ic_kohlrabi(I):
    I.shadow(rx=40)
    for x, rot in ((48, -30), (64, -4), (80, 24)):
        with I.at(64, 64, 1, rot):
            I.line('M0 0Q2 -30 0 -40', '#8fc062', 3)
            I.p('M0 -36C-12 -40 -14 -56 0 -62C14 -56 12 -40 0 -36Z', I.rg('#4f9a3a', .45, .3))
    I.c(64, 80, 30, I.rg('#b9e08a', .45, .3))
    I.line('M44 72Q40 66 36 64M84 72Q88 66 92 64M50 96Q46 102 44 106', '#8fc062', 2.4)
    I.hl(52, 68, 8, 5)
