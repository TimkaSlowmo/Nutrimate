// СГЕНЕРИРОВАНО tool/build_icons.py — не редактировать вручную.
// 3D-иконки: Microsoft Fluent Emoji (MIT, см. assets/icons/LICENSE-fluentui-emoji.txt)
// + собственные иконки NutriMate: assets/icons/s (из SVG assets/icons/*.svg) и assets/icons/p.

import 'package:flutter/material.dart';

import 'main.dart' show FoodItem;

const _emojiIcons = <String>{'1f30a', '1f30d', '1f30f', '1f32d', '1f32e', '1f32f', '1f330', '1f331', '1f334', '1f335', '1f336', '1f338', '1f339', '1f33a', '1f33b', '1f33c', '1f33d', '1f33e', '1f33f', '1f341', '1f343', '1f344', '1f345', '1f346', '1f347', '1f348', '1f349', '1f34a', '1f34b', '1f34c', '1f34d', '1f34e', '1f34f', '1f350', '1f351', '1f352', '1f353', '1f354', '1f355', '1f356', '1f357', '1f358', '1f359', '1f35a', '1f35b', '1f35c', '1f35d', '1f35e', '1f35f', '1f360', '1f361', '1f362', '1f363', '1f364', '1f365', '1f366', '1f367', '1f368', '1f369', '1f36a', '1f36b', '1f36c', '1f36d', '1f36e', '1f36f', '1f370', '1f371', '1f372', '1f373', '1f375', '1f376', '1f377', '1f378', '1f379', '1f37a', '1f37c', '1f37d', '1f37f', '1f383', '1f38b', '1f3c6', '1f407', '1f409', '1f414', '1f419', '1f41a', '1f41f', '1f426', '1f42a', '1f43b', '1f468-200d-1f373', '1f48d', '1f4a7', '1f4aa', '1f534', '1f6d2', '1f7e0', '1f7e1', '1f7e2', '1f7e3', '1f7e4', '1f7eb', '1f91d', '1f920', '1f942', '1f943', '1f944', '1f950', '1f951', '1f952', '1f953', '1f954', '1f955', '1f956', '1f957', '1f958', '1f959', '1f95a', '1f95b', '1f95c', '1f95d', '1f95e', '1f95f', '1f962', '1f963', '1f964', '1f965', '1f966', '1f967', '1f968', '1f969', '1f96a', '1f96b', '1f96c', '1f96d', '1f96e', '1f96f', '1f980', '1f983', '1f986', '1f990', '1f991', '1f99e', '1f9aa', '1f9ac', '1f9b4', '1f9b8', '1f9c0', '1f9c1', '1f9c2', '1f9c3', '1f9c4', '1f9c5', '1f9c6', '1f9c7', '1f9c8', '1f9c9', '1f9ca', '1f9cb', '1f9f5', '1fab7', '1fabf', '1fad0', '1fad1', '1fad2', '1fad3', '1fad6', '1fad8', '1fad9', '1fada', '1fadb', '2615', '2696', '26a1', '26aa', '26ab', '2728', '2744', '2b1c', '2b50'};

