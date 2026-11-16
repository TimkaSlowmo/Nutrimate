#!/usr/bin/env python3
"""Проверка иконок: «одна иконка = один продукт».

Эффективная иконка продукта — собственный рисунок (tool/icon_overrides.json: название → slug;
assets/icons/<slug>.svg или старый assets/icons/p/<slug>.png), иначе его эмодзи.
Печатает группы продуктов с общей иконкой и «unique X of Y» для продуктов, рецептов и категорий.

Ошибка (exit 1), если:
  • продукт, которого нет в tool/icon_dupes_baseline.json, делит иконку с другим продуктом
    (то есть новый продукт получил уже занятую иконку);
  • SVG отсутствует, не парсится, не 128×128, больше 8 КБ, или два SVG побайтно одинаковы;
  • для SVG нет отрисованных PNG (assets/icons/s, iOS FoodIcons) или они устарели (tool/icons_manifest.json).

  python3 tool/check_icons.py                    проверка + отчёт
  python3 tool/check_icons.py -v                 + все группы целиком
  python3 tool/check_icons.py --update-baseline  убрать из базовой линии продукты, у которых теперь своя иконка
  python3 tool/check_icons.py --regenerate-baseline  (один раз) записать текущее состояние как базовую линию
"""
import hashlib, json, os, re, sys
import xml.etree.ElementTree as ET
from collections import defaultdict

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
BASELINE = os.path.join(ROOT, 'tool/icon_dupes_baseline.json')
OVERRIDES = os.path.join(ROOT, 'tool/icon_overrides.json')
MANIFEST = os.path.join(ROOT, 'tool/icons_manifest.json')
SVG_DIR = os.path.join(ROOT, 'assets/icons')
PNG_DIR = os.path.join(ROOT, 'assets/icons/s')
IOS_DIR = os.path.join(ROOT, 'ios/NutriMate/Resources/Assets.xcassets/FoodIcons')
MAX_SVG = 8 * 1024


def norm(e):
    return ''.join(c for c in e if ord(c) != 0xfe0f)


def load_db():
    src = open(os.path.join(ROOT, 'lib/main.dart'), encoding='utf-8').read()
    raw = re.search(r"const _raw = '''\n(.*?)\n''';", src, re.S).group(1)
    foods = []
    for line in raw.strip().split('\n'):
        cat, rest = line.split('|', 1)
        for e in rest.split(';'):
            p = e.strip().split(',')
            sp = p[0].index(' ')
            foods.append({'emoji': p[0][:sp], 'name': p[0][sp + 1:], 'category': cat})
    block = src[src.index('final recipes = <Recipe>['):]
    block = block[:block.index('\n];\n')]
    recipes = re.findall(r"\n  Recipe\(\s*'((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)'", block)
    ce = src[src.index('const catEmoji'):src.index('};', src.index('const catEmoji'))]
    cats = re.findall(r"'([^']+)': '([^']+)'", ce)
    return foods, recipes, cats


def overrides():
    return json.load(open(OVERRIDES, encoding='utf-8'))


def icon_file(slug):
    """Путь к исходнику иконки: SVG (новый формат) или PNG из assets/icons/p (старые 15)."""
    s = os.path.join(SVG_DIR, slug + '.svg')
    if os.path.exists(s): return s
    p = os.path.join(SVG_DIR, 'p', slug + '.png')
    return p if os.path.exists(p) else None


def effective(foods, ov):
    return {f['name']: ('icon:' + ov[f['name']]) if f['name'] in ov else ('emoji:' + norm(f['emoji'])) for f in foods}


def groups(mapping):
    g = defaultdict(list)
    for name, icon in mapping.items(): g[icon].append(name)
    return g


def sha(path):
    return hashlib.sha1(open(path, 'rb').read()).hexdigest()


