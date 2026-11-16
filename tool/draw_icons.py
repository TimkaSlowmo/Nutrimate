#!/usr/bin/env python3
"""Исходники собственных иконок продуктов: каждая функция рисует ОДИН продукт и пишет assets/icons/<slug>.svg,
а tool/icon_overrides.json получает «название продукта → slug». Потом: python3 tool/build_svg_icons.py.
Правило: одна иконка = один продукт; варианты одного продукта отличаются видимой деталью (цвет, этикетка).
Запуск: python3 tool/draw_icons.py [slug …]   (без аргументов — все)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from iconlib import *  # noqa: F401,F403

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
from icons_a import *  # noqa: E402,F401,F403  — упаковки, соусы, порошки, напитки
from icons_b import *  # noqa: E402,F401,F403  — фрукты, ягоды, овощи, зелень
from icons_c import *  # noqa: E402,F401,F403  — рыба, сыр
from icons_d import *  # noqa: E402,F401,F403  — молочное
from icons_e import *  # noqa: E402,F401,F403  — зелень, специи, перцы, листовые овощи
from icons_f import *  # noqa: E402,F401,F403  — фрукты и ягоды
from icons_g import *  # noqa: E402,F401,F403  — новые продукты


def main(only=()):
    ov_path = os.path.join(ROOT, 'tool/icon_overrides.json')
    ov = json.load(open(ov_path, encoding='utf-8'))
    slugs = set()
    for slug, products, fn in REG:
        assert slug not in slugs, 'duplicate slug ' + slug
        slugs.add(slug)
        for p in products:
            assert ov.get(p, slug) == slug or p not in ov or only, f'{p} already mapped to {ov[p]}'
            ov[p] = slug
        if only and slug not in only: continue
        I = Icon()
        fn(I)
        open(os.path.join(ROOT, 'assets/icons', slug + '.svg'), 'w').write(I.svg())
    json.dump(dict(sorted(ov.items())), open(ov_path, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    print(f'{len(REG)} icons')


if __name__ == '__main__':
    main(set(sys.argv[1:]))
