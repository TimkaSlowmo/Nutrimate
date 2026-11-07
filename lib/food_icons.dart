// СГЕНЕРИРОВАНО tool/build_icons.py — не редактировать вручную.
// 3D-иконки: Microsoft Fluent Emoji (MIT, см. assets/icons/LICENSE-fluentui-emoji.txt)
// + собственные иконки NutriMate (assets/icons/p).

import 'package:flutter/material.dart';

import 'main.dart' show FoodItem;

const _emojiIcons = <String>{'1f30d', '1f30f', '1f32d', '1f32e', '1f32f', '1f330', '1f331', '1f334', '1f336', '1f339', '1f33b', '1f33d', '1f33e', '1f33f', '1f341', '1f343', '1f344', '1f345', '1f346', '1f347', '1f348', '1f349', '1f34a', '1f34b', '1f34c', '1f34d', '1f34e', '1f34f', '1f350', '1f351', '1f352', '1f353', '1f354', '1f355', '1f356', '1f357', '1f358', '1f359', '1f35a', '1f35b', '1f35c', '1f35d', '1f35e', '1f35f', '1f360', '1f361', '1f363', '1f364', '1f365', '1f366', '1f367', '1f368', '1f369', '1f36a', '1f36b', '1f36c', '1f36d', '1f36e', '1f36f', '1f370', '1f371', '1f372', '1f373', '1f375', '1f376', '1f377', '1f378', '1f37a', '1f37c', '1f37d', '1f37f', '1f383', '1f38b', '1f3c6', '1f407', '1f409', '1f419', '1f41a', '1f41f', '1f426', '1f43b', '1f468-200d-1f373', '1f4a7', '1f4aa', '1f534', '1f6d2', '1f7e3', '1f7eb', '1f91d', '1f942', '1f943', '1f944', '1f950', '1f951', '1f952', '1f953', '1f954', '1f955', '1f956', '1f957', '1f958', '1f959', '1f95a', '1f95b', '1f95c', '1f95d', '1f95e', '1f95f', '1f962', '1f963', '1f964', '1f965', '1f966', '1f967', '1f968', '1f969', '1f96a', '1f96b', '1f96c', '1f96d', '1f96e', '1f96f', '1f980', '1f983', '1f986', '1f990', '1f991', '1f99e', '1f9aa', '1f9b8', '1f9c0', '1f9c1', '1f9c2', '1f9c3', '1f9c4', '1f9c5', '1f9c6', '1f9c7', '1f9c8', '1f9ca', '1f9cb', '1fabf', '1fad0', '1fad1', '1fad2', '1fad3', '1fad8', '1fad9', '1fada', '1fadb', '2615', '2696', '26a1', '26aa', '26ab', '2728', '2744', '2b1c', '2b50'};

const _foodIcons = <String, String>{
  'Baursaks': 'baursak',
  'Beetroot': 'beetroot',
  'Black Caviar': 'black_caviar',
  'Canned Beets': 'beetroot',
  'Daikon': 'daikon',
  'Irimshik': 'irimshik',
  'Kazy': 'kazy',
  'Kurt': 'kurt',
  'Pickled Beets': 'beetroot',
  'Pomegranate': 'pomegranate',
  'Radish': 'radish',
  'Silken Tofu': 'silken_tofu',
  'Smoked Tofu': 'smoked_tofu',
  'Star Fruit': 'star_fruit',
  'Tempeh': 'tempeh',
  'Tofu': 'tofu',
  'Turnip': 'turnip',
};

String _key(String emoji) => emoji.runes.where((r) => r != 0xfe0f).map((r) => r.toRadixString(16)).join('-');

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
