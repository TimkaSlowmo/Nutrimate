"""Собирает иконки: Fluent Emoji 3D (MIT) для всех эмодзи приложения + свои иконки из assets/icons/p.
Генерирует lib/food_icons.dart и проверяет базу (дубли, ингредиенты рецептов, иконки).
Использование: python3 tool/build_icons.py [путь к клону fluentui-emoji]"""
import re, json, glob, os, sys
from collections import Counter
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
src = open(os.path.join(ROOT, 'lib/main.dart')).read()

def key(x): return '-'.join('%x' % ord(c) for c in x if ord(c) != 0xfe0f)

raw = src[src.index("const _raw = '''") + 16:src.index("''';", src.index('const _raw'))]
foods = []
for line in raw.strip().split('\n'):
    cat, rest = line.split('|', 1)
    for e in rest.split(';'):
        p = e.strip().split(','); em, name = p[0].split(' ', 1)
        foods.append((cat, em, name))
glyphs = {f[1] for f in foods}
cat = src[src.index('const catEmoji'):src.index('};', src.index('const catEmoji'))]
glyphs |= set(re.findall(r": '([^']+)'", cat))
glyphs |= set(re.findall(r"Recipe\(\s*'[^']*',\s*'([^']+)'", src))
glyphs |= set(re.findall(r"Medal\('[^']*', '([^']+)'", src))
glyphs |= set(re.findall(r"emoji: '([^']+)'", src))
glyphs |= {'🛒', '🍽️'}

edir = os.path.join(ROOT, 'assets/icons/e')
if len(sys.argv) > 1:
    from PIL import Image
    fl = sys.argv[1]; meta = {}
    for f in glob.glob(fl + '/assets/*/metadata.json'):
        meta[key(json.load(open(f))['glyph'])] = os.path.dirname(f)
    for g in glyphs:
        k = key(g); out = f'{edir}/{k}.png'
        if os.path.exists(out) or k not in meta: continue
        d = meta[k]; png = (glob.glob(glob.escape(d) + '/3D/*.png') + glob.glob(glob.escape(d) + '/Default/3D/*.png'))
        if not png: continue
        im = Image.open(png[0]).convert('RGBA').resize((128, 128), Image.LANCZOS)
        im.quantize(colors=256, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.NONE).save(out, optimize=True)

have_e = sorted(os.path.basename(f)[:-4] for f in glob.glob(edir + '/*.png'))
have_p = {os.path.basename(f)[:-4] for f in glob.glob(os.path.join(ROOT, 'assets/icons/p/*.png'))}
overrides = json.load(open(os.path.join(ROOT, 'tool/icon_overrides.json')))
names = {f[2] for f in foods}
for n, slug in overrides.items():
    assert n in names, 'override for unknown food ' + n
    assert slug in have_p, 'missing custom icon ' + slug

# Проверки базы
dup = [n for n, c in Counter(f[2].lower() for f in foods).items() if c > 1]
assert not dup, 'duplicates: %s' % dup
ings = re.findall(r"Ing\('([^']+)'", src)
bad = sorted({i for i in ings if i not in names})
assert not bad, 'unknown ingredients: %s' % bad
noicon = [f[2] for f in foods if f[2] not in overrides and key(f[1]) not in have_e]
assert not noicon, 'no icon: %s' % noicon
# Уникальность: продукт уникален, если у него своя иконка или его эмодзи больше ни у кого нет
emc = Counter(f[1] for f in foods if f[2] not in overrides)
uniq = sum(1 for f in foods if f[2] in overrides or emc[f[1]] == 1)

out = ['// СГЕНЕРИРОВАНО tool/build_icons.py — не редактировать вручную.',
       '// 3D-иконки: Microsoft Fluent Emoji (MIT, см. assets/icons/LICENSE-fluentui-emoji.txt)',
       '// + собственные иконки NutriMate (assets/icons/p).', '',
       "import 'package:flutter/material.dart';", '', "import 'main.dart' show FoodItem;", '',
       'const _emojiIcons = <String>{' + ', '.join("'%s'" % k for k in have_e) + '};', '',
       'const _foodIcons = <String, String>{']
out += ["  '%s': '%s'," % (n.replace("'", "\\'"), s) for n, s in sorted(overrides.items())]
out += ['};', '', '''String _key(String emoji) => emoji.runes.where((r) => r != 0xfe0f).map((r) => r.toRadixString(16)).join('-');

/// Путь к картинке-иконке для эмодзи (и, если известно, для конкретного продукта).
String? iconPath(String emoji, [String? food]) {
  final own = food == null ? null : _foodIcons[food];
  if (own != null) return 'assets/icons/p/$own.png';
  final k = _key(emoji);
  return _emojiIcons.contains(k) ? 'assets/icons/e/$k.png' : null;
}

/// Заранее загружает все иконки в кэш, чтобы списки прокручивались без «подгрузки».
void precacheFoodIcons(BuildContext context) {
  for (final k in _emojiIcons) {
    precacheImage(AssetImage('assets/icons/e/$k.png'), context);
  }
  for (final p in _foodIcons.values.toSet()) {
    precacheImage(AssetImage('assets/icons/p/$p.png'), context);
  }
}

/// Глянцевая 3D-иконка вместо шрифтового эмодзи; если картинки нет — обычный эмодзи.
class Emo extends StatelessWidget {
  final String emoji;
  final String? food;
  final double size;
  const Emo(this.emoji, {super.key, this.food, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final path = iconPath(emoji, food);
    final fallback = SizedBox(
      width: size,
      height: size,
      child: FittedBox(child: Text(emoji, style: TextStyle(fontSize: size * 0.8))),
    );
    if (path == null) return fallback;
    return Image.asset(
      path,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// Иконка продукта (учитывает собственные иконки для продуктов без подходящего эмодзи).
class FoodIcon extends StatelessWidget {
  final FoodItem food;
  final double size;
  const FoodIcon(this.food, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) => Emo(food.emoji, food: food.name, size: size);
}
''']
open(os.path.join(ROOT, 'lib/food_icons.dart'), 'w').write('\n'.join(out))
nrec = src[src.index('final recipes = <Recipe>['):].count('  Recipe(' + chr(10))
print(f'foods={len(foods)} recipes={nrec} emoji_icons={len(have_e)} custom={len(have_p)} unique={uniq}/{len(foods)}')
