#!/usr/bin/env python3
"""Единая база: парсит _raw и Recipe(...) из lib/main.dart, проверяет и пишет ios/NutriMate/Resources/foods.json.
Запуск: python3 tool/export_data.py [--check]"""
import json, re, sys, pathlib
root = pathlib.Path(__file__).resolve().parent.parent
src = (root / 'lib/main.dart').read_text(encoding='utf-8')
raw = re.search(r"const _raw = '''\n(.*?)\n''';", src, re.S).group(1)
foods, errors = [], []
for line in raw.strip().split('\n'):
    cat, rest = line.split('|', 1)
    for e in rest.split(';'):
        p = e.strip().split(',')
        sp = p[0].index(' ')
        foods.append({'emoji': p[0][:sp], 'name': p[0][sp+1:], 'kcal': int(p[1]), 'category': cat, 'shelf': int(p[2])})
names = [f['name'] for f in foods]
seen = set()
for n in names:
    if n.lower() in seen: errors.append(f'duplicate product: {n}')
    seen.add(n.lower())
byname = {f['name']: f for f in foods}
block = src[src.index('final recipes = <Recipe>['):]
block = block[:block.index('\n];\n')]
def dstr(s):  # Dart single-quoted string literal -> python
    return s.replace("\\'", "'").replace('\\$', '$')
STR = r"'((?:[^'\\]|\\.)*)'"
recipes = []
for chunk in re.split(r'\n  Recipe\(', block)[1:]:
    m = re.match(r"\s*" + STR + r",\s*" + STR + r",\s*" + STR + r",\s*(\d+),\s*\[(.*?)\],\s*\[(.*?)\],\s*" + STR + r",?\s*(zeroWaste: true)?", chunk, re.S)
    if not m:
        errors.append('cannot parse recipe: ' + chunk[:60]); continue
    name, emoji, time, serv, ings, steps, staples, zw = m.groups()
    ing = [{'name': dstr(a), 'g': int(b)} for a, b in re.findall(r"Ing\(" + STR + r",\s*(\d+)\)", ings)]
    for i in ing:
        if i['name'] not in byname: errors.append(f'recipe "{dstr(name)}": unknown ingredient "{i["name"]}"')
    recipes.append({'name': dstr(name), 'emoji': dstr(emoji), 'time': dstr(time), 'servings': int(serv),
                    'ingredients': ing, 'steps': [dstr(x) for x in re.findall(STR, steps)],
                    'staples': dstr(staples), 'zeroWaste': bool(zw)})
tb = src[src.index('const storageTips = {'):]
tb = tb[:tb.index('\n};')]
tips = {dstr(a): dstr(b) for a, b in re.findall(STR + r":\s*" + STR, tb)}
rn = [r['name'].lower() for r in recipes]
for n in set(rn):
    if rn.count(n) > 1: errors.append('duplicate recipe: ' + n)
expected = src.count('\n  Recipe(\n')
if expected != len(recipes): errors.append(f'parsed {len(recipes)} recipes, expected {expected}')
if errors:
    print('\n'.join(errors)); sys.exit(1)
print(f'OK: {len(foods)} products, {len(recipes)} recipes ({sum(r["zeroWaste"] for r in recipes)} zero-waste), {len(set(f["category"] for f in foods))} categories, {len(tips)} storage tips')
if '--check' not in sys.argv:
    out = root / 'ios/NutriMate/Resources/foods.json'
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({'foods': foods, 'recipes': recipes, 'tips': tips}, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    print('wrote', out.relative_to(root))