def check_svgs(ov, errors):
    svgs = sorted(f[:-4] for f in os.listdir(SVG_DIR) if f.endswith('.svg'))
    used = set(ov.values())
    by_hash = {}
    manifest = json.load(open(MANIFEST)) if os.path.exists(MANIFEST) else {}
    for slug in sorted(used):
        if not icon_file(slug): errors.append(f'icon "{slug}": no assets/icons/{slug}.svg (or p/{slug}.png)')
    for slug in svgs:
        path = os.path.join(SVG_DIR, slug + '.svg')
        data = open(path, 'rb').read()
        if not re.fullmatch(r'[a-z0-9_]+', slug): errors.append(f'{slug}.svg: slug must be [a-z0-9_]')
        if len(data) > MAX_SVG: errors.append(f'{slug}.svg: {len(data)} bytes > {MAX_SVG}')
        try:
            root = ET.fromstring(data)
            if not root.tag.endswith('svg') or root.get('viewBox') != '0 0 128 128':
                errors.append(f'{slug}.svg: root must be <svg viewBox="0 0 128 128">')
        except ET.ParseError as e:
            errors.append(f'{slug}.svg: invalid XML ({e})')
        h = hashlib.sha1(data).hexdigest()
        if h in by_hash: errors.append(f'{slug}.svg is byte-identical to {by_hash[h]}.svg')
        by_hash[h] = slug
        if slug not in used: print(f'warning: {slug}.svg is not used by any product')
        for out in (os.path.join(PNG_DIR, slug + '.png'), os.path.join(IOS_DIR, f'fi_{slug}.imageset', f'fi_{slug}.png')):
            if not os.path.exists(out): errors.append(f'{slug}: missing {os.path.relpath(out, ROOT)} (run tool/build_svg_icons.py)')
        if manifest.get(slug) != h: errors.append(f'{slug}: PNG is older than the SVG (run tool/build_svg_icons.py)')
    for slug in used:
        if icon_file(slug) and icon_file(slug).endswith('.png') and not os.path.exists(os.path.join(IOS_DIR, f'fi_{slug}.imageset')):
            errors.append(f'{slug}: missing iOS imageset (run tool/build_svg_icons.py)')
    return len(svgs)


def run(argv=()):
    argv = list(argv)
    foods, recipes, cats = load_db()
    ov = overrides()
    errors = []
    names = {f['name'] for f in foods}
    for n in ov:
        if n not in names: errors.append(f'icon_overrides.json: unknown product "{n}"')
    eff = effective(foods, ov)
    g = groups(eff)
    shared = {n for v in g.values() if len(v) > 1 for n in v}
    uniq = len(foods) - len(shared)

    if '--regenerate-baseline' in argv:
        json.dump(sorted(shared), open(BASELINE, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
        print(f'baseline regenerated: {len(shared)} products')
    base = set(json.load(open(BASELINE, encoding='utf-8'))) if os.path.exists(BASELINE) else set()
    if '--update-baseline' in argv:
        nb = sorted(n for n in base if n in shared)  # только удаляем
        json.dump(nb, open(BASELINE, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
        print(f'baseline: {len(base)} → {len(nb)}')
        base = set(nb)

    for icon, ns in sorted(g.items(), key=lambda kv: -len(kv[1])):
        new = [n for n in ns if n not in base]
        if len(ns) > 1 and new:
            errors.append(f'shared icon {icon[6:] if icon.startswith("emoji:") else icon}: new product(s) {new} '
                          f'share it with {[n for n in ns if n not in new][:5]} — draw an own icon (assets/icons/<slug>.svg)')
    nsvg = check_svgs(ov, errors)

    verbose = '-v' in argv
    print('Products sharing an icon (top groups):')
    for icon, ns in sorted(g.items(), key=lambda kv: -len(kv[1]))[: None if verbose else 12]:
        if len(ns) < 2: break
        label = icon[6:] if icon.startswith('emoji:') else icon
        print(f'  {label} ×{len(ns)}: ' + ', '.join(ns[: None if verbose else 8]) + ('' if verbose or len(ns) <= 8 else ', …'))
    rg = groups({n: norm(e) for n, e in recipes})
    ruq = sum(1 for v in rg.values() if len(v) == 1)
    cg = groups({c: norm(e) for c, e in cats})
    cuq = sum(1 for v in cg.values() if len(v) == 1)
    print(f'products: unique {uniq} of {len(foods)} ({len(set(eff.values()))} distinct icons, {len(ov)} own, {nsvg} SVG)')
    print(f'recipes: unique {ruq} of {len(recipes)} ({len(rg)} distinct emoji); worst: ' +
          ', '.join(f'{e}×{len(v)}' for e, v in sorted(rg.items(), key=lambda kv: -len(kv[1]))[:6]))
    print(f'categories: unique {cuq} of {len(cats)}' + ('' if cuq == len(cats) else '; shared: ' +
          ', '.join(f'{e} {v}' for e, v in cg.items() if len(v) > 1)))
    print(f'baseline: {len(base)} products still allowed to share an icon')
    if errors:
        print('ICON ERRORS:\n  ' + '\n  '.join(errors))
        return 1
    print('icons OK')
    return 0


if __name__ == '__main__':
    sys.exit(run(sys.argv[1:]))
