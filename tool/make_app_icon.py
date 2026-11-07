#!/usr/bin/env python3
"""Рисует иконку iOS-приложения (лицо Нутрика на бордовом фоне) → ios/NutriMate/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png"""
from PIL import Image, ImageDraw, ImageFilter
import pathlib
S = 4096
k = S / 100
def P(x, y): return (x * k, y * k)
def box(x, y, w, h): return [x * k, y * k, (x + w) * k, (y + h) * k]
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
top, bot = (0x8E, 0x12, 0x30), (0x4A, 0x02, 0x13)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)))
# мягкое кремовое свечение
glow = Image.new('L', (S, S), 0)
ImageDraw.Draw(glow).ellipse(box(14, 14, 72, 72), fill=120)
glow = glow.filter(ImageFilter.GaussianBlur(S // 12))
img.paste(Image.new('RGB', (S, S), (0xF5, 0xF1, 0xE5)), (0, 0), glow)
d = ImageDraw.Draw(img)
hair, skin, blush, leaf = (0x1E, 0x1A, 0x1D), (0xFF, 0xE6, 0xD3), (0xF4, 0xA3, 0xA8), (0x5D, 0xA3, 0x4A)
# ушки
d.polygon([P(19, 40), P(26, 12), P(42, 27)], fill=hair)
d.polygon([P(81, 40), P(74, 12), P(58, 27)], fill=hair)
d.polygon([P(24, 34), P(27, 19), P(36, 28)], fill=blush)
d.polygon([P(76, 34), P(73, 19), P(64, 28)], fill=blush)
# каре
d.rounded_rectangle(box(17, 22, 66, 62), radius=26 * k, fill=hair)
# лицо
d.ellipse(box(23, 30, 54, 50), fill=skin)
# чёлка
d.polygon([P(20, 46), P(26, 27), P(40, 21), P(60, 21), P(74, 27), P(80, 46), P(74, 40), P(67, 45), P(60, 38),
           P(52, 44), P(44, 37), P(37, 44), P(30, 38)], fill=hair)
d.ellipse(box(20, 20, 60, 22), fill=hair)
# прядка
d.line([P(52, 22), P(55, 13), P(62, 10)], fill=hair, width=int(2.4 * k), joint='curve')
# листик
d.polygon([P(64, 30), P(70, 21), P(80, 19), P(76, 28), P(66, 32)], fill=leaf)
d.line([P(66, 30), P(77, 21)], fill=(0xC8, 0xE6, 0xBE), width=int(0.8 * k))
# глаза
for x in (38, 62):
    d.ellipse(box(x - 4.5, 51, 9, 11), fill=hair)
    d.ellipse(box(x - 2.4, 52.5, 3.4, 3.4), fill='white')
# румянец и рот
d.ellipse(box(27, 61, 10, 5), fill=blush)
d.ellipse(box(63, 61, 10, 5), fill=blush)
d.arc(box(44, 60, 6, 5), 0, 180, fill=hair, width=int(1.2 * k))
d.arc(box(50, 60, 6, 5), 0, 180, fill=hair, width=int(1.2 * k))
# бантик снизу
d.polygon([P(50, 86), P(38, 79), P(38, 93)], fill=(0xC8, 0x10, 0x2E))
d.polygon([P(50, 86), P(62, 79), P(62, 93)], fill=(0xC8, 0x10, 0x2E))
d.ellipse(box(46.5, 82.5, 7, 7), fill=(0x9E, 0x0B, 0x24))
out = pathlib.Path(__file__).resolve().parent.parent / 'ios/NutriMate/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
img.resize((1024, 1024), Image.LANCZOS).save(out, optimize=True)
print('wrote', out)