const _foodIcons = <String, String>{
  'Agar-Agar': 's/agar_agar',
  'Almond Milk': 's/almond_milk',
  'Amla': 's/amla',
  'Anchovies': 's/anchovies',
  'Apricot': 's/apricot',
  'Artichoke': 's/artichoke',
  'Arugula': 's/arugula',
  'BBQ Sauce': 's/bbq_sauce',
  'Baked Milk': 's/baked_milk',
  'Baking Powder': 's/baking_powder',
  'Baking Soda': 's/baking_soda',
  'Basil': 's/basil',
  'Baursaks': 'p/baursak',
  'Bay Leaf': 's/bay_leaf',
  'Beetroot': 'p/beetroot',
  'Bird\'s Eye Chili': 's/birds_eye_chili',
  'Black Caviar': 'p/black_caviar',
  'Black Currant': 's/black_currant',
  'Black Pepper': 's/black_pepper',
  'Black Sapote': 's/black_sapote',
  'Black Tea': 's/black_tea',
  'Blackberry': 's/blackberry',
  'Blood Orange': 's/blood_orange',
  'Blue Cheese': 's/blue_cheese',
  'Bok Choy': 's/bok_choy',
  'Brie': 's/brie',
  'Brussels Sprouts': 's/brussels_sprouts',
  'Burrata': 's/burrata',
  'Butter': 's/butter',
  'Buttermilk': 's/buttermilk',
  'Cabbage': 's/cabbage',
  'Camembert': 's/camembert',
  'Canistel': 's/canistel',
  'Canned Beets': 'p/beetroot',
  'Canned Coconut Milk': 's/canned_coconut_milk',
  'Canned Tuna': 's/canned_tuna',
  'Cardamom': 's/cardamom',
  'Carp': 's/carp',
  'Catfish': 's/catfish',
  'Celery': 's/celery',
  'Cheddar Cheese': 's/cheddar',
  'Cherimoya': 's/cherimoya',
  'Chili Pepper': 's/chili_pepper',
  'Chives': 's/chives',
  'Chocolate Hazelnut Spread': 's/choc_hazelnut_spread',
  'Chocolate Milk': 's/chocolate_milk',
  'Chocolate Spread': 's/chocolate_spread',
  'Cilantro': 's/cilantro',
  'Cinnamon': 's/cinnamon',
  'Clementine': 's/clementine',
  'Cloves': 's/cloves',
  'Cocoa Powder': 's/cocoa_powder',
  'Coconut Milk': 's/coconut_milk',
  'Cod': 's/cod',
  'Condensed Milk': 's/condensed_milk',
  'Coriander Seeds': 's/coriander_seeds',
  'Cottage Cheese': 's/cottage_cheese',
  'Cranberry': 's/cranberry',
  'Cream Cheese': 's/cream_cheese',
  'Cream Soup Base': 's/cream_soup_base',
  'Creme Fraiche': 's/creme_fraiche',
  'Cumin': 's/cumin',
  'Daikon': 'p/daikon',
  'Dates': 's/dates',
  'Dijon Mustard': 's/dijon_mustard',
  'Dill': 's/dill',
  'Dragon Fruit': 's/dragon_fruit',
  'Dried Fish': 's/dried_fish',
  'Drinking Yogurt': 's/drinking_yogurt',
  'Durian': 's/durian',
  'Eel': 's/eel',
  'Emmental': 's/emmental',
  'Evaporated Milk': 's/evaporated_milk',
  'Feijoa': 's/feijoa',
  'Fennel': 's/fennel',
  'Feta': 's/feta',
  'Fig': 's/fig',
  'Fish Sauce': 's/fish_sauce',
  'Fresh Sardines': 's/fresh_sardines',
  'Fruit Yogurt': 's/fruit_yogurt',
  'Garlic Sauce': 's/garlic_sauce',
  'Gelatin': 's/gelatin',
  'Goat Cheese': 's/goat_cheese',
  'Goat Milk': 's/goat_milk',
  'Gochujang': 's/gochujang',
  'Goji Berries': 's/goji',
  'Golden Raspberries': 's/golden_raspberries',
  'Gooseberry': 's/gooseberry',
  'Gorgonzola': 's/gorgonzola',
  'Gouda': 's/gouda',
  'Grainy Mustard': 's/grainy_mustard',
  'Granadilla': 's/granadilla',
  'Grapefruit': 's/grapefruit',
  'Greek Yogurt': 's/greek_yogurt',
  'Green Tea': 's/green_tea',
  'Guava': 's/guava',
  'Habanero': 's/habanero',
  'Halloumi': 's/halloumi',
  'Harissa': 's/harissa',
  'Heavy Cream': 's/heavy_cream',
  'Herring': 's/herring',
  'Hoisin Sauce': 's/hoisin_sauce',
  'Horseradish': 's/horseradish',
  'Horseradish Sauce': 's/horseradish_sauce',
  'Hot Sauce': 's/hot_sauce',
  'Irimshik': 'p/irimshik',
  'Jackfruit': 's/jackfruit',
  'Jalapeno': 's/jalapeno',
  'Jujube': 's/jujube',
  'Kale': 's/kale',
  'Kazy': 'p/kazy',
  'Kefir': 's/kefir',
  'Ketchup': 's/ketchup',
  'Kiwano': 's/kiwano',
  'Kohlrabi': 's/kohlrabi',
  'Kumquat': 's/kumquat',
  'Kurt': 'p/kurt',
  'Lactose-Free Milk': 's/lactose_free_milk',
  'Leek': 's/leek',
  'Lemongrass': 's/lemongrass',
  'Lettuce': 's/lettuce',
  'Light Cream': 's/light_cream',
  'Lime': 's/lime',
  'Lingonberry': 's/lingonberry',
  'Liver Pate': 's/liver_pate',
  'Longan': 's/longan',
  'Lychee': 's/lychee',
  'Mackerel': 's/mackerel',
  'Mangosteen': 's/mangosteen',
  'Mascarpone': 's/mascarpone',
  'Mayonnaise': 's/mayonnaise',
  'Medjool Dates': 's/medjool_dates',
  'Milk': 's/milk',
  'Mint': 's/mint',
  'Miso Paste': 's/miso_paste',
  'Mozzarella': 's/mozzarella',
  'Mulberry': 's/mulberry',
  'Mustard': 's/mustard',
  'Mustard Seeds': 's/mustard_seeds',
  'Nutmeg': 's/nutmeg',
  'Oat Milk': 's/oat_milk',
  'Oyster Sauce': 's/oyster_sauce',
  'Paneer': 's/paneer',
  'Papaya': 's/papaya',
  'Paprika': 's/paprika',
  'Parmesan': 's/parmesan',
  'Parsley': 's/parsley',
  'Passion Fruit': 's/passion_fruit',
  'Persimmon': 's/persimmon',
  'Pickled Beets': 'p/beetroot',
  'Pike': 's/pike',
  'Plum': 's/plum',
  'Poblano Pepper': 's/poblano',
  'Pollock': 's/pollock',
  'Pomegranate': 'p/pomegranate',
  'Pomelo': 's/pomelo',
  'Prickly Pear': 's/prickly_pear',
  'Processed Cheese': 's/processed_cheese',
  'Prunes': 's/prunes',
  'Quince': 's/quince',
  'Radish': 'p/radish',
  'Raisins': 's/raisins',
  'Rambutan': 's/rambutan',
  'Raspberry': 's/raspberry',
  'Red Cabbage': 's/red_cabbage',
  'Red Currant': 's/red_currant',
  'Rhubarb': 's/rhubarb',
  'Ricotta': 's/ricotta',
  'Rose Hips': 's/rose_hips',
  'Rosehip': 's/rosehip',
  'Rosemary': 's/rosemary',
  'Ryazhenka': 's/ryazhenka',
  'Saffron': 's/saffron',
  'Sage': 's/sage',
  'Salak': 's/salak',
  'Salmon': 's/salmon',
  'Scotch Bonnet': 's/scotch_bonnet',
  'Sea Bass': 's/sea_bass',
  'Sea Buckthorn': 's/sea_buckthorn',
  'Silken Tofu': 'p/silken_tofu',
  'Skim Milk': 's/skim_milk',
  'Skyr': 's/skyr',
  'Smoked Salmon': 's/smoked_salmon',
  'Smoked Tofu': 'p/smoked_tofu',
  'Sorrel': 's/sorrel',
  'Sour Cream': 's/sour_cream',
  'Soursop': 's/soursop',
  'Soy Milk': 's/soy_milk',
  'Soy Sauce': 's/soy_sauce',
  'Spicy Ketchup': 's/spicy_ketchup',
  'Spinach': 's/spinach',
  'Sriracha': 's/sriracha',
  'Star Anise': 's/star_anise',
  'Star Fruit': 'p/star_fruit',
  'String Cheese': 's/string_cheese',
  'Sultanas': 's/sultanas',
  'Swiss Cheese': 's/swiss_cheese',
  'Tabasco': 's/tabasco',
  'Tangerine': 's/tangerine',
  'Tarragon': 's/tarragon',
  'Tartar Sauce': 's/tartar_sauce',
  'Tempeh': 'p/tempeh',
  'Teriyaki Sauce': 's/teriyaki',
  'Thyme': 's/thyme',
  'Tilapia': 's/tilapia',
  'Tofu': 'p/tofu',
  'Tomato Paste': 's/tomato_paste',
  'Trout': 's/trout',
  'Tuna Steak': 's/tuna_steak',
  'Turmeric': 's/turmeric',
  'Turnip': 'p/turnip',
  'Vanilla Extract': 's/vanilla_extract',
  'Vanilla Sugar': 's/vanilla_sugar',
  'Vanilla Yogurt': 's/vanilla_yogurt',
  'Wasabi': 's/wasabi',
  'Whipped Cream': 's/whipped_cream',
  'White Currant': 's/white_currant',
  'Whole Milk': 's/whole_milk',
  'Worcestershire Sauce': 's/worcestershire',
  'Yeast': 's/yeast',
  'Yellow Dragon Fruit': 's/yellow_dragon_fruit',
  'Yogurt': 's/yogurt',
};

String _key(String emoji) => emoji.runes.where((r) => r != 0xfe0f).map((r) => r.toRadixString(16)).join('-');

/// Путь к картинке-иконке для эмодзи (и, если известно, для конкретного продукта).
String? iconPath(String emoji, [String? food]) {
  final own = food == null ? null : _foodIcons[food];
  if (own != null) return 'assets/icons/$own.png';
  final k = _key(emoji);
  return _emojiIcons.contains(k) ? 'assets/icons/e/$k.png' : null;
}

/// Заранее загружает все иконки в кэш, чтобы списки прокручивались без «подгрузки».
void precacheFoodIcons(BuildContext context) {
  for (final k in _emojiIcons) {
    precacheImage(AssetImage('assets/icons/e/$k.png'), context);
  }
  for (final p in _foodIcons.values.toSet()) {
    precacheImage(AssetImage('assets/icons/$p.png'), context);
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
