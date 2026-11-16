#!/usr/bin/env python3
"""App icons for the Flutter builds (Android / Windows / macOS / Linux) from the same drawing as the iOS icon.

Re-uses tool/make_app_icon.py (Nutrik's face on the burgundy gradient) — runs its drawing code in memory
twice: once as is (full icon) and once on a transparent canvas (foreground layer of the Android adaptive icon).

  python3 tool/make_platform_icons.py

Writes:
  android/app/src/main/res/mipmap-*/ic_launcher.png             legacy icon (Android 7)
  android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive icon foreground (Android 8+)
  android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml   + drawable/ic_launcher_background.xml (gradient)
  windows/runner/resources/app_icon.ico
  macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_*.png (Big Sur-style rounded square with shadow)
  linux/runner/resources/app_icon.png
"""
import io
import pathlib

from PIL import Image, ImageDraw, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = (ROOT / 'tool' / 'make_app_icon.py').read_text(encoding='utf-8')
CREAM = (0xF5, 0xF1, 0xE5)


def render(transparent: bool) -> Image.Image:
    code = SRC.split('\nout = ')[0]  # всё рисование, без сохранения в iOS
    if transparent:
        repl = [
            ("img = Image.new('RGB', (S, S))", "img = Image.new('RGBA', (S, S), (0, 0, 0, 0))"),
            ("for y in range(S):", "for y in range(0):"),
            ("img.paste(Image.new('RGB', (S, S), (0xF5, 0xF1, 0xE5)), (0, 0), glow)",
             "pass  # без свечения: на слое переднего плана оно обрезалось бы квадратом"),
        ]
        for a, b in repl:
            assert a in code, f'make_app_icon.py changed: {a!r} not found'
            code = code.replace(a, b)
    ns = {'__file__': str(ROOT / 'tool' / 'make_app_icon.py')}
    exec(compile(code, 'make_app_icon.py', 'exec'), ns)
    return ns['img'].convert('RGBA')


def rounded(img: Image.Image, size: int, radius: float) -> Image.Image:
    im = img.resize((size, size), Image.LANCZOS)
    m = Image.new('L', (size * 4, size * 4), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=radius * size * 4, fill=255)
    im.putalpha(m.resize((size, size), Image.LANCZOS))
    return im


def save_png(im: Image.Image, path: pathlib.Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    im.save(path, optimize=True)


def main():
    full = render(False).resize((1024, 1024), Image.LANCZOS)
    face = render(True).resize((1024, 1024), Image.LANCZOS)

    # ── Android ──
    res = ROOT / 'android/app/src/main/res'
    dens = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}
    for d, k in dens.items():
        save_png(rounded(full, round(48 * k), 0.18), res / f'mipmap-{d}/ic_launcher.png')
        fg = round(108 * k)
        layer = Image.new('RGBA', (fg, fg), (0, 0, 0, 0))
        inner = round(fg * 0.70)  # лицо целиком в безопасной зоне маски (круг 72 dp из 108)
        layer.alpha_composite(face.resize((inner, inner), Image.LANCZOS), ((fg - inner) // 2, (fg - inner) // 2 - round(fg * 0.01)))
        save_png(layer, res / f'mipmap-{d}/ic_launcher_foreground.png')
    (res / 'mipmap-anydpi-v26').mkdir(parents=True, exist_ok=True)
    (res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@drawable/ic_launcher_background"/>\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n'
        '</adaptive-icon>\n')
    (res / 'drawable/ic_launcher_background.xml').write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<!-- Burgundy gradient of the NutriMate icon (tool/make_platform_icons.py) -->\n'
        '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
        '    <gradient android:angle="270" android:startColor="#8E1230" android:endColor="#4A0213"/>\n'
        '</shape>\n')

    # ── Windows ──
    ico = rounded(full, 256, 0.18)
    path = ROOT / 'windows/runner/resources/app_icon.ico'
    ico.save(path, format='ICO', sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

    # ── macOS (Big Sur template: 824 px rounded square on a 1024 canvas + soft shadow) ──
    canvas = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    body = rounded(full, 824, 0.225)
    shadow = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    sm = Image.new('L', (1024, 1024), 0)
    sm.paste(body.getchannel('A').point(lambda v: v * 0.45), (100, 112))
    shadow.putalpha(sm.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(body, (100, 100))
    mac = ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset'
    for s in (16, 32, 64, 128, 256, 512, 1024):
        save_png(canvas.resize((s, s), Image.LANCZOS), mac / f'app_icon_{s}.png')

    # ── Linux ──
    save_png(rounded(full, 512, 0.18), ROOT / 'linux/runner/resources/app_icon.png')
    print('icons written')


if __name__ == '__main__':
    main()
