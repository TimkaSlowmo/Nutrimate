#!/usr/bin/env python3
"""Рендерит собственные иконки продуктов assets/icons/<slug>.svg в готовые картинки (коммитятся в репозиторий,
CI ничего не перерисовывает):
  • Flutter: assets/icons/s/<slug>.png — 128 px;
  • iOS: ios/NutriMate/Resources/Assets.xcassets/FoodIcons/fi_<slug>.imageset — один PNG 180 px
    (а старые иконки assets/icons/p/<slug>.png копируются туда же, чтобы на iOS и в вебе был один набор).
Потом обновляет tool/icons_manifest.json (sha1 каждого SVG) и перегенерирует lib/food_icons.dart.
Нужно: pip install cairosvg pillow.   Запуск: python3 tool/build_svg_icons.py [--sheet out.png]"""
import glob, hashlib, io, json, os, shutil, subprocess, sys
import cairosvg
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SVG_DIR = os.path.join(ROOT, 'assets/icons')
PNG_DIR = os.path.join(ROOT, 'assets/icons/s')
P_DIR = os.path.join(ROOT, 'assets/icons/p')
IOS_DIR = os.path.join(ROOT, 'ios/NutriMate/Resources/Assets.xcassets/FoodIcons')
MANIFEST = os.path.join(ROOT, 'tool/icons_manifest.json')
INFO = {'author': 'xcode', 'version': 1}


def render(svg_path, px):
    png = cairosvg.svg2png(url=svg_path, output_width=px, output_height=px)
    return Image.open(io.BytesIO(png)).convert('RGBA')


def save_small(im, path):
    # 256 цветов с альфой — в 3–4 раза меньше, на глаз не отличить
    im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(path, optimize=True)


def imageset(slug, im):
    d = os.path.join(IOS_DIR, f'fi_{slug}.imageset')
    os.makedirs(d, exist_ok=True)
    save_small(im, os.path.join(d, f'fi_{slug}.png'))
    json.dump({'images': [{'idiom': 'universal', 'filename': f'fi_{slug}.png'}], 'info': INFO},
              open(os.path.join(d, 'Contents.json'), 'w'), indent=2)


def main():
    os.makedirs(PNG_DIR, exist_ok=True)
    os.makedirs(IOS_DIR, exist_ok=True)
    json.dump({'info': INFO}, open(os.path.join(IOS_DIR, 'Contents.json'), 'w'), indent=2)
    old = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    manifest, slugs = {}, set()
    for svg in sorted(glob.glob(os.path.join(SVG_DIR, '*.svg'))):
        slug = os.path.basename(svg)[:-4]
        slugs.add(slug)
        h = hashlib.sha1(open(svg, 'rb').read()).hexdigest()
        manifest[slug] = h
        out = os.path.join(PNG_DIR, slug + '.png')
        ios = os.path.join(IOS_DIR, f'fi_{slug}.imageset', f'fi_{slug}.png')
        if old.get(slug) == h and os.path.exists(out) and os.path.exists(ios): continue
        save_small(render(svg, 128), out)
        imageset(slug, render(svg, 180))
    for png in sorted(glob.glob(os.path.join(P_DIR, '*.png'))):
        slug = os.path.basename(png)[:-4]
        if slug in slugs: continue
        slugs.add(slug)
        imageset(slug, Image.open(png).convert('RGBA'))
    # убрать устаревшие
    for f in glob.glob(os.path.join(PNG_DIR, '*.png')):
        if os.path.basename(f)[:-4] not in manifest: os.remove(f)
    for d in glob.glob(os.path.join(IOS_DIR, 'fi_*.imageset')):
        if os.path.basename(d)[3:-9] not in slugs: shutil.rmtree(d)
    json.dump(manifest, open(MANIFEST, 'w'), indent=0, sort_keys=True)
    print(f'rendered {len(manifest)} SVG icons → assets/icons/s + iOS FoodIcons ({len(slugs)} imagesets)')
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool/build_icons.py')], check=True)
    if '--sheet' in sys.argv:
        sheet(sys.argv[sys.argv.index('--sheet') + 1])


def sheet(out, slugs=None, cell=150, px=128, cols=10):
    """Контактный лист на тёмно-бордовом фоне: иконка + подпись (для визуальной проверки)."""
    from PIL import ImageDraw, ImageFont
    ov = json.load(open(os.path.join(ROOT, 'tool/icon_overrides.json')))
    names = {}
    for n, s in ov.items(): names.setdefault(s, []).append(n)
    slugs = slugs or sorted(os.path.basename(f)[:-4] for f in glob.glob(os.path.join(SVG_DIR, '*.svg')))
    rows = (len(slugs) + cols - 1) // cols
    W = cols * cell
    img = Image.new('RGB', (W, rows * (cell + 18)), (58, 2, 16))
    dr = ImageDraw.Draw(img)
    try: font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 11)
    except OSError: font = ImageFont.load_default()
    for i, s in enumerate(slugs):
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        im = render(os.path.join(SVG_DIR, s + '.svg'), px)
        img.paste(im, (x + (cell - px) // 2, y + 4), im)
        label = ', '.join(names.get(s, ['(unused) ' + s]))[:24]
        dr.text((x + 4, y + cell - 4), label, fill=(245, 241, 229), font=font)
    img.save(out)
    print('sheet →', out)


if __name__ == '__main__':
    main()
