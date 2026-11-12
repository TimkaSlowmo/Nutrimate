import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' show ImageFilter, PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'food_icons.dart';
import 'l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appState.load(); // данные сохраняются между запусками (localStorage в браузере)
  runApp(const CalorieApp());
}

// Номер версии: ночной агент увеличивает его на 1 при каждом обновлении.
const appVersion = 24;

const burgundy = Color(0xFF6A041C);
const cream = Color(0xFFF5F1E5);
const sand = Color(0xFFEAE2CF);

// «Часы» приложения: кнопка "+1 day" в профиле сдвигает время, чтобы показать порчу продуктов.
int dayShift = 0;
DateTime now() => DateTime.now().add(Duration(days: dayShift));
// Номер дня (дни с 1970 г.) — так дневник калорий не путается после перезапуска.
int dayNum(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
int todayNum() => dayNum(now());

// ───────────────────────── МОДЕЛИ ─────────────────────────

class FoodItem {
  final String emoji, name, category;
  final int kcal, shelf; // kcal на 100 г, срок хранения в днях
  const FoodItem(this.emoji, this.name, this.kcal, this.category, this.shelf);
}

enum Storage { fridge, freezer, pantry }

const _storageLabel = {Storage.fridge: '🧊 Fridge', Storage.freezer: '❄️ Freezer', Storage.pantry: '🫙 Pantry'};
Map<Storage, String> get storageLabel => {for (final e in _storageLabel.entries) e.key: tr(e.value)};
const _shelfStable = {'Grains', 'Pantry', 'Spices', 'Canned', 'Nuts & Legumes', 'Snacks', 'Sweets', 'Drinks', 'World Foods', 'Plant-Based', 'Baby Food'};
const _freezable = {'Meat', 'Seafood', 'Bakery', 'Fruits', 'Berries', 'Vegetables', 'Ready Meals', 'Dairy', 'Plant-Based'};

Storage defaultStorage(FoodItem f) => f.category == 'Frozen'
    ? Storage.freezer
    : _shelfStable.contains(f.category) && f.shelf > 14
    ? Storage.pantry
    : Storage.fridge;
bool canFreeze(FoodItem f) => _freezable.contains(f.category) && !{'Eggs', 'Lettuce', 'Cucumber', 'Salad Mix', 'Yogurt', 'Sour Cream', 'Mayonnaise'}.contains(f.name);

class PantryItem {
  final int id;
  final FoodItem food;
  final DateTime added;
  DateTime expiry;
  Storage storage;
  PantryItem(this.id, this.food, this.added, this.expiry, this.storage);

  int get daysLeft {
    final n = now();
    return DateTime.utc(expiry.year, expiry.month, expiry.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  }

  int get shelf => max(1, DateTime.utc(expiry.year, expiry.month, expiry.day).difference(DateTime.utc(added.year, added.month, added.day)).inDays);
  double get fresh => (daysLeft / shelf).clamp(0.0, 1.0).toDouble();
  String get status => daysLeft < 0
      ? tr('Expired {0} ago', [trp(-daysLeft, 'day|days')])
      : daysLeft == 0
      ? tr('Use today!')
      : daysLeft == 1
      ? tr('Expires tomorrow')
      : tr('{0} left', [trp(daysLeft, 'day|days')]);
  Color get color => daysLeft < 0
      ? Colors.red.shade800
      : daysLeft <= 2
      ? Colors.orange.shade800
      : Colors.green.shade800;
}

// Почему еда оказалась в мусоре — из этого строится аналитика и советы.
enum WasteReason { expired, forgot, tooMuch, spoiled, disliked }

const reasonInfo = {
  WasteReason.expired: ('⏰', 'It expired', 'Check "Use these first" on Home every morning — it takes 5 seconds.'),
  WasteReason.forgot: ('🙈', 'Forgot about it', 'Keep older products at the front of the shelf, new ones at the back (FIFO).'),
  WasteReason.tooMuch: ('🛒', 'Bought too much', 'Plan 3 meals before shopping and buy only what the shopping list says.'),
  WasteReason.spoiled: ('🦠', 'Went bad early', 'Check storage tips in AI Chef — many products last longer when stored right.'),
  WasteReason.disliked: ('😖', 'Did not like it', 'Tell AI Chef what you dislike — it will stop suggesting it.'),
};

class WasteEntry {
  final FoodItem food;
  final WasteReason reason;
  final double money;
  WasteEntry(this.food, this.reason, this.money);
}

class LogEntry {
  final int day;
  final int id, kcal;
  final String emoji, name;
  LogEntry(this.id, this.emoji, this.name, this.kcal, [int? day]) : day = day ?? todayNum();
}

class ChatMessage {
  final String text;
  final bool isUser;
  ChatMessage(this.text, {required this.isUser});
}

class Ing {
  final String name;
  final int g;
  const Ing(this.name, this.g);
}

class Recipe {
  final String name, emoji, time, staples;
  final int servings;
  final List<Ing> ingredients;
  final List<String> steps;
  final bool zeroWaste; // рецепт специально для «спасения» остатков
  Recipe(this.name, this.emoji, this.time, this.servings, this.ingredients, this.steps, this.staples, {this.zeroWaste = false});

  List<String> missing(Set<String> have) => ingredients.where((i) => !have.contains(i.name)).map((i) => i.name).toList();
  int get kcal => (ingredients.fold<double>(0, (s, i) => s + i.g * foodByName[i.name]!.kcal / 100) / servings).round();
}

// ───────────────────────── БАЗА ПРОДУКТОВ ─────────────────────────
// Формат: Категория|эмодзи Название,ккал на 100 г,дней хранения;...

const _raw = '''
Vegetables|🍅 Tomato,18,7;🥒 Cucumber,15,7;🥔 Potato,77,30;🍠 Sweet Potato,86,21;🥕 Carrot,41,21;🧅 Onion,40,30;🧄 Garlic,149,60;🥬 Cabbage,25,21;🥦 Broccoli,34,5;🥬 Spinach,23,4;🫑 Bell Pepper,31,7;🍆 Eggplant,25,7;🥒 Zucchini,17,6;🎃 Pumpkin,26,30;🌽 Corn,86,5;🥬 Lettuce,15,5;🍄 Mushrooms,22,5;🌿 Dill,43,5;🌿 Parsley,36,6;🟣 Beetroot,43,21;🫛 Green Peas,81,5;🥦 Cauliflower,25,6;🥬 Celery,16,10;🌶️ Chili Pepper,40,7;⚪ Radish,16,8;🫛 Green Beans,31,5;🌱 Asparagus,20,4;🫚 Ginger,80,21;🥬 Leek,61,10;⚪ Turnip,28,20;🥬 Arugula,25,4;🥬 Bok Choy,13,5;🥬 Brussels Sprouts,43,7;🌿 Artichoke,47,5;🌿 Fennel,31,7;🥬 Kohlrabi,27,10;🧅 Spring Onion,32,7;🥬 Red Cabbage,31,21;🌶️ Jalapeno,29,7;🌿 Horseradish,48,30;🥒 Okra,33,5;🎃 Butternut Squash,45,30;🥕 Parsnip,75,20;🌿 Sorrel,22,4;🌿 Cilantro,23,5;🌿 Basil,23,5;🌿 Mint,70,5;🧅 Shallot,72,30;🧅 Red Onion,40,30;🍅 Cherry Tomato,18,7;🥒 Pattypan Squash,16,6;⚪ Daikon,18,14;🫛 Edamame,121,5;🥬 Salad Mix,17,4;🥬 Swiss Chard,19,5;🥬 Watercress,11,3;🍄 Champignons,22,5;🍄 Oyster Mushrooms,33,5;🍄 Porcini Mushrooms,34,4;🥔 Red Potato,70,30;🥬 Chinese Cabbage,16,10;🥬 Romaine Lettuce,17,5;🥬 Kale,49,5;🥬 Collard Greens,32,5;🫑 Red Bell Pepper,31,7;🫑 Yellow Bell Pepper,27,7;🫑 Green Bell Pepper,20,7;🥕 Baby Carrots,35,14;🥔 New Potatoes,70,14;🥒 Gherkins,12,7;🌽 Baby Corn,26,5;🥬 Iceberg Lettuce,14,7;🥬 Endive,17,6;🥬 Radicchio,23,7;🌿 Chives,30,5;🌿 Tarragon,50,5;🌿 Lemongrass,99,14;🌱 Microgreens,25,4;🌱 Bean Sprouts,30,3;🌱 Alfalfa Sprouts,23,4;🍄 Shiitake Mushrooms,34,6;🍄 Chanterelles,38,4;🍄 Enoki Mushrooms,37,6;🍄 King Oyster Mushrooms,35,6;🍄 Portobello,22,5;🍠 Yam,118,21;🥔 Jerusalem Artichoke,73,14;🥕 Purple Carrot,41,21;🫛 Snow Peas,42,5;🫛 Sugar Snap Peas,42,5;🥬 Mustard Greens,27,4;🧄 Wild Garlic,35,4;🧅 Pearl Onions,40,30;🥒 Chayote,19,14;🍅 Plum Tomatoes,18,7;🍅 Heirloom Tomatoes,18,6;🍅 Green Tomatoes,23,10;🥦 Broccolini,35,5;🥦 Romanesco,31,6;🎃 Acorn Squash,40,30;🎃 Spaghetti Squash,31,30;🥕 Rutabaga,37,30;🌿 Rhubarb,21,7;🥔 Celery Root,42,30;🥬 Savoy Cabbage,27,14;🥔 Taro,112,14;🌶️ Habanero,40,10;🌶️ Serrano Pepper,32,7;🌶️ Poblano Pepper,20,7;🍆 Baby Eggplant,25,6;🪷 Lotus Root,74,10;🥔 Jicama,38,14;🥒 Bitter Melon,17,5;🍄 Shimeji Mushrooms,39,6;🍄 Wood Ear Mushrooms,25,5;🌿 Thai Basil,23,5;🌿 Shiso,37,4;🫚 Galangal,71,14;🍃 Kaffir Lime Leaves,50,10;🍃 Pandan Leaves,35,7;🍠 Cassava,160,7;🌿 Curry Leaves,108,10;🌿 Chervil,37,5;🍄 Morels,31,3;🎃 Kabocha Squash,34,60;🎃 Delicata Squash,40,30;🥬 Celtuce,18,7;🥕 Salsify,82,14;🌿 Fiddlehead Ferns,34,3;🌿 Ramps,42,5;🌵 Nopales,16,7;🍅 Tomatillo,32,14;🫑 Shishito Peppers,25,7;🫑 Padron Peppers,24,7;🌿 Samphire,20,5;🧄 Garlic Scapes,30,10;🌱 Pea Shoots,30,4;🍠 Purple Sweet Potato,86,21;🍄 Maitake,31,5;🍄 Lion's Mane Mushroom,35,5;🍄 Black Trumpet Mushrooms,35,4;🌿 Lovage,20,5;🌿 Culantro,31,7;🌿 Lemon Verbena,50,5;🥬 Frisée,17,4;🥬 Mizuna,21,4;🥦 Gai Lan,22,4;🍠 Purple Yam,118,21;🥬 Beet Greens,22,3;🫛 Romano Beans,31,5;🥗 Watermelon Radish,20,14;🥬 Dandelion Greens,45,3;🌿 Purslane,20,3;🥒 Persian Cucumbers,12,7;🥬 Tatsoi,22,4;🌶️ Anaheim Pepper,20,7;🫑 Mini Sweet Peppers,27,10;🍄 Cremini Mushrooms,22,7;🥬 Escarole,17,5;🍄 Matsutake,22,4;🌿 Holy Basil,23,4;🌿 Nettles,42,3;🍄 Beech Mushrooms,35,7;🌿 Sea Grapes,4,3;🌱 Burdock Root,72,14;🫛 Yardlong Beans,47,5;🥬 Water Spinach,19,3;🥒 Luffa,20,7;🌿 Garlic Chives,30,5;🌿 Lemon Balm,44,5;⚫ Black Truffle,51,7;🍄 Nameko Mushrooms,20,5;🍄 Chicken of the Woods,33,4;🥬 Cardoon,17,7;🥬 Puntarelle,20,5;🌿 Agretti,17,4;🥬 Choy Sum,15,4;🥔 Oca,61,30;🎃 Hubbard Squash,40,60;🥒 Snake Gourd,18,5;🥒 Tindora,18,5;🌽 Huitlacoche,30,3;🌶️ Scotch Bonnet,40,10;🌶️ Bird's Eye Chili,40,10;🥦 Broccoli Rabe,22,4;🥬 Butter Lettuce,13,5;🥬 Little Gem Lettuce,15,6;🥬 Mache,21,4;🥬 Yu Choy,20,4;🥬 Amaranth Leaves,23,3;🍠 Yacon,54,14;🥔 Malanga,98,14;🍄 Hedgehog Mushrooms,22,5;🍄 Lobster Mushrooms,38,5;🍄 Cauliflower Mushroom,30,4;🌿 Vietnamese Coriander,30,5;🌿 Mitsuba,15,5;🌿 Borage,21,3
Fruits|🍎 Apple,52,14;🍌 Banana,89,4;🍊 Orange,47,10;🍋 Lemon,29,14;🍐 Pear,57,7;🍇 Grapes,69,7;🍑 Peach,39,4;🍒 Cherry,50,4;🍍 Pineapple,50,5;🥭 Mango,60,5;🍉 Watermelon,30,5;🍈 Melon,34,5;🥝 Kiwi,61,7;🥑 Avocado,160,4;🍑 Apricot,48,4;🍑 Plum,46,5;🍊 Tangerine,53,10;🔴 Pomegranate,83,30;🍊 Grapefruit,42,14;🥭 Papaya,43,5;🍈 Fig,74,3;🌴 Dates,282,180;🍋 Lime,30,14;🍑 Nectarine,44,5;🍊 Persimmon,70,7;🍈 Guava,68,5;🍈 Passion Fruit,97,7;🐉 Dragon Fruit,60,5;🍈 Lychee,66,5;🍐 Quince,57,14;🥥 Coconut,354,30;🍇 Raisins,299,365;🍑 Dried Apricots,241,365;🍑 Prunes,240,365;🍈 Dried Figs,249,365;🍊 Pomelo,38,14;🍏 Green Apple,52,14;🍌 Plantain,122,5;🍍 Dried Pineapple,340,180;🍈 Cantaloupe,34,5;🍐 Asian Pear,42,10;🍊 Clementine,47,10;🍋 Yuzu,30,10;🥭 Dried Mango,319,180;🍒 Dried Cherries,333,180;🍌 Baby Bananas,89,4;🍋 Bergamot,30,10;🍊 Kumquat,71,14;🍊 Blood Orange,50,10;🍈 Honeydew Melon,36,7;🍈 Jackfruit,95,5;🍈 Durian,147,4;🍈 Rambutan,82,5;🍈 Mangosteen,73,5;🍈 Feijoa,61,7;🍈 Kiwano,44,14;⭐ Star Fruit,31,7;🍑 Loquat,47,4;🍈 Cherimoya,75,4;🍇 Green Grapes,69,7;🍇 Red Grapes,69,7;🍇 Black Grapes,69,7;🍑 Flat Peach,39,4;🍑 Mirabelle Plum,60,5;🍎 Crab Apples,76,14;🍋 Meyer Lemon,29,14;🥥 Young Coconut,354,14;🍇 Sultanas,299,365;🌴 Medjool Dates,277,180;🍎 Dried Apples,243,365;🍐 Dried Pears,262,365;🍌 Dried Bananas,346,180;🍈 Dried Melon,341,180;🍏 Granny Smith Apple,58,21;🍎 Gala Apple,57,14;🍐 Conference Pear,57,7;🍎 Aport Apple,50,30;🫒 Jida Berries,330,180;🍒 Alycha Cherry Plum,34,7;🟤 Longan,60,5;🍓 Salak,82,7;🍈 Soursop,66,3;🍅 Tamarillo,31,10;🍈 Breadfruit,103,3;🍐 Sapodilla,83,5;🍇 Jabuticaba,45,3;🍒 Acerola,32,4;🫐 Camu Camu,25,5;🥥 Cupuacu,49,5;🥭 Mamey Sapote,124,4;🍐 Medlar,47,10;🥭 Pawpaw,80,3;🍋 Calamansi,25,14;🍋 Buddha's Hand,30,14;🍋 Finger Lime,30,14;🍊 Ugli Fruit,47,14;🍑 Pluot,57,5;🌵 Prickly Pear,41,7;🍉 Yellow Watermelon,30,5;🍫 Black Sapote,130,4;🍊 Cara Cara Orange,45,14;🍇 Cotton Candy Grapes,69,7;🍌 Red Banana,90,5;🍏 Sugar Apple,94,4;🍋 Sudachi,25,14;🍑 Greengage,46,5;🍑 Damson,50,5;🟤 Jujube,79,10;🍎 Wax Apple,25,5;🍈 Pepino Melon,25,7;🥚 Canistel,138,5;🍇 Langsat,57,5;🍊 Sumo Citrus,55,14
Berries|🍓 Strawberry,32,3;🫐 Blueberry,57,5;🍇 Raspberry,52,3;🫐 Blackberry,43,3;🍒 Cranberry,46,10;🍇 Gooseberry,44,4;🍒 Lingonberry,43,7;🍊 Sea Buckthorn,82,5;🍇 Mulberry,43,3;🍒 Goji Berries,349,180;🍒 Sweet Cherry,63,4;🍒 Sour Cherry,50,4;🍇 Black Currant,63,4;🍇 Red Currant,56,4;🌹 Rosehip,162,30;🍓 Wild Strawberry,32,3;🫐 Bilberry,44,4;🍒 Cloudberry,51,4;🍇 Elderberry,73,3;🫐 Honeyberry,55,4;🍇 Boysenberry,50,3;🍇 Loganberry,55,3;🍒 Dried Barberry,316,180;🫐 Aronia,47,10;🍒 Viburnum,26,10;🍇 White Currant,56,4;🫐 Dried Blueberries,317,180;🍒 Dried Cranberries,308,180;🍓 Freeze-Dried Strawberries,350,365;🫐 Acai Berries,70,2;🍒 Physalis,53,10;🍇 Dewberry,43,3;🍓 Garden Strawberry,32,3;🍒 Rowan Berry,50,10;🫐 Huckleberries,37,7;🍓 Tayberry,40,3;🫐 Sloe Berries,50,5;🥝 Kiwiberries,61,10;🫐 Saskatoon Berries,85,5;🫐 Haskap Berries,51,5;🫐 Marionberries,52,4
Dairy|🥛 Milk,60,5;🥛 Kefir,51,7;🥛 Ryazhenka,67,7;🥛 Yogurt,61,7;🥛 Sour Cream,206,7;🧈 Butter,717,30;🧀 Cheddar Cheese,403,21;🧀 Mozzarella,280,10;🧀 Parmesan,431,60;🧀 Feta,264,14;🧀 Cream Cheese,342,10;🧀 Cottage Cheese,98,5;🧀 Processed Cheese,300,30;🥚 Eggs,143,21;🥛 Heavy Cream,340,7;🥛 Oat Milk,45,7;🧀 Ricotta,174,7;🧀 Gouda,356,30;🧀 Brie,334,14;🧀 Swiss Cheese,380,30;🧀 Brynza,260,14;🧀 Suluguni,290,14;🧀 Blue Cheese,353,30;🧀 Goat Cheese,364,14;🥛 Light Cream,205,7;🥛 Whipped Cream,257,5;🧈 Margarine,717,60;🥛 Ayran,40,7;🥛 Soy Milk,33,7;🥛 Almond Milk,24,7;🥛 Greek Yogurt,97,10;🥛 Skyr,63,10;🧈 Ghee,900,90;🥚 Quail Eggs,158,21;🧀 Mascarpone,429,10;🧀 Halloumi,321,30;🧀 Camembert,300,14;🥛 Coconut Milk,230,5;🥛 Lactose-Free Milk,45,7;🥛 Drinking Yogurt,72,10;🧀 Cheese Curds,98,5;🧀 Provolone,351,30;🧀 Edam,357,30;🧀 Emmental,380,30;🧀 Gruyere,413,60;🧀 Manchego,390,60;🧀 Pecorino,387,60;🧀 Roquefort,369,30;🧀 Gorgonzola,353,21;🧀 Burrata,330,4;🧀 Paneer,321,7;🧀 Smoked Cheese,330,30;🧀 String Cheese,300,30;🧀 Cheese Slices,330,30;🧀 Grated Cheese,400,14;🧀 Adyghe Cheese,240,7;🥛 Buttermilk,40,10;🥛 Chocolate Milk,83,7;🥛 Baked Milk,67,7;🥛 Skim Milk,34,7;🥛 Whole Milk,64,7;🥛 Goat Milk,69,7;🥛 Evaporated Milk,134,180;🥛 Matsoni,63,7;🥛 Fruit Yogurt,85,14;🥛 Vanilla Yogurt,95,14;🥛 Low-Fat Kefir,40,7;🍫 Glazed Curd Bar,407,14;🧈 Salted Butter,717,45;🥛 Creme Fraiche,292,14;🥛 Clotted Cream,586,7;🥚 Egg Whites,52,7;🥚 Duck Eggs,185,21;🥛 Prostokvasha,58,5;🧀 Tvorog 9%,159,5;🧀 Kurt,340,180;🧀 Irimshik,380,60;🥛 Katyk,60,7;🥛 Baby Yogurt,90,7;🧀 Suzbe,260,14;🥛 Kaymak,330,7;🍯 Balkaymak,420,10;🧀 Sulguni,286,21;🧀 American Cheese,371,60;🧀 Pimento Cheese,350,14;🧈 Sary Mai,876,180;🥛 Varenets,53,5;🥣 Suzma,160,10;🥛 Snezhok,82,7;🧀 Bryndza,260,30;🥛 Yakult,63,30;🧀 Cotija Cheese,366,30;🥛 Labneh,160,14;🥛 Quark,67,10;🧀 Stracciatella,250,4;🧀 Oaxaca Cheese,330,21;🧀 Comté,410,60;🧀 Fontina,389,30;🧀 Taleggio,315,21;🧀 Raclette Cheese,357,30;🧀 Queso Fresco,299,14;🧀 Stilton,410,30;🧀 Havarti,371,30;🧀 Jarlsberg,355,30;🧀 Ricotta Salata,280,30;🧀 Mimolette,360,60
Meat|🍗 Chicken Breast,165,2;🍗 Chicken Thighs,209,2;🥩 Beef,250,3;🥩 Pork,242,3;🥩 Ground Beef,254,2;🍖 Lamb,294,3;🦃 Turkey,135,2;🌭 Sausages,301,7;🥓 Bacon,541,7;🍖 Ham,145,7;🥩 Boiled Sausage,257,7;🥓 Salo,770,60;🥩 Liver,135,2;🦆 Duck,337,3;🥩 Veal,172,3;🐇 Rabbit,173,3;🍗 Chicken Wings,203,2;🍗 Chicken Drumsticks,172,2;🍗 Whole Chicken,215,2;🍖 Pork Ribs,277,3;🥩 Steak,271,3;🍖 Meatballs,230,3;🥩 Minced Pork,263,2;🌭 Kielbasa,320,10;🍕 Salami,336,21;🍕 Pepperoni,504,30;🥓 Prosciutto,250,30;🥫 Liver Pate,300,7;🍗 Chicken Liver,119,2;🥩 Beef Tongue,224,3;🌭 Smoked Sausage,420,21;🌭 Hot Dog Sausages,260,10;🥓 Pork Belly,518,3;🦃 Turkey Breast,104,2;🍗 Chicken Hearts,153,2;🥩 Ground Turkey,148,2;🥩 Ground Chicken,143,2;🥩 Pork Neck,240,3;🥩 Beef Ribeye,291,3;🥩 Beef Brisket,250,3;🥓 Smoked Bacon,550,14;🥩 Doktorskaya Sausage,257,7;🥩 Cervelat,460,30;🍗 Chicken Legs,184,2;🍗 Chicken Gizzards,94,2;🦃 Turkey Thighs,144,2;🦃 Turkey Wings,197,2;🥩 Lamb Chops,282,3;🥩 Ground Lamb,282,2;🥩 Beef Tenderloin,218,3;🥩 Beef Sirloin,206,3;🥩 Beef Shank,201,3;🥩 Beef Liver,135,2;🥩 Pork Loin,143,3;🥩 Pork Chops,231,3;🥩 Pork Shoulder,236,3;🥩 Pork Tenderloin,143,3;🍖 Pork Knuckle,260,3;🥩 Venison,158,3;🦆 Duck Breast,201,3;🪿 Goose,305,3;🐦 Quail,227,2;🌭 Chorizo,455,30;🌭 Bratwurst,297,10;🌭 Frankfurters,305,10;🌭 Chicken Sausages,172,7;🥓 Pancetta,458,30;🥓 Turkey Bacon,226,14;🍖 Roast Beef,175,5;🍗 Smoked Chicken,190,7;🍖 Smoked Ham,145,10;🥫 Corned Beef,251,7;🥩 Bresaola,151,30;🥩 Basturma,250,30;🍔 Beef Burger Patties,254,2;🍖 Marinated Shashlik,220,2;🍗 Chicken Fillet,113,2;🌭 Kazy,330,30;🌭 Shuzhuk,420,30;🥓 Zhaya,400,14;🥩 Horse Meat,133,3;🐪 Camel Meat,160,3;🌭 Karta,350,10;🥓 Mutton Tail Fat,800,30;🍖 Sur Et,250,30;🌭 Chuchuk,450,30;🥓 Zhal,580,10;🍖 Lamb Ribs,290,3;🥩 Pastrami,150,10;🍖 Mutton,250,3;🥩 Lamb Liver,130,2;🥩 Beef Chuck,218,3;🥓 Mortadella,311,10;🌭 Lap Cheong,450,30;🥩 Char Siu Pork,260,4;🥓 Guanciale,655,60;🌶️ Nduja,470,60;🍖 Beef Short Ribs,295,3;🍖 Oxtail,262,3;🥓 Lardo,890,60;🍖 Soppressata,400,30;🍖 Iberico Ham,375,90
Seafood|🐟 Salmon,208,2;🐟 Cod,82,2;🐟 Herring,158,5;🍤 Shrimp,99,2;🥫 Canned Tuna,116,365;🐟 Mackerel,205,3;🐟 Trout,148,2;🦀 Crab Sticks,95,14;🐟 Tilapia,96,2;🐟 Pollock,72,2;🐟 Sea Bass,97,2;🐟 Carp,127,2;🐟 Pike,84,2;🐟 Catfish,95,2;🐟 Halibut,111,2;🐟 Fresh Sardines,208,2;🐟 Smoked Salmon,172,10;🦑 Squid,92,2;🦪 Mussels,86,2;🦪 Oysters,68,2;🦀 Crab,97,2;🦞 Lobster,89,2;🐙 Octopus,82,2;🐚 Scallops,88,2;🥚 Red Caviar,260,14;🐟 Dried Fish,250,90;🐟 Salted Herring,217,14;🐟 Smoked Mackerel,221,10;🐟 Pangasius,90,2;🐟 Sturgeon,160,2;🍤 Tiger Prawns,106,2;🐟 Anchovies,131,30;🐟 Eel,184,2;🐟 Capelin,157,2;🐟 Tuna Steak,144,2;🐟 Haddock,74,2;🐟 Hake,86,2;🐟 Sole,91,2;🐟 Flounder,91,2;🐟 Perch,91,2;🐟 Zander,84,2;🐟 Dorado,96,2;🐟 Red Snapper,100,2;🐟 Swordfish,144,2;🐟 Mahi-Mahi,85,2;🐟 Arctic Char,140,2;🐟 Coho Salmon,146,2;🐟 Pink Salmon,127,2;🐟 Chum Salmon,120,2;🐟 Smelt,97,2;🐟 Baltic Sprats,137,2;🐟 Kippers,217,10;🐟 Pickled Herring,262,21;🍤 Cooked Shrimp,99,3;🍤 King Prawns,85,2;🦞 Crayfish,77,2;🦑 Calamari Rings,92,2;🦪 Clams,86,2;🦀 King Crab,84,2;⚫ Black Caviar,264,30;🐟 Fish Roe,143,4;🐙 Baby Octopus,82,2;🦐 Seafood Mix,90,2;🐟 Salted Salmon,202,7;🐟 Vobla,235,90;🐟 Caspian Kilka,140,2;🐟 Koktal,180,2;🐟 Monkfish,76,2;🦐 Langoustines,90,2;🐟 Barramundi,97,2;🦑 Cuttlefish,79,2;🟠 Sea Urchin,120,2;🐟 Turbot,95,2;🍣 Tobiko,140,7;🍣 Mentaiko,130,7;🦪 Abalone,105,2
Grains|🍝 Pasta,350,365;🍚 Rice,360,365;🌾 Buckwheat,343,365;🥣 Oats,389,270;🌾 Millet,378,365;🌾 Semolina,360,365;🌾 Couscous,376,365;🌾 Pearl Barley,352,365;🌾 Flour,364,270;🥣 Cornflakes,357,180;🍜 Instant Noodles,450,270;🌾 Bulgur,342,365;🍚 Brown Rice,362,365;🍚 Basmati Rice,350,365;🍚 Jasmine Rice,355,365;🍚 Wild Rice,357,365;🌾 Quinoa,368,365;🌽 Corn Grits,337,365;🌽 Cornmeal,362,365;🌾 Wheat Groats,335,365;🥣 Muesli,363,180;🥣 Granola,471,180;🍝 Spaghetti,350,365;🍝 Penne,350,365;🍝 Fusilli,350,365;🍜 Egg Noodles,384,365;🍜 Rice Noodles,364,365;🍜 Vermicelli,350,365;🌾 Whole Wheat Flour,340,270;🌾 Rye Flour,325,270;🌽 Corn Starch,381,365;🥔 Potato Starch,333,365;🍞 Breadcrumbs,395,180;🍜 Udon Noodles,127,14;🍝 Lasagna Sheets,350,365;🌾 Spelt,338,365;🌾 Oat Bran,246,180;🍚 Sushi Rice,360,365;🥣 Rolled Oats,379,270;🍜 Soba Noodles,336,365;🌾 Wheat Bran,216,180;🍚 Arborio Rice,349,365;🍚 Black Rice,356,365;🍚 Red Rice,355,365;🍚 Parboiled Rice,374,365;🌾 Amaranth,371,365;🌾 Teff,367,365;🌾 Farro,340,365;🌾 Sorghum,329,365;🌾 Freekeh,325,365;🌾 Barley Groats,343,365;🌾 Rye Flakes,338,270;🌾 Buckwheat Flour,335,270;🌾 Rice Flour,366,270;🌾 Almond Flour,571,180;🥥 Coconut Flour,443,180;🌾 Chickpea Flour,387,270;🌽 Polenta,370,365;🍝 Tagliatelle,358,365;🍝 Farfalle,350,365;🍝 Rigatoni,350,365;🍝 Linguine,350,365;🍝 Macaroni,350,365;🍝 Orzo,357,365;🍝 Whole Wheat Pasta,348,365;🍝 Gluten-Free Pasta,357,365;🍝 Fresh Pasta,288,7;🥟 Gnocchi,133,14;🍜 Ramen Noodles,436,270;🍜 Glass Noodles,351,365;🥣 Bran Flakes,357,180;🥣 Chocolate Cereal,388,180;🥣 Puffed Rice,383,180;🥣 Instant Oatmeal,367,270;🌾 Bread Flour,361,270;🌾 Self-Raising Flour,353,270;🌾 Talkan,370,180;🍜 Lagman Noodles,350,14;🍜 Kespe Noodles,360,180;🌾 Tary,360,180;🍝 Bucatini,360,365;🍝 Pappardelle,360,365;🌾 Fonio,360,365;🌾 Kamut,337,365;🌽 Masa Harina,365,365;🍝 Orecchiette,350,365
Bakery|🍞 White Bread,265,4;🍞 Rye Bread,259,5;🥖 Baguette,270,2;🥐 Croissant,406,3;🫓 Lavash,275,5;🫓 Tortilla,237,10;🍞 Toast Bread,270,7;🥯 Bagel,250,3;🫓 Pita,275,4;🫓 Naan,310,4;🍞 Ciabatta,271,3;🥐 Brioche,375,3;🍩 Donut,452,2;🧁 Muffin,377,3;🥧 Apple Pie,237,3;🥨 Pretzel,380,5;🥞 Burger Bun,260,4;🍞 Sourdough Bread,260,4;🍞 Whole Grain Bread,247,5;🍞 Borodinsky Bread,208,5;🍞 Bread Loaf,266,4;🥖 Breadsticks,410,30;🍘 Crispbread,330,180;🍞 Cornbread,270,3;🍪 Gingerbread,350,30;🧇 Waffles,291,14;🥟 Puff Pastry,558,30;🍕 Pizza Dough,271,5;🥟 Phyllo Dough,300,14;🥐 Pain au Chocolat,414,2;🍞 Poppy Seed Bun,330,3;🍰 Yeast Dough,280,3;🍞 Multigrain Bread,265,5;🍞 Gluten-Free Bread,246,5;🍔 Brioche Buns,350,4;🥐 Almond Croissant,420,2;🥐 Cinnamon Roll,390,3;🥯 Sesame Bagel,270,3;🫓 Focaccia,249,3;🫓 Flatbread,290,5;🫓 Chapati,297,4;🧁 English Muffin,227,7;🥞 Crumpets,198,5;🍞 Banana Bread,326,4;🍰 Sponge Cake,297,4;🧁 Cupcake,305,3;🥧 Cherry Pie,260,3;🥧 Quiche,300,3;🫓 Khachapuri,300,2;🥖 Garlic Bread,350,3;🥨 Soft Pretzel,338,2;🌭 Hot Dog Buns,280,5;🫓 Matzo,395,365;🍪 Biscotti,410,90;🍞 Kulich,350,7;🍞 Raisin Bread,274,4;🥐 Rugelach,420,5;🍩 Baursaks,390,3;🫓 Tandoor Flatbread,260,3;🫓 Shelpek,340,3;🥯 Sushki,340,90;🥐 Buttermilk Biscuits,350,3;🥧 Pecan Pie,412,4;🫓 Kattama,330,3;🍔 Hamburger Buns,279,5;🍞 Zucchini Bread,300,4;🥟 Tandyr Samsa,310,2;🫓 Kystyby,250,2;🥯 Bublik,330,7;🥐 Sochniki,330,3;🌮 Corn Tortillas,218,7;🍞 Pumpernickel,250,7;🍞 Milk Bread,280,4
Nuts & Legumes|🥜 Peanuts,567,180;🌰 Almonds,579,180;🌰 Walnuts,654,180;🌰 Cashews,553,180;🫘 Beans,333,365;🫘 Lentils,353,365;🫘 Chickpeas,364,365;🥜 Peanut Butter,588,90;🌻 Sunflower Seeds,584,180;🥜 Pistachios,560,180;🌰 Hazelnuts,628,180;🌰 Pecans,691,180;🥜 Macadamia,718,180;🌰 Pine Nuts,673,180;🥜 Brazil Nuts,659,180;🎃 Pumpkin Seeds,559,180;🌱 Sesame Seeds,573,180;🌱 Chia Seeds,486,365;🌱 Flax Seeds,534,365;🫘 Kidney Beans,333,365;🫘 Black Beans,341,365;🫘 White Beans,333,365;🫘 Green Lentils,353,365;🫘 Split Peas,341,365;🫘 Soybeans,446,365;🫘 Mung Beans,347,365;🥜 Tahini,595,180;🥜 Almond Butter,614,90;🥥 Coconut Flakes,660,180;🌰 Chestnuts,213,30;🫘 Red Lentils,358,365;🥜 Salted Peanuts,585,180;🌰 Mixed Nuts,607,180;🫘 Broad Beans,341,365;🫘 Pinto Beans,347,365;🫘 Navy Beans,337,365;🫘 Lima Beans,338,365;🫘 Adzuki Beans,329,365;🫘 Black-Eyed Peas,336,365;🫘 Yellow Lentils,345,365;🫘 Black Lentils,352,365;🌰 Roasted Almonds,598,180;🥜 Cashew Butter,587,90;🌱 Hemp Seeds,553,365;🌱 Poppy Seeds,525,365;🥜 Crunchy Peanut Butter,597,90;🌰 Tiger Nuts,409,180;🌰 Candied Pecans,620,90;🥜 Smoked Almonds,600,180;🌰 Apricot Kernels,520,180;🫘 Cannellini Beans,333,365;⚫ Black Sesame Seeds,573,180;🫘 Lupini Beans,119,30;🫘 Borlotti Beans,335,365;🫘 Chana Dal,360,365;🫘 Urad Dal,341,365;🫘 Pigeon Peas,343,365
Pantry|🫒 Olive Oil,884,365;🌻 Vegetable Oil,884,365;🥫 Ketchup,101,90;🥫 Mayonnaise,680,60;🥫 Tomato Paste,82,90;🥫 Mustard,66,90;🥫 Soy Sauce,53,180;🍯 Honey,304,365;🧂 Sugar,387,365;🥒 Pickles,11,30;🍓 Jam,250,365;🥬 Sauerkraut,19,30;🍶 Balsamic Vinegar,88,365;🍶 Vinegar,18,365;🍶 Apple Cider Vinegar,21,365;🫒 Sesame Oil,884,365;🥥 Coconut Oil,862,365;🌻 Sunflower Oil,884,365;🥫 BBQ Sauce,150,90;🌶️ Hot Sauce,30,180;🌶️ Sriracha,93,180;🌶️ Adjika,70,60;🍅 Tkemali,100,60;🌿 Pesto,420,14;🥫 Tartar Sauce,300,30;🥫 Salad Dressing,350,90;🍅 Tomato Sauce,35,90;🍝 Pasta Sauce,60,90;🥫 Worcestershire Sauce,78,365;🥫 Teriyaki Sauce,89,180;🌿 Wasabi,109,90;🍁 Maple Syrup,260,365;🧂 Brown Sugar,380,365;🧂 Powdered Sugar,389,365;🍫 Chocolate Spread,539,90;🥄 Baking Powder,53,365;🥄 Baking Soda,0,365;🍞 Yeast,325,180;🍬 Vanilla Sugar,390,365;🥄 Gelatin,335,365;☕ Ground Coffee,2,180;☕ Coffee Beans,2,180;☕ Instant Coffee,353,365;🍵 Black Tea,1,365;🍵 Green Tea,1,365;🍫 Cocoa Powder,228,365;🥫 Horseradish Sauce,70,60;🥫 Garlic Sauce,300,30;🥫 Fish Sauce,35,365;🥫 Oyster Sauce,51,180;🥫 Hoisin Sauce,220,180;🥫 Miso Paste,199,180;🥫 Cream Soup Base,350,180;🍯 Dulce de Leche,328,60;🥫 Apple Sauce,42,14;🍯 Fruit Syrup,260,180;🍯 Agave Syrup,310,365;🥫 Pickled Beets,43,60;🥫 Pickled Cabbage,33,30;🥫 Spicy Ketchup,110,90;🫒 Avocado Oil,884,365;🫒 Flaxseed Oil,884,180;🫒 Pumpkin Seed Oil,884,180;🍶 Rice Vinegar,18,365;🍶 Wine Vinegar,19,365;🥫 Dijon Mustard,66,180;🥫 Grainy Mustard,150,180;🌶️ Sweet Chili Sauce,210,180;🥫 Salsa,36,30;🥑 Guacamole,160,5;🥒 Tzatziki,95,7;🥫 Ranch Dressing,430,60;🥫 Caesar Dressing,450,60;🥫 Thousand Island Dressing,370,60;🌿 Red Pesto,360,14;🥫 Curry Paste,140,180;🌶️ Harissa,90,180;🌶️ Gochujang,220,365;🌶️ Tabasco,12,365;🍯 Golden Syrup,325,365;🍯 Molasses,290,365;🍯 Date Syrup,280,365;🧂 Stevia,0,365;🧂 Cane Sugar,380,365;🍫 Chocolate Chips,480,365;🥥 Coconut Cream,330,7;🥣 Vegetable Broth,10,7;🥣 Chicken Broth,15,7;🧊 Bouillon Cubes,250,365;🥫 Tomato Puree,38,90;🍅 Sun-Dried Tomatoes,258,180;🫒 Capers,23,365;🥄 Vanilla Extract,288,365;🥄 Agar-Agar,26,365;🍋 Citric Acid,0,365;🍋 Lemon Curd,320,30;🍒 Cherry Jam,250,365;🍑 Apricot Jam,250,365;🍊 Orange Marmalade,246,365;🫐 Blueberry Jam,250,365;🍓 Strawberry Jam,250,365;🌰 Chestnut Puree,170,180;🍇 Grape Jelly,270,365;🥞 Pancake Mix,370,365;🍲 Bone Broth,20,5;🟢 Pistachio Cream,570,180;🧈 Lard,902,90;🧈 Shortening,884,365;🧂 Xanthan Gum,333,365;🧄 Black Garlic,250,60;🍫 Chocolate Hazelnut Spread,540,180;🥜 Pistachio Butter,600,180;🌶️ Chili Crisp,600,180;🍯 Hot Honey,300,365;🍬 Monk Fruit Sweetener,0,365;🌶️ Calabrian Chili Paste,200,180;🥥 Coconut Aminos,90,365;🍋 Preserved Lemons,30,180;🫙 Kewpie Mayo,700,60;🫙 Mole Paste,500,180;🦐 Shrimp Paste,150,180;🌶️ Doubanjiang,180,180;🍶 Shaoxing Wine,130,365;🍶 Chinkiang Vinegar,40,365;🌿 Moringa Powder,300,365;🌿 Spirulina Powder,290,365;🥜 Peanut Oil,884,365;🍯 Corn Syrup,286,365;🌿 Chimichurri,350,14;🫙 Romesco Sauce,250,10;🧄 Aioli,700,10;🦐 XO Sauce,450,90;🫙 Black Bean Sauce,120,180;🍶 Mentsuyu,100,90;🫒 Truffle Oil,884,365;🍯 Palm Sugar,375,365;🍶 Shio Koji,120,180;🫙 Chamoy,90,180;🫙 Pomegranate Molasses,280,365;🥄 Baobab Powder,250,365;🥄 Lucuma Powder,329,365
Sweets|🍫 Chocolate,546,180;🍪 Cookies,480,90;🍰 Cake,350,3;🍬 Candy,390,180;🍦 Ice Cream,207,60;🥫 Condensed Milk,321,180;🥜 Halva,516,90;🍫 Dark Chocolate,546,180;🍫 Milk Chocolate,535,180;🍫 White Chocolate,539,180;🍫 Chocolate Bar,520,180;🍬 Caramel,382,180;🍭 Lollipop,380,365;🍬 Marshmallow,318,90;🍬 Zefir,326,30;🍬 Pastila,310,60;🐻 Gummy Bears,343,180;🍮 Jelly,60,14;🍫 Brownie,466,5;🍰 Cheesecake,321,4;🍰 Eclair,262,2;🍫 Chocolate Candies,500,180;🍧 Sorbet,131,60;🍦 Popsicle,100,60;🍪 Wafers,520,90;🍬 Marmalade,321,90;🍬 Turkish Delight,320,90;🥮 Baklava,430,10;🍰 Tiramisu,283,3;🍮 Pudding,115,5;🍮 Panna Cotta,200,4;🍰 Napoleon Cake,380,3;🍰 Honey Cake,370,4;🍪 Oatmeal Cookies,430,60;🍪 Shortbread,502,60;🍫 Truffles,510,30;🍨 Gelato,185,60;🍬 Toffee,436,180;🥜 Nut Brittle,480,90;🍬 Candied Fruit,322,180;🍬 Sunflower Halva,523,90;🍯 Chikki,480,90;🍰 Carrot Cake,415,4;🍪 Chocolate Chip Cookies,488,60;🍪 Macarons,404,7;🥖 Churros,390,1;🍰 Red Velvet Cake,367,4;🍰 Chocolate Cake,371,4;🍰 Swiss Roll,350,7;🍮 Creme Brulee,310,3;🍮 Flan,150,4;🍨 Ice Cream Sandwich,240,60;🍬 Licorice,375,365;🍬 Jelly Beans,375,365;🍬 Mints,390,365;🍫 Fudge,411,90;🍫 Praline,530,90;🍬 Nougat,398,90;🍥 Meringues,390,90;🥧 Pumpkin Pie,243,3;🍰 Bird's Milk Cake,420,7;🍩 Ponchiki,410,2;🍯 Kozinaki,576,90;🍚 Rice Pudding,118,4;🍡 Mochi,240,3;🍭 Cotton Candy,390,365;🥧 Strudel,274,4;🍰 Lemon Tart,350,3;🍯 Chak-Chak,450,30;🍬 Zhent,450,30;🍫 Peanut Butter Cups,515,180;🍪 Pryaniki,364,60;🍰 Funnel Cake,380,2;🥧 Key Lime Pie,350,4;🍰 Mannik,290,4;🍯 Medovik,380,5;🍑 Peach Cobbler,230,3;🍌 Banana Pudding,180,3;🥨 Khvorost,520,14;🍇 Churchkhela,410,60;🍪 Snickerdoodle Cookies,480,14
Drinks|🧃 Orange Juice,45,7;🧃 Apple Juice,46,7;🥤 Kvass,27,7;🥤 Cola,42,180;💧 Mineral Water,0,365;💧 Sparkling Water,0,365;🍋 Lemonade,40,30;🍵 Iced Tea,30,30;⚡ Energy Drink,45,180;🥤 Lemon-Lime Soda,41,180;🍅 Tomato Juice,17,7;🍇 Grape Juice,60,7;🧃 Multifruit Juice,48,7;🍍 Pineapple Juice,53,7;🥥 Coconut Water,19,30;🥤 Smoothie,60,2;🥤 Compote,45,5;🥤 Kissel,60,5;🥤 Mors,40,5;🍫 Hot Chocolate,89,1;🍺 Beer,43,180;🍷 Red Wine,85,365;🍷 White Wine,82,365;🥂 Champagne,76,365;🥃 Whiskey,250,365;🍸 Vodka,231,365;🍎 Cider,50,180;🥛 Milkshake,112,2;🍵 Matcha Latte,60,2;🥤 Juice Box,47,180;🍊 Fresh Orange Juice,45,2;🥤 Tarragon Soda,45,180;🥤 Birch Sap,24,5;🍷 Sangria,80,5;🧃 Peach Juice,50,7;☕ Cold Brew,2,14;☕ Iced Coffee,60,7;🧋 Bubble Tea,90,1;🍵 Kombucha,13,30;🥤 Ginger Ale,34,180;🥤 Tonic Water,34,180;🥤 Root Beer,41,180;🥤 Diet Cola,0,180;🧃 Cranberry Juice,46,7;🧃 Pomegranate Juice,54,7;🥕 Carrot Juice,40,5;🧃 Grapefruit Juice,39,7;🧃 Cherry Juice,50,7;🥭 Mango Nectar,60,7;🥤 Sports Drink,26,180;💧 Flavored Water,15,180;🍺 Non-Alcoholic Beer,26,180;🍺 Dark Beer,51,180;🍸 Gin,263,365;🥃 Rum,231,365;🥃 Cognac,239,365;🍷 Rose Wine,80,365;🥛 Protein Shake,70,3;🥤 Green Smoothie,40,2;🍵 Herbal Tea,1,365;🥛 Tan,25,7;🍵 Chai Latte,60,2;☕ Cappuccino,40,1;🥛 Kumys,50,5;🥛 Shubat,88,5;🥤 Cream Soda,51,180;🧃 Kompot,45,5;🍵 Kazakh Milk Tea,45,1;🥛 Chalap,25,2;🍹 Uzvar,30,5;🍯 Sbiten,50,14;🧋 Sweet Tea,40,5;🍒 Kisel,60,3;☕ Espresso,2,1;🍵 Chamomile Tea,1,365;🍵 Earl Grey Tea,1,365;🧉 Yerba Mate,1,365;🌺 Hibiscus Tea,1,365;🍵 Rooibos Tea,1,365;🍵 Barley Tea,1,365;🍵 Hojicha,1,365;🥛 Horchata,54,5
Frozen|🥟 Pelmeni,250,180;🥟 Vareniki,200,180;🍕 Frozen Pizza,266,180;🥦 Frozen Vegetables,65,180;🍟 French Fries,312,180;🍓 Frozen Berries,50,180;🍗 Chicken Nuggets,296,180;🐟 Fish Fingers,230,180;🌽 Frozen Corn,81,180;🥬 Frozen Spinach,23,180;🫛 Frozen Peas,77,180;🐟 Frozen Fish Fillet,100,180;🍤 Frozen Shrimp,99,180;🍗 Frozen Chicken,165,180;🍖 Frozen Meatballs,230,180;🥩 Frozen Cutlets,240,180;🥞 Frozen Blini,200,180;🥟 Frozen Cheburek,300,180;🥐 Frozen Dough,270,180;🍄 Frozen Mushrooms,25,180;🥭 Frozen Mango,60,180;🧇 Frozen Waffles,290,180;🌯 Frozen Burrito,230,180;🍝 Frozen Lasagna,135,180;🥔 Frozen Hash Browns,150,180;🥟 Pierogi,190,180;🥟 Manti,210,180;🥟 Khinkali,220,180;🥟 Gyoza,200,180;🥟 Cherry Vareniki,190,180;🥬 Frozen Broccoli,35,180;🥕 Frozen Carrot,35,180;🫑 Frozen Bell Pepper,30,180;🍓 Frozen Strawberries,32,180;🫐 Frozen Blueberries,57,180;🍨 Frozen Yogurt,127,60;🥟 Frozen Syrniki,220,180;🍕 Frozen Calzone,250,180;🫛 Frozen Green Beans,31,180;🍠 Frozen Sweet Potato Fries,180,180;🧅 Frozen Onion Rings,280,180;🥬 Frozen Kale,30,180;🥑 Frozen Avocado,160,180;🍍 Frozen Pineapple,50,180;🍒 Frozen Cherries,50,180;🍇 Frozen Raspberries,52,180;🍒 Frozen Cranberries,46,180;🍌 Frozen Bananas,89,90;🥧 Frozen Pie,280,180;🦑 Frozen Squid,92,180;🐟 Frozen Salmon,208,180;🍗 Frozen Chicken Wings,203,180;🥩 Frozen Minced Meat,254,180;🍔 Frozen Burgers,250,180;🌯 Frozen Spring Rolls,220,180;🥟 Frozen Samosas,260,180;🍚 Frozen Fried Rice,160,180;🥟 Frozen Ravioli,180,180;🥞 Frozen Pancakes,230,180;🥦 Frozen Cauliflower Rice,25,180;🥣 Frozen Soup Mix,40,180;🧊 Frozen Herbs,30,180;🥔 Tater Tots,190,180;🌭 Corn Dogs,260,180
Spices|🧂 Salt,0,365;🌶️ Black Pepper,251,365;🌶️ Paprika,282,365;🌿 Cinnamon,247,365;🌿 Bay Leaf,313,365;🌿 Oregano,265,365;🌿 Cumin,375,365;🌿 Turmeric,312,365;🌿 Coriander,298,365;🌿 Vanilla,288,365;🌿 Nutmeg,525,365;🌿 Cloves,274,365;🍛 Curry Powder,325,365;🌶️ Chili Flakes,282,365;🌿 Dried Dill,253,365;🧄 Dried Garlic,331,365;🌿 Rosemary,131,14;🌿 Thyme,101,14;🌿 Saffron,310,365;🌿 Cardamom,311,365;🌿 Italian Herbs,265,365;🌿 Khmeli-Suneli,250,365;🌿 Ginger Powder,335,365;🌿 Mustard Seeds,508,365;🌿 Star Anise,337,365;🌿 Dried Basil,233,365;🌿 Dried Parsley,292,365;🌿 Dried Mint,285,365;🌿 Sage,315,365;🌿 Marjoram,271,365;🌿 Fenugreek,323,365;🌿 Allspice,263,365;🍛 Garam Masala,379,365;🌶️ Cajun Seasoning,280,365;🌿 Ras el Hanout,300,365;🌿 Zaatar,300,365;🌿 Sumac,240,365;🌿 Five Spice,347,365;🌶️ Cayenne Pepper,318,365;🌶️ Smoked Paprika,282,365;🌶️ White Pepper,296,365;🌶️ Pink Peppercorns,250,365;🧂 Sea Salt,0,365;🧂 Himalayan Salt,0,365;🧂 Garlic Salt,10,365;🧅 Onion Powder,341,365;🌿 Celery Seeds,392,365;🌿 Caraway Seeds,333,365;🌿 Fennel Seeds,345,365;🌿 Dill Seeds,305,365;🍋 Lemon Pepper,250,365;🍗 Chicken Seasoning,250,365;🥒 Pickling Spice,280,365;🌶️ Gochugaru,290,365;🍙 Furikake,400,365;🌶️ Guajillo Chiles,324,365;🌿 Coriander Seeds,298,365;🫐 Juniper Berries,44,365;🧂 Chaat Masala,250,365;🥜 Dukkah,520,90;🌶️ Tajin Seasoning,0,365;🌶️ Togarashi,300,365;🌿 Epazote,32,7;🌿 Summer Savory,272,365;🌶️ Aleppo Pepper,280,365;🌶️ Sichuan Peppercorns,300,365;🌿 Nigella Seeds,345,365;🌿 Ajwain,305,365;🧂 Asafoetida,297,365;🧂 Annatto Seeds,350,365;🌶️ Ancho Chiles,281,365;🌶️ Berbere,300,365
Canned|🌽 Canned Corn,76,365;🫛 Canned Peas,70,365;🫘 Canned Beans,90,365;🍅 Canned Tomatoes,21,365;🐟 Sprats in Oil,363,365;🥫 Beef Stew,250,365;🐟 Canned Sardines,208,365;🐟 Canned Salmon,140,365;🫒 Green Olives,115,365;🫒 Black Olives,115,365;🍄 Pickled Mushrooms,22,365;🍑 Canned Peaches,60,365;🍍 Canned Pineapple,60,365;🌶️ Pickled Peppers,20,365;🍄 Canned Mushrooms,22,365;🍆 Eggplant Caviar,90,365;🥫 Canned Chickpeas,119,365;🥫 Canned Lentils,116,365;🥫 Canned Coconut Milk,230,365;🥫 Condensed Soup,60,365;🐟 Canned Pink Salmon,136,365;🥫 Canned Pate,230,365;🥫 Canned Carrot,30,365;🍒 Canned Cherries,70,365;🥫 Canned Pumpkin,34,365;🐟 Canned Mackerel,200,365;🐟 Canned Cod Liver,613,365;🫛 Canned Green Beans,20,365;🥫 Canned Artichokes,45,365;🥫 Canned Asparagus,19,365;🍐 Canned Pears,50,365;🍑 Canned Apricots,48,365;🍊 Canned Mandarins,61,365;🍒 Fruit Cocktail,60,365;🎋 Canned Bamboo Shoots,19,365;🥫 Canned Water Chestnuts,50,365;🥫 Canned Jackfruit,30,365;🫘 Baked Beans,94,365;🌶️ Canned Chili,110,365;🥫 Canned Ravioli,90,365;🍗 Canned Chicken,185,365;🍖 Canned Ham,180,365;🥒 Squash Caviar,97,365;🫑 Lecho,60,365;🌶️ Pickled Jalapenos,27,365;🍅 Canned Tomato Soup,30,365;🥫 Canned Lychees,70,365;🦀 Canned Crab,85,365;🐟 Canned Anchovies,210,365;🟣 Canned Beets,30,365;🐟 Tuna in Water,116,365;🍅 Pickled Tomatoes,15,60;🍒 Cranberry Sauce,159,30;🌶️ Chipotle in Adobo,70,30;🌴 Hearts of Palm,28,365;🥫 Canned Ackee,151,365;🥫 Spam,315,730
Ready Meals|🥙 Hummus,177,5;🍣 Sushi,150,1;🍣 Sushi Rolls,140,1;🌯 Shawarma,215,1;🍔 Burger,295,1;🌭 Hot Dog,290,1;🍕 Pizza Slice,266,2;🍗 Fried Chicken,246,2;🍖 Cutlets,230,3;🥟 Pirozhki,260,2;🥟 Cheburek,300,1;🥟 Samsa,280,1;🥞 Blini,230,3;🧀 Syrniki,220,3;🥔 Mashed Potatoes,88,3;🍚 Fried Rice,163,3;🥗 Pasta Salad,150,3;🥗 Caesar Salad,120,2;🥗 Greek Salad,105,2;🥗 Olivier Salad,198,3;🐟 Herring Under Fur Coat,180,3;🍲 Borscht Soup,49,4;🍲 Chicken Soup,40,4;🍲 Solyanka,75,4;🥣 Okroshka,60,2;🍜 Lagman,105,3;🍚 Plov,190,3;🧀 Mac and Cheese,164,3;🍝 Lasagna,135,3;🧆 Falafel,333,3;🥬 Cabbage Rolls,120,3;🍃 Dolma,180,4;🥘 Goulash,150,3;🥘 Beef Stroganoff,170,3;🍳 Scrambled Eggs,148,1;🌮 Tacos,226,2;🥪 Sandwich,250,2;🥪 Club Sandwich,230,2;🍟 Takeaway Fries,312,1;🍲 Mushroom Soup,60,4;🍕 Margherita Pizza,250,2;🍝 Spaghetti Bolognese,130,3;🍝 Carbonara,190,2;🍛 Chicken Curry,150,3;🍛 Butter Chicken,160,3;🍜 Pho,60,2;🍜 Ramen Bowl,90,2;🍱 Bento Box,170,1;🥘 Paella,160,2;🌶️ Chili Con Carne,120,3;🍲 Minestrone,40,4;🍲 Lentil Soup,70,4;🍅 Tomato Soup,40,4;🍲 Shchi,35,4;🍲 Ukha,45,3;🥗 Vinegret,90,3;🥗 Crab Salad,180,2;🥗 Coleslaw,150,3;🥗 Potato Salad,140,3;🥗 Tabbouleh,120,3;🌯 Burrito,210,2;🌯 Wrap,220,2;🥙 Gyro,215,1;🍝 Pasta Bake,160,3;🥧 Shepherd's Pie,120,3;🥟 Dim Sum,200,1;🍤 Tempura,250,1;🍣 Poke Bowl,140,1;🍗 Chicken Kiev,270,3;🍚 Risotto,150,2;🍆 Moussaka,140,3;🥞 Stuffed Blini,220,3;🥔 Draniki,200,2;🥔 Baked Potato,93,2;🍲 Kharcho,70,3;🍲 Ragout,110,3;🍳 Quiche Lorraine,290,3;🥘 Leftover Stew,110,3;🍲 Beshbarmak,180,3;🥘 Kuyrdak,230,2;🍲 Sorpa,35,3;🥟 Belyashi,300,2;🥬 Golubtsy,120,3;🍲 Holodets,180,4;🥟 Tushpara,220,2;🍖 Pulled Pork,200,4;🍲 Naryn,220,2;🥣 Kozhe,70,2;🍖 Meatloaf,210,3;🍲 Clam Chowder,90,3;🥘 Jambalaya,150,3;🍲 Gumbo,110,3;🥚 Deviled Eggs,200,2;🍔 Sloppy Joe,220,2;🥘 Lobio,140,3;🥣 Oatmeal,71,3;🥣 Overnight Oats,150,3;🍲 Dimlama,95,3;🥟 Chuchvara,220,3;🥕 Korean Carrot Salad,130,7;🍜 Funchoza Salad,150,3;🐟 Heh Fish,120,2;🍅 Achichuk Salad,30,1;🍢 Lula Kebab,270,2;🥣 Buckwheat Porridge,110,3;🥞 Oladi,230,2;🍞 French Toast,230,1;🌮 Quesadilla,290,2;🍗 Buffalo Wings,250,2;🥧 Chicken Pot Pie,240,3;🍳 Biscuits and Gravy,220,2;🥪 Philly Cheesesteak,250,1;🥘 Zharkoe,160,3;🥗 Mimosa Salad,230,2;🥗 Shalgam Salad,45,4;🍖 Sirne,210,3;🥟 Orama,210,2;🧀 Grilled Cheese Sandwich,350,1;🥪 BLT Sandwich,250,1;🍜 Chicken Noodle Soup,60,3;🌮 Fish Tacos,200,1;🍠 Sweet Potato Casserole,190,3;🌯 Breakfast Burrito,230,2;🧆 Hush Puppies,340,2;🍙 Kimbap,150,1;🥟 Fresh Tortellini,300,14
Snacks|🥔 Potato Chips,536,90;🍿 Popcorn,387,30;🌮 Nachos,489,90;🥨 Salted Crackers,430,180;🍫 Granola Bar,450,180;💪 Protein Bar,380,180;🍘 Rice Cakes,387,180;🥜 Trail Mix,462,180;🥩 Beef Jerky,410,180;🥨 Pretzel Sticks,380,180;🧀 Cheese Snacks,500,90;🥜 Roasted Chickpeas,380,90;🍫 Energy Bar,400,180;🥜 Peanut Bar,480,180;🍪 Sandwich Crackers,480,180;🧁 Halva Bar,516,180;🫘 Dried Edamame,430,180;🍌 Banana Chips,519,90;🍎 Apple Chips,240,90;🥥 Coconut Chips,600,90;🍘 Rice Crackers,390,180;🥕 Vegetable Chips,500,90;🫓 Pita Chips,450,90;🌽 Tortilla Chips,489,90;🥜 Honey Roasted Peanuts,560,180;🫛 Wasabi Peas,410,180;🍿 Caramel Popcorn,400,60;🧀 Cheese Crackers,490,180;🥩 Biltong,300,180;🦑 Dried Squid,300,180;🥓 Pork Rinds,544,90;🍪 Protein Cookies,400,180;🍎 Fruit Leather,350,180;🍬 Fruit Snacks,330,180;🥕 Veggie Sticks,40,3;🌻 Seed Mix,560,180;🍘 Senbei,380,180;🍿 Microwave Popcorn,480,180;🌰 Roasted Chestnuts,245,5;🍫 Rice Crispy Bar,410,180;🍞 Rye Croutons,410,180;🍪 Graham Crackers,430,180;🥧 Toaster Pastries,390,180;🍫 S'mores,430,30;🍿 Kettle Corn,430,60
Plant-Based|⬜ Tofu,76,7;⬜ Silken Tofu,55,7;🟫 Smoked Tofu,140,14;🟫 Tempeh,192,10;🥩 Seitan,370,10;🍔 Veggie Burger,180,5;🌭 Vegan Sausages,250,10;🧀 Vegan Cheese,280,30;🥛 Rice Milk,47,7;🥥 Coconut Yogurt,110,10;🥛 Soy Yogurt,66,10;🧈 Plant Butter,600,60;🥩 Plant-Based Mince,200,7;🍗 Vegan Nuggets,230,180;🥛 Pea Milk,40,7;🥛 Cashew Milk,25,7;🥛 Hemp Milk,46,7;🥛 Hazelnut Milk,30,7;🌱 Textured Soy Protein,330,365;🌱 Nutritional Yeast,325,365;🥛 Oat Cream,150,30;🥛 Soy Cream,180,30;🥚 Vegan Mayo,450,60;🥚 Plant-Based Egg,120,10;🫘 Okara,77,3;🫘 Yuba,233,5
World Foods|🌿 Nori Sheets,35,365;🍚 Rice Paper,333,365;🥬 Kimchi,15,60;🫚 Pickled Ginger,20,180;🥣 Miso Soup Mix,40,365;🌿 Wakame,45,365;🍡 Tteok,230,14;🥟 Wonton Wrappers,290,7;🌮 Taco Shells,467,180;🍛 Curry Roux,500,365;🫘 Refried Beans,90,365;🌶️ Enchilada Sauce,30,180;🧀 Queso Dip,180,30;🍜 Laksa Paste,200,180;🍵 Matcha Powder,324,365;🥟 Spring Roll Wrappers,290,30;🫒 Kalamata Olives,230,365;🧆 Falafel Mix,330,365;🥙 Tahini Sauce,450,30;🍚 Glutinous Rice,370,365;🍶 Mirin,240,365;🍶 Ponzu,60,180;🥫 Tamarind Paste,240,180;🌶️ Sambal Oelek,40,365;🫓 Papadums,370,365;🥟 Bao Buns,240,7;🍜 Pad Thai Noodles,360,365;🍙 Onigiri,170,1;⚫ Tapioca Pearls,358,365;🍞 Panko,395,180;🍜 Dashi Granules,224,365;🫘 Red Bean Paste,240,14;🟣 Ube Powder,350,365;🧵 Kataifi,370,60;🍙 Glutinous Rice Flour,360,365;🌊 Kombu,77,365;🐟 Bonito Flakes,330,365;🫘 Natto,212,7;🫘 Doenjang,170,365;🍋 Yuzu Kosho,90,180;🥟 Gyoza Wrappers,280,7;🥗 Seaweed Salad,70,5;🌿 Hijiki,138,365;🌿 Dulse,264,365
Baby Food|🍼 Baby Formula,510,365;🍏 Baby Fruit Puree,60,365;🥕 Baby Vegetable Puree,40,365;🥣 Baby Cereal,390,365;🍪 Baby Biscuits,420,180
''';

final foodDatabase = _raw.trim().split('\n').expand((line) {
  final i = line.indexOf('|');
  final cat = line.substring(0, i);
  return line.substring(i + 1).split(';').map((e) {
    final p = e.trim().split(',');
    final sp = p[0].indexOf(' ');
    return FoodItem(p[0].substring(0, sp), p[0].substring(sp + 1), int.parse(p[1]), cat, int.parse(p[2]));
  });
}).toList();

final foodByName = {for (final f in foodDatabase) f.name: f};
final categories = foodDatabase.map((f) => f.category).toSet().toList();
const catEmoji = {
  'Vegetables': '🥕',
  'Fruits': '🍎',
  'Berries': '🍓',
  'Dairy': '🧀',
  'Meat': '🥩',
  'Seafood': '🐟',
  'Grains': '🌾',
  'Bakery': '🍞',
  'Nuts & Legumes': '🥜',
  'Pantry': '🫙',
  'Sweets': '🍫',
  'Drinks': '🥤',
  'Frozen': '🧊',
  'Spices': '🧂',
  'Canned': '🥫',
  'Ready Meals': '🍱',
  'Snacks': '🍿',
  'Plant-Based': '🌱',
  'World Foods': '🌏',
  'Baby Food': '🍼',
};

// ───────────────────────── РЕЦЕПТЫ (граммы на всё блюдо) ─────────────────────────

final recipes = <Recipe>[
  Recipe(
    'Classic Omelette',
    '🍳',
    '10 min',
    1,
    [Ing('Eggs', 180), Ing('Milk', 60), Ing('Butter', 10)],
    [
      'Crack the eggs into a bowl, add the milk and a pinch of salt, whisk until smooth.',
      'Melt the butter in a non-stick pan over medium heat.',
      'Pour in the mixture and cook 2–3 minutes until the edges set.',
      'Fold in half, cook 1 more minute and serve hot.',
    ],
    'salt',
  ),
  Recipe(
    'Creamy Cheese Pasta',
    '🍝',
    '20 min',
    2,
    [Ing('Pasta', 200), Ing('Cheddar Cheese', 80), Ing('Butter', 20), Ing('Milk', 100)],
    [
      'Boil 2 liters of salted water and cook the pasta 9–10 minutes. Drain.',
      'Melt the butter in a pan on low heat, pour in the milk.',
      'Add grated cheese and stir 2–3 minutes until the sauce is smooth.',
      'Toss the pasta in the sauce and serve immediately.',
    ],
    'salt, black pepper',
  ),
  Recipe(
    'Fresh Summer Salad',
    '🥗',
    '5 min',
    2,
    [Ing('Tomato', 250), Ing('Cucumber', 200), Ing('Sour Cream', 60)],
    ['Wash the vegetables and cut into bite-size pieces.', 'Mix in a bowl, add the sour cream, salt and pepper.', 'Stir gently and serve right away.'],
    'salt, black pepper',
  ),
  Recipe(
    'Mashed Potatoes with Chicken',
    '🍽️',
    '35 min',
    2,
    [Ing('Potato', 400), Ing('Chicken Breast', 300), Ing('Milk', 80), Ing('Butter', 20)],
    [
      'Peel and cut the potatoes, boil in salted water 15–20 minutes until soft.',
      'Slice the chicken, season and fry in a pan 6–8 minutes until golden.',
      'Drain the potatoes, mash with warm milk and butter until creamy.',
      'Serve the chicken on top of the mash.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Fruit Yogurt Bowl',
    '🥣',
    '5 min',
    2,
    [Ing('Apple', 150), Ing('Banana', 120), Ing('Orange', 130), Ing('Yogurt', 200)],
    ['Wash and core the apple, peel the banana and orange.', 'Cut all fruit into small pieces.', 'Divide into two bowls and pour the yogurt over.'],
    'optional: honey',
  ),
  Recipe(
    'Buckwheat with Chicken',
    '🍲',
    '35 min',
    2,
    [Ing('Buckwheat', 200), Ing('Chicken Breast', 300), Ing('Onion', 100), Ing('Carrot', 100), Ing('Vegetable Oil', 15)],
    [
      'Rinse the buckwheat. Boil it in 400 ml of salted water, covered, for 15 minutes.',
      'Dice the onion and grate the carrot, fry them in oil for 5 minutes.',
      'Add the diced chicken and cook 8–10 minutes until done.',
      'Mix with the buckwheat and let it rest 5 minutes under a lid.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Syrniki (Cottage Cheese Pancakes)',
    '🥞',
    '25 min',
    3,
    [Ing('Cottage Cheese', 400), Ing('Eggs', 60), Ing('Flour', 60), Ing('Sugar', 30), Ing('Vegetable Oil', 30)],
    [
      'Mash the cottage cheese, mix with the egg, sugar and a pinch of salt.',
      'Add the flour and knead a soft dough.',
      'Shape into small patties and dip in a little flour.',
      'Fry in oil 3 minutes per side on medium heat. Serve with sour cream or jam.',
    ],
    'salt',
  ),
  Recipe(
    'Classic Borscht',
    '🍅',
    '2 h',
    4,
    [Ing('Beef', 400), Ing('Beetroot', 250), Ing('Cabbage', 250), Ing('Potato', 250), Ing('Carrot', 100), Ing('Onion', 100), Ing('Sour Cream', 80)],
    [
      'Cover the beef with 2.5 liters of cold water, bring to a boil and simmer 1 hour 15 minutes.',
      'Grate the beetroot and carrot, dice the onion, fry 10 minutes.',
      'Add the diced potatoes to the broth, cook 10 minutes.',
      'Add the shredded cabbage and the fried vegetables, cook 15 more minutes.',
      'Season, rest 10 minutes and serve with sour cream.',
    ],
    'salt, bay leaf, pepper',
  ),
  Recipe(
    'Pelmeni with Sour Cream',
    '🥟',
    '15 min',
    2,
    [Ing('Pelmeni', 500), Ing('Sour Cream', 60), Ing('Butter', 10)],
    ['Boil 2 liters of salted water with a bay leaf.', 'Add the frozen pelmeni and stir. Cook 8–10 minutes after they float up.', 'Drain, add the butter and serve with sour cream.'],
    'salt, bay leaf',
  ),
  Recipe(
    'Baked Salmon with Potatoes',
    '🐟',
    '40 min',
    2,
    [Ing('Salmon', 300), Ing('Potato', 400), Ing('Lemon', 40), Ing('Olive Oil', 20)],
    [
      'Preheat the oven to 200 °C. Slice the potatoes thinly.',
      'Toss the potatoes with half of the oil and salt, bake 15 minutes.',
      'Place the salmon on top, drizzle with the remaining oil and lemon juice.',
      'Bake 15–18 more minutes until the fish flakes easily.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Olivier Salad',
    '🥗',
    '45 min',
    4,
    [Ing('Potato', 300), Ing('Carrot', 150), Ing('Eggs', 180), Ing('Boiled Sausage', 250), Ing('Pickles', 120), Ing('Green Peas', 150), Ing('Mayonnaise', 100)],
    [
      'Boil the potatoes and carrots in their skins 25 minutes, hard-boil the eggs 10 minutes.',
      'Cool everything, then peel and dice into equal small cubes.',
      'Dice the sausage and pickles, add the peas.',
      'Mix with mayonnaise, season, and chill for 30 minutes before serving.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Beef Plov',
    '🍚',
    '1 h 30 min',
    4,
    [Ing('Rice', 400), Ing('Beef', 400), Ing('Carrot', 300), Ing('Onion', 200), Ing('Garlic', 30), Ing('Vegetable Oil', 80)],
    [
      'Heat the oil in a heavy pot and fry the diced onion until golden.',
      'Add the beef cubes and brown for 10 minutes, then add the carrot strips and cook 10 more.',
      'Season, pour in 100 ml of water and simmer covered for 40 minutes.',
      'Spread the washed rice on top, add water 1.5 cm above the rice and push the garlic in.',
      'Cook on low heat covered for 20 minutes without stirring, then mix and serve.',
    ],
    'salt, cumin, pepper',
  ),
  // ── Zero-waste рецепты: превращают «почти испорченное» в еду ──
  Recipe(
    'Overripe Banana Bread',
    '🍌',
    '1 h 10 min',
    8,
    [Ing('Banana', 360), Ing('Flour', 250), Ing('Eggs', 120), Ing('Sugar', 120), Ing('Butter', 100)],
    [
      'Preheat the oven to 180 °C. The browner the bananas, the sweeter the bread!',
      'Mash the bananas with a fork, mix in the melted butter, sugar and eggs.',
      'Fold in the flour with a pinch of salt and baking soda until just combined.',
      'Pour into a lined loaf tin and bake 55–60 minutes until a toothpick comes out clean.',
    ],
    'salt, baking soda',
    zeroWaste: true,
  ),
  Recipe(
    'Leftover Fried Rice',
    '🍚',
    '15 min',
    2,
    [Ing('Rice', 150), Ing('Eggs', 120), Ing('Carrot', 80), Ing('Green Peas', 80), Ing('Soy Sauce', 30), Ing('Vegetable Oil', 15)],
    [
      'Cook the rice (or use yesterday\'s — cold rice fries best).',
      'Fry the diced carrot and peas in hot oil for 3 minutes.',
      'Push the veggies aside, scramble the eggs in the same pan.',
      'Add the rice and soy sauce, stir-fry on high heat for 3–4 minutes.',
    ],
    'any leftover veggies',
    zeroWaste: true,
  ),
  Recipe(
    'Fridge-Clearing Frittata',
    '🍳',
    '20 min',
    3,
    [Ing('Eggs', 300), Ing('Potato', 200), Ing('Bell Pepper', 120), Ing('Cheddar Cheese', 60), Ing('Spinach', 60)],
    [
      'Boil or fry the diced potato until soft. Any leftover veggies work here!',
      'Whisk the eggs with salt and grated cheese.',
      'Fry the pepper and spinach 2 minutes, add potatoes, pour the eggs over.',
      'Cook on low heat 5 minutes, then finish under the oven grill for 3 minutes.',
    ],
    'salt, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Everything Veggie Soup',
    '🥣',
    '40 min',
    4,
    [Ing('Potato', 300), Ing('Carrot', 150), Ing('Onion', 100), Ing('Cabbage', 200), Ing('Zucchini', 200)],
    [
      'Soft or wrinkly vegetables are perfect here — just cut off any bad spots.',
      'Fry the onion and carrot in a pot for 5 minutes.',
      'Add the diced potato, cabbage and zucchini, cover with 1.5 liters of water.',
      'Simmer 25 minutes, season. Blend it if you like it creamy.',
    ],
    'salt, bay leaf, herbs',
    zeroWaste: true,
  ),
  Recipe(
    'Rescue Smoothie',
    '🥤',
    '5 min',
    2,
    [Ing('Banana', 120), Ing('Frozen Berries', 150), Ing('Kefir', 300)],
    ['Freeze bananas and berries before they go bad — they make smoothies extra thick.', 'Put everything into a blender.', 'Blend 1 minute until smooth and drink right away.'],
    'optional: honey, oats',
    zeroWaste: true,
  ),
  Recipe(
    'Stale Bread Croutons',
    '🍞',
    '15 min',
    4,
    [Ing('White Bread', 200), Ing('Olive Oil', 30), Ing('Garlic', 10)],
    [
      'Cut the dry bread into small cubes — stale bread works even better.',
      'Toss with oil, crushed garlic and a pinch of salt.',
      'Bake at 190 °C for 10–12 minutes, stirring once, until golden.',
      'Keep in a jar for up to a week. Great for soups and salads!',
    ],
    'salt, dried herbs',
    zeroWaste: true,
  ),
  Recipe(
    'Kefir Pancakes (Oladyi)',
    '🥞',
    '25 min',
    3,
    [Ing('Kefir', 400), Ing('Flour', 250), Ing('Eggs', 60), Ing('Sugar', 30), Ing('Vegetable Oil', 30)],
    [
      'Sour or old kefir is perfect — it makes pancakes fluffier.',
      'Mix kefir, egg, sugar, a pinch of salt and soda. Add flour to make a thick batter.',
      'Spoon small pancakes onto a hot oiled pan.',
      'Fry 2 minutes per side until golden. Serve with jam or sour cream.',
    ],
    'salt, baking soda',
    zeroWaste: true,
  ),
  Recipe(
    'Shakshuka',
    '🍅',
    '25 min',
    2,
    [Ing('Eggs', 240), Ing('Tomato', 400), Ing('Bell Pepper', 150), Ing('Onion', 80)],
    [
      'Soft tomatoes are ideal — chop them together with the pepper and onion.',
      'Fry the onion and pepper 5 minutes, add tomatoes and simmer 10 minutes into a sauce.',
      'Make 4 little wells and crack an egg into each.',
      'Cover and cook 5–6 minutes until the whites are set.',
    ],
    'salt, paprika, cumin',
    zeroWaste: true,
  ),
  Recipe(
    'Apple Crumble',
    '🍏',
    '45 min',
    4,
    [Ing('Apple', 500), Ing('Oats', 100), Ing('Butter', 80), Ing('Sugar', 60)],
    [
      'Wrinkly apples are welcome! Core and slice them, put into a baking dish.',
      'Rub the butter, oats and sugar together into crumbs.',
      'Cover the apples with the crumbs.',
      'Bake at 180 °C for 30–35 minutes until golden and bubbling.',
    ],
    'cinnamon',
    zeroWaste: true,
  ),
  Recipe(
    'Tomato Bruschetta',
    '🥖',
    '10 min',
    2,
    [Ing('Baguette', 150), Ing('Tomato', 200), Ing('Garlic', 10), Ing('Olive Oil', 20), Ing('Basil', 10)],
    ['Slice a day-old baguette and toast the slices in a dry pan.', 'Rub each slice with a cut garlic clove.', 'Top with diced tomatoes, torn basil, salt and a drizzle of oil.'],
    'salt',
    zeroWaste: true,
  ),
  // ── Классика на каждый день ──
  Recipe(
    'Greek Salad',
    '🥗',
    '10 min',
    3,
    [Ing('Tomato', 300), Ing('Cucumber', 250), Ing('Bell Pepper', 150), Ing('Red Onion', 60), Ing('Feta', 150), Ing('Black Olives', 60), Ing('Olive Oil', 30)],
    [
      'Cut the tomatoes, cucumber and pepper into large chunks, slice the onion thinly.',
      'Put everything in a bowl and add the olives.',
      'Place the feta on top as a whole block or in big cubes.',
      'Drizzle with olive oil, sprinkle with oregano and serve.',
    ],
    'salt, oregano',
  ),
  Recipe(
    'Chicken Caesar Salad',
    '🥗',
    '25 min',
    2,
    [Ing('Romaine Lettuce', 300), Ing('Chicken Breast', 250), Ing('Parmesan', 40), Ing('White Bread', 100), Ing('Caesar Dressing', 60)],
    [
      'Cut the bread into cubes and toast in a dry pan until golden.',
      'Season the chicken and fry 6–7 minutes per side, then slice.',
      'Tear the lettuce, toss with the dressing.',
      'Top with chicken, croutons and shaved Parmesan.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Chicken Noodle Soup',
    '🍜',
    '45 min',
    4,
    [Ing('Chicken Thighs', 400), Ing('Egg Noodles', 150), Ing('Carrot', 120), Ing('Onion', 100), Ing('Celery', 80)],
    [
      'Cover the chicken with 2 liters of water, bring to a boil and skim the foam.',
      'Add the whole onion and simmer 25 minutes, then take out the chicken and shred it.',
      'Add sliced carrot and celery, cook 8 minutes.',
      'Add the noodles and the chicken, cook 5 more minutes and season.',
    ],
    'salt, pepper, bay leaf',
  ),
  Recipe(
    'Spaghetti Bolognese',
    '🍝',
    '50 min',
    4,
    [Ing('Spaghetti', 400), Ing('Ground Beef', 400), Ing('Canned Tomatoes', 400), Ing('Onion', 100), Ing('Carrot', 80), Ing('Garlic', 10), Ing('Olive Oil', 20)],
    [
      'Fry the finely chopped onion, carrot and garlic in oil for 6 minutes.',
      'Add the beef and brown it, breaking it up with a spoon.',
      'Pour in the tomatoes and simmer on low heat for 30 minutes.',
      'Cook the spaghetti, drain and toss with the sauce.',
    ],
    'salt, pepper, oregano',
  ),
  Recipe(
    'Pasta Carbonara',
    '🍝',
    '20 min',
    3,
    [Ing('Spaghetti', 300), Ing('Bacon', 150), Ing('Eggs', 120), Ing('Parmesan', 60)],
    [
      'Cook the spaghetti in salted water. Save a cup of the pasta water.',
      'Fry the diced bacon until crispy.',
      'Whisk the eggs with grated Parmesan and lots of black pepper.',
      'Off the heat, toss the hot pasta with bacon and the egg mix, adding pasta water until creamy.',
    ],
    'salt, black pepper',
  ),
  Recipe(
    'Pesto Pasta',
    '🍝',
    '15 min',
    3,
    [Ing('Penne', 300), Ing('Pesto', 100), Ing('Parmesan', 30), Ing('Cherry Tomato', 200)],
    ['Cook the penne in salted water.', 'Halve the cherry tomatoes.', 'Drain the pasta and mix with pesto and tomatoes.', 'Serve with grated Parmesan on top.'],
    'salt',
  ),
  Recipe(
    'Homemade Mac and Cheese',
    '🧀',
    '30 min',
    4,
    [Ing('Macaroni', 300), Ing('Cheddar Cheese', 200), Ing('Milk', 400), Ing('Butter', 40), Ing('Flour', 30)],
    [
      'Cook the macaroni and drain.',
      'Melt the butter, stir in the flour and cook 1 minute.',
      'Slowly whisk in the milk and cook until it thickens.',
      'Melt in the grated cheese, mix with the pasta and serve.',
    ],
    'salt, mustard, pepper',
  ),
  Recipe(
    'Chicken Stir-Fry',
    '🥢',
    '25 min',
    3,
    [
      Ing('Chicken Breast', 400),
      Ing('Broccoli', 250),
      Ing('Bell Pepper', 150),
      Ing('Carrot', 100),
      Ing('Soy Sauce', 40),
      Ing('Garlic', 10),
      Ing('Ginger', 10),
      Ing('Rice', 250),
      Ing('Vegetable Oil', 20),
    ],
    [
      'Cook the rice.',
      'Fry thin chicken strips in hot oil for 5 minutes, take them out.',
      'Stir-fry the vegetables with garlic and ginger for 4 minutes.',
      'Return the chicken, add soy sauce, toss 1 minute and serve with rice.',
    ],
    'sesame seeds, chili',
  ),
  Recipe(
    'Beef Stroganoff',
    '🥘',
    '35 min',
    4,
    [Ing('Beef', 500), Ing('Mushrooms', 250), Ing('Onion', 120), Ing('Sour Cream', 200), Ing('Butter', 30), Ing('Flour', 15)],
    [
      'Cut the beef into thin strips and dust with flour.',
      'Brown the beef quickly in butter and take it out.',
      'Fry the onion and mushrooms 8 minutes.',
      'Return the beef, stir in the sour cream and simmer 5 minutes. Great with mashed potatoes.',
    ],
    'salt, pepper, paprika',
  ),
  Recipe(
    'Chicken Curry',
    '🍛',
    '40 min',
    4,
    [Ing('Chicken Thighs', 500), Ing('Onion', 150), Ing('Canned Tomatoes', 400), Ing('Coconut Milk', 200), Ing('Curry Powder', 15), Ing('Garlic', 10), Ing('Ginger', 10), Ing('Rice', 300)],
    [
      'Fry the onion until soft, add garlic, ginger and curry powder for 1 minute.',
      'Add the chicken pieces and brown them.',
      'Pour in the tomatoes and coconut milk, simmer 25 minutes.',
      'Serve with rice.',
    ],
    'salt, oil',
  ),
  Recipe(
    'Red Lentil Soup',
    '🍲',
    '35 min',
    4,
    [Ing('Red Lentils', 250), Ing('Carrot', 150), Ing('Onion', 120), Ing('Potato', 200), Ing('Tomato Paste', 30), Ing('Olive Oil', 20)],
    [
      'Fry the onion and carrot in oil for 5 minutes, stir in the tomato paste.',
      'Add rinsed lentils, diced potato and 1.5 liters of water.',
      'Simmer 25 minutes until everything is soft.',
      'Blend until smooth and season. Add a squeeze of lemon.',
    ],
    'salt, cumin, lemon',
  ),
  Recipe(
    'Chili Con Carne',
    '🌶️',
    '50 min',
    4,
    [Ing('Ground Beef', 500), Ing('Canned Beans', 400), Ing('Canned Tomatoes', 400), Ing('Onion', 150), Ing('Bell Pepper', 150), Ing('Chili Pepper', 10)],
    [
      'Fry the onion and pepper, add the beef and brown it.',
      'Add chopped chili, tomatoes and spices.',
      'Simmer 30 minutes, then add the beans and cook 10 more.',
      'Serve with rice, bread or tortilla chips.',
    ],
    'salt, cumin, paprika',
  ),
  Recipe(
    'Mushroom Risotto',
    '🍚',
    '40 min',
    3,
    [Ing('Arborio Rice', 300), Ing('Champignons', 300), Ing('Onion', 100), Ing('Parmesan', 50), Ing('Butter', 40), Ing('White Wine', 100)],
    [
      'Fry the sliced mushrooms in half the butter and set aside.',
      'Soften the onion, add the rice and toast 2 minutes. Pour in the wine.',
      'Add hot water or stock one ladle at a time, stirring, for 18–20 minutes.',
      'Stir in mushrooms, the rest of the butter and Parmesan.',
    ],
    'salt, stock',
  ),
  Recipe(
    'Tuna Pasta Salad',
    '🥗',
    '20 min',
    3,
    [Ing('Fusilli', 250), Ing('Canned Tuna', 160), Ing('Canned Corn', 150), Ing('Cucumber', 150), Ing('Mayonnaise', 60)],
    ['Cook the pasta, rinse with cold water.', 'Dice the cucumber, drain the tuna and corn.', 'Mix everything with mayonnaise and season.'],
    'salt, pepper, lemon',
  ),
  Recipe(
    'Stuffed Peppers',
    '🫑',
    '1 h',
    4,
    [Ing('Bell Pepper', 600), Ing('Ground Beef', 300), Ing('Rice', 100), Ing('Onion', 80), Ing('Carrot', 80), Ing('Tomato Paste', 40), Ing('Sour Cream', 100)],
    [
      'Half-cook the rice for 8 minutes. Fry the onion and carrot.',
      'Mix the beef, rice and half of the vegetables, season.',
      'Cut the tops off the peppers, remove seeds and stuff them.',
      'Put in a pot, cover with water mixed with tomato paste and the rest of the vegetables. Simmer 40 minutes. Serve with sour cream.',
    ],
    'salt, pepper',
  ),
  Recipe(
    'Golubtsy (Cabbage Rolls)',
    '🥬',
    '1 h 20 min',
    4,
    [Ing('Cabbage', 800), Ing('Minced Pork', 400), Ing('Rice', 100), Ing('Onion', 80), Ing('Carrot', 80), Ing('Tomato Paste', 50)],
    [
      'Blanch the cabbage head in boiling water and separate the soft leaves.',
      'Mix the meat with half-cooked rice and fried onion.',
      'Wrap a spoon of filling in each leaf.',
      'Lay in a pot, add carrot, tomato paste and water. Simmer 50 minutes.',
    ],
    'salt, pepper, bay leaf',
  ),
  Recipe(
    'Chicken Caesar Wrap',
    '🌯',
    '15 min',
    2,
    [Ing('Tortilla', 240), Ing('Chicken Breast', 250), Ing('Romaine Lettuce', 100), Ing('Parmesan', 30), Ing('Caesar Dressing', 50)],
    ['Fry and slice the chicken.', 'Spread dressing on the tortillas.', 'Add lettuce, chicken and Parmesan, roll up tightly and cut in half.'],
    'pepper',
  ),
  Recipe(
    'Egg Fried Noodles',
    '🍜',
    '15 min',
    2,
    [Ing('Egg Noodles', 250), Ing('Eggs', 120), Ing('Bok Choy', 200), Ing('Soy Sauce', 30), Ing('Spring Onion', 30), Ing('Vegetable Oil', 15)],
    ['Cook the noodles and drain.', 'Scramble the eggs in hot oil, push aside.', 'Add bok choy and fry 2 minutes, then add noodles and soy sauce.', 'Toss everything together, top with spring onion.'],
    'chili flakes',
  ),
  Recipe(
    'Teriyaki Salmon Bowl',
    '🐟',
    '30 min',
    2,
    [Ing('Salmon', 400), Ing('Teriyaki Sauce', 80), Ing('Rice', 250), Ing('Broccoli', 250), Ing('Sesame Seeds', 10)],
    [
      'Cook the rice and steam the broccoli.',
      'Fry the salmon skin-side down 4 minutes, flip and cook 2 more.',
      'Pour the teriyaki sauce in the pan and glaze the fish for 1 minute.',
      'Serve on rice with broccoli and sesame seeds.',
    ],
    '',
  ),
  Recipe(
    'Fish Tacos',
    '🌮',
    '25 min',
    3,
    [Ing('Cod', 400), Ing('Tortilla', 240), Ing('Red Cabbage', 150), Ing('Lime', 60), Ing('Sour Cream', 100), Ing('Cilantro', 15)],
    [
      'Season the fish with salt, paprika and lime zest, fry 3 minutes per side.',
      'Shred the cabbage thinly and mix with lime juice.',
      'Warm the tortillas, add fish, cabbage, sour cream and cilantro.',
    ],
    'salt, paprika',
  ),
  Recipe(
    'Overnight Oats',
    '🥣',
    '5 min + night',
    2,
    [Ing('Rolled Oats', 100), Ing('Milk', 200), Ing('Yogurt', 100), Ing('Banana', 120), Ing('Honey', 20)],
    ['Mix oats, milk, yogurt and honey in a jar.', 'Close and leave in the fridge overnight.', 'In the morning top with sliced banana.'],
    'optional: cinnamon, nuts',
  ),
  Recipe(
    'Fluffy Pancakes',
    '🥞',
    '20 min',
    3,
    [Ing('Flour', 200), Ing('Milk', 300), Ing('Eggs', 120), Ing('Sugar', 30), Ing('Butter', 30)],
    ['Mix flour, sugar, a pinch of salt and baking powder.', 'Whisk in the milk, eggs and melted butter.', 'Cook small pancakes on a hot pan 2 minutes per side.'],
    'salt, baking powder',
  ),
  Recipe(
    'Russian Blini',
    '🥞',
    '30 min',
    4,
    [Ing('Flour', 250), Ing('Milk', 500), Ing('Eggs', 120), Ing('Sugar', 30), Ing('Vegetable Oil', 30)],
    [
      'Whisk the eggs with sugar and salt, add half the milk.',
      'Add the flour, whisk until smooth, then the rest of the milk and the oil.',
      'Pour a thin layer into a hot pan, cook 1 minute per side.',
      'Serve with sour cream, jam or leftover fillings.',
    ],
    'salt',
  ),
  Recipe(
    'Draniki (Potato Pancakes)',
    '🥔',
    '35 min',
    3,
    [Ing('Potato', 600), Ing('Onion', 80), Ing('Eggs', 60), Ing('Flour', 40), Ing('Vegetable Oil', 50), Ing('Sour Cream', 100)],
    ['Grate the potatoes and onion, squeeze out the liquid.', 'Mix with egg, flour and salt.', 'Fry spoonfuls in hot oil 3–4 minutes per side until crispy.', 'Serve hot with sour cream.'],
    'salt, pepper',
  ),
  Recipe(
    'Okroshka',
    '🥣',
    '30 min',
    4,
    [Ing('Kefir', 1000), Ing('Potato', 300), Ing('Cucumber', 200), Ing('Radish', 150), Ing('Eggs', 180), Ing('Dill', 20), Ing('Boiled Sausage', 200)],
    [
      'Boil and cool the potatoes and eggs.',
      'Dice potatoes, eggs, cucumber, radish and sausage.',
      'Chop the dill, mix everything and pour over cold kefir.',
      'Season and serve chilled — perfect for hot days.',
    ],
    'salt, mineral water',
  ),
  Recipe(
    'Vinegret Salad',
    '🥗',
    '1 h',
    4,
    [Ing('Beetroot', 300), Ing('Potato', 300), Ing('Carrot', 200), Ing('Pickles', 150), Ing('Sauerkraut', 150), Ing('Vegetable Oil', 40)],
    ['Boil the beetroot, potatoes and carrots until soft, then cool.', 'Dice everything into small cubes, together with the pickles.', 'Add sauerkraut and oil, mix and season.'],
    'salt',
  ),
  Recipe(
    'Shchi (Cabbage Soup)',
    '🍲',
    '1 h 30 min',
    5,
    [Ing('Beef', 300), Ing('Cabbage', 400), Ing('Potato', 300), Ing('Carrot', 100), Ing('Onion', 100), Ing('Tomato Paste', 30)],
    [
      'Simmer the beef in 2.5 liters of water for 1 hour.',
      'Add shredded cabbage and diced potatoes, cook 15 minutes.',
      'Fry onion and carrot with tomato paste, add to the soup.',
      'Cook 10 more minutes, season and serve with sour cream.',
    ],
    'salt, bay leaf, dill',
  ),
  Recipe(
    'Classic Guacamole',
    '🥑',
    '10 min',
    4,
    [Ing('Avocado', 300), Ing('Lime', 40), Ing('Tomato', 100), Ing('Red Onion', 40), Ing('Cilantro', 10)],
    ['Mash the avocados with lime juice and salt.', 'Fold in the diced tomato, onion and chopped cilantro.', 'Serve right away with chips or on toast.'],
    'salt, chili',
  ),
  Recipe(
    'Homemade Hummus',
    '🧆',
    '10 min',
    6,
    [Ing('Canned Chickpeas', 400), Ing('Tahini', 60), Ing('Lemon', 40), Ing('Garlic', 10), Ing('Olive Oil', 30)],
    ['Drain the chickpeas, keep a little of the liquid.', 'Blend chickpeas, tahini, lemon juice and garlic until smooth.', 'Add some liquid to loosen it, season, drizzle with oil.'],
    'salt, cumin, paprika',
  ),
  Recipe(
    'Berry Smoothie Bowl',
    '🫐',
    '10 min',
    2,
    [Ing('Frozen Berries', 200), Ing('Banana', 120), Ing('Greek Yogurt', 200), Ing('Granola', 60)],
    ['Blend the berries, banana and yogurt into a thick smoothie.', 'Pour into bowls.', 'Top with granola and any fruit you have.'],
    'optional: honey',
  ),
  Recipe(
    'Roasted Chicken Thighs with Veggies',
    '🍗',
    '55 min',
    4,
    [Ing('Chicken Thighs', 600), Ing('Potato', 500), Ing('Carrot', 200), Ing('Onion', 150), Ing('Olive Oil', 30), Ing('Garlic', 10)],
    ['Preheat the oven to 200 °C.', 'Cut the vegetables into chunks, toss with oil, garlic and spices.', 'Lay the chicken on top, season well.', 'Roast 45 minutes until golden and crispy.'],
    'salt, paprika, thyme',
  ),
  Recipe(
    'Tvorog Casserole (Zapekanka)',
    '🍰',
    '50 min',
    4,
    [Ing('Cottage Cheese', 500), Ing('Eggs', 120), Ing('Semolina', 60), Ing('Sugar', 60), Ing('Sour Cream', 100)],
    ['Mix cottage cheese, eggs, sugar and semolina, rest 15 minutes.', 'Put into a greased dish and smooth the top with sour cream.', 'Bake at 180 °C for 35–40 minutes until golden.'],
    'vanilla, raisins',
  ),
  Recipe(
    'Creamy Mushroom Soup',
    '🍄',
    '40 min',
    4,
    [Ing('Mushrooms', 300), Ing('Potato', 300), Ing('Onion', 100), Ing('Carrot', 100), Ing('Sour Cream', 60)],
    ['Fry the onion, carrot and sliced mushrooms 10 minutes.', 'Add diced potatoes and 1.5 liters of water, cook 20 minutes.', 'Blend half of the soup for creaminess, stir in sour cream.'],
    'salt, pepper, dill',
  ),
  Recipe(
    'Pumpkin Soup',
    '🎃',
    '40 min',
    4,
    [Ing('Pumpkin', 800), Ing('Onion', 100), Ing('Carrot', 100), Ing('Heavy Cream', 100), Ing('Ginger', 10)],
    [
      'Fry the onion, carrot and ginger 5 minutes.',
      'Add cubed pumpkin and water to cover, simmer 20 minutes.',
      'Blend until smooth and stir in the cream.',
      'Top with roasted pumpkin seeds — don\'t throw them away!',
    ],
    'salt, nutmeg',
  ),
  Recipe(
    'Teriyaki Tofu Bowl',
    '🌱',
    '25 min',
    3,
    [Ing('Tofu', 400), Ing('Teriyaki Sauce', 80), Ing('Rice', 250), Ing('Edamame', 150), Ing('Carrot', 100)],
    ['Press the tofu with a towel and cut into cubes.', 'Fry until crispy on all sides, add teriyaki and glaze.', 'Serve on rice with edamame and grated carrot.'],
    'sesame seeds, oil',
  ),
  Recipe(
    'Lentil Bolognese',
    '🍝',
    '40 min',
    4,
    [Ing('Green Lentils', 200), Ing('Spaghetti', 300), Ing('Canned Tomatoes', 400), Ing('Onion', 100), Ing('Carrot', 100), Ing('Garlic', 10)],
    ['Fry onion, carrot and garlic until soft.', 'Add lentils, tomatoes and 400 ml water, simmer 25 minutes.', 'Cook the spaghetti and serve with the sauce.'],
    'salt, oregano, oil',
  ),
  Recipe(
    'Beet Salad with Prunes',
    '🟣',
    '15 min',
    4,
    [Ing('Beetroot', 400), Ing('Walnuts', 50), Ing('Garlic', 10), Ing('Mayonnaise', 60), Ing('Prunes', 60)],
    ['Boil or bake the beetroot, then grate it.', 'Chop the walnuts and prunes, crush the garlic.', 'Mix everything with mayonnaise and season.'],
    'salt',
  ),
  Recipe(
    'Grilled Cheese Sandwich',
    '🥪',
    '10 min',
    2,
    [Ing('Toast Bread', 120), Ing('Cheddar Cheese', 80), Ing('Butter', 20)],
    ['Butter the outside of the bread slices.', 'Put cheese between two slices.', 'Fry on medium heat 3 minutes per side until golden and melty.'],
    '',
  ),
  Recipe(
    'Buckwheat with Mushrooms',
    '🍄',
    '30 min',
    3,
    [Ing('Buckwheat', 200), Ing('Mushrooms', 300), Ing('Onion', 100), Ing('Butter', 30)],
    ['Cook the buckwheat in 400 ml salted water for 15 minutes.', 'Fry the onion and mushrooms in butter until golden.', 'Mix with the buckwheat and rest 5 minutes under a lid.'],
    'salt, pepper',
  ),
  Recipe(
    'Baked Potatoes with Cheese',
    '🥔',
    '1 h',
    4,
    [Ing('Potato', 800), Ing('Cheddar Cheese', 100), Ing('Sour Cream', 100), Ing('Butter', 30)],
    ['Wash the potatoes, prick with a fork and bake at 200 °C for 50 minutes.', 'Cut a cross on top, squeeze open, add butter.', 'Top with grated cheese and sour cream.'],
    'salt, chives',
  ),
  // ── Zero-waste: из остатков и «почти испорченного» ──
  Recipe(
    'Veggie Curry from Odds and Ends',
    '🍛',
    '35 min',
    4,
    [Ing('Cauliflower', 400), Ing('Potato', 300), Ing('Green Peas', 150), Ing('Onion', 100), Ing('Coconut Milk', 200), Ing('Curry Powder', 15)],
    [
      'Any tired vegetables work here — cut off bad spots and chop the rest.',
      'Fry the onion with curry powder for 2 minutes.',
      'Add potatoes, cauliflower and coconut milk with a cup of water. Simmer 20 minutes.',
      'Stir in the peas, cook 3 minutes and serve with rice or bread.',
    ],
    'salt, oil',
    zeroWaste: true,
  ),
  Recipe(
    'Ratatouille',
    '🍆',
    '50 min',
    4,
    [Ing('Eggplant', 300), Ing('Zucchini', 300), Ing('Bell Pepper', 200), Ing('Tomato', 400), Ing('Onion', 100), Ing('Olive Oil', 40), Ing('Garlic', 10)],
    [
      'Soft vegetables are perfect here! Dice everything into similar cubes.',
      'Fry the onion and garlic, add eggplant and pepper, cook 10 minutes.',
      'Add zucchini and tomatoes, simmer 25 minutes.',
      'Season with herbs. Even better the next day.',
    ],
    'salt, thyme, basil',
    zeroWaste: true,
  ),
  Recipe(
    'Clean-the-Fridge Quesadilla',
    '🌮',
    '15 min',
    2,
    [Ing('Tortilla', 240), Ing('Cheddar Cheese', 150), Ing('Bell Pepper', 100), Ing('Canned Corn', 100), Ing('Canned Beans', 100)],
    ['Use any leftovers: half a pepper, some corn, beans or chicken.', 'Spread cheese and fillings on half of each tortilla, fold.', 'Fry on a dry pan 2–3 minutes per side until the cheese melts.'],
    'salsa, sour cream',
    zeroWaste: true,
  ),
  Recipe(
    'Leftover Veggie Stir-Fry',
    '🥦',
    '20 min',
    3,
    [Ing('Broccoli', 200), Ing('Carrot', 150), Ing('Bell Pepper', 150), Ing('Mushrooms', 150), Ing('Soy Sauce', 30), Ing('Garlic', 10), Ing('Rice', 200)],
    [
      'Slice the broccoli stems too — they are sweet and crunchy!',
      'Stir-fry all vegetables on high heat 5 minutes.',
      'Add garlic and soy sauce, toss 1 minute.',
      'Serve with rice (yesterday\'s rice is perfect).',
    ],
    'oil, chili',
    zeroWaste: true,
  ),
  Recipe(
    'Potato Peel Crisps',
    '🥔',
    '20 min',
    2,
    [Ing('Potato', 300), Ing('Olive Oil', 20), Ing('Paprika', 5)],
    ['Peeled potatoes for mash? Keep the clean peels!', 'Toss the peels with oil, salt and paprika.', 'Bake at 200 °C for 12–15 minutes until crispy. A free snack!'],
    'salt',
    zeroWaste: true,
  ),
  Recipe(
    'Broccoli Stem Soup',
    '🥦',
    '30 min',
    3,
    [Ing('Broccoli', 400), Ing('Potato', 200), Ing('Onion', 100), Ing('Milk', 200), Ing('Butter', 20)],
    ['Use the whole broccoli — peel the stems and chop them.', 'Soften the onion in butter, add potato, broccoli and 800 ml water.', 'Simmer 15 minutes, add milk and blend until creamy.'],
    'salt, pepper, nutmeg',
    zeroWaste: true,
  ),
  Recipe(
    '2-Ingredient Banana Pancakes',
    '🍌',
    '15 min',
    2,
    [Ing('Banana', 240), Ing('Eggs', 120), Ing('Oats', 60)],
    ['Mash very ripe bananas — the spottier the better.', 'Mix with eggs and oats.', 'Fry small pancakes on low heat 2 minutes per side.'],
    'cinnamon',
    zeroWaste: true,
  ),
  Recipe(
    'Panzanella (Stale Bread Salad)',
    '🥖',
    '15 min',
    3,
    [Ing('White Bread', 250), Ing('Tomato', 400), Ing('Cucumber', 200), Ing('Red Onion', 60), Ing('Olive Oil', 40), Ing('Basil', 10)],
    ['Tear stale bread into chunks — it soaks up juice like a sponge.', 'Chop the tomatoes, cucumber and onion, mix with the bread.', 'Dress with oil, salt and vinegar. Rest 10 minutes, add basil.'],
    'salt, vinegar',
    zeroWaste: true,
  ),
  Recipe(
    'Leftover Pasta Frittata',
    '🍝',
    '20 min',
    3,
    [Ing('Pasta', 150), Ing('Eggs', 240), Ing('Cheddar Cheese', 60), Ing('Milk', 50)],
    ['Got cooked pasta left over? Perfect.', 'Whisk eggs, milk and grated cheese, mix in the pasta.', 'Cook in an oiled pan on low heat 8 minutes, flip or grill the top.'],
    'salt, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Herb Stem Pesto',
    '🌿',
    '10 min',
    6,
    [Ing('Parsley', 60), Ing('Basil', 30), Ing('Garlic', 10), Ing('Walnuts', 50), Ing('Olive Oil', 80), Ing('Parmesan', 40)],
    [
      'Don\'t throw away herb stems or wilted leaves — they are full of flavor.',
      'Blend herbs, garlic, nuts and cheese, slowly adding oil.',
      'Keep in a jar under a layer of oil for a week, or freeze in portions.',
    ],
    'salt, lemon',
    zeroWaste: true,
  ),
  Recipe(
    'Soft Fruit Compote',
    '🍐',
    '25 min',
    6,
    [Ing('Apple', 300), Ing('Pear', 200), Ing('Plum', 200), Ing('Sugar', 60)],
    ['Bruised or soft fruit? Cut off the bad bits and chop the rest.', 'Cover with 2 liters of water, add sugar and bring to a boil.', 'Simmer 10 minutes, cool and drink cold. Eat the fruit too!'],
    'cinnamon, lemon',
    zeroWaste: true,
  ),
  Recipe(
    'Scrap Vegetable Broth',
    '🥣',
    '1 h',
    6,
    [Ing('Onion', 150), Ing('Carrot', 150), Ing('Celery', 100), Ing('Parsley', 20)],
    [
      'Collect peels, ends and stems in a bag in the freezer during the week.',
      'Cover with 2.5 liters of water, add a bay leaf and peppercorns.',
      'Simmer 45 minutes, strain. Use as a base for soups and risotto.',
    ],
    'bay leaf, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Arancini (Leftover Rice Balls)',
    '🍙',
    '30 min',
    4,
    [Ing('Rice', 250), Ing('Mozzarella', 100), Ing('Eggs', 60), Ing('Breadcrumbs', 80), Ing('Vegetable Oil', 60)],
    ['Use cold cooked rice or leftover risotto.', 'Shape balls with a cube of mozzarella inside.', 'Dip in beaten egg, then breadcrumbs.', 'Fry until golden or bake at 200 °C for 20 minutes.'],
    'salt',
    zeroWaste: true,
  ),
  Recipe(
    'Zucchini Fritters',
    '🥒',
    '25 min',
    3,
    [Ing('Zucchini', 400), Ing('Eggs', 60), Ing('Flour', 60), Ing('Dill', 15), Ing('Vegetable Oil', 30)],
    ['A great way to use big or soft zucchini. Grate and squeeze it.', 'Mix with egg, flour, dill and salt.', 'Fry spoonfuls 3 minutes per side. Serve with sour cream.'],
    'salt, garlic',
    zeroWaste: true,
  ),
  Recipe(
    'Soft Tomato Soup',
    '🍅',
    '30 min',
    4,
    [Ing('Tomato', 800), Ing('Onion', 100), Ing('Garlic', 10), Ing('Olive Oil', 30), Ing('Basil', 10), Ing('Heavy Cream', 100)],
    ['Overripe, soft tomatoes give the best flavor!', 'Fry the onion and garlic, add chopped tomatoes and simmer 20 minutes.', 'Blend with basil, stir in the cream and season.'],
    'salt, sugar, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Apple Charlotte',
    '🍎',
    '55 min',
    6,
    [Ing('Apple', 500), Ing('Eggs', 180), Ing('Flour', 150), Ing('Sugar', 150)],
    ['Wrinkly apples are welcome. Slice them into a lined baking tin.', 'Whisk eggs and sugar until fluffy, fold in the flour.', 'Pour the batter over the apples.', 'Bake at 180 °C for 40 minutes.'],
    'cinnamon, vanilla',
    zeroWaste: true,
  ),
  Recipe(
    'Avocado Toast with Egg',
    '🥑',
    '10 min',
    2,
    [Ing('Sourdough Bread', 120), Ing('Avocado', 150), Ing('Eggs', 120), Ing('Lemon', 20), Ing('Chili Flakes', 2)],
    ['Very ripe avocado? Toast time! Toast the bread.', 'Mash the avocado with lemon juice and salt, spread on toast.', 'Top with a fried or poached egg and chili flakes.'],
    'salt',
    zeroWaste: true,
  ),
  Recipe(
    'French Toast',
    '🍞',
    '15 min',
    2,
    [Ing('White Bread', 240), Ing('Eggs', 120), Ing('Milk', 150), Ing('Sugar', 20), Ing('Butter', 20)],
    ['Dry, day-old bread works best — it doesn\'t fall apart.', 'Whisk eggs, milk, sugar and a pinch of cinnamon.', 'Soak the slices for 20 seconds, fry in butter 2–3 minutes per side.'],
    'cinnamon',
    zeroWaste: true,
  ),
  Recipe(
    'Bread Pudding',
    '🍮',
    '50 min',
    6,
    [Ing('White Bread', 300), Ing('Milk', 500), Ing('Eggs', 180), Ing('Sugar', 80), Ing('Raisins', 60)],
    ['Collect stale bread and cut into cubes.', 'Whisk milk, eggs and sugar, pour over the bread with raisins.', 'Let it soak 15 minutes, then bake at 180 °C for 35 minutes.'],
    'vanilla, cinnamon',
    zeroWaste: true,
  ),
  Recipe(
    'Fried Eggs with Soft Tomatoes',
    '🍳',
    '10 min',
    2,
    [Ing('Eggs', 180), Ing('Tomato', 200), Ing('Butter', 10)],
    ['Slice soft tomatoes and fry them in butter 3 minutes.', 'Crack the eggs on top, cover and cook until set.', 'Season with salt, pepper and herbs.'],
    'salt, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Home-Style Kuyrdak',
    '🥘',
    '45 min',
    4,
    [Ing('Lamb', 400), Ing('Beef Liver', 200), Ing('Onion', 150), Ing('Potato', 400)],
    [
      'Cut the lamb and liver into small cubes, the potatoes into chunks, the onion into half-rings.',
      'Fry the lamb in a deep pan with a little oil over high heat 10 minutes until browned.',
      'Add the liver and fry 5 more minutes, stirring.',
      'Add the potatoes and onion, season, pour in 100 ml of water, cover and stew 20 minutes until the potatoes are soft.',
      'Serve hot with flatbread and tea.',
    ],
    'salt, black pepper, oil',
  ),
  Recipe(
    'Homemade Beshbarmak',
    '🍲',
    '2 h 30 min',
    4,
    [Ing('Beef', 600), Ing('Flour', 300), Ing('Eggs', 60), Ing('Onion', 200)],
    [
      'Put the meat in a big pot with 3 liters of cold water, bring to a boil, skim the foam and simmer on low heat 2 hours. Salt at the end.',
      'Meanwhile mix the flour, egg, a pinch of salt and about 120 ml of water into a firm dough. Rest it 20 minutes.',
      'Roll the dough very thin and cut into 7–8 cm squares.',
      'Take the meat out. Ladle 300 ml of broth into a small pan, add the onion rings and simmer 5 minutes.',
      'Boil the dough squares in the remaining broth 3–4 minutes, lay them on a big plate.',
      'Slice the meat, put it on the dough, pour over the onion sauce. Serve the broth (sorpa) in bowls.',
    ],
    'salt, black pepper',
  ),
  Recipe(
    'Fluffy Baursaks',
    '🍩',
    '1 h 30 min',
    6,
    [Ing('Flour', 500), Ing('Milk', 250), Ing('Yeast', 7), Ing('Sugar', 25), Ing('Eggs', 60), Ing('Vegetable Oil', 60)],
    [
      'Warm the milk slightly, stir in the yeast and sugar, wait 10 minutes until foamy.',
      'Add the egg, a pinch of salt and the flour, knead a soft dough. Cover and leave in a warm place 1 hour.',
      'Roll the dough 1 cm thick and cut into squares or diamonds.',
      'Deep-fry in hot oil 1–2 minutes per side until golden and puffed. Drain on paper towels.',
      'Serve warm with tea, honey or jam.',
    ],
    'salt, oil for frying',
  ),
  Recipe(
    'Savory Bread Strata',
    '🍞',
    '45 min',
    4,
    [Ing('White Bread', 250), Ing('Eggs', 180), Ing('Milk', 250), Ing('Cheddar Cheese', 80), Ing('Spinach', 80)],
    [
      'Cut stale bread into cubes and put them in a greased baking dish with the chopped spinach.',
      'Whisk the eggs with the milk, salt and pepper, pour over the bread and press down. Leave 10 minutes to soak.',
      'Sprinkle with grated cheese.',
      'Bake at 180 °C for 30 minutes until puffed and golden.',
    ],
    'salt, black pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Banana Oat Cookies',
    '🍪',
    '25 min',
    4,
    [Ing('Banana', 240), Ing('Oats', 150), Ing('Raisins', 40)],
    [
      'Mash very ripe bananas with a fork until smooth.',
      'Stir in the oats and raisins, leave 5 minutes so the oats soften.',
      'Spoon small heaps onto a baking tray with paper and flatten them a little.',
      'Bake at 180 °C for 15 minutes until golden at the edges. Cool before eating.',
    ],
    'optional: cinnamon',
    zeroWaste: true,
  ),
  Recipe(
    'Homemade Naryn',
    '🍜',
    '2 h',
    4,
    [Ing('Horse Meat', 500), Ing('Kespe Noodles', 250), Ing('Onion', 150)],
    [
      'Cover the meat with cold water, bring to a boil, skim the foam and simmer 1 h 30 min with salt.',
      'Take the meat out and boil the noodles in a little of the broth until soft, 8–10 minutes.',
      'Slice the onion into thin rings and pour over 2–3 ladles of hot broth with black pepper.',
      'Cut the meat into thin strips, mix with the noodles and onion. Serve the rest of the broth (sorpa) in cups.',
    ],
    'salt, black pepper',
  ),
  Recipe(
    'Tushpara Soup',
    '🥟',
    '1 h',
    4,
    [Ing('Flour', 250), Ing('Eggs', 60), Ing('Ground Beef', 300), Ing('Onion', 120), Ing('Carrot', 80), Ing('Potato', 200)],
    [
      'Knead the flour, egg, a pinch of salt and 100 ml of water into a stiff dough. Rest it 15 minutes.',
      'Mix the ground beef with half the onion (very finely chopped), salt and pepper.',
      'Roll the dough thin, cut into 4 cm squares, put a little filling on each and pinch into tiny dumplings.',
      'Boil 1.5 l of water with diced potato, carrot and the rest of the onion for 10 minutes.',
      'Add the dumplings and cook 7–8 minutes after they float. Serve with herbs or a spoon of sour cream.',
    ],
    'salt, black pepper, water',
  ),
  Recipe(
    'Student Lagman Stir-Fry',
    '🍜',
    '30 min',
    2,
    [Ing('Lagman Noodles', 250), Ing('Beef', 250), Ing('Bell Pepper', 150), Ing('Onion', 100), Ing('Tomato', 150), Ing('Garlic', 10)],
    [
      'Boil the noodles 4–5 minutes, drain and rinse with cold water.',
      'Cut the beef into thin strips and fry in a hot pan with oil 4 minutes.',
      'Add sliced onion and pepper, fry 3 minutes, then the diced tomato and garlic for 3 more minutes.',
      'Toss the noodles in the pan with salt, pepper and a splash of soy sauce until hot.',
    ],
    'oil, salt, soy sauce',
  ),
  Recipe(
    'Leftover Fruit Kompot',
    '🧃',
    '30 min',
    6,
    [Ing('Apple', 300), Ing('Pear', 200), Ing('Dried Apricots', 80), Ing('Sugar', 60)],
    [
      'Cut soft or bruised apples and pears into chunks — peel and cores can go in too.',
      'Put the fruit and dried apricots into 2 l of water, add the sugar and bring to a boil.',
      'Simmer 10 minutes, turn off the heat and leave covered until it cools.',
      'Strain into a jug and keep in the fridge up to 3 days. The soft fruit can be eaten with yogurt.',
    ],
    'water',
    zeroWaste: true,
  ),
  Recipe(
    'Tary with Milk & Butter',
    '🥣',
    '10 min',
    1,
    [Ing('Tary', 40), Ing('Milk', 200), Ing('Butter', 10), Ing('Sugar', 10)],
    [
      'Warm the milk in a small pot until hot but not boiling.',
      'Put the tary (toasted millet) into a bowl and pour the hot milk over it.',
      'Add the butter and sugar, stir and wait 3 minutes so the grains soften a little.',
      'Eat warm with a cup of tea — a classic Kazakh breakfast that keeps for months in the pantry.',
    ],
    'tea (optional)',
  ),
  Recipe(
    'Katyk Kozhe with Millet',
    '🥣',
    '40 min',
    4,
    [Ing('Millet', 80), Ing('Beef', 150), Ing('Katyk', 300), Ing('Kurt', 20)],
    [
      'Rinse the millet. Boil the beef in 1.2 l of salted water for 25 minutes, then take it out and dice it.',
      'Add the millet to the broth and cook 12–15 minutes until soft. Let it cool to warm.',
      'Stir in the katyk and the crumbled kurt (a great use for hard, old kurt).',
      'Return the meat, chill and serve cold on a hot day. Keeps 2 days in the fridge.',
    ],
    'salt, water',
    zeroWaste: true,
  ),
  Recipe(
    'Stale Baursak Bread Pudding',
    '🍮',
    '45 min',
    4,
    [Ing('Baursaks', 200), Ing('Milk', 300), Ing('Eggs', 100), Ing('Sugar', 40), Ing('Raisins', 30)],
    [
      'Tear yesterday\'s hard baursaks into pieces and put them into a greased baking dish.',
      'Whisk the milk, eggs and sugar, pour over the baursaks and leave 10 minutes to soak.',
      'Scatter the raisins on top and press them in a little.',
      'Bake at 180 °C for 25–30 minutes until golden and set. Serve warm with tea.',
    ],
    'oil for the dish, cinnamon (optional)',
    zeroWaste: true,
  ),
  Recipe(
    'Dorm Lobio with Walnuts',
    '🫘',
    '30 min',
    3,
    [Ing('Kidney Beans', 250), Ing('Onion', 100), Ing('Walnuts', 40), Ing('Garlic', 10), Ing('Cilantro', 15)],
    [
      'Use cooked or canned beans; keep a little of the cooking liquid.',
      'Fry the chopped onion in oil until soft and golden, about 6 minutes.',
      'Add the beans with 3–4 spoons of liquid, mash about half of them with a fork and warm through.',
      'Crush the walnuts and garlic, stir them in with chopped cilantro, salt and pepper. Good hot or cold.',
    ],
    'oil, salt, black pepper',
  ),
  Recipe(
    'Bruised Aport Apple Pastila',
    '🍎',
    '6 h',
    8,
    [Ing('Aport Apple', 1000), Ing('Sugar', 80)],
    [
      'Cut away only the bruised spots of old or wrinkled apples, core them and chop (skin can stay).',
      'Bake or simmer until very soft, about 20 minutes, then blend into a smooth puree with the sugar.',
      'Spread 5 mm thick on a baking tray lined with paper.',
      'Dry in the oven at 80–90 °C with the door slightly open for 5–6 hours until not sticky. Cut into strips and roll.',
    ],
    'baking paper',
    zeroWaste: true,
  ),
  Recipe(
    'Leftover Plov Fried Rice',
    '🍳',
    '15 min',
    2,
    [Ing('Plov', 400), Ing('Eggs', 100), Ing('Carrot', 50), Ing('Soy Sauce', 15)],
    [
      'Take yesterday plov straight from the fridge: cold rice fries best and does not stick.',
      'Grate the carrot and fry it in a spoon of oil on high heat for 2 minutes.',
      'Add the plov, break up the lumps and fry 4–5 minutes until the rice crackles.',
      'Push the rice aside, scramble the eggs in the gap, then mix everything with soy sauce. Serve hot.',
    ],
    'oil, black pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Kystyby with Leftover Mash',
    '🫓',
    '40 min',
    4,
    [Ing('Flour', 300), Ing('Milk', 200), Ing('Potato', 500), Ing('Butter', 40), Ing('Onion', 80)],
    [
      'Mix warm milk, flour and a pinch of salt into a soft dough; rest it 15 minutes under a towel.',
      'Use leftover mashed potato or boil and mash the potatoes; stir in onion fried in a little butter.',
      'Roll the dough into thin rounds and cook each on a dry hot pan, about 1 minute per side.',
      'Spread mash on half of each hot flatbread, fold over and brush with melted butter.',
    ],
    'salt',
    zeroWaste: true,
  ),
  Recipe(
    'One-Pot Dimlama',
    '🍲',
    '1 h 30 min',
    5,
    [Ing('Lamb', 500), Ing('Potato', 500), Ing('Cabbage', 400), Ing('Carrot', 200), Ing('Onion', 150), Ing('Bell Pepper', 150), Ing('Tomato', 200), Ing('Garlic', 15), Ing('Cumin', 5)],
    [
      'Cut the lamb into chunks and brown it in a heavy pot with a little oil, season with salt and cumin.',
      'Layer on top without stirring: onion rings, carrot, potato, pepper, tomato, garlic, salt each layer.',
      'Cover everything with big cabbage leaves, close the lid tightly — the vegetables steam in their own juice.',
      'Cook on the lowest heat for 1 hour 15 minutes. Great for using up tired vegetables.',
    ],
    'oil, salt, black pepper',
  ),
  Recipe(
    'Stale Bread French Toast',
    '🍞',
    '15 min',
    2,
    [Ing('White Bread', 200), Ing('Eggs', 100), Ing('Milk', 120), Ing('Sugar', 15), Ing('Butter', 20), Ing('Cinnamon', 2)],
    [
      'Dry or 2–3 day old bread is perfect here: it soaks without falling apart.',
      'Whisk eggs, milk, sugar, cinnamon and a pinch of salt in a wide plate.',
      'Soak each slice 10 seconds per side.',
      'Fry in butter on medium heat until golden, 2–3 minutes per side. Top with jam or fruit that needs eating.',
    ],
    'pinch of salt',
    zeroWaste: true,
  ),
  Recipe(
    'Homemade Korean Carrot Salad',
    '🥕',
    '20 min + 2 h',
    4,
    [Ing('Carrot', 500), Ing('Garlic', 15), Ing('Vegetable Oil', 60), Ing('Coriander', 5), Ing('Vinegar', 20), Ing('Sugar', 10), Ing('Chili Flakes', 2)],
    [
      'Cut the carrots into long thin strips (a julienne grater is ideal), add salt and sugar and squeeze with your hands.',
      'Pour over the vinegar, add crushed garlic and chili flakes.',
      'Heat the oil with the ground coriander until it smells nutty and pour it over the carrots, mix well.',
      'Leave in the fridge for at least 2 hours. Keeps a week — a favourite at Almaty bazaars.',
    ],
    'salt',
  ),
  Recipe(
    'Leftover Zharkoe Pot Roast',
    '🥘',
    '1 h',
    4,
    [Ing('Beef', 400), Ing('Potato', 600), Ing('Onion', 150), Ing('Carrot', 150), Ing('Tomato Paste', 30), Ing('Vegetable Oil', 30), Ing('Bay Leaf', 1), Ing('Black Pepper', 2)],
    [
      'Great for soft, sprouting potatoes and the last carrot in the drawer: peel, cut into big chunks.',
      'Cut the beef into 3 cm cubes and brown in hot oil in a heavy pot (kazan), 5–7 minutes.',
      'Add sliced onion and carrot, fry 5 minutes, stir in tomato paste.',
      'Add the potatoes, bay leaf, pepper, salt and water to half-cover. Simmer covered 40 minutes until tender.',
      'Leftovers taste even better the next day — reheat with a splash of water.',
    ],
    'salt, water',
    zeroWaste: true,
  ),
  Recipe(
    'Shalgam Turnip Salad',
    '🥗',
    '20 min + 1 h',
    4,
    [Ing('Turnip', 400), Ing('Carrot', 150), Ing('Bell Pepper', 150), Ing('Onion', 80), Ing('Garlic', 10), Ing('Vinegar', 20), Ing('Vegetable Oil', 40), Ing('Sugar', 10)],
    [
      'Cut turnip, carrot and pepper into thin strips, onion into half-rings.',
      'Add salt and sugar, squeeze with your hands until the vegetables give juice.',
      'Add vinegar and crushed garlic. Heat the oil until hot and pour over the salad.',
      'Mix and chill at least 1 hour. Keeps 4 days — a classic side at Almaty bazaars.',
    ],
    'salt',
  ),
  Recipe(
    'Sour Kefir Khvorost',
    '🥨',
    '40 min',
    6,
    [Ing('Kefir', 200), Ing('Flour', 400), Ing('Eggs', 50), Ing('Sugar', 30), Ing('Baking Soda', 3), Ing('Vegetable Oil', 300), Ing('Powdered Sugar', 30)],
    [
      'Kefir that turned too sour to drink is perfect here — it makes the dough crispy.',
      'Mix kefir, egg, sugar, soda and a pinch of salt; knead in the flour to a firm dough. Rest 15 minutes.',
      'Roll out very thin, cut into strips 3×10 cm, make a slit in the middle and pull one end through.',
      'Fry in hot oil 30–40 seconds per side until golden. Drain on paper, dust with powdered sugar.',
      'Strain and keep the oil for the next frying.',
    ],
    'pinch of salt',
    zeroWaste: true,
  ),
  Recipe(
    'Leftover Chicken Noodle Soup',
    '🍜',
    '35 min',
    4,
    [Ing('Chicken Breast', 250), Ing('Egg Noodles', 120), Ing('Carrot', 100), Ing('Onion', 80), Ing('Celery', 60), Ing('Dill', 10), Ing('Bay Leaf', 1)],
    [
      'Use cooked chicken from yesterday or a raw breast that needs cooking today.',
      'Simmer the chicken with the bay leaf in 1.5 l salted water 15 minutes (5 if already cooked), then shred it.',
      'Add diced carrot, onion and celery — celery leaves and limp stalks are fine. Cook 10 minutes.',
      'Add the noodles and cook 5–7 minutes. Finish with chopped dill, stems too.',
    ],
    'salt, water',
    zeroWaste: true,
  ),
  Recipe(
    'Dorm Grilled Cheese with Tomato',
    '🧀',
    '10 min',
    1,
    [Ing('White Bread', 100), Ing('Cheddar Cheese', 60), Ing('Butter', 10), Ing('Tomato', 80)],
    [
      'Slightly stale bread works best — it gets crispier.',
      'Butter the outside of two slices. Put cheese and sliced tomato between them.',
      'Fry on a dry pan on medium heat, 3 minutes per side, pressing with a spatula, until golden and melted.',
    ],
    '',
  ),
  Recipe(
    'Brown Sugar Boba Milk Tea',
    '🧋',
    '20 min',
    2,
    [Ing('Tapioca Pearls', 80), Ing('Brown Sugar', 40), Ing('Black Tea', 6), Ing('Milk', 400)],
    [
      'Brew the tea strong: 6 g black tea in 200 ml hot water for 5 minutes, strain and let it cool.',
      'Boil the tapioca pearls in plenty of water as the pack says (usually 5–8 min), then rest them covered 5 min.',
      'Melt the brown sugar with 2 tbsp water on low heat for 2 minutes, add the drained pearls and stir until glossy.',
      'Smear the sticky syrup up the sides of two tall glasses, add pearls, ice, the tea and cold milk. Use a wide straw!',
      'Cooked pearls harden in a few hours — make only what you will drink today.',
    ],
    'Ice, water',
  ),
  Recipe(
    'Dubai Chocolate Bar',
    '🍫',
    '25 min + 1 h chill',
    4,
    [Ing('Kataifi', 80), Ing('Butter', 20), Ing('Pistachio Cream', 120), Ing('Tahini', 15), Ing('Milk Chocolate', 200)],
    [
      'Chop the kataifi into short pieces and toast it in the butter on medium heat, stirring, until golden and crunchy (5–7 min). Cool.',
      'Mix the crunchy kataifi with pistachio cream and tahini — this is the famous green filling.',
      'Melt the chocolate (microwave in 20-second bursts). Brush a thin layer into a mold or a small lined dish and chill 10 min.',
      'Spread the filling on top, cover with the rest of the chocolate and chill 1 hour.',
      'Cut with a hot knife and enjoy the crunch. Keeps 5 days in the fridge.',
    ],
    '',
  ),
  Recipe(
    'Quesabirria Tacos',
    '🌮',
    '3 h',
    4,
    [Ing('Beef Chuck', 600), Ing('Guajillo Chiles', 25), Ing('Chipotle in Adobo', 30), Ing('Canned Tomatoes', 200), Ing('Onion', 120), Ing('Garlic', 15), Ing('Corn Tortillas', 240), Ing('Mozzarella', 160), Ing('Cilantro', 15), Ing('Lime', 40)],
    [
      'Remove seeds from the dried chiles, soak them in hot water 15 min, then blend with chipotle, tomatoes, half the onion and garlic.',
      'Brown the beef in big chunks, pour over the sauce plus 1 liter of water, add salt, cumin and a bay leaf. Simmer covered 2.5 h until it falls apart.',
      'Shred the meat. Skim the red fat from the broth (consommé) into a bowl.',
      'Dip each tortilla in the red fat, fry on a hot pan, top with cheese and meat, fold and fry until crispy on both sides.',
      'Serve with the hot consommé for dipping, chopped onion, cilantro and lime. Leftover broth = next day noodle soup!',
    ],
    'Salt, cumin, oregano, bay leaf',
  ),
  Recipe(
    'Strawberry Daifuku Mochi',
    '🍡',
    '30 min',
    6,
    [Ing('Glutinous Rice Flour', 100), Ing('Sugar', 40), Ing('Corn Starch', 30), Ing('Red Bean Paste', 150), Ing('Strawberry', 120)],
    [
      'Wrap each strawberry (remove the green top) in a thin layer of red bean paste. Soft strawberries that need eating today are perfect.',
      'Whisk rice flour, sugar and 170 ml water into a smooth batter. Microwave covered 1 min, stir, then 1 min more and 30 s — it turns sticky and glossy.',
      'Dust the table with toasted corn starch. Divide the hot dough into 6 pieces and flatten each with starchy hands.',
      'Put a wrapped strawberry in the middle, pinch the dough closed and roll into a ball.',
      'Eat the same day — mochi gets hard in the fridge. Cut in half for the famous Instagram shot! 📸',
    ],
    'Water',
  ),
  Recipe(
    'Black Garlic Butter Ramen',
    '🍜',
    '15 min',
    1,
    [Ing('Ramen Noodles', 90), Ing('Butter', 15), Ing('Black Garlic', 15), Ing('Garlic', 5), Ing('Soy Sauce', 15), Ing('Eggs', 50), Ing('Spring Onion', 15), Ing('Sesame Seeds', 3)],
    [
      'Soft-boil the egg 6.5 min, cool in cold water and peel.',
      'Mash black garlic with a fork. Melt the butter, fry the fresh garlic 30 s, add black garlic and soy sauce.',
      'Cook the noodles, keep 4 tablespoons of the water, toss everything with the black garlic butter until glossy.',
      'Top with the halved egg, sliced spring onion and sesame. Tip: dry the leftover spring onion roots in a glass of water — they regrow!',
    ],
    '',
  ),
  Recipe(
    'Fridge-Clean-Out Gyoza',
    '🥟',
    '40 min',
    4,
    [Ing('Gyoza Wrappers', 200), Ing('Minced Pork', 200), Ing('Chinese Cabbage', 150), Ing('Carrot', 60), Ing('Spring Onion', 20), Ing('Ginger', 8), Ing('Soy Sauce', 30), Ing('Sesame Oil', 10), Ing('Vegetable Oil', 15)],
    [
      'Finely chop the cabbage, salt it and squeeze out the water after 10 min. Grate the carrot and ginger — wrinkly veggies from the bottom drawer are fine.',
      'Mix pork, vegetables, spring onion, 1 tbsp soy sauce and sesame oil.',
      'Put a teaspoon of filling on each wrapper, wet the edge and fold with 4–5 pleats.',
      'Fry flat side down in oil 2 min, pour in 80 ml water, cover and steam 5 min, then uncover until crispy.',
      'Dip in soy sauce with a little vinegar. Freeze extras raw on a tray, then in a bag — cook straight from frozen.',
    ],
    'Salt, vinegar',
    zeroWaste: true,
  ),
  Recipe(
    'Labneh Brunch Bowl',
    '🥙',
    '10 min',
    2,
    [Ing('Labneh', 200), Ing('Zaatar', 6), Ing('Olive Oil', 20), Ing('Cherry Tomato', 150), Ing('Cucumber', 120), Ing('Pita', 120)],
    [
      'Spread the labneh in a wide bowl with a spoon, making swirls.',
      'Chop tomatoes and cucumber, season with salt and pile them on top.',
      'Drizzle with olive oil and sprinkle generously with zaatar.',
      'Warm the pita and scoop! Stale pita? Toast it in pieces with oil into crunchy chips for the bowl.',
    ],
    'Salt',
  ),
  Recipe(
    'Viral Baked Feta Pasta',
    '🍝',
    '35 min',
    3,
    [Ing('Cherry Tomato', 400), Ing('Feta', 200), Ing('Olive Oil', 30), Ing('Garlic', 10), Ing('Pasta', 300), Ing('Basil', 10)],
    [
      'Heat the oven to 200 °C. Put the cherry tomatoes in a baking dish — soft, wrinkly ones are perfect here.',
      'Place the block of feta in the middle, pour olive oil over everything, add salt, pepper and chili flakes.',
      'Bake 30 minutes until the tomatoes burst. Meanwhile boil the pasta; keep a cup of pasta water.',
      'Add crushed garlic, mash the feta and tomatoes into a creamy sauce, toss with pasta and a splash of pasta water.',
      'Finish with torn basil. Leftover sauce keeps 3 days in the fridge.',
    ],
    'Salt, pepper, chili flakes',
    zeroWaste: true,
  ),
  Recipe(
    'Chili Crisp Fried Eggs on Rice',
    '🍳',
    '15 min',
    1,
    [Ing('Eggs', 120), Ing('Chili Crisp', 15), Ing('Rice', 80), Ing('Soy Sauce', 10)],
    [
      'Cook the rice — or better, warm up yesterday\'s leftover rice in a pan with a splash of water.',
      'Spoon the chili crisp into a cold non-stick pan and heat until it sizzles.',
      'Crack in the eggs and fry 2–3 minutes until the edges are crispy and the yolks still runny.',
      'Slide the eggs onto the rice, drizzle with soy sauce and the chili oil from the pan.',
    ],
    'Salt',
    zeroWaste: true,
  ),
  Recipe(
    'Blistered Shishito Peppers',
    '🫑',
    '10 min',
    2,
    [Ing('Shishito Peppers', 200), Ing('Olive Oil', 15), Ing('Lemon', 30), Ing('Sea Salt', 3)],
    [
      'Wash and dry the peppers well — wet peppers steam instead of blistering.',
      'Heat the oil in a heavy pan until very hot, add the peppers in one layer.',
      'Fry 4–6 minutes, turning, until blistered and charred in spots.',
      'Squeeze lemon over, sprinkle with flaky sea salt and eat with your fingers. About 1 in 10 is spicy!',
    ],
    'Nothing else',
  ),
  Recipe(
    'Viral Cottage Cheese Flatbread',
    '🫓',
    '35 min',
    2,
    [Ing('Cottage Cheese', 250), Ing('Eggs', 110), Ing('Black Pepper', 1), Ing('Spinach', 40), Ing('Cherry Tomato', 80)],
    [
      'Heat the oven to 180 °C and line a tray with baking paper.',
      'Blend the cottage cheese and eggs until completely smooth — cottage cheese close to its date is perfect here.',
      'Spread thinly (about 5 mm) on the tray, season with pepper and bake 30–35 minutes until golden and firm.',
      'Cool 5 minutes, peel off the paper and wrap it around spinach and halved cherry tomatoes like a tortilla.',
    ],
    'Salt',
    zeroWaste: true,
  ),
  Recipe(
    'Smashed Cucumber Salad',
    '🥒',
    '10 min',
    2,
    [Ing('Cucumber', 400), Ing('Garlic', 8), Ing('Soy Sauce', 20), Ing('Rice Vinegar', 15), Ing('Sesame Oil', 8), Ing('Chili Crisp', 10)],
    [
      'Lay the cucumbers on a board and smash them with the flat side of a knife — soft, slightly bendy cucumbers work great.',
      'Tear into bite-size pieces, salt and leave 5 minutes, then pour off the water.',
      'Mix grated garlic, soy sauce, rice vinegar and sesame oil, toss with the cucumbers.',
      'Top with chili crisp and eat right away.',
    ],
    'Salt, a pinch of sugar',
    zeroWaste: true,
  ),
  Recipe(
    'Marry Me Chicken',
    '💍',
    '30 min',
    3,
    [Ing('Chicken Breast', 500), Ing('Sun-Dried Tomatoes', 60), Ing('Garlic', 10), Ing('Heavy Cream', 200), Ing('Parmesan', 40), Ing('Spinach', 60), Ing('Olive Oil', 15)],
    [
      'Season the chicken with salt and pepper, sear in olive oil 5 minutes per side, take it out.',
      'In the same pan fry the garlic and chopped sun-dried tomatoes 1 minute.',
      'Pour in the cream and grated parmesan, simmer 3 minutes until slightly thick.',
      'Stir in the spinach, return the chicken and simmer 8–10 minutes until cooked through. Great with rice or pasta.',
    ],
    'Salt, pepper, chili flakes',
  ),
  Recipe(
    'Hot Honey Halloumi Toast',
    '🍯',
    '10 min',
    2,
    [Ing('Halloumi', 150), Ing('Hot Honey', 20), Ing('Sourdough Bread', 120), Ing('Arugula', 30), Ing('Lemon', 15)],
    [
      'Slice the halloumi 1 cm thick and pat it dry.',
      'Fry in a dry pan 2 minutes per side until golden. Toast the bread — slightly stale sourdough is ideal.',
      'Pile arugula on the toast, add the halloumi and drizzle with hot honey and a squeeze of lemon.',
    ],
    'Black pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Roasted Kabocha Squash Soup',
    '🎃',
    '45 min',
    4,
    [Ing('Kabocha Squash', 700), Ing('Onion', 100), Ing('Garlic', 10), Ing('Coconut Milk', 200), Ing('Vegetable Oil', 15), Ing('Pumpkin Seeds', 30)],
    [
      'Heat the oven to 200 °C. Cut the squash into wedges — no need to peel, kabocha skin is soft and edible.',
      'Scoop out the seeds and keep them! Roast the wedges with oil 30 minutes until soft.',
      'Fry the onion and garlic in a pot, add the squash and 600 ml water, simmer 5 minutes.',
      'Blend with coconut milk until smooth, season with salt.',
      'Top with toasted seeds. Freezes well for 3 months.',
    ],
    'Salt, pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Viral Pasta alla Vodka',
    '🍝',
    '25 min',
    2,
    [Ing('Penne', 200), Ing('Shallot', 40), Ing('Garlic', 10), Ing('Tomato Paste', 70), Ing('Vodka', 30), Ing('Heavy Cream', 100), Ing('Parmesan', 30), Ing('Butter', 15), Ing('Chili Flakes', 2)],
    [
      'Boil the penne in salted water; keep a cup of the pasta water before draining.',
      'Melt the butter, fry the chopped shallot and garlic 3 minutes until soft.',
      'Add tomato paste and chili flakes, stir 3–4 minutes until it turns brick red.',
      'Pour in the vodka and let it bubble 1 minute (the alcohol cooks off), then stir in the cream.',
      'Toss in the pasta with a splash of pasta water and the grated parmesan until silky.',
    ],
    'Salt, pepper',
  ),
  Recipe(
    'Stracciatella Tomato Toast',
    '🍅',
    '10 min',
    2,
    [Ing('Sourdough Bread', 120), Ing('Stracciatella', 100), Ing('Cherry Tomato', 150), Ing('Basil', 5), Ing('Olive Oil', 15)],
    [
      'Toast slightly stale sourdough in a dry pan or toaster until crunchy — day-old bread works best.',
      'Halve the cherry tomatoes (soft ones are perfect), salt them and leave 5 minutes to get juicy.',
      'Spoon the stracciatella over the toast, top with tomatoes and their juice.',
      'Finish with torn basil, olive oil and black pepper.',
    ],
    'Salt, black pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Clean-Out Egg Muffins',
    '🧁',
    '25 min',
    3,
    [Ing('Eggs', 300), Ing('Spinach', 60), Ing('Bell Pepper', 80), Ing('Cheddar Cheese', 50), Ing('Spring Onion', 20)],
    [
      'Heat the oven to 190 °C and grease a muffin tin.',
      'Chop any veggies that need using up — wilted spinach, half a pepper, spring onion.',
      'Whisk the eggs with salt, stir in the veggies and grated cheese.',
      'Fill 6 muffin cups and bake 18–20 minutes until set.',
      'Keep in the fridge up to 4 days — a grab-and-go breakfast for the whole week.',
    ],
    'Salt, pepper, oil for the tin',
    zeroWaste: true,
  ),
  Recipe(
    'Mapo Tofu',
    '🌶️',
    '20 min',
    2,
    [Ing('Tofu', 400), Ing('Minced Pork', 120), Ing('Doubanjiang', 30), Ing('Sichuan Peppercorns', 3), Ing('Garlic', 10), Ing('Ginger', 10), Ing('Spring Onion', 20), Ing('Corn Starch', 8), Ing('Rice', 150)],
    [
      'Cook the rice. Cut the tofu into 2 cm cubes and soak them in hot salted water for 5 minutes.',
      'Toast the Sichuan peppercorns in a dry pan, then crush them.',
      'Fry the minced pork in a little oil until crisp, add garlic, ginger and doubanjiang and fry 1 minute.',
      'Pour in 200 ml water, slide in the drained tofu and simmer 4 minutes.',
      'Thicken with the corn starch mixed in 2 tbsp water, sprinkle with peppercorns and spring onion, serve over rice.',
    ],
    'Oil, salt',
  ),
  Recipe(
    'Char Siu Leftover Fried Rice',
    '🍚',
    '15 min',
    2,
    [Ing('Rice', 150), Ing('Char Siu Pork', 120), Ing('Eggs', 120), Ing('Frozen Peas', 80), Ing('Spring Onion', 20), Ing('Soy Sauce', 20)],
    [
      'Best with yesterday\'s cold rice — cook it ahead and chill if you have none.',
      'Dice the leftover char siu. Scramble the eggs in a hot oiled wok and set aside.',
      'Fry the pork and peas 2 minutes, add the rice and toss on high heat until it crackles.',
      'Return the eggs, season with soy sauce, finish with spring onion.',
    ],
    'Oil',
    zeroWaste: true,
  ),
  Recipe(
    'Viral Cucumber Kewpie Salad',
    '🥒',
    '10 min',
    1,
    [Ing('Cucumber', 250), Ing('Kewpie Mayo', 20), Ing('Soy Sauce', 10), Ing('Rice Vinegar', 10), Ing('Sesame Oil', 5), Ing('Nori Sheets', 3)],
    [
      'Thinly slice the whole cucumber — skin and ends too.',
      'Put it in a container with a lid, add Kewpie mayo, soy sauce, rice vinegar and sesame oil.',
      'Close the lid and shake hard for 20 seconds.',
      'Top with crumbled nori and eat straight from the container.',
    ],
    'Chili crisp or sesame seeds (optional)',
    zeroWaste: true,
  ),
  Recipe(
    'Spam Musubi',
    '🍙',
    '30 min',
    8,
    [Ing('Spam', 340), Ing('Sushi Rice', 300), Ing('Nori Sheets', 12), Ing('Soy Sauce', 30), Ing('Sugar', 20), Ing('Mirin', 20)],
    [
      'Rinse the sushi rice until the water runs clear and cook it with 360 ml water; keep it covered and warm.',
      'Cut the Spam lengthwise into 8 slices about 1 cm thick.',
      'Fry the slices in a dry pan 2 minutes per side until crisp, then add soy sauce, sugar and mirin and turn until glazed.',
      'Cut the nori sheets in half. Line the empty Spam can with cling film and press in a layer of rice, a slice of Spam and more rice.',
      'Turn the block out onto a nori strip, wrap it tightly and seal the end with a grain of rice. Repeat with the rest.',
    ],
    'Water, cling film',
  ),
  Recipe(
    'Nduja Burrata Rigatoni',
    '🍝',
    '20 min',
    2,
    [Ing('Rigatoni', 200), Ing('Nduja', 60), Ing('Cherry Tomato', 250), Ing('Garlic', 10), Ing('Burrata', 125), Ing('Basil', 10), Ing('Olive Oil', 15)],
    [
      'Cook the rigatoni in well-salted boiling water 1 minute less than the packet says; save 100 ml of pasta water.',
      'Warm the olive oil in a wide pan, add sliced garlic and the nduja and stir until it melts into a red oil.',
      'Add the halved cherry tomatoes and cook 5 minutes, pressing some of them to make a sauce.',
      'Toss in the pasta with a splash of pasta water until glossy and coated.',
      'Plate, tear the burrata over the top and finish with fresh basil.',
    ],
    'Salt',
  ),
  Recipe(
    'Garlic Water Spinach Stir-Fry',
    '🥬',
    '15 min',
    2,
    [Ing('Water Spinach', 300), Ing('Garlic', 15), Ing('Chili Pepper', 5), Ing('Oyster Sauce', 15), Ing('Rice', 150)],
    [
      'Cook the rice. Cut the water spinach into 6 cm pieces, keeping stems and leaves separate — the stems are the best part, nothing goes to waste.',
      'Heat 1 tbsp oil in a wok until smoking, fry the sliced garlic and chili for 20 seconds.',
      'Add the stems and stir-fry 1 minute, then add the leaves and 2 tbsp water.',
      'Stir in the oyster sauce and toss just until the leaves wilt, about 1 minute; serve with the rice.',
    ],
    'Oil, salt',
    zeroWaste: true,
  ),
  Recipe(
    'Smashed Potatoes with Aioli',
    '🥔',
    '45 min',
    4,
    [Ing('New Potatoes', 800), Ing('Olive Oil', 40), Ing('Garlic', 10), Ing('Parmesan', 30), Ing('Parsley', 10), Ing('Aioli', 80)],
    [
      'Boil the whole new potatoes in salted water for 15–18 minutes until a knife slides in easily; drain and let them steam dry for 5 minutes.',
      'Heat the oven to 230 °C. Put the potatoes on an oiled tray and press each one flat with the bottom of a glass until it cracks open.',
      'Brush with olive oil mixed with crushed garlic, season with salt and bake 25 minutes until the edges are deep golden and crispy.',
      'Grate the parmesan over them for the last 3 minutes, then sprinkle with chopped parsley.',
      'Serve hot with the aioli for dipping.',
    ],
    'Salt, pepper',
  ),
  Recipe(
    'Chana Dal Tadka',
    '🍛',
    '50 min',
    4,
    [Ing('Chana Dal', 200), Ing('Onion', 100), Ing('Tomato', 150), Ing('Garlic', 10), Ing('Ginger', 10), Ing('Turmeric', 2), Ing('Cumin', 3), Ing('Ghee', 20), Ing('Cilantro', 10), Ing('Rice', 300)],
    [
      'Rinse the chana dal and soak it in water for 30 minutes (or overnight), then drain.',
      'Simmer the dal in 750 ml water with the turmeric and a pinch of salt for 30–35 minutes until soft but still holding shape. Meanwhile cook the rice.',
      'For the tadka, heat the ghee in a small pan, fry the cumin 20 seconds, then add the chopped onion and cook until golden.',
      'Add the grated ginger, garlic and chopped tomato and cook 5 minutes until jammy.',
      'Pour the tadka into the dal, simmer 2 minutes, finish with chopped cilantro and serve with the rice.',
    ],
    'Salt, chili powder',
  ),
  Recipe(
    'Steak with Herb-Stem Chimichurri',
    '🥩',
    '25 min',
    2,
    [Ing('Steak', 400), Ing('Parsley', 40), Ing('Cilantro', 20), Ing('Garlic', 10), Ing('Oregano', 2), Ing('Vinegar', 20), Ing('Olive Oil', 60), Ing('Chili Flakes', 2)],
    [
      'Take the steak out of the fridge 20 minutes before cooking and season it well with salt.',
      'Chop the parsley and cilantro finely — stems too: they hold the most flavour, so nothing goes in the bin.',
      'Mix the herbs with grated garlic, oregano, chili flakes, vinegar and olive oil; season with salt and let it stand 10 minutes.',
      'Sear the steak in a very hot dry pan 3–4 minutes per side, then rest it 5 minutes on a board.',
      'Slice across the grain and spoon the chimichurri over the top. Leftover sauce keeps 5 days in a jar in the fridge.',
    ],
    'Salt',
    zeroWaste: true,
  ),
  Recipe(
    'XO Sauce Egg Noodles',
    '🍜',
    '15 min',
    2,
    [Ing('Egg Noodles', 200), Ing('XO Sauce', 30), Ing('Spring Onion', 30), Ing('Eggs', 110), Ing('Soy Sauce', 15)],
    [
      'Cook the egg noodles as the packet says, rinse briefly and drain well.',
      'Beat the eggs and scramble them softly in an oiled hot pan; take them out.',
      'Add the XO sauce and the white parts of the spring onion to the pan and fry 30 seconds.',
      'Toss in the noodles and soy sauce over high heat for 2 minutes, fold the eggs back in and finish with the green parts of the spring onion.',
    ],
    'Oil',
  ),
  Recipe(
    'Mentaiko Spaghetti',
    '🍝',
    '15 min',
    2,
    [Ing('Spaghetti', 200), Ing('Mentaiko', 60), Ing('Butter', 20), Ing('Heavy Cream', 50), Ing('Soy Sauce', 5), Ing('Nori Sheets', 3)],
    [
      'Cook the spaghetti in salted water until al dente and keep a cup of the pasta water.',
      'Slit the mentaiko sacs and scrape the roe into a big bowl; mix it with the soft butter, cream and soy sauce.',
      'Toss the hot spaghetti in the bowl with a splash of pasta water until glossy and pink — the heat cooks the roe gently.',
      'Top with thin strips of nori and eat straight away.',
    ],
    'Salt',
  ),
  Recipe(
    'Orecchiette with Broccoli Rabe',
    '🥦',
    '25 min',
    2,
    [Ing('Orecchiette', 200), Ing('Broccoli Rabe', 300), Ing('Garlic', 10), Ing('Anchovies', 15), Ing('Chili Flakes', 2), Ing('Olive Oil', 30), Ing('Parmesan', 30)],
    [
      'Trim only the dry ends of the broccoli rabe and chop the rest — stems, leaves and florets all go in.',
      'Boil the orecchiette in salted water; add the broccoli rabe for the last 4 minutes, then drain, keeping some water.',
      'Warm the olive oil with sliced garlic, anchovies and chili flakes until the anchovies melt.',
      'Toss in the pasta and greens with a splash of cooking water and finish with grated parmesan.',
    ],
    'Salt',
    zeroWaste: true,
  ),
  Recipe(
    'Little Gem Caesar with Stale-Bread Croutons',
    '🥗',
    '20 min',
    2,
    [Ing('Little Gem Lettuce', 300), Ing('White Bread', 100), Ing('Parmesan', 30), Ing('Anchovies', 10), Ing('Garlic', 5), Ing('Lemon', 30), Ing('Mayonnaise', 40), Ing('Olive Oil', 20)],
    [
      'Tear the stale bread into chunks, toss with olive oil and bake at 200 °C for 8–10 minutes until golden.',
      'Mash the anchovies and grated garlic, then whisk in the mayonnaise, lemon juice and half of the grated parmesan.',
      'Cut the little gems into quarters lengthwise and spoon the dressing over the leaves.',
      'Scatter the croutons and the rest of the parmesan on top.',
    ],
    'Pepper',
    zeroWaste: true,
  ),
  Recipe(
    'Roasted Carrots with Pomegranate Molasses',
    '🥕',
    '35 min',
    3,
    [Ing('Carrot', 500), Ing('Pomegranate Molasses', 30), Ing('Olive Oil', 20), Ing('Greek Yogurt', 150), Ing('Zaatar', 5), Ing('Parsley', 15)],
    [
      'Scrub the carrots instead of peeling them and halve the thick ones lengthwise; keep the green tops if they came with them.',
      'Toss with olive oil and salt and roast at 220 °C for 25 minutes; drizzle with pomegranate molasses for the last 5.',
      'Spread the Greek yogurt on a plate and pile the hot carrots on top.',
      'Finish with za\'atar and chopped parsley (and chopped carrot tops).',
    ],
    'Salt',
    zeroWaste: true,
  ),
];

List<Recipe> rankRecipes(AppState s) {
  final names = s.pantryNames;
  final exp = s.toRescue.map((e) => e.food.name).toSet();
  int score(Recipe r) =>
      (r.missing(names).isEmpty ? 1000 : 0) + r.ingredients.where((i) => exp.contains(i.name)).length * 50 + r.ingredients.where((i) => names.contains(i.name)).length * 10 - r.missing(names).length;
  final list = recipes.where((r) => !r.ingredients.any((i) => s.dislikes.any((d) => i.name.toLowerCase().contains(d)))).toList();
  list.sort((a, b) => score(b).compareTo(score(a)));
  return list;
}

// ───────────────────────── СОСТОЯНИЕ ─────────────────────────
// Сейчас всё хранится в памяти. В полноценном проекте этот класс заменяется на SQLite/Firebase.

class AppState extends ChangeNotifier {
  final pantry = <PantryItem>[];
  final log = <LogEntry>[];
  final dislikes = <String>{};
  final chat = <ChatMessage>[ChatMessage('Hi! I\'m your AI Chef 👩‍🍳 Ask me what to cook, what expires soon, how to store food — or tell me what you don\'t like.', isUser: false)];
  bool showTutorial = false, registered = false;
  int wasted = 0, suggestIndex = 0, _id = 0;
  String name = 'Guest', email = '';
  bool isMan = true;
  double weight = 70, height = 175;
  int age = 22;

  /// Язык интерфейса (en / ru / kk). По умолчанию — язык браузера, если ru/kk.
  String get language => appLang;
  void setLanguage(String l) {
    if (!appLangs.contains(l) || l == appLang) return;
    appLang = l;
    if (chat.length == 1 && !chat.first.isUser) chat[0] = ChatMessage(_greeting(), isUser: false);
    notifyListeners();
  }

  String _greeting() => tr('Hi! I\'m your AI Chef 👩‍🍳 Ask me what to cook, what expires soon, how to store food — or tell me what you don\'t like.');

  // BMR (Миффлин — Сан-Жеор) × 1.375 (лёгкая активность) = калории, чтобы держать вес. Раньше показывался только BMR — цель была занижена.
  int get targetCalories => (((10 * weight) + (6.25 * height) - (5 * age) + (isMan ? 5 : -161)) * 1.375).round();
  int kcalOn(int day) => log.where((e) => e.day == day).fold<int>(0, (s, e) => s + e.kcal);
  int get eatenCalories => kcalOn(todayNum());
  List<PantryItem> get expiringSoon => (pantry.where((p) => p.daysLeft <= 2).toList()..sort((a, b) => a.daysLeft.compareTo(b.daysLeft)));
  List<PantryItem> get toRescue => expiringSoon.where((p) => p.daysLeft >= 0).toList();
  Set<String> get pantryNames => pantry.map((p) => p.food.name).toSet();

  final shopping = <String>[];
  final weights = <WeightEntry>[];
  final unlocked = <String>{};
  Medal? pendingBadge;
  bool celebrate = false;
  int consumed = 0, rescued = 0, cooked = 0, bought = 0, tipIndex = 0, frozen = 0, shared = 0;
  double rescuedMoney = 0, wastedMoney = 0;
  DateTime streakStart = DateTime.now();
  final wasteLog = <WasteEntry>[];

  double get moneyAtRisk => expiringSoon.where((p) => p.daysLeft >= 0).fold(0.0, (s, p) => s + price(p.food));
  List<PantryItem> get expired => pantry.where((p) => p.daysLeft < 0).toList();
  Map<WasteReason, int> get wasteByReason => {for (final r in WasteReason.values) r: wasteLog.where((w) => w.reason == r).length};
  Map<String, int> get wasteByCategory {
    final m = <String, int>{};
    for (final w in wasteLog) {
      m[w.food.category] = (m[w.food.category] ?? 0) + 1;
    }
    return Map.fromEntries(m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));
  }

  static const _price = {
    'Meat': 4.5,
    'Seafood': 5.0,
    'Dairy': 2.0,
    'Vegetables': 1.2,
    'Fruits': 1.5,
    'Berries': 3.0,
    'Bakery': 1.5,
    'Grains': 1.2,
    'Nuts & Legumes': 3.0,
    'Pantry': 2.5,
    'Sweets': 2.5,
    'Drinks': 1.8,
    'Frozen': 3.5,
    'Spices': 2.0,
    'Canned': 1.8,
    'Ready Meals': 4.0,
    'Snacks': 2.5,
    'Plant-Based': 3.0,
    'World Foods': 3.0,
    'Baby Food': 2.5,
  };
  double price(FoodItem f) => _price[f.category] ?? 2.0;
  double get co2 => rescued * 0.3 * 2.5;
  int get ecoScore => consumed + wasted == 0 ? 100 : (100 * consumed / (consumed + wasted)).round();
  int get streakDays {
    final n = now();
    return DateTime.utc(n.year, n.month, n.day).difference(DateTime.utc(streakStart.year, streakStart.month, streakStart.day)).inDays;
  }

  void _use(PantryItem p) {
    consumed++;
    if (p.daysLeft >= 0 && p.daysLeft <= 2) {
      rescued++;
      rescuedMoney += price(p.food);
    }
  }

  bool _done(String id) {
    switch (id) {
      case 'first':
        return consumed >= 1;
      case 'rescue':
        return rescued >= 3;
      case 'chef':
        return cooked >= 3;
      case 'fridge':
        return pantry.length >= 10;
      case 'streak':
        return streakDays >= 7;
      case 'shop':
        return bought >= 1;
      case 'weight':
        return weights.length >= 3;
      case 'freezer':
        return frozen >= 3;
      case 'share':
        return shared >= 1;
      case 'cleanfridge':
        return pantry.length >= 5 && expired.isEmpty;
      default:
        return co2 >= 2;
    }
  }

  void _check() {
    for (final m in medals) {
      if (!unlocked.contains(m.id) && _done(m.id)) {
        unlocked.add(m.id);
        pendingBadge = m;
        celebrate = true;
        nutrikEvent('medal');
      }
    }
  }

  void clearBadge() {
    pendingBadge = null;
    notifyListeners();
  }

  void party() {
    celebrate = true;
    notifyListeners();
  }

  void endCelebrate() {
    celebrate = false;
    notifyListeners();
  }

  void nextTip() {
    tipIndex++;
    notifyListeners();
  }

  void addShopping(List<String> names) {
    for (final n in names) {
      if (!shopping.contains(n)) shopping.add(n);
    }
    notifyListeners();
  }

  void removeShopping(String n) {
    shopping.remove(n);
    notifyListeners();
  }

  void buy(String n) {
    final f = foodByName[n];
    shopping.remove(n);
    if (f != null) {
      bought++;
      add(f);
    } else {
      notifyListeners();
    }
  }

  void addWeight(double kg) {
    weights.add(WeightEntry(now(), kg));
    weight = kg;
    _check();
    notifyListeners();
  }

  void register({required String name, required String email, required bool isMan, required int age, required double weight, required double height}) {
    this.name = name;
    this.email = email;
    this.isMan = isMan;
    this.age = age;
    this.weight = weight;
    this.height = height;
    registered = true;
    showTutorial = true;
    weights
      ..clear()
      ..add(WeightEntry(now(), weight));
    streakStart = now();
    notifyListeners();
  }

  void startTutorial() {
    showTutorial = true;
    notifyListeners();
  }

  void endTutorial() {
    showTutorial = false;
    notifyListeners();
  }

  void add(FoodItem f, {int? days, bool quiet = false}) {
    final n = now();
    pantry.add(PantryItem(_id++, f, n, n.add(Duration(days: days ?? f.shelf)), defaultStorage(f)));
    if (!quiet) nutrikEvent('add');
    _check();
    notifyListeners();
  }

  /// ＋ в строке холодильника: ещё одна штука того же продукта в том же месте.
  void addMore(PantryItem p) {
    final n = now();
    pantry.add(PantryItem(_id++, p.food, n, n.add(Duration(days: p.storage == Storage.freezer ? 90 : p.food.shelf)), p.storage));
    _check();
    notifyListeners();
  }

  /// − в строке холодильника: исправление количества (не считается отходом) — убираем самую свежую штуку.
  void removeOne(PantryItem p) {
    final same = pantry.where((x) => x.food.name == p.food.name && x.storage == p.storage).toList()
      ..sort((a, b) => b.daysLeft.compareTo(a.daysLeft));
    if (same.isNotEmpty) pantry.remove(same.first);
    notifyListeners();
  }

  /// Набор продуктов для демонстрации: часть уже «горит», часть свежая.
  void loadDemo() {
    const demo = {
      'Banana': 1,
      'Milk': 0,
      'Kefir': 2,
      'Tomato': 1,
      'Bell Pepper': 3,
      'Eggs': 12,
      'Chicken Breast': 1,
      'White Bread': 0,
      'Apple': 9,
      'Potato': 20,
      'Carrot': 14,
      'Onion': 25,
      'Cheddar Cheese': 10,
      'Spinach': -1,
      'Rice': 300,
      'Flour': 200,
      'Sugar': 300,
      'Butter': 20,
      'Vegetable Oil': 300,
      'Strawberry': 2,
    };
    demo.forEach((name, d) => add(foodByName[name]!, days: d, quiet: true));
    nutrikEvent('add');
  }

  void eat(PantryItem p, int grams, {bool finished = true}) {
    if (finished) {
      _use(p);
      pantry.remove(p);
    }
    log.add(LogEntry(_id++, p.food.emoji, '${p.food.name} · $grams g', (p.food.kcal * grams / 100).round()));
    nutrikEvent('eat');
    _check();
    notifyListeners();
  }

  void throwAway(PantryItem p, [WasteReason reason = WasteReason.expired]) {
    pantry.remove(p);
    wasted++;
    wastedMoney += price(p.food);
    wasteLog.add(WasteEntry(p.food, reason, price(p.food)));
    streakStart = now();
    if (reason == WasteReason.disliked) dislikes.add(p.food.name.toLowerCase());
    nutrikEvent('waste');
    notifyListeners();
  }

  /// Заморозка продлевает жизнь продукта на 3 месяца — это тоже «спасение».
  void freeze(PantryItem p) {
    if (p.daysLeft >= 0 && p.daysLeft <= 2) {
      rescued++;
      rescuedMoney += price(p.food);
    }
    p.storage = Storage.freezer;
    p.expiry = now().add(const Duration(days: 90));
    frozen++;
    nutrikEvent('rescue');
    _check();
    notifyListeners();
  }

  /// Отдать соседу / другу / на фудшеринг.
  void share(PantryItem p) {
    pantry.remove(p);
    shared++;
    nutrikEvent('rescue');
    rescued++;
    consumed++;
    rescuedMoney += price(p.food);
    celebrate = true;
    _check();
    notifyListeners();
  }

  void setExpiry(PantryItem p, DateTime d) {
    p.expiry = d;
    notifyListeners();
  }

  void moveTo(PantryItem p, Storage s) {
    p.storage = s;
    notifyListeners();
  }

  void cook(Recipe r, int portions) {
    for (final i in r.ingredients) {
      final m = pantry.where((p) => p.food.name == i.name).toList()..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
      if (m.isNotEmpty) {
        _use(m.first); // сначала используем то, что скорее испортится
        pantry.remove(m.first);
      }
    }
    log.add(LogEntry(_id++, r.emoji, '${r.name} ×$portions', r.kcal * portions));
    cooked++;
    celebrate = true;
    nutrikEvent('cook');
    _check();
    notifyListeners();
  }

  void removeLog(LogEntry e) {
    log.remove(e);
    notifyListeners();
  }

  void nextDay(int d) {
    dayShift = d == 0 ? 0 : dayShift + d;
    _check();
    notifyListeners();
  }

  // ───── Сохранение между запусками ─────
  static const _key = 'nutrimate_state_v1';
  SharedPreferences? _prefs;
  Timer? _saveTimer;

  @override
  void notifyListeners() {
    super.notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  Map<String, dynamic> toJson() => {
    'registered': registered,
    'language': appLang,
    'name': name,
    'email': email,
    'isMan': isMan,
    'weight': weight,
    'height': height,
    'age': age,
    'id': _id,
    'dayShift': dayShift,
    'pantry': [for (final p in pantry) [p.id, p.food.name, p.added.millisecondsSinceEpoch, p.expiry.millisecondsSinceEpoch, p.storage.index]],
    'log': [for (final e in log) [e.id, e.emoji, e.name, e.kcal, e.day]],
    'dislikes': dislikes.toList(),
    'shopping': shopping,
    'weights': [for (final w in weights) [w.date.millisecondsSinceEpoch, w.kg]],
    'unlocked': unlocked.toList(),
    'c': [wasted, consumed, rescued, cooked, bought, frozen, shared],
    'money': [rescuedMoney, wastedMoney],
    'streak': streakStart.millisecondsSinceEpoch,
    'waste': [for (final w in wasteLog) [w.food.name, w.reason.index, w.money]],
  };

  Future<void> save() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setString(_key, jsonEncode(toJson()));
    } catch (_) {}
  }

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      appLang = systemLang(PlatformDispatcher.instance.locale.languageCode);
      final raw = _prefs!.getString(_key);
      if (raw == null) {
        chat[0] = ChatMessage(_greeting(), isUser: false);
        return;
      }
      final j = jsonDecode(raw) as Map<String, dynamic>;
      // мягко: старые сохранения без языка — язык браузера
      if (appLangs.contains(j['language'])) appLang = j['language'] as String;
      if (chat.length == 1) chat[0] = ChatMessage(_greeting(), isUser: false);
      DateTime d(dynamic ms) => DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
      registered = j['registered'] == true;
      name = j['name'] ?? name;
      email = j['email'] ?? email;
      isMan = j['isMan'] ?? isMan;
      weight = (j['weight'] as num?)?.toDouble() ?? weight;
      height = (j['height'] as num?)?.toDouble() ?? height;
      age = (j['age'] as num?)?.toInt() ?? age;
      _id = (j['id'] as num?)?.toInt() ?? 0;
      dayShift = (j['dayShift'] as num?)?.toInt() ?? 0;
      for (final p in (j['pantry'] as List? ?? [])) {
        final f = foodByName[p[1]];
        if (f != null) pantry.add(PantryItem((p[0] as num).toInt(), f, d(p[2]), d(p[3]), Storage.values[(p[4] as num).toInt()]));
      }
      for (final e in (j['log'] as List? ?? [])) {
        log.add(LogEntry((e[0] as num).toInt(), e[1], e[2], (e[3] as num).toInt(), (e[4] as num).toInt()));
      }
      dislikes.addAll((j['dislikes'] as List? ?? []).cast<String>());
      shopping.addAll((j['shopping'] as List? ?? []).cast<String>());
      for (final w in (j['weights'] as List? ?? [])) {
        weights.add(WeightEntry(d(w[0]), (w[1] as num).toDouble()));
      }
      unlocked.addAll((j['unlocked'] as List? ?? []).cast<String>());
      final c = (j['c'] as List? ?? []).map((e) => (e as num).toInt()).toList();
      if (c.length == 7) {
        wasted = c[0];
        consumed = c[1];
        rescued = c[2];
        cooked = c[3];
        bought = c[4];
        frozen = c[5];
        shared = c[6];
      }
      final m = (j['money'] as List? ?? []).map((e) => (e as num).toDouble()).toList();
      if (m.length == 2) {
        rescuedMoney = m[0];
        wastedMoney = m[1];
      }
      if (j['streak'] != null) streakStart = d(j['streak']);
      for (final w in (j['waste'] as List? ?? [])) {
        final f = foodByName[w[0]];
        if (f != null) wasteLog.add(WasteEntry(f, WasteReason.values[(w[1] as num).toInt()], (w[2] as num).toDouble()));
      }
      for (final p in pantry) {
        if (p.id >= _id) _id = p.id + 1;
      }
      for (final e in log) {
        if (e.id >= _id) _id = e.id + 1;
      }
    } catch (_) {
      // повреждённые данные не должны ломать запуск
    }
  }

  void logout() {
    registered = false;
    notifyListeners();
  }

  /// Полный сброс — только по кнопке в профиле.
  Future<void> eraseAll() async {
    pantry.clear();
    log.clear();
    dislikes.clear();
    shopping.clear();
    weights.clear();
    unlocked.clear();
    wasteLog.clear();
    wasted = consumed = rescued = cooked = bought = frozen = shared = _id = 0;
    rescuedMoney = wastedMoney = 0;
    registered = false;
    name = 'Guest';
    email = '';
    dayShift = 0;
    streakStart = DateTime.now();
    _saveTimer?.cancel();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_key);
    } catch (_) {}
    super.notifyListeners();
  }

  void updateProfile({bool? isMan, double? weight, double? height, int? age}) {
    this.isMan = isMan ?? this.isMan;
    this.weight = weight ?? this.weight;
    this.height = height ?? this.height;
    this.age = age ?? this.age;
    notifyListeners();
  }
}

// ───────────────────────── AI-СЕРВИС ─────────────────────────
// Сейчас — «умная заглушка» с памятью (запоминает, что ты не любишь) и разбором сообщений.
// Настоящий ИИ подключается в полноценном проекте через свой backend: новый класс implements AiService.

abstract class AiService {
  Future<String> reply(String message, AppState state);
}

// Настоящий ИИ-Нутрик: тот же бесплатный Cloudflare Worker, что и в iOS (server/).
// Команды, меняющие данные («не люблю X», список покупок), — локально; при любой ошибке,
// лимите или без сети — молча ответ офлайн-помощника MockAiService.
class SmartAiService implements AiService {
  static const serverUrl = 'https://nutrimate-nutrik.temirlanzaks.workers.dev';
  final _local = MockAiService();
  int _pausedDay = -1; // после 429 — до завтра только офлайн
  String? _deviceId;

  static bool isLocalCommand(String message) {
    final t = message.toLowerCase();
    bool has(List<String> w) => w.any(t.contains);
    if (RegExp(r"(don't like|dont like|do not like|hate|allergic to|не люблю|без)\s+([^\s,.!?]+)").hasMatch(t)) return true;
    if (RegExp(r"i (like|love) ([^\s,.!?]+) again").hasMatch(t)) return true;
    if (has(['shopping', 'to buy', 'need to buy', 'купить', 'add ']) && has(['shopping list', 'list', 'buy', 'купить'])) return true;
    return NutrikActions.parse(message) != null;
  }

  Future<String> _device() async {
    if (_deviceId != null) return _deviceId!;
    var id = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      id = prefs.getString('nutrik_device_id') ?? '';
      if (id.isEmpty) {
        final r = Random.secure();
        id = 'web-${List.generate(24, (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[r.nextInt(36)]).join()}';
        await prefs.setString('nutrik_device_id', id);
      }
    } catch (_) {
      id = 'web-${DateTime.now().millisecondsSinceEpoch}';
    }
    return _deviceId = id;
  }

  Map<String, dynamic> _context(AppState s) {
    final have = s.pantryNames;
    final fridge = [...s.pantry]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    return {
      'name': s.name,
      'language': appLang,
      'fridge': fridge.take(40).map((p) => {'name': p.food.name, 'daysLeft': p.daysLeft}).toList(),
      'kcalToday': s.eatenCalories,
      'kcalGoal': s.targetCalories,
      'dislikes': s.dislikes.take(20).toList(),
      'recipes': rankRecipes(s).take(8).map((r) => {
            'name': r.name,
            'kcal': r.kcal,
            'time': r.time,
            'ingredients': r.ingredients.map((i) => '${i.name} ${i.g} g').toList(),
            'missing': r.missing(have),
          }).toList(),
    };
  }

  @override
  Future<String> reply(String message, AppState s) async {
    if (serverUrl.isEmpty || isLocalCommand(message) || _pausedDay == todayNum()) return _local.reply(message, s);
    try {
      final history = s.chat.skip(1).toList();
      final msgs = history
          .skip(history.length > 10 ? history.length - 10 : 0)
          .map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text})
          .toList();
      if (msgs.isEmpty || msgs.last['role'] != 'user') msgs.add({'role': 'user', 'content': message});
      final res = await http
          .post(Uri.parse('$serverUrl/chat'),
              headers: {'content-type': 'application/json', 'x-nutrimate-client': 'web'},
              body: jsonEncode({'deviceId': await _device(), 'messages': msgs, 'context': _context(s), 'actions': true}))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 429) _pausedDay = todayNum();
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
        // ИИ предложил действия — проверяем по базе, выполняем и пишем подтверждение по факту
        final acts = body['actions'];
        if (acts is List && acts.isNotEmpty) {
          final done = NutrikActions.perform(acts, message, s);
          if (done != null) return done;
        }
        final reply = body['reply'];
        if (body['guarded'] != true && reply is String && reply.trim().isNotEmpty) return '${reply.trim()}\n\n✨ AI · can be wrong';
      }
    } catch (_) {/* офлайн-режим */}
    return _local.reply(message, s);
  }
}

// ───────────────────────── ЧЕСТНЫЕ КОМАНДЫ-ДЕЙСТВИЯ В ЧАТЕ (EN / RU / KK) ─────────────────────────
// «add 2 eggs to fridge», «добавь 2 яйца в холодильник», «тоңазытқышқа 2 жұмыртқа қос», «съел банан»,
// «выбросил кефир», «заморозь курицу». Действие реально выполняется, ответ — по факту, с количеством.
class NutrikActions {
  static const aliases = {'яйц': 'Eggs', 'яичк': 'Eggs', 'молок': 'Milk', 'хлеб': 'White Bread', 'батон': 'White Bread', 'яблок': 'Apple', 'картош': 'Potato', 'картоф': 'Potato', 'лук': 'Onion', 'морков': 'Carrot', 'помидор': 'Tomato', 'томат': 'Tomato', 'огур': 'Cucumber', 'куриц': 'Chicken Breast', 'курин': 'Chicken Breast', 'рис': 'Rice', 'сыр': 'Cheddar Cheese', 'сливочн': 'Butter', 'масл': 'Butter', 'сахар': 'Sugar', 'банан': 'Banana', 'кефир': 'Kefir', 'йогурт': 'Yogurt', 'мук': 'Flour', 'чай': 'Black Tea', 'греч': 'Buckwheat', 'макарон': 'Pasta', 'творог': 'Cottage Cheese', 'сметан': 'Sour Cream', 'апельсин': 'Orange', 'лимон': 'Lemon', 'чеснок': 'Garlic', 'капуст': 'Cabbage', 'говядин': 'Beef', 'свинин': 'Pork', 'фарш': 'Ground Beef', 'гриб': 'Mushrooms', 'клубник': 'Strawberry', 'авокадо': 'Avocado', 'шпинат': 'Spinach', 'перец': 'Bell Pepper', 'перц': 'Bell Pepper', 'пельмен': 'Pelmeni', 'айран': 'Ayran', 'лосос': 'Salmon', 'семг': 'Salmon', 'овсян': 'Oats', 'мёд': 'Honey', 'мед': 'Honey', 'арбуз': 'Watermelon', 'виноград': 'Grapes', 'груш': 'Pear', 'салат': 'Lettuce', 'кукуруз': 'Corn', 'свекл': 'Beetroot', 'свёкл': 'Beetroot', 'майонез': 'Mayonnaise', 'соль': 'Salt', 'курт': 'Kurt', 'жұмыртқа': 'Eggs', 'сүт': 'Milk', 'нан': 'White Bread', 'алма': 'Apple', 'картоп': 'Potato', 'пияз': 'Onion', 'сәбіз': 'Carrot', 'қызанақ': 'Tomato', 'қияр': 'Cucumber', 'тауық': 'Chicken Breast', 'күріш': 'Rice', 'ірімшік': 'Cheddar Cheese', 'қант': 'Sugar', 'ұн': 'Flour', 'шай': 'Black Tea', 'қарақұмық': 'Buckwheat', 'сүзбе': 'Cottage Cheese', 'қаймақ': 'Sour Cream', 'сарымсақ': 'Garlic', 'қырыққабат': 'Cabbage', 'сиыр': 'Beef', 'саңырауқұлақ': 'Mushrooms', 'құлпынай': 'Strawberry', 'қарбыз': 'Watermelon', 'жүзім': 'Grapes', 'алмұрт': 'Pear', 'жүгері': 'Corn', 'қызылша': 'Beetroot', 'тұз': 'Salt', 'құрт': 'Kurt'};
  static const numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'dozen': 12,
    'один': 1, 'одну': 1, 'одна': 1, 'два': 2, 'две': 2, 'три': 3, 'четыре': 4, 'пять': 5, 'шесть': 6, 'десяток': 10, 'десять': 10,
    'бір': 1, 'екі': 2, 'үш': 3, 'төрт': 4, 'бес': 5, 'алты': 6,
  };

  static List<String> words(String t) => t.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true)).where((w) => w.isNotEmpty).toList();

  static String lang(String t) {
    if (RegExp(r'[әғқңөұүһі]').hasMatch(t)) return 'kk';
    if (RegExp(r'[а-яё]').hasMatch(t)) return 'ru';
    return 'en';
  }

  static List<FoodItem> foods(String t) {
    final out = <FoodItem>[];
    final exact = foodDatabase.where((f) => RegExp('\\b${RegExp.escape(f.name.toLowerCase())}s?\\b').hasMatch(t)).toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final f in exact) {
      if (!out.any((o) => o.name.toLowerCase().contains(f.name.toLowerCase()))) out.add(f);
    }
    for (final w in words(t)) {
      String? best;
      for (final k in aliases.keys) {
        if (w.startsWith(k) && (best == null || k.length > best.length)) best = k;
      }
      if (best == null || (best.length <= 3 && w.length > best.length + 3)) continue;
      final f = foodByName[aliases[best]];
      if (f != null && !out.contains(f)) out.add(f);
    }
    return out.take(3).toList();
  }

  /// null — это не команда; иначе {kind, place, qty, foods, lang}
  static Map<String, dynamic>? parse(String message) {
    final t = message.toLowerCase();
    final ws = words(t);
    bool has(List<String> keys) => keys.any((k) => k.startsWith('=') ? ws.contains(k.substring(1)) : k.contains(' ') ? t.contains(k) : ws.any((w) => w.startsWith(k)));
    final question = t.contains('?') || has(['=can', '=how', '=should', '=what', '=why', 'можно', '=как', '=что', '=почему', 'стоит', 'қалай', 'неге']);
    if (question) return null;
    final Storage? place = has(['freezer', 'морозилк', 'морозильник', 'мұздатқыш']) ? Storage.freezer
        : has(['fridge', 'холодильник', 'тоңазытқыш']) ? Storage.fridge
        : has(['pantry', 'cupboard', 'шкаф']) ? Storage.pantry : null;
    final shopping = has(['shopping', '=list', 'список', 'покуп', 'тізім']);
    String? kind;
    if (has(['=threw', 'throw away', 'thrown', '=binned', 'выбросил', 'выкинул', 'выброси', 'тастадым'])) {
      kind = 'discard';
    } else if (has(['i ate', '=ate', '=eaten', 'съел', 'скушал', '=поел', '=поела', 'жедім'])) {
      kind = 'eat';
    } else if (has(['=freeze', '=froze', 'заморозь', 'заморозил', 'заморозить', 'мұздат']) && place != Storage.fridge) {
      kind = 'freeze';
    } else if (!shopping && has(['=add', '=put', '=bought', 'добавь', 'добавить', 'положи', '=купил', '=купила', '=қос', '=сал', 'сатып алдым'])) {
      kind = 'add';
    }
    if (kind == null) return null;
    var qty = 1;
    final num = ws.map(int.tryParse).firstWhere((n) => n != null && n > 0 && n < 100, orElse: () => null);
    if (num != null) {
      qty = num;
    } else {
      for (final e in numberWords.entries) {
        if (ws.contains(e.key)) { qty = e.value; break; }
      }
    }
    final found = foods(t);
    if (found.isEmpty && kind != 'add') return null;
    return {'kind': kind, 'place': place, 'qty': qty, 'foods': found, 'lang': lang(t)};
  }

  static String _tr(String l, String en, String ru, String kk) => l == 'ru' ? ru : l == 'kk' ? kk : en;

  static String _left(AppState s, FoodItem f, String l) {
    final n = s.pantry.where((p) => p.food.name == f.name).length;
    return n > 0 ? _tr(l, '×$n left.', 'Осталось ×$n.', '×$n қалды.') : _tr(l, 'None left.', 'Больше не осталось.', 'Енді қалмады.');
  }

  /// Одно действие с одним продуктом. Текст — по факту.
  static String run(AppState s, String kind, FoodItem f, int qty, Storage? place, String l) {
    final name = '${f.emoji} ${f.name}';
    if (kind == 'add') {
      final n = qty.clamp(1, 30).toInt();
      for (var i = 0; i < n; i++) {
        s.add(f, quiet: i < n - 1);
        if (place != null) s.pantry.last.storage = place;
      }
      final where = place ?? defaultStorage(f);
      final w = _tr(l, where == Storage.fridge ? 'fridge' : where == Storage.freezer ? 'freezer' : 'pantry',
          where == Storage.fridge ? 'холодильник' : where == Storage.freezer ? 'морозилку' : 'шкаф',
          where == Storage.fridge ? 'тоңазытқышқа' : where == Storage.freezer ? 'мұздатқышқа' : 'шкафқа');
      final total = s.pantry.where((p) => p.food.name == f.name).length;
      return _tr(l, '✅ Added $name ×$n to your $w', '✅ Добавил $name ×$n в $w', '✅ $name ×$n $w қосылды') +
          (total > n ? _tr(l, ' — now ×$total.', ' — теперь ×$total.', ' — енді ×$total.') : '.');
    }
    if (kind == 'shopping') {
      final had = s.shopping.contains(f.name);
      if (!had) s.addShopping([f.name]);
      return had
          ? _tr(l, '🛒 $name is already on your shopping list.', '🛒 $name уже есть в списке покупок.', '🛒 $name сатып алу тізімінде бар.')
          : _tr(l, '🛒 Added $name to your shopping list.', '🛒 Добавил $name в список покупок.', '🛒 $name сатып алу тізіміне қосылды.');
    }
    final rows = s.pantry.where((p) => p.food.name == f.name && (kind != 'freeze' || p.storage != Storage.freezer)).toList()
      ..sort((a, b) => a.expiry.compareTo(b.expiry));
    if (rows.isEmpty) {
      return _tr(l, "❌ There's no $name in your fridge — I didn't change anything.", '❌ $name нет в холодильнике — я ничего не менял.',
          '❌ Тоңазытқышта $name жоқ — ештеңе өзгертпедім.');
    }
    final n = min(qty, rows.length);
    if (kind == 'eat') {
      for (final p in rows.take(n).toList()) {
        s.eat(p, 100);
      }
      return _tr(l, '🍽️ Logged: you ate $name ×$n (≈${f.kcal * n} kcal, 100 g each). ', '🍽️ Записал: ты съел $name ×$n (≈${f.kcal * n} ккал, по 100 г). ',
              '🍽️ Жазып қойдым: $name ×$n жедің (≈${f.kcal * n} ккал). ') + _left(s, f, l);
    }
    if (kind == 'discard') {
      for (final p in rows.take(n).toList()) {
        s.throwAway(p, p.daysLeft < 0 ? WasteReason.expired : WasteReason.spoiled);
      }
      return _tr(l, '🗑️ Marked $name ×$n as thrown away (oldest first). ', '🗑️ Отметил: $name ×$n выброшено (сначала старое). ',
              '🗑️ Белгіледім: $name ×$n тасталды. ') + _left(s, f, l);
    }
    for (final p in rows.take(n).toList()) {
      s.freeze(p);
    }
    return _tr(l, '❄️ Moved $name ×$n to the freezer — good for ~3 months.', '❄️ Переложил $name ×$n в морозилку — хватит примерно на 3 месяца.',
        '❄️ $name ×$n мұздатқышқа салынды — шамамен 3 айға жетеді.');
  }

  static String? handle(String message, AppState s) {
    final p = parse(message);
    if (p == null) return null;
    final l = p['lang'] as String;
    final list = p['foods'] as List<FoodItem>;
    if (list.isEmpty) {
      return _tr(l, '🙈 I couldn\'t find that product in my food base, so I didn\'t change anything. Try: "add 2 eggs to fridge".',
          '🙈 Не нашёл такой продукт в базе, поэтому ничего не менял. Попробуй так: «добавь 2 яйца в холодильник».',
          '🙈 Бұл өнімді базадан таппадым, сондықтан ештеңе өзгертпедім. Былай жазып көр: «тоңазытқышқа 2 жұмыртқа қос».');
    }
    return list.map((f) => run(s, p['kind'] as String, f, p['qty'] as int, p['place'] as Storage?, l)).join('\n');
  }

  static FoodItem? resolve(String name) {
    final low = name.trim().toLowerCase();
    for (final v in [low, '${low}s', '${low}es', if (low.length > 3) low.substring(0, low.length - 1)]) {
      for (final f in foodDatabase) {
        if (f.name.toLowerCase() == v) return f;
      }
    }
    final r = foods(low);
    return r.isEmpty ? null : r.first;
  }

  /// Действия, предложенные ИИ-сервером: проверяем имя по базе, выполняем, подтверждение пишем сами.
  static String? perform(List actions, String userText, AppState s) {
    final l = lang(userText.toLowerCase());
    final lines = <String>[];
    for (final a in actions.take(5)) {
      if (a is! Map) continue;
      final type = '${a['type']}';
      final name = '${a['name'] ?? ''}';
      final qty = ((a['qty'] is num) ? (a['qty'] as num).round() : 1).clamp(1, 30).toInt();
      final f = resolve(name);
      if (f == null) {
        lines.add(_tr(l, '🙈 I couldn\'t find "$name" in my food base, so I didn\'t change anything.', '🙈 Не нашёл «$name» в базе продуктов, поэтому ничего не менял.',
            '🙈 «$name» өнімін базадан таппадым, сондықтан ештеңе өзгертпедім.'));
        continue;
      }
      switch (type) {
        case 'add_fridge':
          lines.add(run(s, 'add', f, qty, Storage.fridge, l));
        case 'add_freezer':
          lines.add(run(s, 'add', f, qty, Storage.freezer, l));
        case 'add_shopping':
          lines.add(run(s, 'shopping', f, qty, null, l));
        case 'eat':
        case 'discard':
        case 'freeze':
          lines.add(run(s, type, f, qty, null, l));
      }
    }
    return lines.isEmpty ? null : lines.join('\n');
  }
}

class MockAiService implements AiService {
  /// Названия продукта на всех трёх языках (без пояснений в скобках), в нижнем регистре.
  static Iterable<String> _names(FoodItem f) => {f.name, tn(f.name)}.map((n) => n.replaceAll(RegExp(r'\s*\(.*?\)'), '').toLowerCase());

  List<FoodItem> _mentioned(String t) {
    final words = t.split(RegExp(r'[^\p{L}]+', unicode: true)).toSet();
    // короткие названия («лук», «oca») — только целым словом, иначе «oca» находится в «avocado»
    final exact = foodDatabase.where((f) => _names(f).any((n) => n.length > 3 ? t.contains(n) : words.contains(n))).toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    if (exact.isNotEmpty) return exact.take(3).toList();
    // «помидоры», «жұмыртқаны»: сравниваем основу слова (без окончания)
    return foodDatabase
        .where((f) => _names(f).any((n) => n.split(' ').any((w) => w.length > 3 && t.contains(w.length > 5 ? w.substring(0, w.length - 2) : w))))
        .take(3)
        .toList();
  }

  @override
  Future<String> reply(String message, AppState s) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final t = message.toLowerCase();
    bool has(List<String> w) => w.any((x) => t.contains(x));
    final done = NutrikActions.handle(message, s);
    if (done != null) return done;
    final mentioned = _mentioned(t);
    final exp = s.expiringSoon;

    final dm = RegExp(r"(?:don't like|dont like|hate|allergic to|не люблю|не ем|аллергия на)\s+([^\s,.!?]+)").firstMatch(t) ??
        RegExp(r"([^\s,.!?]+)\s+(?:ұнамайды|жемеймін)").firstMatch(t);
    if (dm != null) {
      var w = mentioned.isNotEmpty ? mentioned.first.name.toLowerCase() : dm.group(1)!;
      if (mentioned.isEmpty) {
        if (w.endsWith('oes')) {
          w = w.substring(0, w.length - 2);
        } else if (w.endsWith('s')) {
          w = w.substring(0, w.length - 1);
        }
      }
      s.dislikes.add(w);
      return tr('Got it, {0}! I\'ll skip recipes with "{1}" from now on. 👍', [s.name, mentioned.isNotEmpty ? tn(mentioned.first.name) : w]);
    }
    if (RegExp(r'\b(hi|hello|hey)\b').hasMatch(t) || has(['привет', 'здравств', 'сәлем', 'салем'])) {
      return tr('Hi, {0}! 👋 You have {1} at home{2}. Ask me what to cook!', [s.name, trp(s.pantry.length, 'product|products'), '']);
    }
    if (has(['thank', 'спасибо', 'рахмет'])) return tr('Anytime! Happy cooking 🍳 (I\'ll be here, probably tripping over a carrot)');
    if (has(['calorie', 'kcal', 'калор', 'ккал'])) {
      if (mentioned.isNotEmpty) return mentioned.map((f) => tr('{0} {1}: {2} kcal per 100 g', [f.emoji, tn(f.name), f.kcal])).join('\n');
      final left = s.targetCalories - s.eatenCalories;
      return tr('Today: {0} of {1} kcal. {2}', [
        s.eatenCalories,
        s.targetCalories,
        left > 0 ? tr('{0} kcal left — {1}', [left, tr(left > 600 ? 'time for a proper meal! 🍲' : 'a light snack fits 🍎')]) : tr('Goal reached! 🎯'),
      ]);
    }
    if (has(['do i have', 'have i', 'is there', 'есть ли', 'у меня есть', 'бар ма']) && mentioned.isNotEmpty) {
      return mentioned
          .map((f) {
            final m = s.pantry.where((p) => p.food.name == f.name).toList()..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
            return m.isEmpty
                ? tr('{0} No {1} at home.', [f.emoji, tn(f.name)])
                : tr('{0} {1}: ×{2} in the {3}, soonest — {4}.', [f.emoji, tn(f.name), m.length, storageLabel[m.first.storage], m.first.status]);
          })
          .join('\n');
    }
    if (has(['freeze', 'freezer', 'замороз', 'морозил', 'мұздат', 'мұздатқыш']) && mentioned.isNotEmpty) {
      final yes = mentioned.where((f) => canFreeze(f) || f.category == 'Frozen').map((f) => tn(f.name)).toList();
      final no = mentioned.map((f) => tn(f.name)).where((n) => !yes.contains(n)).toList();
      return [
        if (yes.isNotEmpty) tr('❄️ {0}: yes! Frozen it keeps about 3 months. Tip: portion it first, so you thaw only what you need.', [yes.join(', ')]),
        if (no.isNotEmpty) tr('🚫 {0}: better not — the texture gets watery or it simply keeps fine without freezing. Use it fresh.', [no.join(', ')]),
      ].join('\n');
    }
    if (has(['store', 'keep', 'хран', 'сақта', 'last longer']) && mentioned.isNotEmpty) {
      return mentioned
          .map((f) => tr('{0} {1}: {2}. Usually lasts about {3}.',
              [f.emoji, tn(f.name), tr(storageTips[f.name] ?? storageTips[f.category] ?? 'keep it cool and dry'), trp(f.shelf, 'day|days')]))
          .join('\n');
    }
    if (has(['still good', 'still ok', 'safe to eat', 'can i eat', 'испорт', 'можно ли есть', 'бүлін', 'жеуге бола'])) {
      return tr('Trust your senses for "best before" products: look, smell, taste a little. ⚠️ But never risk it with meat, fish or dairy past the "use by" date. When in doubt — throw it out.');
    }
    if (has(['expire', 'waste', 'spoil', 'soon', 'срок', 'пропад', 'мерзім', 'бұзыл'])) {
      if (exp.isEmpty) return tr('Nothing is expiring soon. Great job! 🎉');
      return tr('Use these first: {0}.', [exp.map((e) => '${e.food.emoji} ${tn(e.food.name)} (${e.status})').join(', ')]);
    }
    if (has(['cook', 'recipe', 'eat', 'dinner', 'lunch', 'breakfast', 'hungry', 'suggest', 'make', 'more', 'another', 'else',
        'приготов', 'рецепт', 'ужин', 'обед', 'завтрак', 'голод', 'ещё', 'еще', 'другой', 'пісір', 'тамақ', 'кешкі ас', 'түскі ас', 'таңғы ас', 'тағы', 'басқа'])) {
      if (s.pantry.isEmpty) return tr('Your fridge is empty 😿 Add some products in the Search tab first — then I\'ll find you a recipe!');
      var list = rankRecipes(s);
      if (mentioned.isNotEmpty) {
        list = list.where((r) => r.ingredients.any((i) => mentioned.any((m) => m.name == i.name))).toList();
      }
      if (list.isEmpty) return tr('I couldn\'t find a recipe with that. Try another product! 🤔');
      s.suggestIndex = has(['more', 'another', 'else', 'ещё', 'еще', 'другой', 'тағы', 'басқа']) ? s.suggestIndex + 1 : 0;
      final r = list[s.suggestIndex % list.length];
      final miss = r.missing(s.pantryNames);
      return tr('{0} {1} — {2} kcal per serving, {3}.{4} {5} Say "another" for more ideas.', [
        r.emoji,
        tn(r.name),
        r.kcal,
        trTime(r.time),
        r.zeroWaste ? tr(' ♻️ Zero-waste!') : '',
        miss.isEmpty ? tr('You have everything!') : tr('You still need: {0}.', [miss.map(tn).join(', ')]),
      ]);
    }
    return tr('Sorry, I didn\'t quite get "{0}". Try: "what can I cook?", "what expires soon?", "how to store tomatoes", "can I freeze bread?", "do I have milk?" or "I don\'t like onion".', [message]);
  }
}

const storageTips = {
  'Tapioca Pearls': 'dry pearls in a closed jar; cooked pearls get hard in a few hours, so cook only what you drink today',
  'Lotus Root': 'wrapped in a damp paper towel in the fridge; once cut, keep slices in water with a little vinegar',
  'Pandan Leaves': 'wrapped in a paper towel in a bag in the fridge, or freeze whole leaves for months',
  'Kataifi': 'keep the pack sealed in the fridge; freeze what you don\'t use — it thaws in 2 hours',
  'Soursop': 'ripen at room temperature until soft, then eat within a day or freeze the pulp',
  'Tomato': 'keep at room temperature, stem down, away from sunlight — the fridge kills the flavor',
  'Banana': 'keep apart from other fruit (bananas make them ripen faster); wrap the stems in foil',
  'Potato': 'dark, cool and dry place, never next to onions',
  'Onion': 'dry, airy and dark place, away from potatoes',
  'Bread': 'in a bread box or paper bag; freeze the slices you won\'t eat within 2 days',
  'White Bread': 'in a bread box or paper bag; freeze the slices you won\'t eat within 2 days',
  'Milk': 'on a fridge shelf, not in the door — the door is the warmest spot',
  'Eggs': 'in their box on a fridge shelf, not in the door',
  'Apple': 'in the fridge crisper drawer, separately from vegetables',
  'Avocado': 'ripen on the counter, then move to the fridge to slow it down',
  'Spinach': 'in a box lined with a paper towel to soak up moisture',
  'Lettuce': 'wrapped in a damp towel inside a bag in the crisper drawer',
  'Cheddar Cheese': 'wrapped in wax or baking paper, not plastic — cheese needs to breathe',
  'Strawberry': 'unwashed, in one layer on a paper towel; wash right before eating',
  'Carrot': 'cut off the green tops, store in the crisper drawer',
  'Herbs': 'like flowers: stems in a glass of water',
  'Vegetables': 'in the crisper drawer of the fridge',
  'Fruits': 'in the fridge or a cool place, away from bananas',
  'Berries': 'unwashed in the fridge, wash just before eating',
  'Dairy': 'on a middle fridge shelf, not in the door',
  'Meat': 'on the bottom shelf of the fridge (coldest), or freeze within 2 days',
  'Seafood': 'on ice on the bottom shelf, eat within 1–2 days or freeze',
  'Bakery': 'in a bread box; freeze what you can\'t eat soon',
  'Grains': 'airtight jar in a dry cupboard',
  'Frozen': 'at −18 °C, never refreeze after thawing',
  'Ready Meals': 'in a closed container in the fridge, eat within 2–3 days',
};

// ───────────────────────── АНИМАЦИИ ─────────────────────────

class Appear extends StatefulWidget {
  final Widget child;
  final int index;
  const Appear({super.key, required this.child, this.index = 0});
  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  late final Animation<double> a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: 60 * widget.index.clamp(0, 10)), () {
      if (mounted) c.forward();
    });
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(a),
      child: widget.child,
    ),
  );
}

Route<T> fadeSlide<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 450),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);

const titleStyle = TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: burgundy);
const headStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: burgundy);

// ───────────────────────── ПРИЛОЖЕНИЕ ─────────────────────────

final appState = AppState();
final aiService = SmartAiService();

class CalorieApp extends StatelessWidget {
  const CalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // системные тексты Flutter (календарь, «Отмена»/«OK») — на языке приложения; смена языка — через locale: у пикеров
      locale: Locale(appLang),
      supportedLocales: const [Locale('en'), Locale('ru'), Locale('kk')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'serif',
        colorScheme: ColorScheme.fromSeed(
          seedColor: burgundy,
          primary: burgundy,
        ).copyWith(surface: cream, surfaceTint: Colors.transparent, secondaryContainer: const Color(0xFFE8DFC8), primaryContainer: const Color(0xFFE8DFC8)),
        scaffoldBackgroundColor: cream,
      ),
      home: appState.registered ? MainScreen(state: appState, ai: aiService) : RegisterScreen(state: appState, ai: aiService),
    );
  }
}

// ───────────────────────── НУТРИК (маскот) ─────────────────────────
// Чиби-девочка-кошка: чёрное каре с ушками, бежевая рубашка-оверсайз с красным бантом,
// хвост и листик-заколка (символ свежей еды). Рисуется целиком в CustomPainter.

enum NutrikMode { idle, walk, run, eat, fall, sleep, wave, dance, dangle, stretch, love, sit, sad, jump, cheer }

class NutrikPainter extends CustomPainter {
  final NutrikMode mode;
  final double t, blink, mouth, look, tilt, point;
  final bool hasPoint, stars;
  final String? snack;
  NutrikPainter(this.mode, this.t, this.blink, this.mouth, this.look, this.tilt, this.point, this.hasPoint, this.stars, this.snack);

  static const ink = Color(0xFF2A1F2D);
  static const hairC = Color(0xFF1F1B24);
  static const hairHi = Color(0xFF4A4357);
  static const skin = Color(0xFFFFE8D8);
  static const shirt = Color(0xFFE9C79A);
  static const shirtDark = Color(0xFFD6B080);
  static const shorts = Color(0xFF3B3F4C);
  static const bowC = Color(0xFFC0392B);
  static const pink = Color(0xFFF4A7B0);

  Paint fill(Color c) => Paint()..color = c;
  Paint line(double w, [Color c = ink]) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 100, size.height / 100);
    final m = mode;
    final cyc = t * 2 * pi;
    final moving = m == NutrikMode.walk || m == NutrikMode.run;
    final step = sin(cyc * (m == NutrikMode.run ? 4 : 2));
    final seated = m == NutrikMode.sit || m == NutrikMode.sleep;

    if (m != NutrikMode.dangle) {
      c.drawOval(Rect.fromCenter(center: const Offset(50, 96), width: m == NutrikMode.jump ? 22 : 36, height: 5), fill(Colors.black.withValues(alpha: 0.12)));
    }
    final bob = moving
        ? -2.2 * step.abs()
        : m == NutrikMode.dance
        ? -2.5 * sin(cyc * 2).abs()
        : 0.0;
    final sway = m == NutrikMode.dance
        ? 0.12 * sin(cyc * 2)
        : m == NutrikMode.dangle
        ? 0.1 * sin(cyc)
        : 0.0;
    c.translate(50, 94);
    c.rotate(tilt + sway);
    c.scale(1, 1 + (m == NutrikMode.sleep ? 0.03 : 0.015) * sin(cyc)); // дыхание
    c.translate(-50, -94 + bob + (seated ? 7 : 0));

    _tail(c, cyc, m);
    _legs(c, cyc, m, step, seated);
    _body(c);
    final armsUp = m == NutrikMode.stretch || m == NutrikMode.cheer || m == NutrikMode.jump;
    if (armsUp) _arms(c, cyc, m, step);
    _head(c, cyc, m);
    if (!armsUp) _arms(c, cyc, m, step);
    _extras(c, cyc, m);
    c.restore();
  }

  void _tail(Canvas c, double cyc, NutrikMode m) {
    final happy = m == NutrikMode.dance || m == NutrikMode.love || m == NutrikMode.cheer;
    final wag = happy
        ? sin(cyc * 3) * 8
        : m == NutrikMode.sleep
        ? 0.0
        : sin(cyc) * 4;
    final p = Path()..moveTo(59, 76);
    if (m == NutrikMode.dangle || m == NutrikMode.sad) {
      p.cubicTo(66, 82, 68, 90, 64 + wag * 0.3, 98);
    } else if (m == NutrikMode.sleep || m == NutrikMode.sit) {
      p.cubicTo(74, 82, 76, 94, 56, 95);
    } else {
      p.cubicTo(76, 80, 86 + wag * 0.4, 68, 80 + wag, 52);
    }
    c.drawPath(p, line(9.5));
    c.drawPath(p, line(7, hairC));
    c.drawPath(p, line(1.2, hairHi));
  }

  void _legs(Canvas c, double cyc, NutrikMode m, double step, bool seated) {
    void leg(double hip, Offset foot) {
      c.drawLine(Offset(hip, 80), foot, line(6.2));
      c.drawLine(Offset(hip, 80), foot, line(4.4, skin));
      final f = Rect.fromCenter(center: foot.translate(1.2, 0.6), width: 7.5, height: 4.4);
      c.drawOval(f, fill(skin));
      c.drawOval(f, line(1.1));
    }

    if (seated) {
      leg(45, const Offset(36, 87));
      leg(55, const Offset(64, 87));
    } else if (m == NutrikMode.dangle) {
      final s = sin(cyc * 2) * 2.5;
      leg(45, Offset(44 + s, 96));
      leg(55, Offset(56 - s, 96));
    } else if (m == NutrikMode.jump) {
      leg(45, const Offset(41, 88));
      leg(55, const Offset(59, 88));
    } else if (m == NutrikMode.walk || m == NutrikMode.run) {
      final k = m == NutrikMode.run ? 5.0 : 3.5;
      leg(45, Offset(45 + step * k, 93 - max(0.0, step) * 3));
      leg(55, Offset(55 - step * k, 93 - max(0.0, -step) * 3));
    } else if (m == NutrikMode.dance) {
      final s = sin(cyc * 2);
      leg(45, Offset(43 + s * 2, 93 - max(0.0, s) * 4));
      leg(55, Offset(57 + s * 2, 93 - max(0.0, -s) * 4));
    } else {
      leg(45, const Offset(44, 93));
      leg(55, const Offset(56, 93));
    }
  }

  void _body(Canvas c) {
    final sh = RRect.fromRectAndRadius(const Rect.fromLTRB(39, 74, 61, 83), const Radius.circular(3));
    c.drawRRect(sh, fill(shorts));
    c.drawRRect(sh, line(1.3));
    final p = Path()
      ..moveTo(41, 56)
      ..quadraticBezierTo(36, 66, 33, 79)
      ..quadraticBezierTo(50, 83, 67, 79)
      ..quadraticBezierTo(64, 66, 59, 56)
      ..close();
    c.drawPath(p, fill(shirt));
    c.save();
    c.clipPath(p);
    c.drawRect(const Rect.fromLTRB(30, 76, 70, 86), fill(shirtDark));
    c.restore();
    c.drawPath(p, line(1.6));
    c.drawPath(
      Path()
        ..moveTo(43, 56)
        ..lineTo(50, 63)
        ..lineTo(57, 56),
      line(1.2),
    );
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTRB(54, 69, 61, 75), const Radius.circular(1.5)), line(0.9, ink.withValues(alpha: 0.55)));
    final b = fill(bowC);
    c.drawPath(
      Path()
        ..moveTo(50, 61)
        ..lineTo(43.5, 57.5)
        ..lineTo(44, 64.5)
        ..close(),
      b,
    );
    c.drawPath(
      Path()
        ..moveTo(50, 61)
        ..lineTo(56.5, 57.5)
        ..lineTo(56, 64.5)
        ..close(),
      b,
    );
    c.drawPath(
      Path()
        ..moveTo(49, 62)
        ..lineTo(46.5, 68)
        ..lineTo(48.6, 67.4)
        ..close(),
      b,
    );
    c.drawPath(
      Path()
        ..moveTo(51, 62)
        ..lineTo(53.5, 68)
        ..lineTo(51.4, 67.4)
        ..close(),
      b,
    );
    c.drawCircle(const Offset(50, 61), 1.8, fill(const Color(0xFF962D22)));
  }

  void _arm(Canvas c, Offset from, Offset to) {
    c.drawLine(from, to, line(7.6));
    c.drawLine(from, to, line(5.8, shirt));
    c.drawCircle(to, 2.7, fill(skin));
    c.drawCircle(to, 2.7, line(1.1));
  }

  void _arms(Canvas c, double cyc, NutrikMode m, double step) {
    const l = Offset(42, 59), r = Offset(58, 59);
    if (hasPoint) {
      final right = cos(point) >= 0;
      final s = right ? r : l;
      _arm(c, s, s + Offset(cos(point), sin(point)) * 18);
      _arm(c, right ? l : r, right ? const Offset(36, 73) : const Offset(64, 73));
      return;
    }
    switch (m) {
      case NutrikMode.eat:
        _arm(c, l, const Offset(46, 52));
        _arm(c, r, const Offset(54, 52));
      case NutrikMode.wave:
        _arm(c, l, const Offset(36, 74));
        _arm(c, r, Offset(72 + sin(cyc * 4) * 3, 42));
      case NutrikMode.dance:
        final up = sin(cyc * 2) > 0;
        _arm(c, l, up ? const Offset(31, 46) : const Offset(34, 72));
        _arm(c, r, up ? const Offset(66, 72) : const Offset(69, 46));
      case NutrikMode.stretch:
        _arm(c, l, Offset(34, 30 + sin(cyc) * 2));
        _arm(c, r, Offset(66, 30 + sin(cyc) * 2));
      case NutrikMode.cheer || NutrikMode.jump:
        _arm(c, l, const Offset(29, 44));
        _arm(c, r, const Offset(71, 44));
      case NutrikMode.dangle || NutrikMode.sad:
        _arm(c, l, const Offset(40, 76));
        _arm(c, r, const Offset(60, 76));
      case NutrikMode.walk || NutrikMode.run:
        _arm(c, l, Offset(35, 72 + step * 4));
        _arm(c, r, Offset(65, 72 - step * 4));
      case NutrikMode.sleep || NutrikMode.sit:
        _arm(c, l, const Offset(44, 77));
        _arm(c, r, const Offset(56, 77));
      case NutrikMode.fall:
        _arm(c, l, const Offset(30, 52));
        _arm(c, r, const Offset(70, 52));
      case NutrikMode.love:
        _arm(c, l, const Offset(47, 67));
        _arm(c, r, const Offset(53, 67));
      case NutrikMode.idle:
        _arm(c, l, Offset(36, 73 + sin(cyc)));
        _arm(c, r, Offset(64, 73 - sin(cyc)));
    }
  }

  void _head(Canvas c, double cyc, NutrikMode m) {
    final droop = m == NutrikMode.sad || m == NutrikMode.dangle || m == NutrikMode.sleep ? 1.0 : 0.0;
    final twitch = sin(cyc * 3) > 0.93 ? 0.18 : 0.0;
    // волосы сзади
    c.drawOval(Rect.fromCenter(center: const Offset(50, 35), width: 52, height: 46), fill(hairC));
    c.drawPath(
      Path()
        ..moveTo(26, 32)
        ..quadraticBezierTo(21, 48, 27, 57)
        ..lineTo(35, 50)
        ..close(),
      fill(hairC),
    );
    c.drawPath(
      Path()
        ..moveTo(74, 32)
        ..quadraticBezierTo(79, 48, 73, 57)
        ..lineTo(65, 50)
        ..close(),
      fill(hairC),
    );
    // ушки
    void ear(Offset base, double side, double rot) {
      c.save();
      c.translate(base.dx, base.dy);
      c.rotate(rot);
      c.scale(side, 1); // правое ушко — зеркальная копия левого
      final o = Path()
        ..moveTo(-8, 4)
        ..quadraticBezierTo(-6, -7, -3, -17)
        ..quadraticBezierTo(4, -9, 8, 3)
        ..close();
      c.drawPath(o, fill(hairC));
      c.drawPath(o, line(1.1));
      c.save();
      c.translate(-1.5, -5);
      c.scale(0.5);
      c.translate(1.5, 5);
      c.drawPath(o, fill(pink));
      c.restore();
      c.restore();
    }

    ear(const Offset(35, 16), 1, -0.22 - 0.45 * droop - twitch);
    ear(const Offset(65, 16), -1, 0.22 + 0.45 * droop);
    // лицо
    c.drawOval(Rect.fromCenter(center: const Offset(50, 39), width: 41, height: 34), fill(skin));
    // чёлка
    final bangs = Path()
      ..moveTo(25, 36)
      ..quadraticBezierTo(25, 10, 50, 11)
      ..quadraticBezierTo(75, 10, 75, 36)
      ..lineTo(71, 30)
      ..lineTo(68, 35)
      ..lineTo(63, 27)
      ..lineTo(59, 33)
      ..lineTo(54, 26)
      ..lineTo(50, 32)
      ..lineTo(45, 26)
      ..lineTo(41, 33)
      ..lineTo(36, 27)
      ..lineTo(32, 35)
      ..lineTo(29, 30)
      ..close();
    c.drawPath(bangs, fill(hairC));
    c.drawArc(Rect.fromCenter(center: const Offset(50, 22), width: 34, height: 15), pi * 1.1, pi * 0.5, false, line(1.6, hairHi));
    // пряди по бокам лица
    c.drawPath(
      Path()
        ..moveTo(27, 30)
        ..quadraticBezierTo(24, 45, 29, 53)
        ..lineTo(32, 44)
        ..quadraticBezierTo(30, 37, 31, 32)
        ..close(),
      fill(hairC),
    );
    c.drawPath(
      Path()
        ..moveTo(73, 30)
        ..quadraticBezierTo(76, 45, 71, 53)
        ..lineTo(68, 44)
        ..quadraticBezierTo(70, 37, 69, 32)
        ..close(),
      fill(hairC),
    );
    // листик-заколка
    c.save();
    c.translate(67, 20);
    c.rotate(0.6);
    c.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 5), fill(const Color(0xFF6DBE45)));
    c.drawLine(const Offset(-4, 0), const Offset(4, 0), line(0.8, const Color(0xFF3E7D22)));
    c.restore();
    _face(c, cyc, m);
  }

  void _face(Canvas c, double cyc, NutrikMode m) {
    c.drawOval(Rect.fromCenter(center: const Offset(36.5, 48), width: 6.5, height: 3.2), fill(pink.withValues(alpha: 0.75)));
    c.drawOval(Rect.fromCenter(center: const Offset(63.5, 48), width: 6.5, height: 3.2), fill(pink.withValues(alpha: 0.75)));
    final happy = m == NutrikMode.love || m == NutrikMode.dance || m == NutrikMode.cheer || m == NutrikMode.jump;
    final closed = m == NutrikMode.sleep || m == NutrikMode.stretch;
    for (final (i, cx) in const [(0, 42.0), (1, 58.0)]) {
      if (m == NutrikMode.fall) {
        c.drawCircle(Offset(cx, 42), 3.2, line(1));
        c.drawCircle(Offset(cx, 42), 1.3, line(1));
      } else if (happy) {
        c.drawArc(Rect.fromCenter(center: Offset(cx, 43.5), width: 7, height: 6), pi, pi, false, line(1.7));
      } else if (closed || blink > 0.85) {
        c.drawArc(Rect.fromCenter(center: Offset(cx, 41), width: 7, height: 5), 0.2, pi - 0.4, false, line(1.5));
      } else if (m == NutrikMode.dangle && i == 1) {
        // недовольный прищур, как на референсе
        c.drawLine(Offset(cx - 3.6, 43), Offset(cx + 3.4, 41.6), line(1.6));
      } else {
        final h = 9.0 * (1 - blink);
        final ex = cx + look * 0.8;
        final eye = Rect.fromCenter(center: Offset(ex, 42.5), width: 6.6, height: h);
        c.drawOval(eye, fill(const Color(0xFF2B2235)));
        c.drawOval(Rect.fromCenter(center: Offset(ex, 44.6), width: 4.4, height: h * 0.38), fill(const Color(0xFF8A5A9E)));
        if (blink < 0.5) {
          c.drawCircle(Offset(ex - 1.3, 40.4), 1.4, fill(Colors.white));
          c.drawCircle(Offset(ex + 1.2, 44.8), 0.6, fill(Colors.white));
        }
        c.drawArc(Rect.fromCenter(center: Offset(ex, 42.5), width: 7.8, height: h + 1), pi * 1.08, pi * 0.84, false, line(1.5));
      }
    }
    if (m == NutrikMode.sad) {
      final ty = 46 + (t * 9) % 9;
      c.drawOval(Rect.fromCenter(center: Offset(38.5, ty), width: 2.2, height: 3.2), fill(const Color(0xBB6EC6FF)));
      c.drawOval(Rect.fromCenter(center: Offset(61.5, ty), width: 2.2, height: 3.2), fill(const Color(0xBB6EC6FF)));
    }
    // рот
    final open = m == NutrikMode.stretch ? 0.6 + 0.4 * sin(cyc).abs() : mouth;
    if (snack != null) return; // рот закрыт едой
    if (open > 0.05) {
      c.drawOval(Rect.fromCenter(center: const Offset(50, 50.8), width: 3.4 + open * 1.6, height: 1.2 + open * 3.8), fill(const Color(0xFF8E2B3A)));
      if (open > 0.45) c.drawOval(Rect.fromCenter(center: const Offset(50, 52), width: 2.4, height: 1.2), fill(const Color(0xFFFF8A9A)));
    } else if (m == NutrikMode.dangle || m == NutrikMode.sad) {
      c.drawArc(Rect.fromCenter(center: const Offset(50, 52.2), width: 4, height: 3), pi * 1.1, pi * 0.8, false, line(1.1));
    } else {
      // кошачий ротик «ω»
      c.drawArc(Rect.fromCenter(center: const Offset(48.6, 49.8), width: 2.8, height: 2.4), 0, pi, false, line(1.0));
      c.drawArc(Rect.fromCenter(center: const Offset(51.4, 49.8), width: 2.8, height: 2.4), 0, pi, false, line(1.0));
    }
  }

  Path _heart(Offset o, double s) => Path()
    ..moveTo(o.dx, o.dy + s * 0.9)
    ..cubicTo(o.dx - s * 1.6, o.dy - s * 0.2, o.dx - s * 0.6, o.dy - s * 1.3, o.dx, o.dy - s * 0.4)
    ..cubicTo(o.dx + s * 0.6, o.dy - s * 1.3, o.dx + s * 1.6, o.dy - s * 0.2, o.dx, o.dy + s * 0.9);

  void _text(Canvas c, String s, Offset o, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, o - Offset(tp.width / 2, tp.height / 2));
  }

  void _extras(Canvas c, double cyc, NutrikMode m) {
    for (var k = 0; k < 3; k++) {
      final p = (t + k / 3) % 1;
      if (m == NutrikMode.sleep) _text(c, 'z', Offset(68 + p * 12, 22 - p * 18), 5 + p * 5, ink.withValues(alpha: 1 - p));
      if (m == NutrikMode.love) c.drawPath(_heart(Offset(38 + k * 12 + sin(p * 6) * 2, 18 - p * 16), 2.2 + p * 1.5), fill(const Color(0xFFE84A6F).withValues(alpha: 1 - p)));
      if (m == NutrikMode.dance) _text(c, k.isEven ? '♪' : '♫', Offset(k == 1 ? 80 : 20 + k * 30, 30 - p * 20), 8, ink.withValues(alpha: 1 - p));
    }
    if (stars || m == NutrikMode.fall) {
      for (var k = 0; k < 3; k++) {
        final a = cyc * 2 + k * 2 * pi / 3;
        c.drawCircle(Offset(50 + 18 * cos(a), 9 + 4 * sin(a)), 2.4, fill(Colors.amber));
      }
    }
    if (m == NutrikMode.run) c.drawOval(Rect.fromCenter(center: const Offset(74, 26), width: 3, height: 4.5), fill(const Color(0xAA6EC6FF)));
    if (m == NutrikMode.cheer) {
      for (var k = 0; k < 4; k++) {
        final a = cyc + k * pi / 2;
        c.drawCircle(Offset(50 + 30 * cos(a), 34 + 22 * sin(a)), 1.4, fill(const Color(0xFFFFC94D)));
      }
    }
    if (snack != null) _text(c, snack!, Offset(50, 52 + sin(cyc * 4)), 10, Colors.black);
  }

  @override
  bool shouldRepaint(covariant NutrikPainter o) => true;
}

class Nutrik extends StatefulWidget {
  final NutrikMode mode;
  final bool talking, faceRight, stars;
  final double? point;
  final double size, tilt;
  final String? snack;
  const Nutrik({super.key, this.mode = NutrikMode.idle, this.talking = false, this.faceRight = true, this.stars = false, this.point, this.size = 100, this.tilt = 0, this.snack});
  @override
  State<Nutrik> createState() => _NutrikState();
}

class _NutrikState extends State<Nutrik> with TickerProviderStateMixin {
  late final AnimationController cycle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  late final AnimationController blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
  final _r = Random();

  @override
  void initState() {
    super.initState();
    _blinkLoop();
  }

  Future<void> _blinkLoop() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 1800 + _r.nextInt(2600)));
      if (!mounted) return;
      await blink.forward(from: 0);
      if (!mounted) return;
      await blink.reverse();
    }
  }

  @override
  void dispose() {
    cycle.dispose();
    blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([cycle, blink]),
      builder: (_, _) {
        final t = cycle.value;
        var m = 0.0;
        if (widget.mode == NutrikMode.fall) {
          m = 0.6;
        } else if (widget.mode == NutrikMode.cheer || widget.mode == NutrikMode.jump) {
          m = 0.7;
        } else if (widget.talking) {
          m = sin(t * 2 * pi * 4).abs();
        }
        final look = widget.talking ? 0.0 : sin(DateTime.now().millisecondsSinceEpoch / 1000 * 0.8);
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(widget.faceRight ? 1 : -1, 1, 1),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: NutrikPainter(widget.mode, t, blink.value, m, look, widget.tilt, widget.point ?? 0, widget.point != null, widget.stars, widget.snack),
          ),
        );
      },
    );
  }
}

/// Нутрик + облачко, в котором текст печатается, а рот двигается.
class NutrikSays extends StatefulWidget {
  final String text;
  final double? point;
  final double size;
  final NutrikMode mode;
  const NutrikSays({super.key, required this.text, this.point, this.size = 96, this.mode = NutrikMode.idle});
  @override
  State<NutrikSays> createState() => _NutrikSaysState();
}

class _NutrikSaysState extends State<NutrikSays> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 22 * widget.text.length),
  )..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, _) {
        final n = (c.value * widget.text.length).round();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Nutrik(size: widget.size, talking: c.value < 1, point: widget.point, mode: widget.mode),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () => c.value = 1, // тап — показать весь текст сразу
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: burgundy, width: 1.5),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Stack(
                    children: [
                      Opacity(opacity: 0, child: Text(widget.text, style: const TextStyle(fontSize: 15))),
                      Text(widget.text.substring(0, n), style: const TextStyle(fontSize: 15, color: Colors.black87)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Плавающие еда-эмодзи на фоне.
class FloatingFood extends StatefulWidget {
  const FloatingFood({super.key});
  @override
  State<FloatingFood> createState() => _FloatingFoodState();
}

class _FloatingFoodState extends State<FloatingFood> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
  static const items = ['🍎', '🥕', '🧀', '🍞', '🥑', '🍓', '🥛', '🍌', '🥦', '🍅', '🥚', '🍋'];

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => Stack(
      children: [
        for (var k = 0; k < items.length; k++)
          Align(
            alignment: Alignment((k / (items.length - 1)) * 2 - 1, 1 - ((c.value + k * 0.37) % 1) * 2.4),
            child: Transform.rotate(
              angle: sin((c.value + k) * 2 * pi) * 0.4,
              child: Opacity(opacity: 0.22, child: Text(items[k], style: const TextStyle(fontSize: 30))),
            ),
          ),
      ],
    ),
  );
}

// События приложения, на которые Нутрик реагирует (выбросили еду, приготовили, спасли...).
final nutrikEvents = ValueNotifier<(String, int)>(('', 0));
void nutrikEvent(String e) => nutrikEvents.value = (e, nutrikEvents.value.$2 + 1);

/// Нутрик живёт внизу экрана. Сама гуляет, бегает, спит, танцует, ест, ловит бабочек...
/// Тап — погладить, двойной тап — подпрыгнуть, можно схватить, таскать и даже бросить.
class NutrikRoamer extends StatefulWidget {
  final bool paused;
  final double bottom;
  final AppState? state;
  const NutrikRoamer({super.key, required this.paused, this.bottom = 6, this.state});
  @override
  State<NutrikRoamer> createState() => _RoamerState();
}

class _RoamerState extends State<NutrikRoamer> with SingleTickerProviderStateMixin {
  static const size = 72.0;
  static const gravity = 2200.0;
  final _r = Random();
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double x = 30, y = 0, vx = 0, vy = 0, tilt = 0; // y — высота над «полом»
  double w = 360, h = 600;
  double? targetX;
  double speed = 70;
  bool held = false, right = true, _busy = false;
  NutrikMode mode = NutrikMode.idle;
  String? snack, say;
  Offset? fly; // бабочка
  double _flyT = 0;
  int _gen = 0, _pokes = 0, _sayId = 0;
  DateTime _lastPoke = DateTime(2000);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
    nutrikEvents.addListener(_onEvent);
    _life();
  }

  @override
  void dispose() {
    nutrikEvents.removeListener(_onEvent);
    _ticker.dispose();
    super.dispose();
  }

  // ── физика и ходьба ──
  void _tick(Duration el) {
    final dt = ((el - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = el;
    var changed = false;
    if (fly != null) {
      _flyT += dt;
      fly = Offset((w * (0.5 + 0.42 * sin(_flyT * 0.9))).clamp(0, w - 24), 60 + 40 * sin(_flyT * 2.3).abs());
      changed = true;
    }
    if (held) {
      if (changed) setState(() {});
      return;
    }
    if (y > 0 || vy > 0) {
      vy -= gravity * dt;
      x += vx * dt;
      y += vy * dt;
      if (x < 0 || x > w - size) {
        x = x.clamp(0.0, max(0.0, w - size));
        vx = -vx * 0.5;
      }
      if (y > h - size) {
        y = h - size;
        vy = -vy.abs() * 0.3;
      }
      if (y <= 0) {
        y = 0;
        final impact = -vy;
        vy = 0;
        if (impact > 1150) {
          vx = 0;
          _land(hard: true);
        } else if (impact > 380) {
          vy = impact * 0.32; // отскок
          vx *= 0.6;
        } else {
          vx = 0;
          _land(hard: false);
        }
      }
      changed = true;
    } else if (targetX != null) {
      final d = targetX! - x;
      final s = speed * dt;
      if (d.abs() <= s) {
        x = targetX!;
        targetX = null;
      } else {
        x += s * d.sign;
        right = d > 0;
      }
      changed = true;
    }
    if (changed && mounted) setState(() {});
  }

  void _land({required bool hard}) {
    final g = ++_gen;
    if (hard) {
      _busy = true;
      setState(() {
        mode = NutrikMode.fall;
        tilt = right ? 1.35 : -1.35;
      });
      _quip(['Ouch! My tail! 😵', 'Owie... gentle please!', 'I can\'t fly! 🙀', 'The floor is hard...'][_r.nextInt(4)]);
      Future.delayed(const Duration(milliseconds: 1700), () {
        if (!mounted || g != _gen) return;
        setState(() {
          tilt = 0;
          mode = NutrikMode.sad;
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted && g == _gen) setState(() => mode = NutrikMode.idle);
          _busy = false;
        });
      });
    } else {
      setState(() {
        tilt = 0;
        mode = NutrikMode.idle;
      });
      _busy = false;
    }
  }

  // ── хелперы поведения ──
  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));
  bool _alive(int g) => mounted && g == _gen && !held && y == 0;

  void _quip(String s, [int ms = 2200]) {
    if (!mounted) return;
    final id = ++_sayId;
    setState(() => say = s);
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && id == _sayId) setState(() => say = null);
    });
  }

  Future<bool> _walkTo(double tx, int g, {bool run = false}) async {
    targetX = tx.clamp(0.0, max(0.0, w - size));
    speed = run ? 190 : 75;
    setState(() => mode = run ? NutrikMode.run : NutrikMode.walk);
    while (targetX != null) {
      await _wait(40);
      if (!_alive(g)) {
        targetX = null;
        return false;
      }
    }
    return true;
  }

  Future<bool> _do(NutrikMode m, int ms, int g, {String? line, String? food}) async {
    if (!_alive(g)) return false;
    setState(() {
      mode = m;
      snack = food;
    });
    if (line != null) _quip(line, min(ms + 400, 2600));
    await _wait(ms);
    if (mounted) setState(() => snack = null);
    return _alive(g);
  }

  void _hop([double power = 560]) {
    vy = power;
    y = 0.1;
    setState(() => mode = NutrikMode.jump);
  }

  String _idleLine() {
    final s = widget.state;
    final exp = s?.toRescue ?? [];
    final dead = s?.expired ?? [];
    if (dead.isNotEmpty && _r.nextBool()) return tr('{0} smells funny... 👃', ['${dead.first.food.emoji} ${tn(dead.first.food.name)}']);
    if (exp.isNotEmpty && _r.nextBool()) {
      final p = exp.first;
      return p.daysLeft == 0 ? tr('Eat the {0} today, please! 🥺', [tn(p.food.name)]) : tr('⏳ {0} spoils in {1} d!', [tn(p.food.name), p.daysLeft]);
    }
    return ['Is it snack time yet?', 'Don\'t waste food, nya!', 'Did you check the fridge?', 'Old food goes to the front!', 'Leftovers = free lunch 😋', 'I love a clean fridge ✨'][_r.nextInt(6)];
  }

  // ── жизнь: случайные занятия ──
  Future<void> _life() async {
    await _wait(1200);
    while (mounted) {
      await _wait(1600 + _r.nextInt(2800));
      if (!mounted) return;
      if (widget.paused || held || _busy || y > 0) continue;
      final g = ++_gen;
      await _randomAction(g);
      if (mounted && g == _gen && !held && y == 0) {
        setState(() {
          mode = NutrikMode.idle;
          snack = null;
        });
      }
    }
  }

  Future<void> _randomAction(int g) async {
    final roll = _r.nextInt(100);
    final far = _r.nextDouble() * max(0.0, w - size);
    if (roll < 18) {
      await _walkTo(far, g);
    } else if (roll < 24) {
      _quip('Zoomies! 💨', 1400);
      if (await _walkTo(x < w / 2 ? w - size : 0, g, run: true)) await _walkTo(far, g, run: true);
    } else if (roll < 31) {
      // спотыкается
      if (!await _walkTo((x + far) / 2, g)) return;
      setState(() {
        mode = NutrikMode.fall;
        tilt = right ? 1.35 : -1.35;
      });
      _quip(['Oops! Tiny legs... 😵', 'Who put that there?!', '*trips gracefully*'][_r.nextInt(3)]);
      await _wait(1600);
      if (!mounted || g != _gen) return;
      setState(() => tilt = 0);
    } else if (roll < 41) {
      await _do(NutrikMode.eat, 3000, g, line: ['Nom nom nom...', 'Yum! 😋', 'Crunchy!'][_r.nextInt(3)], food: ['🍎', '🧀', '🍙', '🥕', '🍪', '🍌', '🍓', '🥐'][_r.nextInt(8)]);
    } else if (roll < 50) {
      setState(() => mode = NutrikMode.stretch);
      _quip('*yaaawn*', 1500);
      await _wait(1600);
      if (!_alive(g)) return;
      setState(() => mode = NutrikMode.sleep);
      _busy = true;
      await _wait(6000 + _r.nextInt(5000));
      _busy = false;
      if (_alive(g)) await _do(NutrikMode.stretch, 1200, g, line: 'Good nap!');
    } else if (roll < 58) {
      await _do(NutrikMode.dance, 3600, g, line: ['La-la-la~ ♪', 'Dance break!', 'Nya-nya-nya ♫'][_r.nextInt(3)]);
    } else if (roll < 64) {
      right = x < w / 2;
      await _do(NutrikMode.wave, 2200, g, line: ['Hi there! 👋', 'Hello, human!', 'Psst! Over here!'][_r.nextInt(3)]);
    } else if (roll < 71) {
      await _do(NutrikMode.sit, 3500 + _r.nextInt(2000), g, line: _r.nextBool() ? null : 'Just sitting... 🍃');
    } else if (roll < 79) {
      // ловит бабочку
      setState(() {
        fly = Offset(w * 0.5, 80);
        _flyT = _r.nextDouble() * 6;
      });
      _quip('A butterfly!! 🦋', 1500);
      for (var k = 0; k < 3 && mounted && g == _gen; k++) {
        if (!await _walkTo((fly?.dx ?? x) - size / 3, g, run: true)) break;
        _hop(640);
        await _wait(700);
      }
      if (mounted) setState(() => fly = null);
      if (mounted && g == _gen && !held) await _do(NutrikMode.sad, 1300, g, line: 'It got away... 😿');
    } else if (roll < 85) {
      _hop(520);
      _quip('Boing!', 900);
    } else if (roll < 93) {
      final line = _idleLine();
      await _do(line.contains('👃') || line.contains('🥺') || line.contains('⏳') ? NutrikMode.sad : NutrikMode.idle, 2400, g, line: line);
    } else {
      await _do(NutrikMode.cheer, 1800, g, line: ['You\'re doing great! ✨', 'Go, food saver! 💪'][_r.nextInt(2)]);
    }
  }

  // ── реакции на действия в приложении ──
  void _onEvent() {
    final e = nutrikEvents.value.$1;
    if (held || widget.paused || !mounted) return;
    final g = ++_gen;
    targetX = null;
    _busy = false;
    switch (e) {
      case 'waste':
        _do(NutrikMode.sad, 2600, g, line: ['Noo... that food deserved better 😿', 'Into the bin? Sniff...', 'Next time we save it!'][_r.nextInt(3)]);
      case 'cook':
        _do(NutrikMode.dance, 3200, g, line: ['Chef mode! 👩‍🍳', 'Smells amazing!', 'Food rescued deliciously!'][_r.nextInt(3)]);
      case 'rescue':
        _hop(600);
        _quip(['Food saved! 🦸', 'Hero move! ❄️', 'Zero waste, nya! ✨'][_r.nextInt(3)]);
      case 'eat':
        _do(NutrikMode.eat, 1800, g, line: 'Can I have a bite? 🥺', food: '🍴');
      case 'add':
        _do(NutrikMode.cheer, 1400, g, line: ['New groceries! 🛒', 'Into the fridge!'][_r.nextInt(2)]);
      case 'medal':
        _do(NutrikMode.cheer, 2200, g, line: 'A new badge! ✨');
    }
  }

  // ── взаимодействие с пользователем ──
  void _tap() {
    if (held || y > 0) return;
    final g = ++_gen;
    targetX = null;
    tilt = 0;
    final wasAsleep = mode == NutrikMode.sleep;
    _busy = false;
    if (wasAsleep) {
      _do(NutrikMode.sad, 1600, g, line: ['Hey! I was sleeping 😾', 'Five more minutes...', 'Mrrr... who woke me?'][_r.nextInt(3)]);
      return;
    }
    final now = DateTime.now();
    _pokes = now.difference(_lastPoke).inMilliseconds < 1300 ? _pokes + 1 : 1;
    _lastPoke = now;
    if (_pokes >= 5) {
      _pokes = 0;
      setState(() => right = !right);
      _do(NutrikMode.sad, 1800, g, line: 'Stop poking me! 😾');
      _walkTo(x < w / 2 ? x + 120 : x - 120, g, run: true);
      return;
    }
    _do(NutrikMode.love, 1500, g, line: _r.nextInt(3) == 0 ? _idleLine() : ['Purr~ 💕', 'Hehe, that tickles!', '*happy nya*', 'Pet me more!'][_r.nextInt(4)]);
  }

  void _doubleTap() {
    if (held) return;
    ++_gen;
    targetX = null;
    _busy = false;
    tilt = 0;
    _hop(820);
    _quip('Wheee! 🎉', 1200);
  }

  void _grab(DragStartDetails d) {
    ++_gen;
    targetX = null;
    _busy = false;
    setState(() {
      held = true;
      vx = vy = 0;
      tilt = 0;
      snack = null;
      mode = NutrikMode.dangle;
    });
    _quip(['Hey! Put me down! 🙀', 'Where are we going?', 'Wheee... I mean, NO!', 'I\'m not a toy! 😾'][_r.nextInt(4)], 1800);
  }

  void _drag(DragUpdateDetails d) {
    setState(() {
      x = (x + d.delta.dx).clamp(0.0, max(0.0, w - size));
      y = (y - d.delta.dy).clamp(0.0, max(0.0, h - size));
      if (d.delta.dx.abs() > 1) right = d.delta.dx > 0;
    });
  }

  void _drop(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    setState(() {
      held = false;
      vx = v.dx.clamp(-1600.0, 1600.0);
      vy = (-v.dy).clamp(-1600.0, 1800.0);
      if (y > 1 || vy > 0) {
        mode = NutrikMode.jump;
        if (y < 1) y = 0.1;
      } else {
        mode = NutrikMode.idle;
      }
    });
    if (v.distance > 900) _quip('AAAAA! 🙀', 1200);
  }

  @override
  Widget build(BuildContext context) {
    // Positioned, а не SizedBox: иначе Stack сжимается до 0×0 и страницы не рисуются.
    if (widget.paused) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, c) {
          w = c.maxWidth;
          h = c.maxHeight - widget.bottom;
          final left = x.clamp(0.0, max(0.0, w - size)).toDouble();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Ключи нужны, чтобы появление облачка не пересоздавало Нутрик посреди перетаскивания.
              if (fly != null)
                Positioned(
                  key: const ValueKey('fly'),
                  left: fly!.dx,
                  bottom: widget.bottom + fly!.dy,
                  child: IgnorePointer(
                    child: Transform.rotate(
                      angle: sin(_flyT * 12) * 0.3,
                      child: const Text('🦋', style: TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              if (say != null)
                Positioned(
                  key: const ValueKey('say'),
                  left: (left - 44).clamp(0.0, max(0.0, w - 160)).toDouble(),
                  width: 160,
                  bottom: widget.bottom + y + size + 2,
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: burgundy),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: Text(
                          tr(say!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                key: const ValueKey('nutrik'),
                left: left,
                bottom: widget.bottom + y,
                child: GestureDetector(
                  onTap: _tap,
                  onDoubleTap: _doubleTap,
                  onPanStart: _grab,
                  onPanUpdate: _drag,
                  onPanEnd: _drop,
                  child: Nutrik(size: size, mode: mode, faceRight: right, tilt: tilt, snack: snack),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── ТУТОРИАЛ (интерактивный тур) ─────────────────────────
// Подсвечивает настоящие элементы экрана (через GlobalKey), просит нажать нужные кнопки
// и даёт потаскать Нутрик. Шаг пропускается сам, если его элемента сейчас нет на экране.

class Tour {
  static final hero = GlobalKey(debugLabel: 'tour-hero');
  static final useFirst = GlobalKey(debugLabel: 'tour-use-first');
  static final tiles = GlobalKey(debugLabel: 'tour-tiles');
  static final fridgeTop = GlobalKey(debugLabel: 'tour-fridge');
  static final recipeFilters = GlobalKey(debugLabel: 'tour-recipes');
  static final chatInput = GlobalKey(debugLabel: 'tour-chat');
  static final nav = List.generate(5, (i) => GlobalKey(debugLabel: 'tour-nav$i'));
}

enum TourKind { info, demo, tap, drag, finish }

class TourStep {
  final String text;
  final GlobalKey? target;
  final int? tab; // какую вкладку показать перед шагом
  final TourKind kind;
  final int? opens; // для TourKind.tap: какую вкладку открывает нажатие
  const TourStep(this.text, {this.target, this.tab, this.kind = TourKind.info, this.opens});
}

class SpotPainter extends CustomPainter {
  final Rect hole;
  final bool hasHole;
  final double pulse;
  SpotPainter(this.hole, this.hasHole, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(hole, const Radius.circular(22));
    final dim = Paint()..color = const Color(0xFF14060A).withValues(alpha: 0.82);
    if (!hasHole) {
      canvas.drawRect(Offset.zero & size, dim);
      return;
    }
    canvas.drawPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addRRect(rr)), dim);
    for (var k = 0; k < 2; k++) {
      final p = (pulse + k / 2) % 1;
      canvas.drawRRect(
        rr.inflate(p * 18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFF2C879).withValues(alpha: (1 - p) * 0.8),
      );
    }
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant SpotPainter o) => true;
}

/// Ставит облачко под подсвеченным элементом, а если места нет — над ним.
class _BubbleLayout extends SingleChildLayoutDelegate {
  final Rect hole;
  final bool hasHole;
  final EdgeInsets safe;
  final bool top; // облачко наверху (когда в центре экрана стоит большая Нутрик)
  _BubbleLayout(this.hole, this.hasHole, this.safe, {this.top = false});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(minWidth: min(c.maxWidth - 32, 460), maxWidth: min(c.maxWidth - 32, 460), maxHeight: c.maxHeight);

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (size.width - child.width) / 2;
    if (top) return Offset(x, safe.top + 64);
    if (!hasHole) return Offset(x, (size.height - child.height) * 0.4);
    final below = hole.bottom + 18, above = hole.top - 18 - child.height;
    final fitsBelow = below + child.height < size.height - safe.bottom - 8;
    var yy = hole.center.dy < size.height * 0.5 && fitsBelow ? below : above;
    if (yy < safe.top + 8) yy = fitsBelow ? below : safe.top + 8;
    return Offset(x, yy.clamp(safe.top + 8, max(safe.top + 8, size.height - child.height - 8)));
  }

  @override
  bool shouldRelayout(_BubbleLayout o) => o.hole != hole || o.hasHole != hasHole || o.top != top;
}

class TutorialOverlay extends StatefulWidget {
  final AppState state;
  final ValueChanged<int> onTab;
  final VoidCallback onDone;
  const TutorialOverlay({super.key, required this.state, required this.onTab, required this.onDone});
  @override
  State<TutorialOverlay> createState() => _TutorialState();
}

class _TutorialState extends State<TutorialOverlay> with TickerProviderStateMixin {
  late final List<TourStep> steps = [
    const TourStep('Hi! I\'m Nutrik 🐾 your zero-waste kitchen buddy. About a third of the world\'s food ends up in the bin. Let\'s make sure yours doesn\'t! Want a quick tour?'),
    if (widget.state.pantry.isEmpty)
      const TourStep('Your fridge is empty. Shall I fill it with demo groceries? Some of them are about to spoil, so you can see how rescuing food works.', kind: TourKind.demo),
    TourStep('This is your Rescue Mission: products that spoil within 2 days and the money at risk. The eco score shows how much of your food you actually use.', target: Tour.hero, tab: 0),
    TourStep('These need you first! Tap a card to eat it, freeze it, share it or fix the date.', target: Tour.useFirst, tab: 0),
    TourStep('Shortcuts: your eco impact, shopping list, weight and achievements.', target: Tour.tiles, tab: 0),
    TourStep('Now open your fridge: tap the glowing Fridge button 👇', target: Tour.nav[2], tab: 0, kind: TourKind.tap, opens: 2),
    TourStep('Everything you own, sorted by urgency. Swipe right to eat, left to throw away. Filter by fridge, freezer or pantry.', target: Tour.fridgeTop, tab: 2),
    TourStep('Hungry? Tap Recipes 👇', target: Tour.nav[3], tab: 2, kind: TourKind.tap, opens: 3),
    TourStep('Recipes that use up your spoiling food come first. Try the ♻️ Rescue food and 🌱 Zero-waste filters!', target: Tour.recipeFilters, tab: 3),
    TourStep('Last tab: tap AI Chef 👇', target: Tour.nav[4], tab: 3, kind: TourKind.tap, opens: 4),
    TourStep('Ask me anything: what to cook, how to store tomatoes, whether you can freeze bread...', target: Tour.chatInput, tab: 4),
    const TourStep('One more secret: I live at the bottom of your screen! Grab me and drag me around. Go on, try it now! 👆', kind: TourKind.drag, tab: 0),
    const TourStep('Purr-fect! 🎉 Tap me to pet me, double-tap to make me jump, or throw me if you dare 😼 Now let\'s go save some food!', kind: TourKind.finish, tab: 0),
  ];

  int step = 0, _dir = 1;
  Rect? hole;
  bool _ready = false;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  late final AnimationController back = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  Offset drag = Offset.zero, _dragFrom = Offset.zero;
  bool dragging = false, dragDone = false;

  @override
  void initState() {
    super.initState();
    back.addListener(() => setState(() => drag = Offset.lerp(_dragFrom, Offset.zero, Curves.elasticOut.transform(back.value))!));
    WidgetsBinding.instance.addPostFrameCallback((_) => _show());
  }

  @override
  void dispose() {
    pulse.dispose();
    back.dispose();
    super.dispose();
  }

  TourStep get st => steps[step];

  Future<void> _show() async {
    final s = st;
    setState(() => _ready = false);
    if (s.tab != null) widget.onTab(s.tab!);
    await Future.delayed(const Duration(milliseconds: 320)); // ждём смену вкладки
    if (!mounted) return;
    final ctx = s.target?.currentContext;
    if (s.target != null && ctx == null) {
      _go(step + _dir); // элемента нет (например, нечего «спасать») — пропускаем шаг
      return;
    }
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(ctx, alignment: 0.25, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;
    setState(() {
      hole = ctx != null && ctx.mounted ? _rectOf(ctx) : null;
      _ready = true;
    });
  }

  Rect? _rectOf(BuildContext ctx) {
    final box = ctx.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null || !box.attached || !box.hasSize) return null;
    return (box.localToGlobal(Offset.zero, ancestor: me) & box.size).inflate(6);
  }

  void _go(int i) {
    if (i < 0) return;
    if (i >= steps.length) {
      _finish();
      return;
    }
    setState(() {
      _dir = i >= step ? 1 : -1;
      step = i;
      drag = Offset.zero;
      dragDone = false;
    });
    _show();
  }

  void _finish() {
    widget.onTab(0);
    widget.state.party();
    widget.onDone();
  }

  Widget _btn(String t, VoidCallback f, {bool filled = true}) => filled
      ? FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: burgundy, padding: const EdgeInsets.symmetric(horizontal: 18)),
          onPressed: f,
          child: Text(tr(t), style: const TextStyle(fontWeight: FontWeight.bold)),
        )
      : TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          onPressed: f,
          child: Text(tr(t)),
        );

  Widget _controls() {
    final s = st;
    final progress = Row(
      children: [
        Text('${step + 1}/${steps.length}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (step + 1) / steps.length),
              duration: const Duration(milliseconds: 400),
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 5, color: const Color(0xFFF2C879), backgroundColor: Colors.white24),
            ),
          ),
        ),
      ],
    );
    final List<Widget> right = switch (s.kind) {
      TourKind.demo => [
        _btn('Keep it empty', () => _go(step + 1), filled: false),
        _btn('Fill my fridge! 🧺', () {
          widget.state.loadDemo();
          _go(step + 1);
        }),
      ],
      TourKind.tap => [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, _) => Opacity(
            opacity: 0.55 + 0.45 * sin(pulse.value * 2 * pi).abs(),
            child: Text(
              tr('👆 Tap the glowing button'),
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
      TourKind.drag => [if (dragDone) _btn('Next', () => _go(step + 1)) else Text(tr('Drag her! 👆'), style: const TextStyle(color: Colors.white70))],
      TourKind.finish => [_btn('Let\'s go! 🚀', _finish)],
      TourKind.info => [if (step > 0) _btn('Back', () => _go(step - 1), filled: false), _btn(step == 0 ? 'Show me around' : 'Next', () => _go(step + 1))],
    };
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xE62A0A12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(children: [progress, const Spacer(), ...right]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = st;
    final dragStep = s.kind == TourKind.drag || s.kind == TourKind.finish;
    return LayoutBuilder(
      builder: (context, c) {
        final size = c.biggest;
        final has = hole != null && _ready;
        final target = has ? hole! : Rect.fromCenter(center: size.center(Offset.zero), width: 0, height: 0);
        final pointUp = has && target.center.dy < size.height * 0.5;
        final ang = has ? atan2(pointUp ? -1.0 : 1.0, ((target.center.dx - 70) / 160).clamp(-1.5, 1.5)) : null;
        return Stack(
          children: [
            // блокируем всё под оверлеем
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: target),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOutCubic,
                  builder: (_, r, _) => AnimatedBuilder(
                    animation: pulse,
                    builder: (_, _) => CustomPaint(painter: SpotPainter(r ?? target, has, pulse.value)),
                  ),
                ),
              ),
            ),
            // «дырка» в шаге tap пропускает нажатие на настоящую кнопку
            if (has && s.kind == TourKind.tap)
              Positioned.fromRect(
                rect: target,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onTab(s.opens!);
                    _go(step + 1);
                  },
                ),
              ),
            // большая Нутрик, которую можно таскать
            if (dragStep)
              Positioned(
                key: const ValueKey('guide'),
                left: size.width / 2 - 70 + drag.dx,
                top: size.height * 0.52 + drag.dy,
                child: GestureDetector(
                  onPanStart: s.kind == TourKind.drag
                      ? (_) {
                          back.stop();
                          setState(() => dragging = true);
                        }
                      : null,
                  onPanUpdate: s.kind == TourKind.drag ? (d) => setState(() => drag += d.delta) : null,
                  onPanEnd: s.kind == TourKind.drag
                      ? (_) {
                          _dragFrom = drag;
                          back.forward(from: 0);
                          setState(() {
                            dragging = false;
                            dragDone = true;
                          });
                        }
                      : null,
                  child: Nutrik(
                    size: 140,
                    mode: s.kind == TourKind.finish
                        ? NutrikMode.cheer
                        : dragging
                        ? NutrikMode.dangle
                        : dragDone
                        ? NutrikMode.love
                        : NutrikMode.wave,
                  ),
                ),
              ),
            if (_ready)
              Positioned.fill(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: target),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeInOutCubic,
                  builder: (_, r, child) => CustomSingleChildLayout(
                    delegate: _BubbleLayout(r ?? target, has, mq.padding, top: dragStep),
                    child: child,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      key: ValueKey('$step$dragDone'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (dragStep)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: burgundy, width: 1.5),
                            ),
                            child: Text(
                              dragDone && s.kind == TourKind.drag ? tr('Wheee! You got it! 😸 I don\'t always enjoy it though...') : tr(s.text),
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                          )
                        else
                          NutrikSays(text: tr(s.text), point: ang, size: 92, mode: s.kind == TourKind.tap ? NutrikMode.cheer : NutrikMode.idle),
                        const SizedBox(height: 10),
                        _controls(),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: mq.padding.top + 8,
              right: 12,
              child: TextButton.icon(
                style: TextButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                onPressed: widget.onDone,
                icon: const Icon(Icons.close, size: 18),
                label: Text(tr('Skip')),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ───────────────────────── РЕГИСТРАЦИЯ (с Нутриком) ─────────────────────────

class RegisterScreen extends StatefulWidget {
  final AppState state;
  final AiService ai;
  const RegisterScreen({super.key, required this.state, required this.ai});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _k1 = GlobalKey<FormState>(), _k2 = GlobalKey<FormState>();
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();
  final _age = TextEditingController(text: '22'), _weight = TextEditingController(text: '70'), _height = TextEditingController(text: '175');
  bool isMan = true, hide = true, busy = false, arrived = false;
  int step = 0; // 0 знакомство, 1 аккаунт, 2 параметры
  String say = tr('Hi! I\'m Nutrik 🐾 I help people stop wasting food. Nice to meet you!');

  /// Шаг 0 — выбор языка: Нутрик сразу здоровается на выбранном.
  void _pickLang(String l) {
    widget.state.setLanguage(l);
    setState(() => say = '${langHello[l]} ${tr('I help people stop wasting food. Nice to meet you!')}');
  }

  Widget _langCards() => Row(
    children: [
      for (final l in appLangs)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _pickLang(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: appLang == l ? burgundy : sand,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: appLang == l ? [BoxShadow(color: burgundy.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))] : null,
                ),
                child: Column(
                  children: [
                    Text(langFlag[l]!, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: Text(
                        langNative[l]!,
                        style: TextStyle(fontWeight: FontWeight.bold, color: appLang == l ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _age, _weight, _height]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _dec(String label, IconData icon, {Widget? suffix}) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: burgundy),
    suffixIcon: suffix,
    filled: true,
    fillColor: sand,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
  );

  String? _num(String? v, int lo, int hi) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    return (n == null || n < lo || n > hi) ? tr('Enter {0}–{1}', [lo, hi]) : null;
  }

  void _go(int s, String text) => setState(() {
    step = s;
    say = text;
  });

  void _next() {
    if (step == 1) {
      if (_k1.currentState!.validate()) {
        _go(2, tr('Now your body stats! I\'ll use them to work out your daily calorie goal. 🔢'));
      } else {
        setState(() => say = tr('Hmm, please check the fields in red!'));
      }
    } else if (step == 2) {
      if (_k2.currentState!.validate()) {
        _submit();
      } else {
        setState(() => say = tr('Those numbers look a bit odd... try again?'));
      }
    }
  }

  Future<void> _submit({bool guest = false}) async {
    setState(() {
      busy = true;
      say = tr('Yay! Preparing your fridge...');
    });
    await Future.delayed(const Duration(milliseconds: 1300));
    if (!mounted) return;
    double p(TextEditingController c, double d) => double.tryParse(c.text.replaceAll(',', '.')) ?? d;
    widget.state.register(
      name: guest || _name.text.trim().isEmpty ? 'Guest' : _name.text.trim(),
      email: guest ? '' : _email.text.trim(),
      isMan: isMan,
      age: guest ? 22 : p(_age, 22).round(),
      weight: guest ? 70 : p(_weight, 70),
      height: guest ? 175 : p(_height, 175),
    );
    Navigator.pushReplacement(context, fadeSlide(MainScreen(state: widget.state, ai: widget.ai)));
  }

  Widget _gender(String t, bool v) {
    final sel = isMan == v;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => isMan = v),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: sel ? burgundy : sand, borderRadius: BorderRadius.circular(14)),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.bold, color: sel ? Colors.white : Colors.black87),
            child: Text(t),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    return Column(
      key: const ValueKey('intro'),
      children: [
        const Spacer(),
        const Appear(
          child: Text(
            'NutriMate',
            style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: burgundy),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('ZERO-WASTE KITCHEN'),
          style: TextStyle(color: burgundy, fontSize: 12, letterSpacing: 3, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          tr('Save food. Save money. Save the planet.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in [tr('🗑️ 1/3 of food is wasted'), tr('💰 ≈\$1,500 per family / year'), tr('🌍 8–10% of CO₂')])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(20)),
                child: Text(f, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        _langCards(),
        const SizedBox(height: 16),
        SizedBox(
          height: 130,
          child: arrived
              ? NutrikSays(key: ValueKey(say), text: say, size: 110)
              : TweenAnimationBuilder<double>(
                  tween: Tween(begin: -140, end: 0),
                  duration: const Duration(milliseconds: 2400),
                  curve: Curves.easeOut,
                  onEnd: () => setState(() => arrived = true),
                  builder: (_, v, _) => Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: v,
                        bottom: 0,
                        child: const Nutrik(size: 110, mode: NutrikMode.run),
                      ),
                    ],
                  ),
                ),
        ),
        const SizedBox(height: 20),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: arrived ? 1 : 0,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: burgundy),
                  onPressed: arrived ? () => _go(1, tr('Let\'s create your account! What\'s your name? (It\'s just a test account — I won\'t tell anyone 🤫)')) : null,
                  child: Text(tr('Create account'), style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              TextButton(
                onPressed: arrived ? () => _submit(guest: true) : null,
                child: Text(tr('Continue as guest'), style: const TextStyle(color: burgundy)),
              ),
            ],
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _form() {
    return SingleChildScrollView(
      key: ValueKey('form$step'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NutrikSays(key: ValueKey(say), text: say, point: pi / 2, size: 96),
          const SizedBox(height: 16),
          if (step == 1)
            Form(
              key: _k1,
              child: Column(
                children: [
                  Appear(
                    index: 0,
                    child: TextFormField(controller: _name, decoration: _dec(tr('Name'), Icons.person_outline), validator: (v) => (v ?? '').trim().isEmpty ? tr('Enter your name') : null),
                  ),
                  const SizedBox(height: 12),
                  Appear(
                    index: 1,
                    child: TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _dec(tr('Email'), Icons.mail_outline),
                      validator: (v) => (v ?? '').contains('@') ? null : tr('Enter a valid email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Appear(
                    index: 2,
                    child: TextFormField(
                      controller: _pass,
                      obscureText: hide,
                      decoration: _dec(
                        tr('Password'),
                        Icons.lock_outline,
                        suffix: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide)),
                      ),
                      validator: (v) => (v ?? '').length < 4 ? tr('At least 4 characters') : null,
                    ),
                  ),
                ],
              ),
            )
          else
            Form(
              key: _k2,
              child: Column(
                children: [
                  Appear(index: 0, child: Row(children: [_gender(tr('Man'), true), const SizedBox(width: 12), _gender(tr('Woman'), false)])),
                  const SizedBox(height: 12),
                  Appear(
                    index: 1,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(controller: _age, keyboardType: TextInputType.number, decoration: _dec(tr('Age'), Icons.cake_outlined), validator: (v) => _num(v, 14, 90)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(controller: _weight, keyboardType: TextInputType.number, decoration: _dec(tr('kg'), Icons.monitor_weight_outlined), validator: (v) => _num(v, 40, 150)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(controller: _height, keyboardType: TextInputType.number, decoration: _dec(tr('cm'), Icons.height), validator: (v) => _num(v, 120, 220)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              if (!busy)
                TextButton(
                  onPressed: () => _go(step - 1, step == 1 ? tr('Back so soon? OK!') : tr('Let\'s fix your account info!')),
                  child: Text(tr('Back'), style: const TextStyle(color: burgundy)),
                ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(horizontal: 28)),
                  onPressed: busy ? null : _next,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: busy
                        ? const SizedBox(
                            key: ValueKey('b'),
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            step == 1 ? tr('Next') : tr('Finish'),
                            key: ValueKey('t$step'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: IgnorePointer(child: FloatingFood())),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: step == 0 ? _intro() : _form(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── GLASS-НАВИГАЦИЯ (прозрачное стекло, лупа, «желе») ─────────────────────────

/// Тонкая яркая кромка стекла + мягкая тень только снаружи (чтобы стекло оставалось прозрачным).
class RimPainter extends CustomPainter {
  final double radius;
  final List<Color> colors;
  final bool shadow;
  RimPainter(this.radius, this.colors, {this.shadow = true});

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius((Offset.zero & size).deflate(1), Radius.circular(radius));
    if (shadow) {
      canvas.save();
      canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(Rect.fromLTWH(-60, -60, size.width + 120, size.height + 120)), Path()..addRRect(rr)));
      canvas.drawRRect(
        rr.shift(const Offset(0, 8)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.restore();
    }
    final sh = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(Offset.zero & size);
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..shader = sh
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = sh,
    );
    canvas.drawRRect(
      rr.deflate(3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  @override
  bool shouldRepaint(covariant RimPainter o) => false;
}

class GlassNav extends StatefulWidget {
  final int index, fridge;
  final ValueChanged<int> onTap;
  const GlassNav({super.key, required this.index, required this.fridge, required this.onTap});
  @override
  State<GlassNav> createState() => _GlassNavState();
}

class _GlassNavState extends State<GlassNav> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))..value = 1;
  double from = 0;
  late double to = widget.index.toDouble();
  static const icons = [Icons.home_rounded, Icons.search_rounded, Icons.kitchen_rounded, Icons.restaurant_menu_rounded, Icons.chat_bubble_rounded];
  static const labels = ['Home', 'Search', 'Fridge', 'Recipes', 'AI'];

  double get _pos => from + (to - from) * Curves.elasticOut.transform(c.value);

  @override
  void didUpdateWidget(covariant GlassNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      from = _pos;
      to = widget.index.toDouble();
      c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Widget _item(int i) {
    final on = widget.index == i;
    final col = on ? burgundy : Colors.black87;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: on ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: 1 + 0.2 * v, child: child),
          child: Badge(
            isLabelVisible: i == 2 && widget.fridge > 0,
            label: Text('${widget.fridge}'),
            child: Icon(icons[i], color: col, size: 25),
          ),
        ),
        Text(
          tr(labels[i]),
          style: TextStyle(fontSize: 10, color: col, fontWeight: on ? FontWeight.bold : FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).padding.bottom;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, inset + 12),
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, cs) {
              final seg = cs.maxWidth / 5;
              return CustomPaint(
                foregroundPainter: RimPainter(32, [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.6)]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.03)]),
                      ),
                      child: AnimatedBuilder(
                        animation: c,
                        builder: (_, _) {
                          final sq = sin(c.value * pi).abs();
                          final dist = min((to - from).abs(), 3.0);
                          final w = (seg - 8) * (1 + 0.2 * sq * dist);
                          final h = 54 * (1 - 0.12 * sq);
                          final left = _pos * seg + (seg - w) / 2;
                          return Stack(
                            children: [
                              Positioned(
                                left: left,
                                top: (64 - h) / 2,
                                width: w,
                                height: h,
                                child: RawMagnifier(
                                  size: Size(w, h),
                                  magnificationScale: 1.35,
                                  decoration: MagnifierDecoration(
                                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(27))),
                                    shadows: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3))],
                                  ),
                                  child: CustomPaint(
                                    foregroundPainter: RimPainter(27, [Colors.white, const Color(0xAAF2C879), const Color(0x889B1B33), const Color(0xCCFFFFFF)], shadow: false),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(27),
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          stops: const [0, 0.5],
                                          colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < 5; i++)
                                    Expanded(
                                      child: KeyedSubtree(
                                        key: Tour.nav[i],
                                        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onTap(i), child: _item(i)),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── ГЛАВНЫЙ ЭКРАН ─────────────────────────

class MainScreen extends StatefulWidget {
  final AppState state;
  final AiService ai;
  const MainScreen({super.key, required this.state, required this.ai});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int i = 0;
  late final AnimationController fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 260), value: 1);
  bool _iconsCached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_iconsCached) {
      _iconsCached = true;
      precacheFoodIcons(context);
    }
  }

  @override
  void dispose() {
    fade.dispose();
    super.dispose();
  }

  void _tab(int v) {
    if (v == i) return;
    setState(() => i = v);
    fade.forward(from: 0);
  }

  Widget _page(int i) {
    final s = widget.state;
    switch (i) {
      case 0:
        return HomePage(state: s, ai: widget.ai, onTab: _tab);
      case 1:
        return SearchPage(state: s);
      case 2:
        return PantryPage(state: s, onSearch: () => _tab(1));
      case 3:
        return RecipesPage(state: s);
      default:
        return ChatPage(state: s, ai: widget.ai);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pad = MediaQuery.of(context).padding.bottom;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Stack(
        children: [
          Scaffold(
            extendBody: true,
            body: Stack(
              fit: StackFit.expand,
              children: [
                // IndexedStack хранит состояние вкладок (поиск, чат, фильтры не сбрасываются).
                Positioned.fill(
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: fade, curve: Curves.easeOut),
                    child: IndexedStack(
                      index: i,
                      children: [for (var k = 0; k < 5; k++) TickerMode(enabled: k == i, child: _page(k))],
                    ),
                  ),
                ),
                // В чате пол Нутрик поднят над полем ввода.
                NutrikRoamer(paused: s.showTutorial, bottom: 76 + pad + (i == 4 ? 128 : 6), state: s),
              ],
            ),
            bottomNavigationBar: GlassNav(index: i, fridge: s.pantry.length, onTap: _tab),
          ),
          // Ключи обязательны: без них появление конфетти пересоздавало бы туториал с нуля.
          if (s.celebrate)
            Positioned.fill(
              key: const ValueKey('confetti'),
              child: IgnorePointer(child: Confetti(onDone: s.endCelebrate)),
            ),
          if (s.pendingBadge != null)
            Positioned.fill(
              key: const ValueKey('badge'),
              child: IgnorePointer(
                child: Material(
                  type: MaterialType.transparency,
                  child: BadgePopup(key: ValueKey(s.pendingBadge!.id), m: s.pendingBadge!, onDone: s.clearBadge),
                ),
              ),
            ),
          if (s.showTutorial)
            Positioned.fill(
              key: const ValueKey('tour'),
              child: Material(
                type: MaterialType.transparency,
                child: TutorialOverlay(state: s, onTab: _tab, onDone: s.endTutorial),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── LIQUID GLASS + ПЕРЕХОДЫ ─────────────────────────

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final Color? tint;
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 22, this.tint});

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [(tint ?? Colors.white).withValues(alpha: 0.7), (tint ?? Colors.white).withValues(alpha: 0.28)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.2),
        boxShadow: [BoxShadow(color: burgundy.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class BlobPainter extends CustomPainter {
  final double t;
  BlobPainter(this.t);
  static const cols = [burgundy, Color(0xFFD9B26F), Color(0xFF7BA05B), Color(0xFFB85C4A)];

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 0; k < 4; k++) {
      final c = Offset(size.width * (0.5 + 0.4 * sin(t + k * 1.7)), size.height * (0.5 + 0.4 * cos(t * 0.8 + k * 2.3)));
      final r = size.shortestSide * (0.5 + 0.08 * sin(t + k));
      canvas.drawCircle(c, r, Paint()..shader = RadialGradient(colors: [cols[k].withValues(alpha: 0.38), cols[k].withValues(alpha: 0)]).createShader(Rect.fromCircle(center: c, radius: r)));
    }
  }

  @override
  bool shouldRepaint(covariant BlobPainter o) => true;
}

/// Живой «жидкий» фон: размытые цветные пятна плавно плавают.
class LiquidBg extends StatefulWidget {
  const LiquidBg({super.key});
  @override
  State<LiquidBg> createState() => _LiquidBgState();
}

class _LiquidBgState extends State<LiquidBg> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: c,
      builder: (_, _) => CustomPaint(painter: BlobPainter(c.value * 2 * pi), size: Size.infinite),
    ),
  );
}

class _CircleClip extends CustomClipper<Path> {
  final double f;
  final Offset o;
  _CircleClip(this.f, this.o);

  @override
  Path getClip(Size s) {
    final far = [Offset.zero, Offset(s.width, 0), Offset(0, s.height), Offset(s.width, s.height)].map((p) => (p - o).distance).reduce(max);
    return Path()..addOval(Rect.fromCircle(center: o, radius: far * f));
  }

  @override
  bool shouldReclip(covariant _CircleClip old) => old.f != f;
}

/// Страница «раскрывается» кругом из точки нажатия.
Route<T> circleReveal<T>(Widget page, Offset origin) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 700),
  reverseTransitionDuration: const Duration(milliseconds: 450),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) => ClipPath(clipper: _CircleClip(Curves.easeInOutCubic.transform(a.value), origin), child: child),
);

Offset centerOf(BuildContext c) {
  final b = c.findRenderObject() as RenderBox;
  return b.localToGlobal(b.size.center(Offset.zero));
}

class GlassPage extends StatelessWidget {
  final String title;
  final Widget child;
  const GlassPage({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: cream,
    appBar: AppBar(
      title: Text(tr(title), style: headStyle),
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    body: Stack(
      children: [
        const Positioned.fill(child: LiquidBg()),
        SafeArea(child: child),
      ],
    ),
  );
}

// ───────────────────────── КОНФЕТТИ И НАГРАДЫ ─────────────────────────

class _Piece {
  final double x, delay, sway, rot, size;
  final int color;
  _Piece(Random r) : x = r.nextDouble(), delay = r.nextDouble() * 0.4, sway = r.nextDouble() * 2 - 1, rot = r.nextDouble() * 6, size = 6 + r.nextDouble() * 6, color = r.nextInt(6);
}

class ConfettiPainter extends CustomPainter {
  final List<_Piece> ps;
  final double v;
  ConfettiPainter(this.ps, this.v);
  static const cols = [burgundy, Color(0xFFD9A441), Color(0xFF5B8C51), Color(0xFFC96A5A), Color(0xFF3C6E71), Color(0xFFE8D8B0)];

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in ps) {
      final t = ((v - p.delay) / (1 - p.delay)).clamp(0.0, 1.0).toDouble();
      if (t <= 0) continue;
      final x = p.x * size.width + sin(t * 6 + p.sway * 3) * 30 * p.sway;
      final y = -20 + t * t * (size.height + 40) * 0.4 + t * (size.height + 40) * 0.6;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rot + t * 8);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), Paint()..color = cols[p.color].withValues(alpha: 1 - max(0.0, (t - 0.8) / 0.2)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter o) => true;
}

class Confetti extends StatefulWidget {
  final VoidCallback onDone;
  const Confetti({super.key, required this.onDone});
  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  final ps = List.generate(80, (_) => _Piece(Random()));
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: c,
    builder: (_, _) => CustomPaint(painter: ConfettiPainter(ps, c.value), size: Size.infinite),
  );
}

class Medal {
  final String id, emoji, _title, _desc;
  const Medal(this.id, this.emoji, this._title, this._desc);
  String get title => tr(_title);
  String get desc => tr(_desc);
}

const medals = [
  Medal('first', '🍽️', 'First Bite', 'Eat or cook your first product'),
  Medal('rescue', '🦸', 'Rescuer', 'Save 3 products that were about to expire'),
  Medal('chef', '👨‍🍳', 'Home Chef', 'Cook 3 recipes'),
  Medal('fridge', '🧊', 'Fridge Master', 'Have 10 products in your fridge'),
  Medal('streak', '🌱', 'Zero Waste Week', '7 days without throwing food away'),
  Medal('shop', '🛒', 'Smart Shopper', 'Buy a product from your shopping list'),
  Medal('weight', '⚖️', 'Weigh-in', 'Log your weight 3 times'),
  Medal('planet', '🌍', 'Planet Hero', 'Avoid 2 kg of CO₂ by rescuing food'),
  Medal('freezer', '❄️', 'Ice Saver', 'Freeze 3 products before they spoil'),
  Medal('share', '🤝', 'Good Neighbor', 'Share food with someone instead of binning it'),
  Medal('cleanfridge', '✨', 'Clean Fridge', '5+ products and nothing expired'),
];

class WeightEntry {
  final DateTime date;
  final double kg;
  WeightEntry(this.date, this.kg);
}

const tips = [
  'Store tomatoes at room temperature — the fridge kills their flavor.',
  'Freeze bread and milk before they expire. Future you says thanks!',
  'Put the oldest products at the front of the fridge.',
  'Overripe bananas are perfect for pancakes and smoothies.',
  'Wilted veggies still make a great soup or stock.',
  '"Best before" is about quality, "use by" is about safety.',
  'Plan 3 meals before shopping — it cuts waste a lot.',
  'Keep fresh herbs in a glass of water, like flowers.',
  'Shop with a list and never shop hungry — you buy 20–30% less.',
  'Stale bread → croutons, toast or bread pudding. Never the bin!',
  'Freeze leftovers in single portions — instant lunch later.',
  'The fridge door is the warmest spot: keep sauces there, not milk.',
  'Vegetable peels and stems make a great free broth.',
  'Too much food? Share it with neighbors or a community fridge.',
];

class BadgePopup extends StatefulWidget {
  final Medal m;
  final VoidCallback onDone;
  const BadgePopup({super.key, required this.m, required this.onDone});
  @override
  State<BadgePopup> createState() => _BadgePopupState();
}

class _BadgePopupState extends State<BadgePopup> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3600), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.translate(
              offset: Offset(0, -130 * (1 - v)),
              child: Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: child),
            ),
            child: Glass(
              tint: const Color(0xFFFFF3C4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Emo(widget.m.emoji, size: 46),
                  const SizedBox(width: 12),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Achievement unlocked!'), style: TextStyle(fontSize: 12, color: burgundy)),
                      Text(
                        widget.m.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── ECO IMPACT ─────────────────────────

class RingPainter extends CustomPainter {
  final double p, w;
  final Color color;
  RingPainter(this.p, this.color, [this.w = 12]);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(w / 2 + 2, w / 2 + 2, size.width - w - 4, size.height - w - 4);
    canvas.drawArc(
      r,
      0,
      2 * pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..color = Colors.black12,
    );
    canvas.drawArc(
      r,
      -pi / 2,
      2 * pi * p,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter o) => o.p != p || o.color != color || o.w != w;
}

class ImpactPage extends StatelessWidget {
  final AppState state;
  const ImpactPage({super.key, required this.state});

  Widget _tile(String emoji, String label, double v, int dec, {String prefix = '', String suffix = ''}) => Expanded(
    child: Glass(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(end: v),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, x, _) => Text(
              '$prefix${x.toStringAsFixed(dec)}$suffix',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: burgundy),
            ),
          ),
          Text(tr(label), style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
    ),
  );

  /// Аналитика выброшенного: по причинам (бары) и самая «проблемная» категория + персональный совет.
  Widget _whyWaste(AppState s) {
    final by = s.wasteByReason;
    final total = s.wasteLog.length;
    final top = by.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final cat = s.wasteByCategory.entries.first;
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in by.entries.where((e) => e.value > 0))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${reasonInfo[e.key]!.$1}  ${tr(reasonInfo[e.key]!.$2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text('${e.value}', style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: e.value / total),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, color: e.key == top ? burgundy : burgundy.withValues(alpha: 0.4), backgroundColor: Colors.black12),
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          Text('${catEmoji[cat.key] ?? '🍽️'} ${tr('You waste {0} most often ({1}×).', [tn(cat.key), cat.value])}', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('💡 ${tr(reasonInfo[top]!.$3)}', style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Eco Impact',
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state;
          final score = s.ecoScore;
          final col = score >= 70
              ? Colors.green.shade700
              : score >= 40
              ? Colors.orange.shade800
              : Colors.red.shade700;
          final mood = score >= 80
              ? tr('You\'re a food-saving superstar! Keep it up! ⭐')
              : score >= 50
              ? tr('Not bad! Use the expiring products first.')
              : tr('Oh no... let\'s waste less. Check Recipes for ideas!');
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Appear(
                child: Glass(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 112,
                        height: 112,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: score / 100),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => CustomPaint(
                            painter: RingPainter(v, col),
                            child: Center(
                              child: Text(
                                '${(v * 100).round()}%',
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(tr('Eco score'), style: titleStyle),
                            const SizedBox(height: 4),
                            Text(
                              s.consumed + s.wasted == 0 ? tr('Eat and cook your food to build your score!') : tr('{0} products used, {1} thrown away.', [s.consumed, s.wasted]),
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 1,
                child: NutrikSays(key: ValueKey(mood), text: mood, size: 84),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 2,
                child: Row(
                  children: [
                    _tile('🦸', 'Rescued items', s.rescued.toDouble(), 0),
                    const SizedBox(width: 12),
                    _tile('⚖️', 'Food saved', s.rescued * 0.3, 1, suffix: ' ${tr('kg')}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 3,
                child: Row(
                  children: [
                    _tile('💰', 'Money saved', s.rescuedMoney, 2, prefix: '\$'),
                    const SizedBox(width: 12),
                    _tile('🌍', 'CO₂ avoided', s.co2, 1, suffix: ' ${tr('kg')}'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 4,
                child: Glass(
                  child: Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('{0} without waste', [trp(s.streakDays, 'day|days')]),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 5,
                child: Glass(
                  tint: const Color(0xFFFFD6D6),
                  child: Row(
                    children: [
                      const Text('🗑️', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr('Wasted: {0} · about {1}', [trp(s.wasted, 'item|items'), '\$${s.wastedMoney.toStringAsFixed(2)}']),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Appear(index: 6, child: Row(children: [_tile('❄️', 'Frozen in time', s.frozen.toDouble(), 0), const SizedBox(width: 12), _tile('🤝', 'Shared', s.shared.toDouble(), 0)])),
              if (s.wasteLog.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(tr('Why food ends up in your bin'), style: headStyle),
                const SizedBox(height: 8),
                Appear(index: 7, child: _whyWaste(s)),
              ],
              const SizedBox(height: 18),
              Text(tr('Did you know?'), style: headStyle),
              const SizedBox(height: 8),
              for (final f in const [
                ('🗑️', 'About 1/3 of all food produced in the world is lost or wasted.'),
                ('🏠', 'Most of the waste happens at home — not in shops or restaurants.'),
                ('🌍', 'Food waste causes 8–10% of global greenhouse gas emissions.'),
                ('💧', 'One wasted apple = ~125 liters of water used for nothing.'),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    child: Row(
                      children: [
                        Text(f.$1, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(tr(f.$2), style: const TextStyle(color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                tr('Estimates: about 300 g per product, average prices, about 2.5 kg of CO₂ per kg of food. Sources: UNEP Food Waste Index, FAO.'),
                style: const TextStyle(color: Colors.black45, fontSize: 11),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── ВЕС ─────────────────────────

class WeightPainter extends CustomPainter {
  final List<WeightEntry> e;
  final double p;
  WeightPainter(this.e, this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - 32, h = size.height - 48;
    final ks = e.map((x) => x.kg);
    final lo = ks.reduce(min) - 1, hi = ks.reduce(max) + 1;
    Offset pt(int i) => Offset(16 + (e.length == 1 ? w / 2 : w * i / (e.length - 1)), 20 + h * (1 - (e[i].kg - lo) / (hi - lo)));
    for (var k = 0; k < 4; k++) {
      canvas.drawLine(Offset(16, 20 + h * k / 3), Offset(16 + w, 20 + h * k / 3), Paint()..color = Colors.black12);
    }
    if (e.length > 1) {
      final path = Path()..moveTo(pt(0).dx, pt(0).dy);
      for (var i = 1; i < e.length; i++) {
        path.lineTo(pt(i).dx, pt(i).dy);
      }
      final m = path.computeMetrics().first;
      final part = m.extractPath(0, m.length * p);
      final end = m.getTangentForOffset(m.length * p)?.position ?? pt(0);
      final fill = Path.from(part)
        ..lineTo(end.dx, 20 + h)
        ..lineTo(pt(0).dx, 20 + h)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [burgundy.withValues(alpha: 0.3), burgundy.withValues(alpha: 0)]).createShader(Offset.zero & size),
      );
      canvas.drawPath(
        part,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = burgundy,
      );
    }
    for (var i = 0; i < e.length; i++) {
      if (e.length > 1 && p < i / (e.length - 1)) continue;
      canvas.drawCircle(pt(i), 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        pt(i),
        6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = burgundy,
      );
      if (i == 0 || i == e.length - 1) {
        final tp = TextPainter(
          text: TextSpan(
            text: e[i].kg.toStringAsFixed(1),
            style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, pt(i) - Offset(tp.width / 2, 22));
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeightPainter o) => true;
}

void weightSheet(BuildContext ctx, AppState s) {
  double v = s.weight;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Log your weight'), style: titleStyle),
            Slider(value: v, min: 30, max: 200, divisions: 1700, label: '${v.toStringAsFixed(1)} ${tr('kg')}', onChanged: (x) => set(() => v = x)),
            Text(
              '${v.toStringAsFixed(1)} kg',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: burgundy),
                onPressed: () {
                  s.addWeight(double.parse(v.toStringAsFixed(1)));
                  Navigator.pop(c);
                },
                child: Text(tr('Save')),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class WeightPage extends StatelessWidget {
  final AppState state;
  const WeightPage({super.key, required this.state});

  String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Weight',
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state;
          final bmi = s.weight / pow(s.height / 100, 2);
          final cat = bmi < 18.5
              ? tr('Underweight')
              : bmi < 25
              ? tr('Normal')
              : bmi < 30
              ? tr('Overweight')
              : tr('Obese');
          final list = s.weights.reversed.toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Appear(
                child: Glass(
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
                  child: SizedBox(
                    height: 210,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey(s.weights.length),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 1300),
                      curve: Curves.easeInOutCubic,
                      builder: (_, v, _) => CustomPaint(painter: WeightPainter(s.weights, v), size: Size.infinite),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 1,
                child: Row(
                  children: [
                    Expanded(
                      child: Glass(
                        child: Column(
                          children: [
                            Text(
                              '${s.weight.toStringAsFixed(1)} ${tr('kg')}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy),
                            ),
                            Text(tr('Current'), style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Glass(
                        child: Column(
                          children: [
                            Text(
                              bmi.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy),
                            ),
                            Text('${tr('BMI')} · $cat', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Glass(
                        child: Column(
                          children: [
                            Text(
                              '${s.targetCalories}',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy),
                            ),
                            Text(tr('kcal goal'), style: TextStyle(color: Colors.black54, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Appear(
                index: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: burgundy),
                    onPressed: () => weightSheet(context, s),
                    icon: const Icon(Icons.add),
                    label: Text(tr('Log weight')),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(tr('BMI is only a rough guide, not a diagnosis.'), style: TextStyle(color: Colors.black45, fontSize: 11)),
              const SizedBox(height: 8),
              for (var i = 0; i < list.length; i++)
                Appear(
                  key: ValueKey('w${list[i].date.microsecondsSinceEpoch}$i'),
                  index: i + 3,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Text(_d(list[i].date), style: const TextStyle(color: Colors.black54)),
                          const Spacer(),
                          if (i < list.length - 1)
                            Text(
                              '${list[i].kg - list[i + 1].kg >= 0 ? '+' : ''}${(list[i].kg - list[i + 1].kg).toStringAsFixed(1)}  ',
                              style: TextStyle(color: list[i].kg - list[i + 1].kg > 0 ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 12),
                            ),
                          Text('${list[i].kg.toStringAsFixed(1)} ${tr('kg')}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── СПИСОК ПОКУПОК ─────────────────────────

class ShoppingPage extends StatefulWidget {
  final AppState state;
  const ShoppingPage({super.key, required this.state});
  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  TextEditingController? _fc;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return GlassPage(
      title: 'Shopping list',
      child: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Autocomplete<FoodItem>(
              displayStringForOption: (f) => tn(f.name),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<FoodItem>.empty();
                return foodDatabase.where((f) => searchKey(f.name).contains(q)).take(8);
              },
              onSelected: (f) {
                s.addShopping([f.name]);
                Future.microtask(() => _fc?.clear());
              },
              fieldViewBuilder: (ctx, ctrl, node, onSub) {
                _fc = ctrl;
                return TextField(
                  controller: ctrl,
                  focusNode: node,
                  decoration: InputDecoration(
                    hintText: tr('Add to shopping list...'),
                    prefixIcon: const Icon(Icons.add_shopping_cart, color: burgundy),
                    filled: true,
                    fillColor: Colors.white70,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            if (s.shopping.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: NutrikSays(text: tr('Your list is empty! Add items here, or open a recipe and tap "Add missing to shopping list".'), size: 90),
              ),
            for (var i = 0; i < s.shopping.length; i++)
              Appear(
                key: ValueKey('sh${s.shopping[i]}'),
                index: i,
                child: Dismissible(
                  key: ValueKey('shd${s.shopping[i]}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => s.removeShopping(s.shopping[i]),
                  background: Container(
                    color: Colors.red.shade900,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Emo(foodByName[s.shopping[i]]?.emoji ?? '🛒', food: s.shopping[i], size: 32),
                        title: Text(tn(s.shopping[i]), style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(tr('Tap ✓ when you buy it — it goes straight to your fridge')),
                        trailing: IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: burgundy, size: 30),
                          onPressed: () {
                            final n = s.shopping[i];
                            s.buy(n);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: burgundy, duration: const Duration(milliseconds: 1400), content: Text(tr('{0} is in your fridge 🧊', [tn(n)]))),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── ДОСТИЖЕНИЯ ─────────────────────────

class MedalsPage extends StatelessWidget {
  final AppState state;
  const MedalsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Achievements',
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final n = state.unlocked.length;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Appear(
                child: Glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('{0} / {1} unlocked', [n, medals.length]), style: titleStyle),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: n / medals.length),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: burgundy, backgroundColor: Colors.black12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                children: [
                  for (var i = 0; i < medals.length; i++)
                    Appear(
                      index: i + 1,
                      child: Builder(
                        builder: (context) {
                          final m = medals[i];
                          final on = state.unlocked.contains(m.id);
                          return Glass(
                            tint: on ? const Color(0xFFFFF3C4) : null,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                on
                                    ? TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.4, end: 1),
                                        duration: const Duration(milliseconds: 800),
                                        curve: Curves.elasticOut,
                                        builder: (_, v, child) => Transform.scale(scale: v, child: child),
                                        child: Emo(m.emoji, size: 48),
                                      )
                                    : Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          ColorFiltered(
                                            colorFilter: const ColorFilter.matrix(<double>[0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0, 0, 0, 1, 0]),
                                            child: Opacity(opacity: 0.35, child: Emo(m.emoji, size: 48)),
                                          ),
                                          const Icon(Icons.lock, size: 18, color: Colors.black45),
                                        ],
                                      ),
                                const SizedBox(height: 8),
                                Text(
                                  m.title,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  m.desc,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ───────────────────────── HOME: быстрые плитки ─────────────────────────

class QuickTile extends StatefulWidget {
  final String emoji, label;
  final int badge;
  final void Function(BuildContext) onTap;
  const QuickTile({super.key, required this.emoji, required this.label, required this.onTap, this.badge = 0});
  @override
  State<QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<QuickTile> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: GestureDetector(
          onTapDown: (_) => setState(() => down = true),
          onTapCancel: () => setState(() => down = false),
          onTapUp: (_) {
            setState(() => down = false);
            widget.onTap(context);
          },
          child: AnimatedScale(
            scale: down ? 0.92 : 1,
            duration: const Duration(milliseconds: 120),
            child: Glass(
              radius: 18,
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Badge(
                    isLabelVisible: widget.badge > 0,
                    label: Text('${widget.badge}'),
                    child: Emo(widget.emoji, size: 30),
                  ),
                  const SizedBox(height: 4),
                  Text(tr(widget.label), style: const TextStyle(fontSize: 11, color: Colors.black87)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── HOME ─────────────────────────

class WavePainter extends CustomPainter {
  final double level, t;
  WavePainter(this.level, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final c = Offset(r, r);
    final circle = Path()..addOval(Rect.fromCircle(center: c, radius: r - 3));
    canvas.drawPath(circle, Paint()..color = Colors.white.withValues(alpha: 0.1));
    canvas.save();
    canvas.clipPath(circle);
    final base = size.height * (1 - (0.06 + level.clamp(0.0, 1.0) * 0.88));
    for (var k = 0; k < 2; k++) {
      final amp = 5.0 + k * 2;
      final ph = t * 2 * pi * (k == 0 ? 1 : -1.3) + k * 1.5;
      final p = Path()..moveTo(0, size.height);
      for (var x = 0.0; x <= size.width; x += 4) {
        p.lineTo(x, base + sin(x / size.width * 2 * pi * 1.3 + ph) * amp);
      }
      p
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        p,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: k == 0 ? const [Color(0xCCF3D9A0), Color(0xCCD9A441)] : const [Color(0x88FFF3D0), Color(0x66C98A2B)],
          ).createShader(Rect.fromLTWH(0, base - 10, size.width, size.height - base + 10)),
      );
    }
    for (var k = 0; k < 6; k++) {
      final bt = (t * 0.7 + k * 0.17) % 1;
      final by = size.height - bt * (size.height - base);
      if (by < base + 4) continue;
      canvas.drawCircle(Offset(r + sin(k * 2.1 + bt * 6) * r * 0.5, by), 2 + (k % 3), Paint()..color = Colors.white.withValues(alpha: 0.5 * (1 - bt)));
    }
    canvas.restore();
    canvas.drawCircle(
      c,
      r - 3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r - 12),
      pi * 1.05,
      pi * 0.45,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(covariant WavePainter o) => true;
}

/// Круглый «жидкий» индикатор: уровень жидкости = доля (эко-рейтинг, калории и т.п.).
class LiquidGauge extends StatefulWidget {
  final double level, size;
  final int value;
  final String suffix, label;
  const LiquidGauge({super.key, required this.level, required this.value, this.suffix = '', this.label = 'kcal eaten', this.size = 150});
  @override
  State<LiquidGauge> createState() => _LiquidGaugeState();
}

class _LiquidGaugeState extends State<LiquidGauge> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: widget.level),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => AnimatedBuilder(
              animation: c,
              builder: (_, _) => CustomPaint(size: Size.square(widget.size), painter: WavePainter(v, c.value)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(end: widget.value),
                duration: const Duration(milliseconds: 1200),
                builder: (_, v, _) => Text(
                  '$v${widget.suffix}',
                  style: TextStyle(
                    fontSize: widget.size * 0.21,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
              ),
              Text(tr(widget.label), style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class Pulse extends StatefulWidget {
  final Widget child;
  const Pulse({super.key, required this.child});
  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
    scale: Tween<double>(begin: 0.9, end: 1.2).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
    child: widget.child,
  );
}

class HomePage extends StatefulWidget {
  final AppState state;
  final AiService ai;
  final ValueChanged<int> onTab;
  const HomePage({super.key, required this.state, required this.ai, required this.onTab});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final sc = ScrollController();

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  AppState get state => widget.state;

  Widget _pill(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
  );

  /// Главная карточка: «спасательная миссия» — что вот-вот испортится и сколько это стоит.
  Widget _hero() {
    final save = state.expiringSoon.where((p) => p.daysLeft >= 0).toList();
    final dead = state.expired.length;
    final empty = state.pantry.isEmpty;
    final score = state.ecoScore;
    final line = empty
        ? tr('"Empty fridge = zero waste... but I\'m hungry!"')
        : save.isNotEmpty
        ? tr('"Eat these first! I found recipes for them."')
        : dead > 0
        ? tr('"Something smells funny in there... 👃"')
        : tr('"Everything is fresh. You\'re a legend!"');
    final cta = empty
        ? tr('Stock your fridge')
        : save.isNotEmpty
        ? tr('Cook with them')
        : tr('Open fridge');
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 60),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A041C), Color(0xFF9B1B33)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
            boxShadow: [BoxShadow(color: burgundy.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LiquidGauge(level: score / 100, value: score, suffix: '%', label: 'eco score', size: 124),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('RESCUE MISSION'), style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 2)),
                        const SizedBox(height: 4),
                        Text(
                          empty
                              ? tr('Fridge is empty')
                              : save.isEmpty
                              ? tr('Nothing to rescue')
                              : tr('{0} to save', [trp(save.length, 'item|items')]),
                          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          save.isNotEmpty
                              ? tr('≈ {0} at risk', ['\$${state.moneyAtRisk.toStringAsFixed(2)}'])
                              : dead > 0
                              ? tr('{0} expired in the fridge', [dead])
                              : tr('all products are fresh'),
                          style: TextStyle(color: dead > 0 && save.isEmpty ? const Color(0xFFFFB4B4) : Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Wrap(spacing: 6, runSpacing: 6, children: [_pill('🦸 ${tr('{0} rescued', [state.rescued])}'), _pill('💰 ${tr('{0} saved', ['\$${state.rescuedMoney.toStringAsFixed(0)}'])}')]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                line,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: burgundy),
                  onPressed: () => widget.onTab(
                    empty
                        ? 1
                        : save.isNotEmpty
                        ? 3
                        : 2,
                  ),
                  icon: Icon(
                    empty
                        ? Icons.add_shopping_cart
                        : save.isNotEmpty
                        ? Icons.restaurant_menu
                        : Icons.kitchen,
                  ),
                  label: Text(cta, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -17,
          right: 14,
          child: Nutrik(size: 92, mode: dead > 0 && save.isEmpty ? NutrikMode.fall : NutrikMode.idle, stars: !empty && save.isEmpty && dead == 0),
        ),
      ],
    );
  }

  Widget _calories() {
    final total = state.eatenCalories, goal = state.targetCalories, left = goal - total;
    final vals = [for (var k = 0; k < 7; k++) state.kcalOn(todayNum() - 6 + k)];
    final mx = max(goal * 1.15, vals.reduce(max).toDouble());
    return Glass(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 60,
                height: 60,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (total / goal).clamp(0.0, 1.0).toDouble()),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => CustomPaint(
                    painter: RingPainter(v, total > goal ? Colors.orange.shade800 : burgundy, 7),
                    child: Center(
                      child: Text('${(total / goal * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Calories today'), style: headStyle),
                    Text(tr('{0} of {1} kcal · {2}', [total, goal, left >= 0 ? tr('{0} left', [left]) : tr('{0} over', [-left])]), style: const TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 88,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 18 + 64 * (goal / mx),
                  child: Container(height: 1, color: burgundy.withValues(alpha: 0.3)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var k = 0; k < 7; k++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: vals[k] / mx),
                              duration: Duration(milliseconds: 700 + k * 90),
                              curve: Curves.easeOutBack,
                              builder: (_, v, _) => Container(
                                width: 16,
                                height: max(5.0, 64 * v),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: k == 6 ? const [Color(0xFFD9A441), burgundy] : [burgundy.withValues(alpha: 0.55), burgundy.withValues(alpha: 0.2)],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('MTWTFSS')[now().subtract(Duration(days: 6 - k)).weekday - 1],
                              style: TextStyle(fontSize: 10, fontWeight: k == 6 ? FontWeight.bold : FontWeight.normal, color: k == 6 ? burgundy : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _health() {
    final p = state.pantry;
    final bad = p.where((e) => e.daysLeft < 0).length, soon = p.where((e) => e.daysLeft >= 0 && e.daysLeft <= 2).length, ok = p.length - bad - soon;
    return GestureDetector(
      onTap: () => widget.onTab(2),
      child: Glass(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(tr('Fridge health'), style: headStyle),
                const Spacer(),
                Text('${trp(p.length, 'item|items')}  ›', style: const TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (ok > 0)
                            Expanded(
                              flex: ok,
                              child: Container(color: Colors.green.shade600),
                            ),
                          if (soon > 0)
                            Expanded(
                              flex: soon,
                              child: Container(color: Colors.orange.shade700),
                            ),
                          if (bad > 0)
                            Expanded(
                              flex: bad,
                              child: Container(color: Colors.red.shade700),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 14, children: [_dot(Colors.green.shade600, tr('{0} fresh', [ok])), _dot(Colors.orange.shade700, tr('{0} use soon', [soon])), _dot(Colors.red.shade700, tr('{0} expired', [bad]))]),
          ],
        ),
      ),
    );
  }

  Widget _dot(Color c, String t) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(t, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    ],
  );

  Widget _emptyFridge() => Glass(
    child: Column(
      children: [
        NutrikSays(text: tr('Your fridge is empty! Add what you bought — or load a demo fridge to see how food rescue works.'), size: 78),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: burgundy, minimumSize: const Size(0, 46)),
                onPressed: state.loadDemo,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: Text(tr('Demo fridge')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: burgundy,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: burgundy),
                ),
                onPressed: () => widget.onTab(1),
                icon: const Icon(Icons.search, size: 18),
                label: Text(tr('Add products')),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _expiryCard(PantryItem it, int i) => Appear(
    index: i,
    child: SizedBox(
      width: 146,
      child: GestureDetector(
        onTap: () => itemSheet(context, state, it),
        child: Glass(
          padding: const EdgeInsets.all(12),
          tint: it.daysLeft < 0 ? const Color(0xFFFFE0E0) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: it.fresh),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, v, _) => CustomPaint(painter: RingPainter(v, it.color, 5)),
                    ),
                  ),
                  FoodIcon(it.food, size: 32),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tn(it.food.name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                it.status,
                style: TextStyle(color: it.color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const Spacer(),
              Row(
                children: [
                  _mini(Icons.restaurant, burgundy, 'Eat', () => eatSheet(context, state, it)),
                  if (it.daysLeft >= 0 && canFreeze(it.food) && it.storage != Storage.freezer) _mini(Icons.ac_unit, Colors.blue.shade700, 'Freeze', () => freezeWithSnack(context, state, it)),
                  _mini(Icons.delete_outline, Colors.black54, 'Throw away', () => throwSheet(context, state, it)),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _mini(IconData i, Color c, String tip, VoidCallback f) => IconButton(
    tooltip: tr(tip),
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 38, minHeight: 32),
    icon: Icon(i, color: c, size: 20),
    onPressed: f,
  );

  @override
  Widget build(BuildContext context) {
    final hr = now().hour;
    final greet = hr < 5
        ? tr('Hello, night owl')
        : hr < 12
        ? tr('Good morning')
        : hr < 18
        ? tr('Good afternoon')
        : tr('Good evening');
    final exp = state.expiringSoon;
    final today = state.log.where((e) => e.day == todayNum()).toList();
    return Stack(
      children: [
        const Positioned.fill(child: LiquidBg()),
        SafeArea(
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Appear(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greet, style: const TextStyle(color: Colors.black54)),
                          Text('${state.name} 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: tr('Days without throwing food away'),
                      child: Glass(
                        radius: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Row(
                          children: [
                            Pulse(child: const Text('🔥', style: TextStyle(fontSize: 18))),
                            const SizedBox(width: 4),
                            Text(tr('{0}d', [state.streakDays]), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => Navigator.push(context, fadeSlide(ProfilePage(state: state, ai: widget.ai))),
                      child: CircleAvatar(
                        backgroundColor: burgundy,
                        child: Text(state.name.isEmpty ? '?' : state.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
              Appear(
                index: 1,
                child: AnimatedBuilder(
                  animation: sc,
                  builder: (_, child) {
                    final o = sc.hasClients ? sc.offset.clamp(0.0, 400.0).toDouble() : 0.0;
                    return Opacity(
                      opacity: (1 - o / 700).clamp(0.4, 1.0).toDouble(),
                      child: Transform.scale(scale: 1 - o / 2400, child: child),
                    );
                  },
                  child: KeyedSubtree(key: Tour.hero, child: _hero()),
                ),
              ),
              const SizedBox(height: 16),
              if (state.pantry.isEmpty) Appear(index: 2, child: _emptyFridge()),
              if (exp.isNotEmpty) ...[
                Appear(
                  index: 2,
                  child: Row(
                    children: [
                      Text(tr('Use these first ⚠️'), style: headStyle),
                      const Spacer(),
                      Text(tr('tap for options'), style: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  key: Tour.useFirst,
                  height: 182,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: exp.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, i) => _expiryCard(exp[i], i),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Appear(
                index: 3,
                child: Row(
                  key: Tour.tiles,
                  children: [
                    QuickTile(
                      emoji: '🌍',
                      label: 'Impact',
                      onTap: (c) => Navigator.push(c, circleReveal(ImpactPage(state: state), centerOf(c))),
                    ),
                    QuickTile(
                      emoji: '🛒',
                      label: 'Shopping',
                      badge: state.shopping.length,
                      onTap: (c) => Navigator.push(c, circleReveal(ShoppingPage(state: state), centerOf(c))),
                    ),
                    QuickTile(
                      emoji: '⚖️',
                      label: 'Weight',
                      onTap: (c) => Navigator.push(c, circleReveal(WeightPage(state: state), centerOf(c))),
                    ),
                    QuickTile(
                      emoji: '🏆',
                      label: '${state.unlocked.length}/${medals.length}',
                      onTap: (c) => Navigator.push(c, circleReveal(MedalsPage(state: state), centerOf(c))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.pantry.isNotEmpty) ...[Appear(index: 4, child: _health()), const SizedBox(height: 12)],
              Appear(
                index: 5,
                child: GestureDetector(
                  onTap: state.nextTip,
                  child: Glass(
                    child: Row(
                      children: [
                        const Text('💡', style: TextStyle(fontSize: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 400),
                            child: Text(
                              tr(tips[state.tipIndex % tips.length]),
                              key: ValueKey(state.tipIndex),
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ),
                        ),
                        const Icon(Icons.refresh, size: 18, color: Colors.black38),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Appear(index: 6, child: _calories()),
              const SizedBox(height: 16),
              Text(tr('Eaten today'), style: headStyle),
              const SizedBox(height: 8),
              if (today.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(tr('Nothing eaten yet. Tap a product, then Eat.'), style: const TextStyle(color: Colors.black45)),
                  ),
                ),
              for (final e in today)
                Dismissible(
                  key: ValueKey('log_${e.id}'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => state.removeLog(e),
                  background: Container(
                    color: Colors.red.shade900,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Glass(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Emo(e.emoji, food: e.name.split(' · ').first, size: 30),
                        title: Text(e.name.split(' · ').map(tn).join(' · ')),
                        trailing: Text(
                          '${e.kcal} kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: burgundy),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── ДЕЙСТВИЯ С ПРОДУКТОМ (шторки) ─────────────────────────


void _snack(ScaffoldMessengerState m, String text, {Color color = burgundy}) => m
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: color, duration: const Duration(milliseconds: 2600), content: Text(text)));

void freezeWithSnack(BuildContext ctx, AppState s, PantryItem p) {
  s.freeze(p);
  _snack(ScaffoldMessenger.of(ctx), tr('❄️ {0} frozen — good until {1}', [tn(p.food.name), fmtDate(p.expiry)]), color: Colors.blue.shade800);
}

void eatSheet(BuildContext ctx, AppState s, PantryItem p) {
  double g = 100;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  FoodIcon(p.food, size: 34),
                  const SizedBox(width: 8),
                  Flexible(child: Text(tn(p.food.name), style: titleStyle)),
                ],
              ),
              const SizedBox(height: 4),
              Text(tr('How much did you eat?')),
              Slider(value: g, min: 10, max: 500, divisions: 49, label: '${g.round()} ${tr('g')}', onChanged: (v) => set(() => g = v)),
              Text(
                '${g.round()} ${tr('g')} · ${(p.food.kcal * g / 100).round()} ${tr('kcal')}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: burgundy),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: burgundy),
                  onPressed: () {
                    s.eat(p, g.round());
                    Navigator.pop(c);
                  },
                  child: Text(tr('Finished it 🎉')),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: burgundy,
                    side: const BorderSide(color: burgundy),
                  ),
                  onPressed: () {
                    s.eat(p, g.round(), finished: false);
                    Navigator.pop(c);
                  },
                  child: Text(tr('Ate some — keep the rest')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Выбор причины выброса: копит статистику и сразу даёт совет на будущее.
void throwSheet(BuildContext ctx, AppState s, PantryItem p) {
  final m = ScaffoldMessenger.of(ctx);
  showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FoodIcon(p.food, size: 26),
                const SizedBox(width: 8),
                Flexible(child: Text(tr('Why does {0} go to the bin?', [tn(p.food.name)]), style: headStyle)),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('An honest answer helps Nutrik give you better tips 💛'), style: TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 12),
            for (final r in WasteReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: sand,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      Navigator.pop(c);
                      s.throwAway(p, r);
                      _snack(m, '💡 ${tr(reasonInfo[r]!.$3)}', color: Colors.red.shade900);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Text(reasonInfo[r]!.$1, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(tr(reasonInfo[r]!.$2), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.black38),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (p.daysLeft >= 0 && canFreeze(p.food) && p.storage != Storage.freezer)
              Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.blue.shade800),
                  onPressed: () {
                    Navigator.pop(c);
                    s.freeze(p);
                    _snack(m, tr('❄️ Saved! {0} is in the freezer until {1}', [tn(p.food.name), fmtDate(p.expiry)]), color: Colors.blue.shade800);
                  },
                  icon: const Icon(Icons.ac_unit),
                  label: Text(tr('Wait! Freeze it instead (+90 days)')),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Карточка продукта со всеми действиями: съесть, приготовить, заморозить, отдать, сменить дату, выбросить.
void itemSheet(BuildContext ctx, AppState s, PantryItem p) {
  final m = ScaffoldMessenger.of(ctx);
  final recs = recipes.where((r) => r.ingredients.any((i) => i.name == p.food.name)).take(4).toList();
  final tip = storageTips[p.food.name] ?? storageTips[p.food.category];
  final freezable = p.daysLeft >= 0 && canFreeze(p.food) && p.storage != Storage.freezer;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) {
      Widget act(String emoji, String label, VoidCallback? f, {Color? color}) => Expanded(
        child: Opacity(
          opacity: f == null ? 0.4 : 1,
          child: Material(
            color: color ?? Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: f == null
                  ? null
                  : () {
                      Navigator.pop(c);
                      f();
                    },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 2),
                    Text(tr(label), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FoodIcon(p.food, size: 54),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tn(p.food.name), style: titleStyle),
                        Text('${storageLabel[p.storage]} · ${p.food.kcal} ${tr('kcal/100 g')}', style: const TextStyle(color: Colors.black54)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: p.color, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      p.status,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: p.fresh, minHeight: 8, color: p.color, backgroundColor: Colors.black12),
              ),
              const SizedBox(height: 6),
              Text(tr('Added {0} · good until {1}', [fmtDate(p.added), fmtDate(p.expiry)]), style: const TextStyle(color: Colors.black54, fontSize: 12)),
              if (tip != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: sand, borderRadius: BorderRadius.circular(14)),
                  child: Text('💡 ${tr('Storage: {0}', [tr(tip)])}', style: const TextStyle(fontSize: 13)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  act('🍽️', 'Eat', () => eatSheet(ctx, s, p)),
                  const SizedBox(width: 8),
                  act('❄️', 'Freeze', freezable ? () => freezeWithSnack(ctx, s, p) : null, color: const Color(0xFFE3F0FB)),
                  const SizedBox(width: 8),
                  act('🤝', 'Share', () {
                    s.share(p);
                    _snack(m, tr('🤝 {0} shared — food rescued, neighbor happy!', [tn(p.food.name)]));
                  }, color: const Color(0xFFE8EFE0)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  act('📅', 'Change date', () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: p.expiry,
                      firstDate: now().subtract(const Duration(days: 60)),
                      lastDate: now().add(const Duration(days: 730)),
                      helpText: tr('Date on the package'),
                      locale: Locale(appLang),
                    );
                    if (d != null) s.setExpiry(p, d);
                  }),
                  const SizedBox(width: 8),
                  act(
                    p.storage == Storage.pantry ? '🧊' : '🫙',
                    p.storage == Storage.pantry ? 'To fridge' : 'To pantry',
                    p.storage == Storage.freezer ? null : () => s.moveTo(p, p.storage == Storage.pantry ? Storage.fridge : Storage.pantry),
                  ),
                  const SizedBox(width: 8),
                  act('🗑️', 'Throw away', () => throwSheet(ctx, s, p), color: const Color(0xFFFBE3E3)),
                ],
              ),
              if (recs.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(tr('Cook it into...'), style: headStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in recs)
                      ActionChip(
                        avatar: Emo(r.emoji, size: 20),
                        label: Text(tn(r.name)),
                        onPressed: () {
                          Navigator.pop(c);
                          Navigator.push(ctx, fadeSlide(RecipePage(state: s, recipe: r)));
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class PantryTile extends StatelessWidget {
  final PantryItem item;
  final AppState state;
  final int count;
  final int batches;
  const PantryTile({super.key, required this.item, required this.state, this.count = 1, this.batches = 1});

  Widget _step(IconData i, String tip, VoidCallback f) => SizedBox(
    width: 30,
    height: 30,
    child: IconButton(
      tooltip: tr(tip),
      padding: EdgeInsets.zero,
      iconSize: 18,
      style: IconButton.styleFrom(backgroundColor: burgundy.withValues(alpha: 0.08)),
      icon: Icon(i, color: burgundy),
      onPressed: f,
    ),
  );

  @override
  Widget build(BuildContext context) {
    Widget bg(Color c, IconData i, String t, Alignment a) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: a,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            tr(t),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
    return Dismissible(
      key: ValueKey('tile${item.id}'),
      background: bg(Colors.green.shade700, Icons.restaurant, 'Eat', Alignment.centerLeft),
      secondaryBackground: bg(Colors.red.shade800, Icons.delete_outline, 'Throw away', Alignment.centerRight),
      confirmDismiss: (d) async {
        d == DismissDirection.startToEnd ? eatSheet(context, state, item) : throwSheet(context, state, item);
        return false;
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: () => itemSheet(context, state, item),
          child: Glass(
            radius: 18,
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            tint: item.daysLeft < 0 ? const Color(0xFFFFE0E0) : null,
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: item.fresh),
                        duration: const Duration(milliseconds: 800),
                        builder: (_, v, _) => CustomPaint(painter: RingPainter(v, item.color, 4)),
                      ),
                    ),
                    FoodIcon(item.food, size: 28),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              tn(item.food.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                          if (count > 1)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(color: burgundy, borderRadius: BorderRadius.circular(10)),
                              child: Text('×$count', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            item.status,
                            style: TextStyle(color: item.color, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Flexible(
                            child: Text(
                              '  ·  ${batches > 1 ? trp(batches, 'batch|batches') : storageLabel[item.storage]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black45, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _step(Icons.remove, 'One less', () => state.removeOne(item)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, color: burgundy)),
                ),
                _step(Icons.add, 'One more', () => state.addMore(item)),
                IconButton(
                  tooltip: tr('Eat'),
                  icon: const Icon(Icons.restaurant, color: burgundy),
                  onPressed: () => eatSheet(context, state, item),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── SEARCH ─────────────────────────

class SearchPage extends StatefulWidget {
  final AppState state;
  const SearchPage({super.key, required this.state});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _c = TextEditingController();
  String q = '';
  String? cat;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int _score(FoodItem f, String qq) {
    // ищет по английскому, русскому и казахскому названию
    final n = searchKey(f.name);
    if (tn(f.name).toLowerCase().startsWith(qq)) return 0;
    if (n.startsWith(qq)) return 0;
    if (n.split(' ').any((w) => w.startsWith(qq))) return 1;
    if (n.contains(qq)) return 2;
    return 3;
  }

  List<FoodItem> get results {
    final qq = q.trim().toLowerCase();
    final list = foodDatabase.where((f) => (cat == null || f.category == cat) && (qq.isEmpty || _score(f, qq) < 3)).toList();
    list.sort((a, b) => _score(a, qq) != _score(b, qq) ? _score(a, qq).compareTo(_score(b, qq)) : tn(a.name).compareTo(tn(b.name)));
    return list;
  }

  void _add(FoodItem f) {
    widget.state.add(f);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: burgundy,
          duration: const Duration(milliseconds: 1500),
          content: Text(tr('{0} added · stays fresh for {1}', ['${f.emoji} ${tn(f.name)}', trp(f.shelf, 'day|days')])),
        ),
      );
  }

  Widget _chip(String label, String? value) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(value == null ? tr(label) : '${catEmoji[value]} ${tn(label)}'),
      selected: cat == value,
      selectedColor: burgundy,
      labelStyle: TextStyle(color: cat == value ? Colors.white : Colors.black87),
      showCheckmark: false,
      onSelected: (_) => setState(() => cat = value),
    ),
  );

  Widget _grid() => GridView.count(
    key: const ValueKey('grid'),
    padding: const EdgeInsets.only(bottom: 120),
    crossAxisCount: 2,
    childAspectRatio: 2.3,
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    children: [
      for (var i = 0; i < categories.length; i++)
        Appear(
          index: i,
          child: Material(
            color: sand,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() => cat = categories[i]),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Emo(catEmoji[categories[i]] ?? '🍽️', size: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tn(categories[i]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(trp(foodDatabase.where((f) => f.category == categories[i]).length, 'product|products'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ],
  );

  Widget _list(List<FoodItem> res) {
    if (res.isEmpty)
      return Center(
        key: const ValueKey('none'),
        child: Text(tr('Nothing found for "{0}"', [q]), style: const TextStyle(color: Colors.grey)),
      );
    final count = <String, int>{};
    for (final p in widget.state.pantry) {
      count[p.food.name] = (count[p.food.name] ?? 0) + 1;
    }
    final ids = res.map((f) => f.name).toSet();
    final related = q.trim().isEmpty ? <FoodItem>[] : foodDatabase.where((f) => f.category == res.first.category && !ids.contains(f.name)).take(6).toList();
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: res.length + 1,
      itemBuilder: (context, i) {
        if (i == res.length) {
          if (related.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('You may also like'), style: headStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in related)
                      ActionChip(
                        avatar: FoodIcon(f, size: 20),
                        label: Text(tn(f.name)),
                        onPressed: () => setState(() {
                          _c.text = tn(f.name);
                          _c.selection = TextSelection.collapsed(offset: _c.text.length);
                          q = _c.text;
                        }),
                      ),
                  ],
                ),
              ],
            ),
          );
        }
        final f = res[i];
        final n = count[f.name] ?? 0;
        return Card(
          color: sand,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: FoodIcon(f, size: 34),
            title: Text(tn(f.name), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${f.kcal} ${tr('kcal/100 g')} · ${tr('keeps {0} d', [f.shelf])} · ${storageLabel[defaultStorage(f)]}${n > 0 ? '\n${tr('✓ in fridge ×{0}', [n])}' : ''}', style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.add_circle, color: burgundy, size: 30),
              onPressed: () => _add(f),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final showGrid = q.trim().isEmpty && cat == null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Search products'), style: titleStyle),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              onChanged: (v) => setState(() => q = v),
              decoration: InputDecoration(
                hintText: tr('Try "cheese", "potato", "kefir"...'),
                prefixIcon: const Icon(Icons.search, color: burgundy),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _c.clear();
                          setState(() => q = '');
                        },
                      ),
                filled: true,
                fillColor: sand,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, children: [_chip('All', null), ...categories.map((c) => _chip(c, c))]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: showGrid ? _grid() : _list(results)),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── FRIDGE ─────────────────────────

class PantryPage extends StatefulWidget {
  final AppState state;
  final VoidCallback onSearch;
  const PantryPage({super.key, required this.state, required this.onSearch});
  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  Storage? place;

  Widget _chip(String label, Storage? v, int n) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text('${tr(label)}  $n'),
      selected: place == v,
      selectedColor: burgundy,
      labelStyle: TextStyle(color: place == v ? Colors.white : Colors.black87),
      showCheckmark: false,
      onSelected: (_) => setState(() => place = v),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final all = [...s.pantry]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    // Одинаковые продукты в одном месте складываются в одну строку «×N» (жалоба 2):
    // строка показывает самую старую партию — «съел»/«выбросил» списывают сначала её.
    final count = <String, int>{};
    final batches = <String, Set<int>>{};
    String key(PantryItem p) => '${p.food.name}|${p.storage.index}';
    for (final p in all) {
      count[key(p)] = (count[key(p)] ?? 0) + 1;
      (batches[key(p)] ??= <int>{}).add(p.daysLeft);
    }
    final seen = <String>{};
    final items = all.where((p) => (place == null || p.storage == place) && seen.add(key(p))).toList();
    final groups = <(String, String, List<PantryItem>)>[
      ('☠️', 'Expired', items.where((p) => p.daysLeft < 0).toList()),
      ('🔥', 'Use today or tomorrow', items.where((p) => p.daysLeft >= 0 && p.daysLeft <= 1).toList()),
      ('⏳', 'This week', items.where((p) => p.daysLeft >= 2 && p.daysLeft <= 7).toList()),
      ('✅', 'Fresh', items.where((p) => p.daysLeft > 7).toList()),
    ];
    var idx = 0;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tr('Your fridge'), style: titleStyle)),
                if (all.isNotEmpty) IconButton.filledTonal(tooltip: tr('Add products'), onPressed: widget.onSearch, icon: const Icon(Icons.add)),
              ],
            ),
            const SizedBox(height: 2),
            Text('${trp(all.length, 'product|products')} · ${tr('swipe → eat, ← throw away · tap for more')}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 10),
            if (all.isNotEmpty)
              SizedBox(
                key: Tour.fridgeTop,
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [_chip('All', null, all.length), for (final st in Storage.values) _chip(storageLabel[st]!, st, all.where((p) => p.storage == st).length)],
                ),
              ),
            const SizedBox(height: 6),
            Expanded(
              child: all.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🧊', style: TextStyle(fontSize: 56)),
                          const SizedBox(height: 8),
                          Text(tr('Fridge is empty'), style: TextStyle(color: Colors.grey)),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: burgundy),
                            onPressed: widget.onSearch,
                            icon: const Icon(Icons.search),
                            label: Text(tr('Find products')),
                          ),
                          TextButton.icon(
                            onPressed: s.loadDemo,
                            icon: const Icon(Icons.auto_awesome, color: burgundy),
                            label: Text(tr('Load demo fridge'), style: TextStyle(color: burgundy)),
                          ),
                        ],
                      ),
                    )
                  : items.isEmpty
                  ? Center(
                      child: Text(tr('Nothing stored here yet'), style: const TextStyle(color: Colors.grey)),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        for (final g in groups)
                          if (g.$3.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                              child: Row(
                                children: [
                                  Text('${g.$1}  ${tr(g.$2)}', style: headStyle),
                                  const Spacer(),
                                  Text(
                                    '${g.$3.fold<int>(0, (a, p) => a + (count[key(p)] ?? 1))}',
                                    style: const TextStyle(color: Colors.black45, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            for (final p in g.$3)
                              Appear(
                                key: ValueKey('p${p.id}'),
                                index: idx++,
                                child: PantryTile(item: p, state: s, count: count[key(p)] ?? 1, batches: batches[key(p)]?.length ?? 1),
                              ),
                          ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── RECIPES ─────────────────────────

class RecipesPage extends StatefulWidget {
  final AppState state;
  const RecipesPage({super.key, required this.state});
  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  int filter = 0; // 0 все, 1 спасают продукты, 2 можно готовить, 3 zero-waste
  static const _filters = ['All', '♻️ Rescue food', '✅ Ready to cook', '🌱 Zero-waste'];

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final names = state.pantryNames;
    final expNames = state.toRescue.map((e) => e.food.name).toSet();
    var list = rankRecipes(state);
    var hidden = 0;
    if (state.pantry.isNotEmpty && filter != 3) {
      final all = list.length;
      list = list.where((r) => r.ingredients.any((i) => names.contains(i.name))).toList();
      hidden = all - list.length;
    }
    list = switch (filter) {
      1 => list.where((r) => r.ingredients.any((i) => expNames.contains(i.name))).toList(),
      2 => list.where((r) => r.missing(names).isEmpty).toList(),
      3 => list.where((r) => r.zeroWaste).toList(),
      _ => list,
    };
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          Text(tr('Recipes'), style: titleStyle),
          const SizedBox(height: 2),
          Text(
            state.pantry.isEmpty ? tr('Your fridge is empty — add products to see what you can cook.') : tr('Sorted so the food that spoils first gets used first.'),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          SizedBox(
            key: Tour.recipeFilters,
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var k = 0; k < _filters.length; k++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tr(_filters[k])),
                      selected: filter == k,
                      selectedColor: burgundy,
                      labelStyle: TextStyle(color: filter == k ? Colors.white : Colors.black87),
                      showCheckmark: false,
                      onSelected: (_) => setState(() => filter = k),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: NutrikSays(
                key: ValueKey(filter),
                text: filter == 1 ? tr('Nothing is about to spoil — nothing to rescue right now! 🎉') : tr('No recipes here yet. Add more products to your fridge!'),
                size: 84,
              ),
            ),
          for (final e in list.asMap().entries) _card(context, e.value, e.key, names, expNames),
          if (hidden > 0 && filter == 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(tr('Add more products to unlock {0} more recipes', [hidden]), style: const TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(20)),
    child: Text(
      t,
      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _card(BuildContext context, Recipe r, int idx, Set<String> names, Set<String> expNames) {
    final missing = r.missing(names);
    final can = missing.isEmpty;
    final saves = r.ingredients.where((i) => expNames.contains(i.name)).map((i) => i.name).toList();
    final have = r.ingredients.length - missing.length;
    return Appear(
      key: ValueKey(r.name),
      index: idx,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => Navigator.push(context, fadeSlide(RecipePage(state: widget.state, recipe: r))),
          child: Glass(
            tint: can ? const Color(0xFFE3F0D8) : null,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(16)),
                      child: Emo(r.emoji, size: 34),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tn(r.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text('${r.kcal} ${tr('kcal')} · ${trTime(r.time)} · ${tr('{0} serv.', [r.servings])}', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: have / r.ingredients.length,
                              minHeight: 5,
                              color: can ? Colors.green.shade700 : Colors.orange.shade700,
                              backgroundColor: Colors.black12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(can ? tr('Ready to cook') : tr('{0} in fridge', ['$have/${r.ingredients.length}']), can ? Colors.green.shade800 : Colors.orange.shade800),
                    if (r.zeroWaste) _tag(tr('🌱 Zero-waste'), const Color(0xFF3C6E71)),
                    if (saves.isNotEmpty) _tag(tr('♻️ Saves {0}', [saves.length]), burgundy),
                  ],
                ),
                if (saves.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      tr('Rescues: {0}', [saves.map(tn).join(', ')]),
                      style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                if (missing.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(tr('Need: {0}', [missing.map(tn).join(', ')]), style: TextStyle(color: Colors.red.shade900, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class RecipePage extends StatefulWidget {
  final AppState state;
  final Recipe recipe;
  const RecipePage({super.key, required this.state, required this.recipe});
  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> {
  late int portions = widget.recipe.servings;

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final s = widget.state;
    final sorted = [...s.pantry]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final inFridge = {for (final p in sorted.reversed) p.food.name: p};
    final missing = r.missing(s.pantryNames);

    return Scaffold(
      appBar: AppBar(title: Text(tn(r.name), style: headStyle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          Appear(
            child: Row(
              children: [
                Emo(r.emoji, size: 60),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('{0} kcal total', [r.kcal * portions]), style: titleStyle),
                      Text('${tr('{0} kcal per serving', [r.kcal])} · ${trTime(r.time)}', style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Appear(
            index: 1,
            child: Row(
              children: [
                Text(tr('Servings'), style: headStyle),
                const Spacer(),
                IconButton.filledTonal(onPressed: portions > 1 ? () => setState(() => portions--) : null, icon: const Icon(Icons.remove)),
                SizedBox(
                  width: 40,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: Text(
                      '$portions',
                      key: ValueKey(portions),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton.filledTonal(onPressed: portions < 12 ? () => setState(() => portions++) : null, icon: const Icon(Icons.add)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(tr('Ingredients'), style: headStyle),
          const SizedBox(height: 6),
          for (final e in r.ingredients.asMap().entries)
            Appear(
              index: e.key + 2,
              child: ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(inFridge.containsKey(e.value.name) ? Icons.check_circle : Icons.cancel, color: inFridge.containsKey(e.value.name) ? Colors.green.shade800 : Colors.red.shade800),
                title: Row(
                  children: [
                    FoodIcon(foodByName[e.value.name]!, size: 24),
                    const SizedBox(width: 8),
                    Flexible(child: Text(tn(e.value.name))),
                  ],
                ),
                subtitle: Text(inFridge.containsKey(e.value.name) ? '${tr('in fridge')} · ${inFridge[e.value.name]!.status}' : tr('not in your fridge — add it in Search')),
                trailing: Text('${(e.value.g * portions / r.servings).round()} ${tr('g')}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          if (r.staples.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(tr('Also needed: {0}', [trStaples(r.staples)]), style: const TextStyle(color: Colors.grey)),
            ),
          const SizedBox(height: 18),
          Text(tr('Instructions'), style: headStyle),
          const SizedBox(height: 8),
          for (final e in trSteps(r.name, r.steps).asMap().entries)
            Appear(
              index: e.key + 4,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: burgundy,
                      child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value, style: const TextStyle(height: 1.35))),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy),
              onPressed: missing.isEmpty
                  ? () {
                      s.cook(r, portions);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: burgundy, content: Text(tr('Bon appétit! {0} kcal logged, ingredients used up.', [r.kcal * portions]))));
                    }
                  : () {
                      s.addShopping(missing);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: burgundy,
                          content: Text(tr('{0} added to your shopping list 🛒', [trp(missing.length, 'item|items')])),
                        ),
                      );
                    },
              child: Text(missing.isEmpty ? tr('I cooked it · log {0} kcal', [r.kcal * portions]) : tr('Add missing to shopping list ({0})', [missing.length])),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── AI CHAT ─────────────────────────

class ChatPage extends StatefulWidget {
  final AppState state;
  final AiService ai;
  const ChatPage({super.key, required this.state, required this.ai});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _c = TextEditingController();
  final _sc = ScrollController();
  final _focus = FocusNode();
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    _sc.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scroll() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_sc.hasClients) _sc.animateTo(_sc.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  });

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _c.text).trim();
    if (text.isEmpty || _loading) return;
    final s = widget.state;
    s.chat.add(ChatMessage(text, isUser: true));
    _c.clear();
    if (preset == null) _focus.requestFocus(); // можно сразу писать следующий вопрос
    setState(() => _loading = true);
    _scroll();
    String answer;
    try {
      answer = await widget.ai.reply(text, s);
    } catch (e) {
      answer = tr('Sorry, something went wrong. Try again.');
    }
    if (!mounted) return;
    s.chat.add(ChatMessage(answer, isUser: false));
    setState(() => _loading = false);
    _scroll();
  }

  @override
  Widget build(BuildContext context) {
    final msgs = widget.state.chat;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(tr('NutriMate AI'), style: titleStyle),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _sc,
              padding: const EdgeInsets.all(16),
              itemCount: msgs.length,
              itemBuilder: (_, i) {
                final m = msgs[i];
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(
                    opacity: v,
                    child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child),
                  ),
                  child: Align(
                    alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: m.isUser ? burgundy : sand, borderRadius: BorderRadius.circular(16)),
                      child: Text(m.text, style: TextStyle(color: m.isUser ? Colors.white : Colors.black87)),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_loading) const Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6), child: LinearProgressIndicator(minHeight: 2)),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final q in [tr('What can I cook?'), tr('What expires soon?'), tr('How to store tomatoes?'), tr('Can I freeze bread?'), tr('Another idea'), tr('Is it still good?'), tr('Do I have milk?')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(q), onPressed: () => _send(q)),
                  ),
              ],
            ),
          ),
          Padding(
            key: Tour.chatInput,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _c,
                    focusNode: _focus,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: tr('Ask anything...'),
                      filled: true,
                      fillColor: sand,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: burgundy),
                  onPressed: () => _send(),
                ),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

// ───────────────────────── PROFILE ─────────────────────────

class ProfilePage extends StatelessWidget {
  final AppState state;
  final AiService ai;
  const ProfilePage({super.key, required this.state, required this.ai});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(tr('Profile'), style: headStyle)),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Appear(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: burgundy,
                  child: Text(state.name.isEmpty ? '?' : state.name[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                ),
                title: Text(state.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(state.email.isEmpty ? tr('Guest account') : state.email),
              ),
            ),
            ListTile(
              title: Text(tr('Goal: {0} kcal/day', [state.targetCalories])),
              leading: const Icon(Icons.track_changes, color: burgundy),
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: burgundy),
              title: Text(tr('Language')),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final l in appLangs)
                      ChoiceChip(
                        label: Text('${langFlag[l]} ${langNative[l]}'),
                        selected: appLang == l,
                        selectedColor: burgundy,
                        labelStyle: TextStyle(color: appLang == l ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                        showCheckmark: false,
                        onSelected: (_) => state.setLanguage(l),
                      ),
                  ],
                ),
              ),
            ),
            SwitchListTile(
              title: Text(tr('Male')),
              value: state.isMan,
              onChanged: (v) => state.updateProfile(isMan: v),
            ),
            _slider('Weight', '${state.weight.round()} ${tr('kg')}', state.weight, 40, 150, (v) => state.updateProfile(weight: v)),
            _slider('Height', '${state.height.round()} ${tr('cm')}', state.height, 120, 220, (v) => state.updateProfile(height: v)),
            _slider('Age', tr('{0} y', [state.age]), state.age.toDouble(), 14, 90, (v) => state.updateProfile(age: v.round())),
            const Divider(height: 32),
            Text(tr('Demo tools'), style: headStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(onPressed: () => state.nextDay(1), icon: const Icon(Icons.skip_next), label: Text(tr('+1 day (now +{0})', [dayShift]))),
                OutlinedButton(onPressed: () => state.nextDay(0), child: Text(tr('Reset time'))),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    state.startTutorial();
                  },
                  icon: const Icon(Icons.school_outlined),
                  label: Text(tr('Replay tutorial')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(tr('Tap "+1 day" to watch freshness bars drop and products expire.'), style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                state.logout();
                Navigator.pushAndRemoveUntil(context, fadeSlide(RegisterScreen(state: state, ai: ai)), (_) => false);
              },
              icon: const Icon(Icons.logout, color: burgundy),
              label: Text(tr('Log out'), style: TextStyle(color: burgundy)),
            ),
            TextButton.icon(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (c) => AlertDialog(
                    title: Text(tr('Erase all data?')),
                    content: Text(tr('Fridge, diary, weight, shopping list and medals will be deleted. This cannot be undone.')),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Cancel'))),
                      FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Erase'))),
                    ],
                  ),
                );
                if (ok != true || !context.mounted) return;
                await state.eraseAll();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(context, fadeSlide(RegisterScreen(state: state, ai: ai)), (_) => false);
              },
              icon: Icon(Icons.delete_forever_outlined, color: Colors.red.shade800),
              label: Text(tr('Erase all data'), style: TextStyle(color: Colors.red.shade800)),
            ),
            Center(child: Text('NutriMate Pro v$appVersion', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _slider(String title, String valueText, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 8),
          child: Text('${tr(title)}: $valueText', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Slider(value: value, min: min, max: max, onChanged: onChanged),
      ],
    );
  }
}
