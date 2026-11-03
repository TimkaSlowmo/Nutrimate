import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

void main() => runApp(const CalorieApp());

const burgundy = Color(0xFF6A041C);
const cream = Color(0xFFF5F1E5);
const sand = Color(0xFFEAE2CF);

// «Часы» приложения: кнопка "+1 day" в профиле сдвигает время, чтобы показать порчу продуктов.
int dayShift = 0;
DateTime now() => DateTime.now().add(Duration(days: dayShift));

// ───────────────────────── МОДЕЛИ ─────────────────────────

class FoodItem {
  final String emoji, name, category;
  final int kcal, shelf; // kcal на 100 г, срок хранения в днях
  const FoodItem(this.emoji, this.name, this.kcal, this.category, this.shelf);
}

class PantryItem {
  final int id;
  final FoodItem food;
  final DateTime added, expiry;
  PantryItem(this.id, this.food, this.added, this.expiry);

  int get daysLeft {
    final n = now();
    return DateTime.utc(expiry.year, expiry.month, expiry.day).difference(DateTime.utc(n.year, n.month, n.day)).inDays;
  }

  double get fresh => (daysLeft / food.shelf).clamp(0.0, 1.0).toDouble();
  String get status => daysLeft < 0 ? 'Expired' : daysLeft == 0 ? 'Last day!' : '$daysLeft d left';
  Color get color => daysLeft <= 0 ? Colors.red.shade800 : daysLeft <= 2 ? Colors.orange.shade800 : Colors.green.shade800;
}

class LogEntry {
  final int day = dayShift;
  final int id, kcal;
  final String emoji, name;
  LogEntry(this.id, this.emoji, this.name, this.kcal);
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
  Recipe(this.name, this.emoji, this.time, this.servings, this.ingredients, this.steps, this.staples);

  List<String> missing(Set<String> have) => ingredients.where((i) => !have.contains(i.name)).map((i) => i.name).toList();
  int get kcal => (ingredients.fold<double>(0, (s, i) => s + i.g * foodByName[i.name]!.kcal / 100) / servings).round();
}

// ───────────────────────── БАЗА ПРОДУКТОВ ─────────────────────────
// Формат: Категория|эмодзи Название,ккал на 100 г,дней хранения;...

const _raw = '''
Vegetables|🍅 Tomato,18,7;🥒 Cucumber,15,7;🥔 Potato,77,30;🍠 Sweet Potato,86,21;🥕 Carrot,41,21;🧅 Onion,40,30;🧄 Garlic,149,60;🥬 Cabbage,25,21;🥦 Broccoli,34,5;🥬 Spinach,23,4;🫑 Bell Pepper,31,7;🍆 Eggplant,25,7;🥒 Zucchini,17,6;🎃 Pumpkin,26,30;🌽 Corn,86,5;🥬 Lettuce,15,5;🍄 Mushrooms,22,5;🌿 Dill,43,5;🌿 Parsley,36,6;🟣 Beetroot,43,21;🫛 Green Peas,81,5;🥦 Cauliflower,25,6;🥬 Celery,16,10;🌶️ Chili Pepper,40,7;⚪ Radish,16,8;🫛 Green Beans,31,5;🌱 Asparagus,20,4;🫚 Ginger,80,21;🥬 Leek,61,10;🥬 Turnip,28,20;🥬 Arugula,25,4;🥬 Bok Choy,13,5;🥬 Brussels Sprouts,43,7;🌿 Artichoke,47,5;🌿 Fennel,31,7;🥬 Kohlrabi,27,10;🧅 Spring Onion,32,7;🥬 Red Cabbage,31,21;🌶️ Jalapeno,29,7;🌿 Horseradish,48,30;🥒 Okra,33,5;🎃 Butternut Squash,45,30;🥕 Parsnip,75,20;🌿 Sorrel,22,4;🌿 Cilantro,23,5;🌿 Basil,23,5;🌿 Mint,70,5;🧅 Shallot,72,30;🧅 Red Onion,40,30;🍅 Cherry Tomato,18,7;🥒 Pattypan Squash,16,6;⚪ Daikon,18,14;🫛 Edamame,121,5;🥬 Salad Mix,17,4;🥬 Swiss Chard,19,5;🥬 Watercress,11,3;🍄 Champignons,22,5;🍄 Oyster Mushrooms,33,5;🍄 Porcini Mushrooms,34,4;🥔 Red Potato,70,30;🌶️ Hot Pepper,40,7;🥬 Chinese Cabbage,16,10;🥬 Romaine Lettuce,17,5
Fruits|🍎 Apple,52,14;🍌 Banana,89,4;🍊 Orange,47,10;🍋 Lemon,29,14;🍐 Pear,57,7;🍇 Grapes,69,7;🍑 Peach,39,4;🍒 Cherry,50,4;🍍 Pineapple,50,5;🥭 Mango,60,5;🍉 Watermelon,30,5;🍈 Melon,34,5;🥝 Kiwi,61,7;🥑 Avocado,160,4;🍑 Apricot,48,4;🍑 Plum,46,5;🍊 Tangerine,53,10;🍎 Pomegranate,83,30;🍊 Grapefruit,42,14;🥭 Papaya,43,5;🍈 Fig,74,3;🌴 Dates,282,180;🍋 Lime,30,14;🍑 Nectarine,44,5;🍊 Persimmon,70,7;🍈 Guava,68,5;🍈 Passion Fruit,97,7;🐉 Dragon Fruit,60,5;🍈 Lychee,66,5;🍐 Quince,57,14;🥥 Coconut,354,30;🍇 Raisins,299,365;🍑 Dried Apricots,241,365;🍑 Prunes,240,365;🍈 Dried Figs,249,365;🍊 Pomelo,38,14;🍏 Green Apple,52,14;🍌 Plantain,122,5;🍍 Dried Pineapple,340,180;🍈 Cantaloupe,34,5;🍐 Asian Pear,42,10;🍊 Clementine,47,10;🍋 Yuzu,30,10
Berries|🍓 Strawberry,32,3;🫐 Blueberry,57,5;🍇 Raspberry,52,3;🫐 Blackberry,43,3;🍒 Cranberry,46,10;🍇 Currant,56,4;🍇 Gooseberry,44,4;🍒 Lingonberry,43,7;🍊 Sea Buckthorn,82,5;🍇 Mulberry,43,3;🍒 Goji Berries,349,180;🍒 Sweet Cherry,63,4;🍒 Sour Cherry,50,4;🍇 Black Currant,63,4;🍇 Red Currant,56,4;🌹 Rosehip,162,30;🍓 Wild Strawberry,32,3;🫐 Bilberry,44,4;🍒 Cloudberry,51,4
Dairy|🥛 Milk,60,5;🥛 Kefir,51,7;🥛 Ryazhenka,67,7;🥛 Yogurt,61,7;🥛 Sour Cream,206,7;🧈 Butter,717,30;🧀 Cheddar Cheese,403,21;🧀 Mozzarella,280,10;🧀 Parmesan,431,60;🧀 Feta,264,14;🧀 Cream Cheese,342,10;🧀 Cottage Cheese,98,5;🧀 Processed Cheese,300,30;🥚 Eggs,143,21;🥛 Heavy Cream,340,7;🥛 Oat Milk,45,7;🧀 Ricotta,174,7;🧀 Gouda,356,30;🧀 Brie,334,14;🧀 Swiss Cheese,380,30;🧀 Brynza,260,14;🧀 Suluguni,290,14;🧀 Blue Cheese,353,30;🧀 Goat Cheese,364,14;🥛 Light Cream,205,7;🥛 Whipped Cream,257,5;🧈 Margarine,717,60;🥛 Ayran,40,7;🥛 Soy Milk,33,7;🥛 Almond Milk,24,7;🥛 Greek Yogurt,97,10;🥛 Skyr,63,10;🧈 Ghee,900,90;🥚 Quail Eggs,158,21;🧀 Mascarpone,429,10;🧀 Halloumi,321,30;🧀 Camembert,300,14;🥛 Coconut Milk,230,5;🥛 Lactose-Free Milk,45,7;🥛 Drinking Yogurt,72,10;🧀 Cheese Curds,98,5;🧀 Provolone,351,30;🧀 Parmigiano Slices,400,30;🥛 Condensed Cream,300,60
Meat|🍗 Chicken Breast,165,2;🍗 Chicken Thighs,209,2;🥩 Beef,250,3;🥩 Pork,242,3;🥩 Ground Beef,254,2;🍖 Lamb,294,3;🦃 Turkey,135,2;🌭 Sausages,301,7;🥓 Bacon,541,7;🍖 Ham,145,7;🥩 Boiled Sausage,257,7;🥓 Salo,770,60;🥩 Liver,135,2;🦆 Duck,337,3;🥩 Veal,172,3;🐇 Rabbit,173,3;🍗 Chicken Wings,203,2;🍗 Chicken Drumsticks,172,2;🍗 Whole Chicken,215,2;🍖 Pork Ribs,277,3;🥩 Steak,271,3;🍖 Meatballs,230,3;🥩 Minced Pork,263,2;🌭 Kielbasa,320,10;🍕 Salami,336,21;🍕 Pepperoni,504,30;🥓 Prosciutto,250,30;🥫 Liver Pate,300,7;🍗 Chicken Liver,119,2;🥩 Beef Tongue,224,3;🌭 Smoked Sausage,420,21;🌭 Hot Dog Sausages,260,10;🥓 Pork Belly,518,3;🦃 Turkey Breast,104,2;🍗 Chicken Hearts,153,2;🥩 Ground Turkey,148,2;🥩 Ground Chicken,143,2;🥩 Pork Neck,240,3;🥩 Beef Ribeye,291,3;🥩 Beef Brisket,250,3;🥓 Smoked Bacon,550,14;🥩 Doctor Sausage,257,7;🥩 Cervelat,460,30
Seafood|🐟 Salmon,208,2;🐟 Cod,82,2;🐟 Herring,158,5;🍤 Shrimp,99,2;🥫 Canned Tuna,116,365;🐟 Mackerel,205,3;🐟 Trout,148,2;🦀 Crab Sticks,95,14;🐟 Tilapia,96,2;🐟 Pollock,72,2;🐟 Sea Bass,97,2;🐟 Carp,127,2;🐟 Pike,84,2;🐟 Catfish,95,2;🐟 Halibut,111,2;🐟 Fresh Sardines,208,2;🐟 Smoked Salmon,172,10;🦑 Squid,92,2;🦪 Mussels,86,2;🦪 Oysters,68,2;🦀 Crab,97,2;🦞 Lobster,89,2;🐙 Octopus,82,2;🐚 Scallops,88,2;🥚 Red Caviar,260,14;🐟 Dried Fish,250,90;🐟 Salted Herring,217,14;🐟 Smoked Mackerel,221,10;🐟 Pangasius,90,2;🐟 Sturgeon,160,2;🍤 Tiger Prawns,106,2;🐟 Anchovies,131,30;🐟 Eel,184,2;🐟 Capelin,157,2
Grains|🍝 Pasta,350,365;🍚 Rice,360,365;🌾 Buckwheat,343,365;🥣 Oats,389,270;🌾 Millet,378,365;🌾 Semolina,360,365;🌾 Couscous,376,365;🌾 Pearl Barley,352,365;🌾 Flour,364,270;🥣 Cornflakes,357,180;🍜 Instant Noodles,450,270;🌾 Bulgur,342,365;🍚 Brown Rice,362,365;🍚 Basmati Rice,350,365;🍚 Jasmine Rice,355,365;🍚 Wild Rice,357,365;🌾 Quinoa,368,365;🌽 Corn Grits,337,365;🌽 Cornmeal,362,365;🌾 Wheat Groats,335,365;🥣 Muesli,363,180;🥣 Granola,471,180;🍝 Spaghetti,350,365;🍝 Penne,350,365;🍝 Fusilli,350,365;🍜 Egg Noodles,384,365;🍜 Rice Noodles,364,365;🍜 Vermicelli,350,365;🌾 Whole Wheat Flour,340,270;🌾 Rye Flour,325,270;🌽 Corn Starch,381,365;🥔 Potato Starch,333,365;🍞 Breadcrumbs,395,180;🍜 Udon Noodles,127,14;🍝 Lasagna Sheets,350,365;🌾 Spelt,338,365;🌾 Oat Bran,246,180;🍚 Sushi Rice,360,365;🥣 Rolled Oats,379,270;🍜 Soba Noodles,336,365;🌾 Hercules Flakes,352,270;🌾 Wheat Bran,216,180
Bakery|🍞 White Bread,265,4;🍞 Rye Bread,259,5;🥖 Baguette,270,2;🥐 Croissant,406,3;🫓 Lavash,275,5;🫓 Tortilla,237,10;🍞 Toast Bread,270,7;🥯 Bagel,250,3;🫓 Pita,275,4;🫓 Naan,310,4;🍞 Ciabatta,271,3;🥐 Brioche,375,3;🍩 Donut,452,2;🧁 Muffin,377,3;🥧 Apple Pie,237,3;🥨 Pretzel,380,5;🥞 Burger Bun,260,4;🍞 Sourdough Bread,260,4;🍞 Whole Grain Bread,247,5;🍞 Borodinsky Bread,208,5;🍞 Bread Loaf,266,4;🥖 Breadsticks,410,30;🍘 Crispbread,330,180;🍞 Cornbread,270,3;🍪 Gingerbread,350,30;🧇 Waffles,291,14;🥟 Puff Pastry,558,30;🍕 Pizza Dough,271,5;🥟 Phyllo Dough,300,14;🥐 Pain au Chocolat,414,2;🍞 Bun with Poppy Seeds,330,3;🍰 Pirozhki Dough,280,3
Nuts & Legumes|🥜 Peanuts,567,180;🌰 Almonds,579,180;🌰 Walnuts,654,180;🌰 Cashews,553,180;🫘 Beans,333,365;🫘 Lentils,353,365;🫘 Chickpeas,364,365;🥜 Peanut Butter,588,90;🌻 Sunflower Seeds,584,180;🥜 Pistachios,560,180;🌰 Hazelnuts,628,180;🌰 Pecans,691,180;🥜 Macadamia,718,180;🌰 Pine Nuts,673,180;🥜 Brazil Nuts,659,180;🎃 Pumpkin Seeds,559,180;🌱 Sesame Seeds,573,180;🌱 Chia Seeds,486,365;🌱 Flax Seeds,534,365;🫘 Kidney Beans,333,365;🫘 Black Beans,341,365;🫘 White Beans,333,365;🫘 Green Lentils,353,365;🫘 Split Peas,341,365;🫘 Soybeans,446,365;🫘 Mung Beans,347,365;🥜 Tahini,595,180;🥜 Almond Butter,614,90;🥥 Coconut Flakes,660,180;🌰 Chestnuts,213,30;🫘 Red Lentils,358,365;🥜 Salted Peanuts,585,180;🌰 Mixed Nuts,607,180;🫘 Broad Beans,341,365
Pantry|🫒 Olive Oil,884,365;🌻 Vegetable Oil,884,365;🥫 Ketchup,101,90;🥫 Mayonnaise,680,60;🥫 Tomato Paste,82,90;🥫 Mustard,66,90;🥫 Soy Sauce,53,180;🍯 Honey,304,365;🧂 Sugar,387,365;🥒 Pickles,11,30;🍓 Jam,250,365;🥬 Sauerkraut,19,30;🍶 Balsamic Vinegar,88,365;🍶 Vinegar,18,365;🍶 Apple Cider Vinegar,21,365;🫒 Sesame Oil,884,365;🥥 Coconut Oil,862,365;🌻 Sunflower Oil,884,365;🥫 BBQ Sauce,150,90;🌶️ Hot Sauce,30,180;🌶️ Sriracha,93,180;🌶️ Adjika,70,60;🍅 Tkemali,100,60;🌿 Pesto,420,14;🥫 Tartar Sauce,300,30;🥫 Salad Dressing,350,90;🍅 Tomato Sauce,35,90;🍝 Pasta Sauce,60,90;🥫 Worcestershire Sauce,78,365;🥫 Teriyaki Sauce,89,180;🌿 Wasabi,109,90;🍁 Maple Syrup,260,365;🧂 Brown Sugar,380,365;🧂 Powdered Sugar,389,365;🍫 Chocolate Spread,539,90;🥄 Baking Powder,53,365;🥄 Baking Soda,0,365;🍞 Yeast,325,180;🍬 Vanilla Sugar,390,365;🥄 Gelatin,335,365;☕ Ground Coffee,2,180;☕ Coffee Beans,2,180;☕ Instant Coffee,2,365;🍵 Black Tea,1,365;🍵 Green Tea,1,365;🍫 Cocoa Powder,228,365;🥫 Horseradish Sauce,70,60;🥫 Garlic Sauce,300,30;🥫 Fish Sauce,35,365;🥫 Oyster Sauce,51,180;🥫 Hoisin Sauce,220,180;🥫 Miso Paste,199,180;🥫 Cream Soup Base,350,180;🍯 Dulce de Leche,328,60;🥫 Apple Sauce,42,14;🍯 Fruit Syrup,260,180;🍯 Agave Syrup,310,365;🥫 Pickled Beets,43,60;🥫 Pickled Cabbage,33,30;🥫 Tomato Ketchup Spicy,110,90
Sweets|🍫 Chocolate,546,180;🍪 Cookies,480,90;🍰 Cake,350,3;🍬 Candy,390,180;🍦 Ice Cream,207,60;🥫 Condensed Milk,321,180;🥜 Halva,516,90;🍫 Dark Chocolate,546,180;🍫 Milk Chocolate,535,180;🍫 White Chocolate,539,180;🍫 Chocolate Bar,520,180;🍬 Caramel,382,180;🍭 Lollipop,380,365;🍬 Marshmallow,318,90;🍬 Zefir,326,30;🍬 Pastila,310,60;🐻 Gummy Bears,343,180;🍮 Jelly,60,14;🍫 Brownie,466,5;🍰 Cheesecake,321,4;🍰 Eclair,262,2;🍫 Chocolate Candies,500,180;🍧 Sorbet,131,60;🍦 Popsicle,100,60;🍪 Wafers,520,90;🍬 Marmalade,321,90;🍬 Turkish Delight,320,90;🥮 Baklava,430,10;🍰 Tiramisu,283,3;🍮 Pudding,115,5;🍮 Panna Cotta,200,4;🍰 Napoleon Cake,380,3;🍰 Honey Cake,370,4;🍪 Oatmeal Cookies,430,60;🍪 Shortbread,502,60;🍫 Truffles,510,30;🍨 Gelato,185,60;🍬 Toffee,436,180;🥜 Nut Brittle,480,90;🍬 Candied Fruit,322,180;🍬 Halva Sunflower,523,90;🍯 Chikki,480,90;🍰 Carrot Cake,415,4
Drinks|🧃 Orange Juice,45,7;🧃 Apple Juice,46,7;🥤 Kvass,27,7;🥤 Cola,42,180;💧 Mineral Water,0,365;💧 Sparkling Water,0,365;🍋 Lemonade,40,30;🍵 Iced Tea,30,30;⚡ Energy Drink,45,180;🥤 Lemon-Lime Soda,41,180;🍅 Tomato Juice,17,7;🍇 Grape Juice,60,7;🧃 Multivitamin Juice,48,7;🍍 Pineapple Juice,53,7;🥥 Coconut Water,19,30;🥤 Smoothie,60,2;🥤 Compote,45,5;🥤 Kissel,60,5;🥤 Mors,40,5;🍫 Hot Chocolate,89,1;🍺 Beer,43,180;🍷 Red Wine,85,365;🍷 White Wine,82,365;🥂 Champagne,76,365;🥃 Whiskey,250,365;🍸 Vodka,231,365;🍎 Cider,50,180;🥛 Milkshake,112,2;🍵 Matcha Latte,60,2;🥤 Fruit Juice Box,47,180;🍊 Fresh Orange Juice,45,2;🥤 Tarragon Soda,45,180;🥤 Birch Sap,24,5;🍷 Sangria,80,5;🧃 Peach Juice,50,7
Frozen|🥟 Pelmeni,250,180;🥟 Vareniki,200,180;🍕 Frozen Pizza,266,180;🥦 Frozen Vegetables,65,180;🍟 French Fries,312,180;🍓 Frozen Berries,50,180;🍗 Chicken Nuggets,296,180;🐟 Fish Fingers,230,180;🌽 Frozen Corn,81,180;🥬 Frozen Spinach,23,180;🫛 Frozen Peas,77,180;🐟 Frozen Fish Fillet,100,180;🍤 Frozen Shrimp,99,180;🍗 Frozen Chicken,165,180;🍖 Frozen Meatballs,230,180;🥩 Frozen Cutlets,240,180;🥞 Frozen Blini,200,180;🥟 Frozen Cheburek,300,180;🥐 Frozen Dough,270,180;🍄 Frozen Mushrooms,25,180;🥭 Frozen Mango,60,180;🧇 Frozen Waffles,290,180;🌯 Frozen Burrito,230,180;🍝 Frozen Lasagna,135,180;🥔 Frozen Hash Browns,150,180;🥟 Pierogi,190,180;🥟 Manti,210,180;🥟 Khinkali,220,180;🥟 Gyoza,200,180;🥟 Dumplings with Cherry,190,180;🥬 Frozen Broccoli,35,180;🥕 Frozen Carrot,35,180;🫑 Frozen Bell Pepper,30,180;🍓 Frozen Strawberries,32,180;🫐 Frozen Blueberries,57,180;🍨 Frozen Yogurt,127,60;🥟 Frozen Syrniki,220,180;🍕 Frozen Calzone,250,180
Spices|🧂 Salt,0,365;🌶️ Black Pepper,251,365;🌶️ Paprika,282,365;🌿 Cinnamon,247,365;🌿 Bay Leaf,313,365;🌿 Oregano,265,365;🌿 Cumin,375,365;🌿 Turmeric,312,365;🌿 Coriander,298,365;🌿 Vanilla,288,365;🌿 Nutmeg,525,365;🌿 Cloves,274,365;🍛 Curry Powder,325,365;🌶️ Chili Flakes,282,365;🌿 Dried Dill,253,365;🧄 Dried Garlic,331,365;🌿 Rosemary,131,14;🌿 Thyme,101,14;🌿 Saffron,310,365;🌿 Cardamom,311,365;🌿 Italian Herbs,265,365;🌿 Suneli Hops,250,365;🌿 Ginger Powder,335,365;🌿 Mustard Seeds,508,365;🌿 Star Anise,337,365
Canned|🌽 Canned Corn,76,365;🫛 Canned Peas,70,365;🫘 Canned Beans,90,365;🍅 Canned Tomatoes,21,365;🐟 Sprats in Oil,363,365;🥫 Beef Stew,250,365;🐟 Canned Sardines,208,365;🐟 Canned Salmon,140,365;🫒 Green Olives,115,365;🫒 Black Olives,115,365;🍄 Pickled Mushrooms,22,365;🍑 Canned Peaches,60,365;🍍 Canned Pineapple,60,365;🌶️ Pickled Peppers,20,365;🍄 Canned Mushrooms,22,365;🍆 Eggplant Caviar,90,365;🥫 Canned Chickpeas,119,365;🥫 Canned Lentils,116,365;🥫 Canned Coconut Milk,230,365;🥫 Condensed Soup,60,365;🐟 Pink Salmon Canned,136,365;🥫 Canned Pate,230,365;🥫 Canned Carrot,30,365;🍒 Canned Cherries,70,365;🥫 Canned Pumpkin,34,365
Ready Meals|🥙 Hummus,177,5;🍣 Sushi,150,1;🍣 Sushi Rolls,140,1;🌯 Shawarma,215,1;🍔 Burger,295,1;🌭 Hot Dog,290,1;🍕 Pizza Slice,266,2;🍗 Fried Chicken,246,2;🍖 Cutlets,230,3;🥟 Pirozhki,260,2;🥟 Cheburek,300,1;🥟 Samsa,280,1;🥞 Blini,230,3;🧀 Syrniki,220,3;🥔 Mashed Potatoes,88,3;🍚 Fried Rice,163,3;🥗 Pasta Salad,150,3;🥗 Caesar Salad,120,2;🥗 Greek Salad,105,2;🥗 Olivier Salad,198,3;🐟 Herring Under Fur Coat,180,3;🍲 Borscht Soup,49,4;🍲 Chicken Soup,40,4;🍲 Solyanka,75,4;🥣 Okroshka,60,2;🍜 Lagman,105,3;🍚 Plov Ready,190,3;🧀 Mac and Cheese,164,3;🍝 Lasagna,135,3;🧆 Falafel,333,3;🥬 Cabbage Rolls,120,3;🍃 Dolma,180,4;🥘 Goulash,150,3;🥘 Beef Stroganoff,170,3;🍳 Scrambled Eggs,148,1;🌮 Tacos,226,2;🥪 Sandwich,250,2;🥪 Club Sandwich,230,2;🍟 Fries Takeaway,312,1;🍲 Mushroom Soup,60,4
Snacks|🥔 Potato Chips,536,90;🍿 Popcorn,387,30;🌮 Nachos,489,90;🥨 Salted Crackers,430,180;🍫 Granola Bar,450,180;💪 Protein Bar,380,180;🍘 Rice Cakes,387,180;🥜 Trail Mix,462,180;🥩 Beef Jerky,410,180;🥨 Pretzel Sticks,380,180;🧀 Cheese Snacks,500,90;🥜 Roasted Chickpeas,380,90;🍫 Energy Bar,400,180;🥜 Peanut Bar,480,180;🍪 Cracker Sandwich,480,180;🧁 Sunflower Halva Bar,516,180;🫘 Dried Edamame,430,180;🍌 Banana Chips,519,90;🍎 Apple Chips,240,90;🥥 Coconut Chips,600,90
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
  'Vegetables': '🥕', 'Fruits': '🍎', 'Berries': '🍓', 'Dairy': '🧀', 'Meat': '🥩', 'Seafood': '🐟',
  'Grains': '🌾', 'Bakery': '🍞', 'Nuts & Legumes': '🥜', 'Pantry': '🫙', 'Sweets': '🍫', 'Drinks': '🥤', 'Frozen': '🧊', 'Spices': '🧂', 'Canned': '🥫', 'Ready Meals': '🍱', 'Snacks': '🍿',
};

// ───────────────────────── РЕЦЕПТЫ (граммы на всё блюдо) ─────────────────────────

final recipes = <Recipe>[
  Recipe('Classic Omelette', '🍳', '10 min', 1, [Ing('Eggs', 180), Ing('Milk', 60), Ing('Butter', 10)], [
    'Crack the eggs into a bowl, add the milk and a pinch of salt, whisk until smooth.',
    'Melt the butter in a non-stick pan over medium heat.',
    'Pour in the mixture and cook 2–3 minutes until the edges set.',
    'Fold in half, cook 1 more minute and serve hot.',
  ], 'salt'),
  Recipe('Creamy Cheese Pasta', '🍝', '20 min', 2, [Ing('Pasta', 200), Ing('Cheddar Cheese', 80), Ing('Butter', 20), Ing('Milk', 100)], [
    'Boil 2 liters of salted water and cook the pasta 9–10 minutes. Drain.',
    'Melt the butter in a pan on low heat, pour in the milk.',
    'Add grated cheese and stir 2–3 minutes until the sauce is smooth.',
    'Toss the pasta in the sauce and serve immediately.',
  ], 'salt, black pepper'),
  Recipe('Fresh Summer Salad', '🥗', '5 min', 2, [Ing('Tomato', 250), Ing('Cucumber', 200), Ing('Sour Cream', 60)], [
    'Wash the vegetables and cut into bite-size pieces.',
    'Mix in a bowl, add the sour cream, salt and pepper.',
    'Stir gently and serve right away.',
  ], 'salt, black pepper'),
  Recipe('Mashed Potatoes with Chicken', '🍽️', '35 min', 2, [Ing('Potato', 400), Ing('Chicken Breast', 300), Ing('Milk', 80), Ing('Butter', 20)], [
    'Peel and cut the potatoes, boil in salted water 15–20 minutes until soft.',
    'Slice the chicken, season and fry in a pan 6–8 minutes until golden.',
    'Drain the potatoes, mash with warm milk and butter until creamy.',
    'Serve the chicken on top of the mash.',
  ], 'salt, pepper'),
  Recipe('Fruit Yogurt Bowl', '🥣', '5 min', 2, [Ing('Apple', 150), Ing('Banana', 120), Ing('Orange', 130), Ing('Yogurt', 200)], [
    'Wash and core the apple, peel the banana and orange.',
    'Cut all fruit into small pieces.',
    'Divide into two bowls and pour the yogurt over.',
  ], 'optional: honey'),
  Recipe('Buckwheat with Chicken', '🍲', '35 min', 2, [Ing('Buckwheat', 200), Ing('Chicken Breast', 300), Ing('Onion', 100), Ing('Carrot', 100), Ing('Vegetable Oil', 15)], [
    'Rinse the buckwheat. Boil it in 400 ml of salted water, covered, for 15 minutes.',
    'Dice the onion and grate the carrot, fry them in oil for 5 minutes.',
    'Add the diced chicken and cook 8–10 minutes until done.',
    'Mix with the buckwheat and let it rest 5 minutes under a lid.',
  ], 'salt, pepper'),
  Recipe('Syrniki (Cottage Cheese Pancakes)', '🥞', '25 min', 3, [Ing('Cottage Cheese', 400), Ing('Eggs', 60), Ing('Flour', 60), Ing('Sugar', 30), Ing('Vegetable Oil', 30)], [
    'Mash the cottage cheese, mix with the egg, sugar and a pinch of salt.',
    'Add the flour and knead a soft dough.',
    'Shape into small patties and dip in a little flour.',
    'Fry in oil 3 minutes per side on medium heat. Serve with sour cream or jam.',
  ], 'salt'),
  Recipe('Classic Borscht', '🍅', '2 h', 4, [Ing('Beef', 400), Ing('Beetroot', 250), Ing('Cabbage', 250), Ing('Potato', 250), Ing('Carrot', 100), Ing('Onion', 100), Ing('Sour Cream', 80)], [
    'Cover the beef with 2.5 liters of cold water, bring to a boil and simmer 1 hour 15 minutes.',
    'Grate the beetroot and carrot, dice the onion, fry 10 minutes.',
    'Add the diced potatoes to the broth, cook 10 minutes.',
    'Add the shredded cabbage and the fried vegetables, cook 15 more minutes.',
    'Season, rest 10 minutes and serve with sour cream.',
  ], 'salt, bay leaf, pepper'),
  Recipe('Pelmeni with Sour Cream', '🥟', '15 min', 2, [Ing('Pelmeni', 500), Ing('Sour Cream', 60), Ing('Butter', 10)], [
    'Boil 2 liters of salted water with a bay leaf.',
    'Add the frozen pelmeni and stir. Cook 8–10 minutes after they float up.',
    'Drain, add the butter and serve with sour cream.',
  ], 'salt, bay leaf'),
  Recipe('Baked Salmon with Potatoes', '🐟', '40 min', 2, [Ing('Salmon', 300), Ing('Potato', 400), Ing('Lemon', 40), Ing('Olive Oil', 20)], [
    'Preheat the oven to 200 °C. Slice the potatoes thinly.',
    'Toss the potatoes with half of the oil and salt, bake 15 minutes.',
    'Place the salmon on top, drizzle with the remaining oil and lemon juice.',
    'Bake 15–18 more minutes until the fish flakes easily.',
  ], 'salt, pepper'),
  Recipe('Olivier Salad', '🥗', '45 min', 4, [Ing('Potato', 300), Ing('Carrot', 150), Ing('Eggs', 180), Ing('Boiled Sausage', 250), Ing('Pickles', 120), Ing('Green Peas', 150), Ing('Mayonnaise', 100)], [
    'Boil the potatoes and carrots in their skins 25 minutes, hard-boil the eggs 10 minutes.',
    'Cool everything, then peel and dice into equal small cubes.',
    'Dice the sausage and pickles, add the peas.',
    'Mix with mayonnaise, season, and chill for 30 minutes before serving.',
  ], 'salt, pepper'),
  Recipe('Beef Plov', '🍚', '1 h 30 min', 4, [Ing('Rice', 400), Ing('Beef', 400), Ing('Carrot', 300), Ing('Onion', 200), Ing('Garlic', 30), Ing('Vegetable Oil', 80)], [
    'Heat the oil in a heavy pot and fry the diced onion until golden.',
    'Add the beef cubes and brown for 10 minutes, then add the carrot strips and cook 10 more.',
    'Season, pour in 100 ml of water and simmer covered for 40 minutes.',
    'Spread the washed rice on top, add water 1.5 cm above the rice and push the garlic in.',
    'Cook on low heat covered for 20 minutes without stirring, then mix and serve.',
  ], 'salt, cumin, pepper'),
];

List<Recipe> rankRecipes(AppState s) {
  final names = s.pantryNames;
  final exp = s.expiringSoon.map((e) => e.food.name).toSet();
  int score(Recipe r) =>
      (r.missing(names).isEmpty ? 1000 : 0) +
      r.ingredients.where((i) => exp.contains(i.name)).length * 50 +
      r.ingredients.where((i) => names.contains(i.name)).length * 10 -
      r.missing(names).length;
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
  final chat = <ChatMessage>[
    ChatMessage('Hello! I am your AI Chef. Ask what to cook, what expires soon, or tell me what you do not like.', isUser: false)
  ];
  bool showTutorial = false;
  int wasted = 0, suggestIndex = 0, _id = 0;
  String name = 'Guest', email = '';
  bool isMan = true;
  double weight = 70, height = 175;
  int age = 22;

  int get targetCalories => ((10 * weight) + (6.25 * height) - (5 * age) + (isMan ? 5 : -161)).round();
  int kcalOn(int day) => log.where((e) => e.day == day).fold<int>(0, (s, e) => s + e.kcal);
  int get eatenCalories => kcalOn(dayShift);
  List<PantryItem> get expiringSoon => (pantry.where((p) => p.daysLeft <= 2).toList()..sort((a, b) => a.daysLeft.compareTo(b.daysLeft)));
  Set<String> get pantryNames => pantry.map((p) => p.food.name).toSet();

  final shopping = <String>[];
  final weights = <WeightEntry>[];
  final unlocked = <String>{};
  Medal? pendingBadge;
  bool celebrate = false;
  int consumed = 0, rescued = 0, cooked = 0, bought = 0, tipIndex = 0;
  double rescuedMoney = 0, wastedMoney = 0;
  DateTime streakStart = DateTime.now();

  static const _price = {'Meat': 4.5, 'Seafood': 5.0, 'Dairy': 2.0, 'Vegetables': 1.2, 'Fruits': 1.5, 'Berries': 3.0, 'Bakery': 1.5, 'Grains': 1.2, 'Nuts & Legumes': 3.0, 'Pantry': 2.5, 'Sweets': 2.5, 'Drinks': 1.8, 'Frozen': 3.5, 'Spices': 2.0, 'Canned': 1.8, 'Ready Meals': 4.0, 'Snacks': 2.5};
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
      }
    }
  }

  void clearBadge() {
    pendingBadge = null;
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

  void add(FoodItem f) {
    final n = now();
    pantry.add(PantryItem(_id++, f, n, n.add(Duration(days: f.shelf))));
    _check();
    notifyListeners();
  }

  void eat(PantryItem p, int grams) {
    _use(p);
    pantry.remove(p);
    log.add(LogEntry(_id++, p.food.emoji, '${p.food.name} · $grams g', (p.food.kcal * grams / 100).round()));
    _check();
    notifyListeners();
  }

  void throwAway(PantryItem p) {
    pantry.remove(p);
    wasted++;
    wastedMoney += price(p.food);
    streakStart = now();
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

class MockAiService implements AiService {
  List<FoodItem> _mentioned(String t) {
    final exact = foodDatabase.where((f) => t.contains(f.name.toLowerCase())).toList();
    if (exact.isNotEmpty) return exact.take(3).toList();
    return foodDatabase.where((f) => f.name.toLowerCase().split(' ').any((w) => w.length > 3 && t.contains(w))).take(3).toList();
  }

  @override
  Future<String> reply(String message, AppState s) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final t = message.toLowerCase();
    bool has(List<String> w) => w.any((x) => t.contains(x));
    final mentioned = _mentioned(t);
    final exp = s.expiringSoon;

    final dm = RegExp(r"(?:don't like|dont like|hate|allergic to|без|не люблю)\s+([^\s,.!?]+)").firstMatch(t);
    if (dm != null) {
      var w = dm.group(1)!;
      if (w.endsWith('oes')) {
        w = w.substring(0, w.length - 2);
      } else if (w.endsWith('s')) {
        w = w.substring(0, w.length - 1);
      }
      s.dislikes.add(w);
      return 'Got it, ${s.name}! I will avoid recipes with "$w" from now on. 👍';
    }
    if (RegExp(r'\b(hi|hello|hey)\b').hasMatch(t) || t.contains('привет')) {
      return 'Hi ${s.name}! You have ${s.pantry.length} products in the fridge. Ask me what to cook!';
    }
    if (has(['thank', 'спасибо'])) return 'Anytime! Happy cooking 🍳';
    if (has(['calorie', 'kcal', 'калор'])) {
      if (mentioned.isNotEmpty) return mentioned.map((f) => '${f.emoji} ${f.name}: ${f.kcal} kcal per 100 g').join('\n');
      final left = s.targetCalories - s.eatenCalories;
      return 'Today: ${s.eatenCalories} of ${s.targetCalories} kcal. ${left > 0 ? '$left kcal left.' : 'Goal reached!'}';
    }
    if (has(['do i have', 'have i', 'is there', 'есть ли']) && mentioned.isNotEmpty) {
      return mentioned.map((f) {
        final m = s.pantry.where((p) => p.food.name == f.name).toList();
        return m.isEmpty ? '${f.emoji} No ${f.name} in the fridge.' : '${f.emoji} ${f.name}: ${m.length} pcs, soonest ${m.map((p) => p.status).first}.';
      }).join('\n');
    }
    if (has(['expire', 'waste', 'spoil', 'soon', 'срок'])) {
      if (exp.isEmpty) return 'Nothing is expiring soon. Great job! 🎉';
      return 'Use these first: ${exp.map((e) => '${e.food.emoji} ${e.food.name} (${e.status})').join(', ')}.';
    }
    if (has(['cook', 'recipe', 'eat', 'dinner', 'lunch', 'breakfast', 'hungry', 'suggest', 'make', 'more', 'another', 'else', 'приготов'])) {
      if (s.pantry.isEmpty) return 'Your fridge is empty. Find products in the Search tab first!';
      var list = rankRecipes(s);
      if (mentioned.isNotEmpty) {
        list = list.where((r) => r.ingredients.any((i) => mentioned.any((m) => m.name == i.name))).toList();
      }
      if (list.isEmpty) return 'I found no recipes for that. Try other products!';
      s.suggestIndex = has(['more', 'another', 'else']) ? s.suggestIndex + 1 : 0;
      final r = list[s.suggestIndex % list.length];
      final miss = r.missing(s.pantryNames);
      return '${r.emoji} ${r.name} — ${r.kcal} kcal per serving, ${r.time}. ' +
          (miss.isEmpty ? 'You have everything! Open Recipes for grams and steps.' : 'You still need: ${miss.join(', ')}.') +
          ' Say "another" for more ideas.';
    }
    return 'I did not fully get "$message". Try: "what can I cook?", "what expires soon?", "calories in cheese", "do I have milk?" or "I don\'t like onion".';
  }
}

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
        child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(a), child: widget.child),
      );
}

Route<T> fadeSlide<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => FadeTransition(
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
final aiService = MockAiService();

class CalorieApp extends StatelessWidget {
  const CalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'serif',
        colorScheme: ColorScheme.fromSeed(seedColor: burgundy, primary: burgundy).copyWith(surface: cream, surfaceTint: Colors.transparent, secondaryContainer: const Color(0xFFE8DFC8), primaryContainer: const Color(0xFFE8DFC8)),
        scaffoldBackgroundColor: cream,
      ),
      home: RegisterScreen(state: appState, ai: aiService),
    );
  }
}

// ───────────────────────── НУТРИК (маскот) ─────────────────────────

enum NutrikMode { idle, run, eat, fall }

class NutrikPainter extends CustomPainter {
  final NutrikMode mode;
  final double t, blink, mouth, look, tilt, point;
  final bool hasPoint, stars;
  final String? snack;
  NutrikPainter(this.mode, this.t, this.blink, this.mouth, this.look, this.tilt, this.point, this.hasPoint, this.stars, this.snack);

  static const ink = Color(0xFF5A0016);
  static const bodyC = Color(0xFFFFC38A);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final run = mode == NutrikMode.run;
    final line = Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    Paint fill(Color c) => Paint()..color = c;
    final bounce = run ? -3 * sin(t * 4 * pi).abs() : 0.0;

    canvas.drawOval(Rect.fromCenter(center: const Offset(50, 93), width: 40 - bounce.abs() * 2, height: 6), fill(Colors.black12));
    canvas.translate(50, 90);
    canvas.rotate(tilt);
    canvas.translate(0, bounce);
    canvas.scale(1, 1 + 0.025 * sin(t * 2 * pi)); // дыхание
    canvas.translate(-50, -90);

    // ножки (маленькие!)
    void leg(double x, double sw) {
      final foot = Offset(x + (run ? sw * 5 : 0), 90 - (run ? max(0.0, sw) * 4 : 0));
      canvas.drawLine(Offset(x, 80), foot, line..strokeWidth = 5);
      canvas.drawOval(Rect.fromCenter(center: foot.translate(2, 0), width: 11, height: 6), fill(ink));
    }
    leg(41, sin(t * 4 * pi));
    leg(59, -sin(t * 4 * pi));
    line.strokeWidth = 2.4;

    // растрёпанные волосы-росток
    final w = sin(t * 2 * pi) * 1.2;
    final hair = Paint()..color = const Color(0xFF4C9A2A)..style = PaintingStyle.stroke..strokeWidth = 2.6..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(46, 30)..quadraticBezierTo(38 + w, 17, 43, 9), hair);
    canvas.drawPath(Path()..moveTo(50, 28)..quadraticBezierTo(53, 12 - w, 61, 13), hair);
    canvas.drawPath(Path()..moveTo(56, 30)..quadraticBezierTo(67, 22 + w, 72, 27), hair);
    canvas.save();
    canvas.translate(62, 13);
    canvas.rotate(-0.5);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 10, height: 5), fill(const Color(0xFF6DBE45)));
    canvas.restore();

    // тело
    final bodyRect = const Rect.fromLTRB(22, 28, 78, 88);
    canvas.drawOval(bodyRect, fill(bodyC));
    canvas.drawOval(const Rect.fromLTRB(36, 58, 64, 85), fill(Colors.white24));
    canvas.drawOval(bodyRect, line);
    // пятно кетчупа и крошки
    canvas.drawOval(Rect.fromCenter(center: const Offset(60, 76), width: 9, height: 5), fill(const Color(0xFFC62828)));
    canvas.drawCircle(const Offset(61, 80), 1.6, fill(const Color(0xFFC62828)));
    for (final o in const [Offset(45, 71), Offset(55, 72), Offset(33, 66), Offset(68, 68)]) {
      canvas.drawCircle(o, 1.1, fill(const Color(0xFF8D5524)));
    }
    canvas.drawCircle(const Offset(30, 58), 5, fill(const Color(0x88FF6F91)));
    canvas.drawCircle(const Offset(70, 58), 5, fill(const Color(0x88FF6F91)));

    // глаза
    for (final cx in const [39.0, 61.0]) {
      if (mode == NutrikMode.fall) {
        canvas.drawLine(Offset(cx - 4, 45), Offset(cx + 4, 53), line);
        canvas.drawLine(Offset(cx + 4, 45), Offset(cx - 4, 53), line);
      } else if (blink > 0.85) {
        canvas.drawLine(Offset(cx - 5, 49), Offset(cx + 5, 49), line);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, 49), width: 14, height: 14 * (1 - blink)), fill(Colors.white));
        canvas.drawOval(Rect.fromCenter(center: Offset(cx, 49), width: 14, height: 14 * (1 - blink)), line..strokeWidth = 1.4);
        if (blink < 0.5) {
          canvas.drawCircle(Offset(cx + look * 2.2, 49.5), 3.4, fill(Colors.black87));
          canvas.drawCircle(Offset(cx + look * 2.2 + 1, 48.3), 1, fill(Colors.white));
        }
        line.strokeWidth = 2.4;
      }
    }

    // рот
    if (mouth > 0.05) {
      canvas.drawOval(Rect.fromCenter(center: const Offset(50, 64), width: 9, height: 2 + 7 * mouth), fill(const Color(0xFF7A1020)));
      if (mouth > 0.4) canvas.drawOval(Rect.fromCenter(center: const Offset(50, 66.5), width: 5, height: 2.5), fill(const Color(0xFFFF8A9A)));
    } else {
      canvas.drawPath(Path()..moveTo(44, 62)..quadraticBezierTo(50, 68, 56, 62), line..strokeWidth = 1.8);
      line.strokeWidth = 2.4;
    }

    // руки
    void arm(Offset from, Offset to, {bool finger = false}) {
      canvas.drawLine(from, to, line..strokeWidth = 6.4);
      canvas.drawLine(from, to, fill(bodyC)..strokeWidth = 3.6..strokeCap = StrokeCap.round);
      canvas.drawCircle(to, 3.8, fill(bodyC));
      canvas.drawCircle(to, 3.8, line..strokeWidth = 1.8);
      if (finger) {
        final d = to - from;
        final u = d / d.distance;
        canvas.drawLine(to + u * 3, to + u * 8, line..strokeWidth = 2.6);
      }
      line.strokeWidth = 2.4;
    }
    const ls = Offset(24, 62), rs = Offset(76, 62);
    final sw = sin(t * 4 * pi);
    if (hasPoint) {
      final right = cos(point) >= 0;
      final s = right ? rs : ls;
      arm(s, s + Offset(cos(point), sin(point)) * 24, finger: true);
      arm(right ? ls : rs, right ? const Offset(15, 71) : const Offset(85, 71));
    } else if (mode == NutrikMode.eat) {
      arm(ls, const Offset(38, 66));
      arm(rs, const Offset(62, 66));
    } else if (run) {
      arm(ls, Offset(15, 66 + sw * 6));
      arm(rs, Offset(85, 66 - sw * 6));
    } else if (mode == NutrikMode.fall) {
      arm(ls, const Offset(12, 50));
      arm(rs, const Offset(88, 50));
    } else {
      arm(ls, Offset(14, 70 + sin(t * 2 * pi) * 1.5));
      arm(rs, Offset(86, 70 - sin(t * 2 * pi) * 1.5));
    }

    if (snack != null) {
      final tp = TextPainter(text: TextSpan(text: snack, style: const TextStyle(fontSize: 18)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(50 - tp.width / 2, 62 - tp.height / 2 + sin(t * 4 * pi) * 1.5));
    }
    if (stars) {
      for (var k = 0; k < 3; k++) {
        final a = t * 4 * pi + k * 2 * pi / 3;
        canvas.drawCircle(Offset(50 + 18 * cos(a), 14 + 5 * sin(a)), 2.6, fill(Colors.amber));
      }
    }
    canvas.restore();
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
  late final AnimationController cycle = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
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
      builder: (_, __) {
        final t = cycle.value;
        var m = 0.0;
        if (widget.mode == NutrikMode.eat) {
          m = sin(t * 2 * pi * 2).abs() * 0.7;
        } else if (widget.mode == NutrikMode.fall) {
          m = 0.6;
        } else if (widget.talking) {
          m = sin(t * 2 * pi * 3).abs();
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
  const NutrikSays({super.key, required this.text, this.point, this.size = 96});
  @override
  State<NutrikSays> createState() => _NutrikSaysState();
}

class _NutrikSaysState extends State<NutrikSays> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: Duration(milliseconds: 26 * widget.text.length))..forward();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) {
        final n = (c.value * widget.text.length).round();
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Nutrik(size: widget.size, talking: c.value < 1, point: widget.point),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: burgundy, width: 1.5),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: Stack(children: [
                Opacity(opacity: 0, child: Text(widget.text, style: const TextStyle(fontSize: 15))),
                Text(widget.text.substring(0, n), style: const TextStyle(fontSize: 15, color: Colors.black87)),
              ]),
            ),
          ),
        ]);
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
        builder: (_, __) => Stack(children: [
          for (var k = 0; k < items.length; k++)
            Align(
              alignment: Alignment((k / (items.length - 1)) * 2 - 1, 1 - ((c.value + k * 0.37) % 1) * 2.4),
              child: Transform.rotate(angle: sin((c.value + k) * 2 * pi) * 0.4, child: Opacity(opacity: 0.22, child: Text(items[k], style: const TextStyle(fontSize: 30)))),
            ),
        ]),
      );
}

/// Нутрик бегает по низу экрана: ест, спотыкается, падает.
class NutrikRoamer extends StatefulWidget {
  final bool paused;
  final double bottom;
  final AppState? state;
  const NutrikRoamer({super.key, required this.paused, this.bottom = 6, this.state});
  @override
  State<NutrikRoamer> createState() => _RoamerState();
}

class _RoamerState extends State<NutrikRoamer> with TickerProviderStateMixin {
  final _r = Random();
  late final AnimationController move = AnimationController(vsync: this);
  late final AnimationController fall = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700));
  late final AnimationController hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  double _from = 0.1, _to = 0.1;
  bool right = true;
  NutrikMode mode = NutrikMode.idle;
  String? snack, say;

  double get x => _from + (_to - _from) * move.value;

  @override
  void initState() {
    super.initState();
    _life();
  }

  @override
  void dispose() {
    move.dispose();
    fall.dispose();
    hop.dispose();
    super.dispose();
  }

  Future<void> _leg(double to) async {
    _from = x;
    _to = to;
    right = to >= _from;
    move.duration = Duration(milliseconds: (700 + (to - _from).abs() * 4200).round());
    setState(() => mode = NutrikMode.run);
    await move.forward(from: 0);
  }

  Future<void> _quip(String s, [int ms = 1800]) async {
    if (!mounted) return;
    setState(() => say = s);
    await Future.delayed(Duration(milliseconds: ms));
    if (mounted) setState(() => say = null);
  }

  Future<void> _life() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: 1500 + _r.nextInt(3500)));
      if (!mounted) return;
      if (widget.paused) continue;
      final r = _r.nextInt(10);
      if (r < 3) {
        await _leg(_r.nextDouble());
      } else if (r < 5) {
        final target = _r.nextDouble();
        await _leg((x + target) / 2);
        if (!mounted) return;
        setState(() => mode = NutrikMode.fall);
        _quip('Ouch! Tiny legs... 😵');
        await fall.forward(from: 0);
        await _leg(target);
      } else if (r < 8) {
        setState(() {
          mode = NutrikMode.eat;
          snack = ['🍎', '🧀', '🍞', '🥕', '🍪', '🍌'][_r.nextInt(6)];
        });
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        setState(() => snack = null);
        _quip('Yum! 😋', 1200);
      } else {
        _quip(_idleLine());
      }
      if (mounted) setState(() => mode = NutrikMode.idle);
    }
  }

  String _idleLine() {
    final exp = widget.state?.expiringSoon ?? [];
    if (exp.isNotEmpty && _r.nextBool()) {
      final p = exp.first;
      return p.daysLeft <= 0 ? '${p.food.name} is expired! 😱' : '${p.food.name} expires in ${p.daysLeft} d! Eat me... I mean it!';
    }
    return ['Crumbs everywhere!', 'Is it snack time?', 'Do not waste food!', 'Did you check the fridge?'][_r.nextInt(4)];
  }

  void _tap() {
    if (mode == NutrikMode.fall) return;
    hop.forward(from: 0);
    _quip(_r.nextBool() ? _idleLine() : ['Hehe! 😄', 'Hi there!', 'Tickles!'][_r.nextInt(3)], 2200);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(builder: (context, c) {
        const size = 64.0;
        return AnimatedBuilder(
          animation: Listenable.merge([move, fall, hop]),
          builder: (_, __) {
            final p = fall.value;
            final tilt = p == 0 ? 0.0 : p < .2 ? 1.4 * (p / .2) : p < .8 ? 1.4 : 1.4 * (1 - (p - .8) / .2);
            final left = x * (c.maxWidth - size);
            return Stack(clipBehavior: Clip.none, children: [
              if (say != null)
                Positioned(
                  left: (left - 30).clamp(0.0, max(0.0, c.maxWidth - 124)).toDouble(),
                  width: 124,
                  bottom: widget.bottom + size + 2,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: burgundy)),
                      child: Text(say!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black87)),
                    ),
                  ),
                ),
              Positioned(
                left: left,
                bottom: widget.bottom,
                child: GestureDetector(
                  onTap: _tap,
                  child: Transform.translate(
                    offset: Offset(0, -22 * sin(hop.value * pi)),
                    child: Nutrik(size: size, mode: mode, faceRight: right, tilt: tilt, stars: p > .2 && p < .8, snack: snack),
                  ),
                ),
              ),
            ]);
          },
        );
      }),
    );
  }
}

// ───────────────────────── ТУТОРИАЛ ─────────────────────────

class _Step {
  final int? tab;
  final String text;
  const _Step(this.tab, this.text);
}

const _steps = [
  _Step(null, 'Hi! I am Nutrik, your messy little kitchen buddy. Let me show you around — it takes 20 seconds!'),
  _Step(0, 'HOME: your daily calories and the products that will expire soon. Use those first!'),
  _Step(1, 'SEARCH: hundreds of products. Find one, tap + and it jumps into your fridge.'),
  _Step(2, 'FRIDGE: everything you own with freshness bars. Eat it or throw it away here.'),
  _Step(3, 'RECIPES: dishes made from YOUR fridge, with grams and steps. Tap one to cook!'),
  _Step(4, 'AI CHEF: ask what to cook. Tell me what you hate and I will remember it!'),
  _Step(null, 'That is all! On Home, tap the glass tiles: Impact, Shopping, Weight and Achievements. Now go save food! 🏃'),
];

class SpotPainter extends CustomPainter {
  final Rect hole;
  final double pulse;
  SpotPainter(this.hole, this.pulse);

  @override
  void paint(Canvas canvas, Size size) {
    final r = hole.width / 2;
    final path = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), Path()..addOval(hole));
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.72));
    if (r < 6) return;
    for (var k = 0; k < 3; k++) {
      final p = (pulse + k / 3) % 1;
      canvas.drawCircle(hole.center, r + p * 34, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = Colors.white.withValues(alpha: (1 - p) * 0.7));
    }
    canvas.drawCircle(hole.center, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant SpotPainter o) => true;
}

class TutorialOverlay extends StatefulWidget {
  final ValueChanged<int> onTab;
  final VoidCallback onDone;
  const TutorialOverlay({super.key, required this.onTab, required this.onDone});
  @override
  State<TutorialOverlay> createState() => _TutorialState();
}

class _TutorialState extends State<TutorialOverlay> with SingleTickerProviderStateMixin {
  int step = 0;
  late final AnimationController pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    pulse.dispose();
    super.dispose();
  }

  void _next() {
    if (step == _steps.length - 1) {
      widget.onDone();
      return;
    }
    setState(() => step++);
    widget.onTab(_steps[step].tab ?? (step == _steps.length - 1 ? 0 : 0));
  }

  @override
  Widget build(BuildContext context) {
    final st = _steps[step];
    final pad = MediaQuery.of(context).padding;
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth, h = c.maxHeight;
      final navH = 76 + pad.bottom;
      final spot = st.tab == null ? null : Offset(16 + (w - 32) / 5 * (st.tab! + 0.5), h - pad.bottom - 44);
      final hole = spot == null ? Rect.fromCircle(center: Offset(w / 2, h / 2), radius: 0.1) : Rect.fromCircle(center: spot, radius: 40);
      final last = step == _steps.length - 1;
      double? ang;
      if (spot != null) {
        final from = Offset(16 + 48, h - navH - 176);
        ang = atan2(spot.dy - from.dy, spot.dx - from.dx);
      }
      return Stack(children: [
        Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () {}, child: const SizedBox.expand())),
        Positioned.fill(
          child: IgnorePointer(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(end: hole),
              duration: const Duration(milliseconds: 550),
              curve: Curves.easeInOutCubic,
              builder: (_, r, __) => AnimatedBuilder(animation: pulse, builder: (_, __) => CustomPaint(painter: SpotPainter(r ?? hole, pulse.value))),
            ),
          ),
        ),
        if (spot != null) ...[
          Positioned.fromRect(rect: hole, child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _next)),
          Positioned(
            left: spot.dx - 22,
            top: hole.top - 54,
            child: AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Transform.translate(
                offset: Offset(0, 8 * sin(pulse.value * 2 * pi)),
                child: const Icon(Icons.arrow_downward_rounded, size: 44, color: Colors.white, shadows: [Shadow(color: Colors.white54, blurRadius: 14)]),
              ),
            ),
          ),
        ],
        Positioned(
          top: pad.top + 8,
          right: 12,
          child: TextButton.icon(
            style: TextButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
            onPressed: widget.onDone,
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Skip tutorial'),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: spot == null ? null : navH + 70,
          top: spot == null ? h * 0.3 : null,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            NutrikSays(key: ValueKey(step), text: st.text, point: ang, size: 96),
            const SizedBox(height: 10),
            Row(children: [
              for (var k = 0; k < _steps.length; k++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.only(right: 5),
                  width: k == step ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(color: k == step ? Colors.white : Colors.white38, borderRadius: BorderRadius.circular(4)),
                ),
              const Spacer(),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: burgundy), onPressed: _next, child: Text(last ? 'Let\'s go!' : 'Next →')),
            ]),
          ]),
        ),
      ]);
    });
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
  String say = 'Hi! I am Nutrik! I help people stop wasting food. Nice to meet you!';

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
    return (n == null || n < lo || n > hi) ? 'Enter $lo–$hi' : null;
  }

  void _go(int s, String text) => setState(() {
        step = s;
        say = text;
      });

  void _next() {
    if (step == 1) {
      if (_k1.currentState!.validate()) {
        _go(2, 'Now your body stats! I will use them to count your daily calorie goal. 🔢');
      } else {
        setState(() => say = 'Hmm, check the red fields for me please!');
      }
    } else if (step == 2) {
      if (_k2.currentState!.validate()) {
        _submit();
      } else {
        setState(() => say = 'Those numbers look odd... try again?');
      }
    }
  }

  Future<void> _submit({bool guest = false}) async {
    setState(() {
      busy = true;
      say = 'Yay! Preparing your fridge...';
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
    return Column(key: const ValueKey('intro'), children: [
      const Spacer(),
      const Appear(child: Text('NutriMate Pro', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: burgundy))),
      const SizedBox(height: 6),
      Text('Track calories. Cook from your fridge. Waste less.', style: TextStyle(color: Colors.grey.shade700)),
      const SizedBox(height: 24),
      SizedBox(
        height: 130,
        child: arrived
            ? NutrikSays(key: ValueKey(say), text: say, size: 110)
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: -140, end: 0),
                duration: const Duration(milliseconds: 2400),
                curve: Curves.easeOut,
                onEnd: () => setState(() => arrived = true),
                builder: (_, v, __) => Stack(clipBehavior: Clip.none, children: [
                  Positioned(left: v, bottom: 0, child: const Nutrik(size: 110, mode: NutrikMode.run)),
                ]),
              ),
      ),
      const SizedBox(height: 20),
      AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: arrived ? 1 : 0,
        child: Column(children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy),
              onPressed: arrived ? () => _go(1, 'Let us make your account! Who are you? (It is a test account, I will not tell anyone 🤫)') : null,
              child: const Text('Create account', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          TextButton(onPressed: arrived ? () => _submit(guest: true) : null, child: const Text('Continue as guest', style: TextStyle(color: burgundy))),
        ]),
      ),
      const Spacer(),
    ]);
  }

  Widget _form() {
    return SingleChildScrollView(
      key: ValueKey('form$step'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NutrikSays(key: ValueKey(say), text: say, point: pi / 2, size: 96),
        const SizedBox(height: 16),
        if (step == 1)
          Form(
            key: _k1,
            child: Column(children: [
              Appear(index: 0, child: TextFormField(controller: _name, decoration: _dec('Name', Icons.person_outline), validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your name' : null)),
              const SizedBox(height: 12),
              Appear(index: 1, child: TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _dec('Email', Icons.mail_outline), validator: (v) => (v ?? '').contains('@') ? null : 'Enter a valid email')),
              const SizedBox(height: 12),
              Appear(
                index: 2,
                child: TextFormField(
                  controller: _pass,
                  obscureText: hide,
                  decoration: _dec('Password', Icons.lock_outline, suffix: IconButton(icon: Icon(hide ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => hide = !hide))),
                  validator: (v) => (v ?? '').length < 4 ? 'At least 4 characters' : null,
                ),
              ),
            ]),
          )
        else
          Form(
            key: _k2,
            child: Column(children: [
              Appear(index: 0, child: Row(children: [_gender('Man', true), const SizedBox(width: 12), _gender('Woman', false)])),
              const SizedBox(height: 12),
              Appear(
                index: 1,
                child: Row(children: [
                  Expanded(child: TextFormField(controller: _age, keyboardType: TextInputType.number, decoration: _dec('Age', Icons.cake_outlined), validator: (v) => _num(v, 14, 90))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _weight, keyboardType: TextInputType.number, decoration: _dec('kg', Icons.monitor_weight_outlined), validator: (v) => _num(v, 40, 150))),
                  const SizedBox(width: 8),
                  Expanded(child: TextFormField(controller: _height, keyboardType: TextInputType.number, decoration: _dec('cm', Icons.height), validator: (v) => _num(v, 120, 220))),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 24),
        Row(children: [
          if (!busy)
            TextButton(onPressed: () => _go(step - 1, step == 1 ? 'Back so soon? OK!' : 'Let us fix your account info!'), child: const Text('Back', style: TextStyle(color: burgundy))),
          const Spacer(),
          SizedBox(
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy, padding: const EdgeInsets.symmetric(horizontal: 28)),
              onPressed: busy ? null : _next,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: busy
                    ? const SizedBox(key: ValueKey('b'), width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(step == 1 ? 'Next →' : 'Finish', key: ValueKey('t$step'), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: IgnorePointer(child: FloatingFood())),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, a) => FadeTransition(opacity: a, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero).animate(a), child: child)),
                  child: step == 0 ? _intro() : _form(),
                ),
              ),
            ),
          ),
        ),
      ]),
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
      canvas.drawRRect(rr.shift(const Offset(0, 8)), Paint()..color = Colors.black.withValues(alpha: 0.16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      canvas.restore();
    }
    final sh = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors).createShader(Offset.zero & size);
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..shader = sh..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    canvas.drawRRect(rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..shader = sh);
    canvas.drawRRect(rr.deflate(3), Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = Colors.white.withValues(alpha: 0.22));
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
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TweenAnimationBuilder<double>(
        tween: Tween(end: on ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: 1 + 0.2 * v, child: child),
        child: Badge(isLabelVisible: i == 2 && widget.fridge > 0, label: Text('${widget.fridge}'), child: Icon(icons[i], color: col, size: 25)),
      ),
      Text(labels[i], style: TextStyle(fontSize: 10, color: col, fontWeight: on ? FontWeight.bold : FontWeight.w500)),
    ]);
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
          child: LayoutBuilder(builder: (context, cs) {
            final seg = cs.maxWidth / 5;
            return CustomPaint(
              foregroundPainter: RimPainter(32, [Colors.white.withValues(alpha: 0.95), Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.6)]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.03)])),
                    child: AnimatedBuilder(
                      animation: c,
                      builder: (_, __) {
                        final sq = sin(c.value * pi).abs();
                        final dist = min((to - from).abs(), 3.0);
                        final w = (seg - 8) * (1 + 0.2 * sq * dist);
                        final h = 54 * (1 - 0.12 * sq);
                        final left = _pos * seg + (seg - w) / 2;
                        return Stack(children: [
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
                                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.5], colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Row(children: [
                            for (var i = 0; i < 5; i++) Expanded(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => widget.onTap(i), child: _item(i))),
                          ]),
                        ]);
                      },
                    ),
                  ),
                ),
              ),
            );
          }),
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

class _MainScreenState extends State<MainScreen> {
  int i = 0;

  Widget _page(int i) {
    final s = widget.state;
    switch (i) {
      case 0:
        return HomePage(state: s, ai: widget.ai);
      case 1:
        return SearchPage(state: s);
      case 2:
        return PantryPage(state: s, onSearch: () => setState(() => this.i = 1));
      case 3:
        return RecipesPage(state: s);
      default:
        return ChatPage(state: s, ai: widget.ai);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Stack(children: [
        Scaffold(
          extendBody: true,
          body: Stack(children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(a), child: child),
                ),
                child: KeyedSubtree(key: ValueKey(i), child: _page(i)),
              ),
            ),
            NutrikRoamer(paused: s.showTutorial, bottom: 76 + MediaQuery.of(context).padding.bottom + (i == 4 ? 130 : 6), state: s),
          ]),
          bottomNavigationBar: GlassNav(index: i, fridge: s.pantry.length, onTap: (v) => setState(() => i = v)),
        ),
        if (s.celebrate) Positioned.fill(child: IgnorePointer(child: Confetti(onDone: s.endCelebrate))),
        if (s.pendingBadge != null)
          Positioned.fill(child: IgnorePointer(child: Material(type: MaterialType.transparency, child: BadgePopup(key: ValueKey(s.pendingBadge!.id), m: s.pendingBadge!, onDone: s.clearBadge)))),
        if (s.showTutorial)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: TutorialOverlay(onTab: (v) => setState(() => i = v), onDone: s.endTutorial),
            ),
          ),
      ]),
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
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [(tint ?? Colors.white).withValues(alpha: 0.7), (tint ?? Colors.white).withValues(alpha: 0.28)],
        ),
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
          builder: (_, __) => CustomPaint(painter: BlobPainter(c.value * 2 * pi), size: Size.infinite),
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
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, a, __, child) => ClipPath(clipper: _CircleClip(Curves.easeInOutCubic.transform(a.value), origin), child: child),
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
        appBar: AppBar(title: Text(title, style: headStyle), backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0),
        body: Stack(children: [const Positioned.fill(child: LiquidBg()), SafeArea(child: child)]),
      );
}

// ───────────────────────── КОНФЕТТИ И НАГРАДЫ ─────────────────────────

class _Piece {
  final double x, delay, sway, rot, size;
  final int color;
  _Piece(Random r)
      : x = r.nextDouble(),
        delay = r.nextDouble() * 0.4,
        sway = r.nextDouble() * 2 - 1,
        rot = r.nextDouble() * 6,
        size = 6 + r.nextDouble() * 6,
        color = r.nextInt(6);
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
  Widget build(BuildContext context) => AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(painter: ConfettiPainter(ps, c.value), size: Size.infinite));
}

class Medal {
  final String id, emoji, title, desc;
  const Medal(this.id, this.emoji, this.title, this.desc);
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
            builder: (_, v, child) => Transform.translate(offset: Offset(0, -130 * (1 - v)), child: Opacity(opacity: v.clamp(0.0, 1.0).toDouble(), child: child)),
            child: Glass(
              tint: const Color(0xFFFFF3C4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(widget.m.emoji, style: const TextStyle(fontSize: 38)),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Achievement unlocked!', style: TextStyle(fontSize: 12, color: burgundy)),
                  Text(widget.m.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                ]),
              ]),
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
    canvas.drawArc(r, 0, 2 * pi, false, Paint()..style = PaintingStyle.stroke..strokeWidth = w..color = Colors.black12);
    canvas.drawArc(r, -pi / 2, 2 * pi * p, false, Paint()..style = PaintingStyle.stroke..strokeWidth = w..strokeCap = StrokeCap.round..color = color);
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            TweenAnimationBuilder<double>(
              tween: Tween(end: v),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, x, __) => Text('$prefix${x.toStringAsFixed(dec)}$suffix', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: burgundy)),
            ),
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      title: 'Eco Impact',
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final s = state;
          final score = s.ecoScore;
          final col = score >= 70 ? Colors.green.shade700 : score >= 40 ? Colors.orange.shade800 : Colors.red.shade700;
          final mood = score >= 80
              ? 'You are a food-saving superstar! Keep it up! ⭐'
              : score >= 50
                  ? 'Not bad! Use the expiring products first.'
                  : 'Oh no... let us waste less. Check Recipes for ideas!';
          return ListView(padding: const EdgeInsets.all(16), children: [
            Appear(
              child: Glass(
                padding: const EdgeInsets.all(20),
                child: Row(children: [
                  SizedBox(
                    width: 112,
                    height: 112,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: score / 100),
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => CustomPaint(painter: RingPainter(v, col), child: Center(child: Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)))),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Eco score', style: titleStyle),
                      const SizedBox(height: 4),
                      Text(s.consumed + s.wasted == 0 ? 'Eat and cook your food to build your score!' : '${s.consumed} products used, ${s.wasted} thrown away.', style: const TextStyle(color: Colors.black54)),
                    ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Appear(index: 1, child: NutrikSays(key: ValueKey(mood), text: mood, size: 84)),
            const SizedBox(height: 12),
            Appear(index: 2, child: Row(children: [_tile('🦸', 'Rescued items', s.rescued.toDouble(), 0), const SizedBox(width: 12), _tile('⚖️', 'Food saved', s.rescued * 0.3, 1, suffix: ' kg')])),
            const SizedBox(height: 12),
            Appear(index: 3, child: Row(children: [_tile('💰', 'Money saved', s.rescuedMoney, 2, prefix: '\$'), const SizedBox(width: 12), _tile('🌍', 'CO₂ avoided', s.co2, 1, suffix: ' kg')])),
            const SizedBox(height: 12),
            Appear(
              index: 4,
              child: Glass(
                child: Row(children: [
                  const Text('🔥', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${s.streakDays} days without waste', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            Appear(
              index: 5,
              child: Glass(
                tint: const Color(0xFFFFD6D6),
                child: Row(children: [
                  const Text('🗑️', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Wasted: ${s.wasted} items · about \$${s.wastedMoney.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Estimates: ~300 g per product, average prices, ~2.5 kg CO₂ per kg of food.', style: TextStyle(color: Colors.black45, fontSize: 11)),
          ]);
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
      final fill = Path.from(part)..lineTo(end.dx, 20 + h)..lineTo(pt(0).dx, 20 + h)..close();
      canvas.drawPath(
        fill,
        Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [burgundy.withValues(alpha: 0.3), burgundy.withValues(alpha: 0)]).createShader(Offset.zero & size),
      );
      canvas.drawPath(part, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round..color = burgundy);
    }
    for (var i = 0; i < e.length; i++) {
      if (e.length > 1 && p < i / (e.length - 1)) continue;
      canvas.drawCircle(pt(i), 6, Paint()..color = Colors.white);
      canvas.drawCircle(pt(i), 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5..color = burgundy);
      if (i == 0 || i == e.length - 1) {
        final tp = TextPainter(text: TextSpan(text: e[i].kg.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
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
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Log your weight', style: titleStyle),
          Slider(value: v, min: 30, max: 200, divisions: 1700, label: '${v.toStringAsFixed(1)} kg', onChanged: (x) => set(() => v = x)),
          Text('${v.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy),
              onPressed: () {
                s.addWeight(double.parse(v.toStringAsFixed(1)));
                Navigator.pop(c);
              },
              child: const Text('Save'),
            ),
          ),
        ]),
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
          final cat = bmi < 18.5 ? 'Underweight' : bmi < 25 ? 'Normal' : bmi < 30 ? 'Overweight' : 'Obese';
          final list = s.weights.reversed.toList();
          return ListView(padding: const EdgeInsets.all(16), children: [
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
                    builder: (_, v, __) => CustomPaint(painter: WeightPainter(s.weights, v), size: Size.infinite),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Appear(
              index: 1,
              child: Row(children: [
                Expanded(child: Glass(child: Column(children: [Text('${s.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy)), const Text('Current', style: TextStyle(color: Colors.black54, fontSize: 12))]))),
                const SizedBox(width: 10),
                Expanded(child: Glass(child: Column(children: [Text(bmi.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy)), Text('BMI · $cat', style: const TextStyle(color: Colors.black54, fontSize: 12))]))),
                const SizedBox(width: 10),
                Expanded(child: Glass(child: Column(children: [Text('${s.targetCalories}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: burgundy)), const Text('kcal goal', style: TextStyle(color: Colors.black54, fontSize: 12))]))),
              ]),
            ),
            const SizedBox(height: 12),
            Appear(
              index: 2,
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: burgundy), onPressed: () => weightSheet(context, s), icon: const Icon(Icons.add), label: const Text('Log weight')),
              ),
            ),
            const SizedBox(height: 8),
            const Text('BMI is only a rough guide.', style: TextStyle(color: Colors.black45, fontSize: 11)),
            const SizedBox(height: 8),
            for (var i = 0; i < list.length; i++)
              Appear(
                key: ValueKey('w${list[i].date.microsecondsSinceEpoch}$i'),
                index: i + 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Text(_d(list[i].date), style: const TextStyle(color: Colors.black54)),
                      const Spacer(),
                      if (i < list.length - 1)
                        Text(
                          '${list[i].kg - list[i + 1].kg >= 0 ? '+' : ''}${(list[i].kg - list[i + 1].kg).toStringAsFixed(1)}  ',
                          style: TextStyle(color: list[i].kg - list[i + 1].kg > 0 ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 12),
                        ),
                      Text('${list[i].kg.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ),
          ]);
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
        builder: (context, _) => ListView(padding: const EdgeInsets.all(16), children: [
          Autocomplete<FoodItem>(
            displayStringForOption: (f) => f.name,
            optionsBuilder: (v) {
              final q = v.text.trim().toLowerCase();
              if (q.isEmpty) return const Iterable<FoodItem>.empty();
              return foodDatabase.where((f) => f.name.toLowerCase().contains(q)).take(8);
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
                  hintText: 'Add to shopping list...',
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
            const Padding(padding: EdgeInsets.only(top: 12), child: NutrikSays(text: 'Your list is empty! Add things here, or open a recipe and tap "Add missing to shopping list".', size: 90)),
          for (var i = 0; i < s.shopping.length; i++)
            Appear(
              key: ValueKey('sh${s.shopping[i]}'),
              index: i,
              child: Dismissible(
                key: ValueKey('shd${s.shopping[i]}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => s.removeShopping(s.shopping[i]),
                background: Container(color: Colors.red.shade900, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(foodByName[s.shopping[i]]?.emoji ?? '🛒', style: const TextStyle(fontSize: 26)),
                      title: Text(s.shopping[i], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Tap ✓ when bought — it goes to your fridge'),
                      trailing: IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: burgundy, size: 30),
                        onPressed: () {
                          final n = s.shopping[i];
                          s.buy(n);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: burgundy, duration: const Duration(milliseconds: 1400), content: Text('$n is in your fridge 🧊')));
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ]),
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
          return ListView(padding: const EdgeInsets.all(16), children: [
            Appear(
              child: Glass(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$n / ${medals.length} unlocked', style: titleStyle),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: n / medals.length),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 10, color: burgundy, backgroundColor: Colors.black12),
                    ),
                  ),
                ]),
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
                    child: Builder(builder: (context) {
                      final m = medals[i];
                      final on = state.unlocked.contains(m.id);
                      return Glass(
                        tint: on ? const Color(0xFFFFF3C4) : null,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          on
                              ? TweenAnimationBuilder<double>(tween: Tween(begin: 0.4, end: 1), duration: const Duration(milliseconds: 800), curve: Curves.elasticOut, builder: (_, v, child) => Transform.scale(scale: v, child: child), child: Text(m.emoji, style: const TextStyle(fontSize: 40)))
                              : Stack(alignment: Alignment.center, children: [
                                  ColorFiltered(
                                    colorFilter: const ColorFilter.matrix(<double>[0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0.21, 0.72, 0.07, 0, 0, 0, 0, 0, 1, 0]),
                                    child: Opacity(opacity: 0.35, child: Text(m.emoji, style: const TextStyle(fontSize: 40))),
                                  ),
                                  const Icon(Icons.lock, size: 18, color: Colors.black45),
                                ]),
                          const SizedBox(height: 8),
                          Text(m.title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text(m.desc, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                        ]),
                      );
                    }),
                  ),
              ],
            ),
          ]);
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
              child: Column(children: [
                Badge(isLabelVisible: widget.badge > 0, label: Text('${widget.badge}'), child: Text(widget.emoji, style: const TextStyle(fontSize: 24))),
                const SizedBox(height: 4),
                Text(widget.label, style: const TextStyle(fontSize: 11, color: Colors.black87)),
              ]),
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
    canvas.drawCircle(c, r - 3, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawArc(Rect.fromCircle(center: c, radius: r - 12), pi * 1.05, pi * 0.45, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(covariant WavePainter o) => true;
}

/// Круглый «жидкий» индикатор калорий: уровень жидкости = съеденное от цели.
class LiquidGauge extends StatefulWidget {
  final double level, size;
  final int kcal;
  const LiquidGauge({super.key, required this.level, required this.kcal, this.size = 150});
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
      child: Stack(alignment: Alignment.center, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: widget.level),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => AnimatedBuilder(animation: c, builder: (_, __) => CustomPaint(size: Size.square(widget.size), painter: WavePainter(v, c.value))),
        ),
        Column(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(end: widget.kcal),
            duration: const Duration(milliseconds: 1200),
            builder: (_, v, __) => Text('$v', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 8)])),
          ),
          const Text('kcal eaten', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
      ]),
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
  Widget build(BuildContext context) => ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1.2).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)), child: widget.child);
}

class HomePage extends StatefulWidget {
  final AppState state;
  final AiService ai;
  const HomePage({super.key, required this.state, required this.ai});
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
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white24)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 12)),
      );

  Widget _hero() {
    final total = state.eatenCalories, goal = state.targetCalories, left = goal - total;
    final level = (total / goal).clamp(0.0, 1.0).toDouble();
    final line = total == 0
        ? '"Feed me data! Log what you eat."'
        : total < goal * 0.5
            ? '"Nice start! Keep going."'
            : total <= goal
                ? '"Almost there! Do not forget water."'
                : '"Mmm... that is over the goal 😅"';
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        margin: const EdgeInsets.only(top: 60),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6A041C), Color(0xFF9B1B33)]),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.2),
          boxShadow: [BoxShadow(color: burgundy.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14))],
        ),
        child: Row(children: [
          LiquidGauge(level: level, kcal: total),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TODAY', style: TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 2)),
              const SizedBox(height: 4),
              Text(left >= 0 ? '$left kcal left' : '${-left} kcal over', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
              Text('goal $goal kcal', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [_pill('🥗 ${state.log.where((e) => e.day == dayShift).length} meals'), _pill('🦸 ${state.rescued} rescued')]),
              const SizedBox(height: 10),
              Text(line, style: const TextStyle(color: Colors.white70, fontSize: 12, fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      ),
      Positioned(top: -17, right: 14, child: Nutrik(size: 92, mode: total > goal ? NutrikMode.eat : NutrikMode.idle, snack: total > goal ? '🍰' : null)),
    ]);
  }

  Widget _week() {
    final goal = state.targetCalories;
    final vals = [for (var k = 0; k < 7; k++) state.kcalOn(dayShift - 6 + k)];
    final mx = max(goal * 1.15, vals.reduce(max).toDouble());
    final nz = vals.where((v) => v > 0).toList();
    final avg = nz.isEmpty ? 0 : (nz.reduce((a, b) => a + b) / nz.length).round();
    return Glass(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('This week', style: headStyle), const Spacer(), Text('avg $avg kcal', style: const TextStyle(color: Colors.black54, fontSize: 12))]),
        const SizedBox(height: 12),
        SizedBox(
          height: 124,
          child: Stack(children: [
            Positioned(left: 0, right: 0, bottom: 22 + 94 * (goal / mx), child: Container(height: 1, color: burgundy.withValues(alpha: 0.3))),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var k = 0; k < 7; k++)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: vals[k] / mx),
                      duration: Duration(milliseconds: 700 + k * 90),
                      curve: Curves.easeOutBack,
                      builder: (_, v, __) => Container(
                        width: 18,
                        height: max(5.0, 94 * v),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: k == 6 ? const [Color(0xFFD9A441), burgundy] : [burgundy.withValues(alpha: 0.55), burgundy.withValues(alpha: 0.2)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('MTWTFSS'[now().subtract(Duration(days: 6 - k)).weekday - 1], style: TextStyle(fontSize: 11, fontWeight: k == 6 ? FontWeight.bold : FontWeight.normal, color: k == 6 ? burgundy : Colors.black54)),
                  ]),
                ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _health() {
    final p = state.pantry;
    final bad = p.where((e) => e.daysLeft <= 0).length, soon = p.where((e) => e.daysLeft > 0 && e.daysLeft <= 2).length, ok = p.length - bad - soon;
    if (p.isEmpty) return const Text('Your fridge is empty. Stock it in Search!', style: TextStyle(color: Colors.black54));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: FractionallySizedBox(
              widthFactor: v,
              child: SizedBox(
                height: 10,
                child: Row(children: [
                  if (ok > 0) Expanded(flex: ok, child: Container(color: Colors.green.shade600)),
                  if (soon > 0) Expanded(flex: soon, child: Container(color: Colors.orange.shade700)),
                  if (bad > 0) Expanded(flex: bad, child: Container(color: Colors.red.shade700)),
                ]),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      Text('$ok fresh · $soon use soon · $bad expired', style: const TextStyle(color: Colors.black54, fontSize: 12)),
    ]);
  }

  Widget _expiryCard(PantryItem it, int i) => Appear(
        index: i,
        child: SizedBox(
          width: 138,
          child: Glass(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Stack(alignment: Alignment.center, children: [
                SizedBox(width: 56, height: 56, child: TweenAnimationBuilder<double>(tween: Tween(end: it.fresh), duration: const Duration(milliseconds: 900), builder: (_, v, __) => CustomPaint(painter: RingPainter(v, it.color, 5)))),
                Text(it.food.emoji, style: const TextStyle(fontSize: 26)),
              ]),
              const SizedBox(height: 8),
              Text(it.food.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(it.status, style: TextStyle(color: it.color, fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Row(children: [
                IconButton(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 32), icon: const Icon(Icons.restaurant, color: burgundy, size: 20), onPressed: () => eatSheet(context, state, it)),
                IconButton(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 40, minHeight: 32), icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => state.throwAway(it)),
              ]),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final hr = now().hour;
    final greet = hr < 5 ? 'Good night' : hr < 12 ? 'Good morning' : hr < 18 ? 'Good afternoon' : 'Good evening';
    final exp = state.expiringSoon;
    final today = state.log.where((e) => e.day == dayShift).toList();
    return Stack(children: [
      const Positioned.fill(child: LiquidBg()),
      SafeArea(
        child: ListView(
          controller: sc,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          children: [
            Appear(
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(greet, style: const TextStyle(color: Colors.black54)),
                    Text('${state.name} 👋', maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                  ]),
                ),
                Glass(radius: 20, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), child: Row(children: [Pulse(child: const Text('🔥', style: TextStyle(fontSize: 18))), const SizedBox(width: 4), Text('${state.streakDays}d', style: const TextStyle(fontWeight: FontWeight.bold))])),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.push(context, fadeSlide(ProfilePage(state: state, ai: widget.ai))),
                  child: CircleAvatar(backgroundColor: burgundy, child: Text(state.name.isEmpty ? '?' : state.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                ),
              ]),
            ),
            Appear(
              index: 1,
              child: AnimatedBuilder(
                animation: sc,
                builder: (_, child) {
                  final o = sc.hasClients ? sc.offset.clamp(0.0, 400.0).toDouble() : 0.0;
                  return Transform.translate(offset: Offset(0, o * 0.22), child: Transform.scale(scale: 1 - o / 1800, child: child));
                },
                child: _hero(),
              ),
            ),
            const SizedBox(height: 14),
            Appear(index: 2, child: _week()),
            const SizedBox(height: 12),
            Appear(
              index: 3,
              child: Row(children: [
                QuickTile(emoji: '🌍', label: 'Impact', onTap: (c) => Navigator.push(c, circleReveal(ImpactPage(state: state), centerOf(c)))),
                QuickTile(emoji: '🛒', label: 'Shopping', badge: state.shopping.length, onTap: (c) => Navigator.push(c, circleReveal(ShoppingPage(state: state), centerOf(c)))),
                QuickTile(emoji: '⚖️', label: 'Weight', onTap: (c) => Navigator.push(c, circleReveal(WeightPage(state: state), centerOf(c)))),
                QuickTile(emoji: '🏆', label: '${state.unlocked.length}/${medals.length}', onTap: (c) => Navigator.push(c, circleReveal(MedalsPage(state: state), centerOf(c)))),
              ]),
            ),
            const SizedBox(height: 12),
            Appear(
              index: 4,
              child: GestureDetector(
                onTap: state.nextTip,
                child: Glass(
                  child: Row(children: [
                    const Text('💡', style: TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 400), child: Text(tips[state.tipIndex % tips.length], key: ValueKey(state.tipIndex), style: const TextStyle(color: Colors.black87)))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Appear(index: 5, child: Row(children: [const Text('Fridge health', style: headStyle), const Spacer(), Text('${state.pantry.length} items', style: const TextStyle(color: Colors.black54, fontSize: 12))])),
            const SizedBox(height: 8),
            Appear(index: 5, child: _health()),
            const SizedBox(height: 14),
            if (exp.isNotEmpty) ...[
              const Text('Use these first ⚠️', style: headStyle),
              const SizedBox(height: 8),
              SizedBox(
                height: 176,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: exp.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _expiryCard(exp[i], i),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const Text('Consumed today', style: headStyle),
            const SizedBox(height: 8),
            if (today.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Nothing eaten yet. Mark a product as eaten!', style: TextStyle(color: Colors.black45)))),
            for (final e in today)
              Dismissible(
                key: ValueKey('log_${e.id}'),
                onDismissed: (_) => state.removeLog(e),
                background: Container(color: Colors.red.shade900, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Glass(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(e.emoji, style: const TextStyle(fontSize: 24)),
                      title: Text(e.name),
                      trailing: Text('${e.kcal} kcal', style: const TextStyle(fontWeight: FontWeight.bold, color: burgundy)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ]);
  }
}

void eatSheet(BuildContext ctx, AppState s, PantryItem p) {
  double g = 100;
  showModalBottomSheet(
    context: ctx,
    backgroundColor: cream,
    showDragHandle: true,
    builder: (_) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${p.food.emoji} ${p.food.name}', style: titleStyle),
          const SizedBox(height: 4),
          const Text('How much did you eat?'),
          Slider(value: g, min: 10, max: 500, divisions: 49, label: '${g.round()} g', onChanged: (v) => set(() => g = v)),
          Text('${g.round()} g · ${(p.food.kcal * g / 100).round()} kcal', style: const TextStyle(fontWeight: FontWeight.bold, color: burgundy)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: burgundy),
              onPressed: () {
                s.eat(p, g.round());
                Navigator.pop(c);
              },
              child: const Text('Mark as eaten (finished)'),
            ),
          ),
        ]),
      ),
    ),
  );
}

class PantryTile extends StatelessWidget {
  final PantryItem item;
  final AppState state;
  const PantryTile({super.key, required this.item, required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: sand,
      elevation: 0,
      child: ListTile(
        leading: Text(item.food.emoji, style: const TextStyle(fontSize: 26)),
        title: Text(item.food.name),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.status, style: TextStyle(color: item.color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: item.fresh),
              duration: const Duration(milliseconds: 700),
              builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 5, color: item.color, backgroundColor: Colors.black12),
            ),
          ),
        ]),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Eat', icon: const Icon(Icons.restaurant, color: burgundy), onPressed: () => eatSheet(context, state, item)),
          IconButton(tooltip: 'Throw away', icon: const Icon(Icons.delete_outline), onPressed: () => state.throwAway(item)),
        ]),
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
    final n = f.name.toLowerCase();
    if (n.startsWith(qq)) return 0;
    if (n.split(' ').any((w) => w.startsWith(qq))) return 1;
    if (n.contains(qq)) return 2;
    return 3;
  }

  List<FoodItem> get results {
    final qq = q.trim().toLowerCase();
    final list = foodDatabase.where((f) => (cat == null || f.category == cat) && (qq.isEmpty || _score(f, qq) < 3)).toList();
    list.sort((a, b) => _score(a, qq) != _score(b, qq) ? _score(a, qq).compareTo(_score(b, qq)) : a.name.compareTo(b.name));
    return list;
  }

  void _add(FoodItem f) {
    widget.state.add(f);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: burgundy,
        duration: const Duration(milliseconds: 1500),
        content: Text('${f.emoji} ${f.name} added · fresh for ${f.shelf} days'),
      ));
  }

  Widget _chip(String label, String? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(value == null ? label : '${catEmoji[value]} $label'),
          selected: cat == value,
          selectedColor: burgundy,
          labelStyle: TextStyle(color: cat == value ? Colors.white : Colors.black87),
          showCheckmark: false,
          onSelected: (_) => setState(() => cat = value),
        ),
      );

  Widget _grid() => GridView.count(
        key: const ValueKey('grid'),
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
                    child: Row(children: [
                      Text(catEmoji[categories[i]] ?? '🍽️', style: const TextStyle(fontSize: 26)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(categories[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${foodDatabase.where((f) => f.category == categories[i]).length} products', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      );

  Widget _list(List<FoodItem> res) {
    if (res.isEmpty) return Center(key: const ValueKey('none'), child: Text('Nothing found for "$q"', style: const TextStyle(color: Colors.grey)));
    final count = <String, int>{};
    for (final p in widget.state.pantry) {
      count[p.food.name] = (count[p.food.name] ?? 0) + 1;
    }
    final ids = res.map((f) => f.name).toSet();
    final related = q.trim().isEmpty ? <FoodItem>[] : foodDatabase.where((f) => f.category == res.first.category && !ids.contains(f.name)).take(6).toList();
    return ListView.builder(
      key: const ValueKey('list'),
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: res.length + 1,
      itemBuilder: (context, i) {
        if (i == res.length) {
          if (related.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('You may also like', style: headStyle),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final f in related)
                  ActionChip(
                    avatar: Text(f.emoji),
                    label: Text(f.name),
                    onPressed: () => setState(() {
                      _c.text = f.name;
                      _c.selection = TextSelection.collapsed(offset: f.name.length);
                      q = f.name;
                    }),
                  ),
              ]),
            ]),
          );
        }
        final f = res[i];
        final n = count[f.name] ?? 0;
        return Card(
          color: sand,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Text(f.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(f.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${f.category} · ${f.kcal} kcal/100 g · keeps ${f.shelf} d${n > 0 ? ' · in fridge ×$n' : ''}'),
            trailing: IconButton(icon: const Icon(Icons.add_circle, color: burgundy, size: 30), onPressed: () => _add(f)),
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Search products', style: titleStyle),
          const SizedBox(height: 12),
          TextField(
            controller: _c,
            onChanged: (v) => setState(() => q = v),
            decoration: InputDecoration(
              hintText: 'Try "cheese", "potato", "kefir"...',
              prefixIcon: const Icon(Icons.search, color: burgundy),
              suffixIcon: q.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _c.clear();
                        setState(() => q = '');
                      }),
              filled: true,
              fillColor: sand,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: [_chip('All', null), ...categories.map((c) => _chip(c, c))])),
          const SizedBox(height: 8),
          Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: showGrid ? _grid() : _list(results))),
        ]),
      ),
    );
  }
}

// ───────────────────────── FRIDGE ─────────────────────────

class PantryPage extends StatelessWidget {
  final AppState state;
  final VoidCallback onSearch;
  const PantryPage({super.key, required this.state, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    final items = [...state.pantry]..sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
    final bad = items.where((p) => p.daysLeft <= 0).length;
    final soon = items.where((p) => p.daysLeft > 0 && p.daysLeft <= 2).length;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your fridge', style: titleStyle),
          const SizedBox(height: 4),
          Text('${items.length} products · $soon expiring soon · $bad expired', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('🧊', style: TextStyle(fontSize: 56)),
                      const SizedBox(height: 8),
                      const Text('Fridge is empty', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: burgundy), onPressed: onSearch, icon: const Icon(Icons.search), label: const Text('Find products')),
                    ]),
                  )
                : ListView(children: [
                    for (final e in items.asMap().entries) Appear(key: ValueKey('p${e.value.id}'), index: e.key, child: PantryTile(item: e.value, state: state)),
                  ]),
          ),
        ]),
      ),
    );
  }
}

// ───────────────────────── RECIPES ─────────────────────────

class RecipesPage extends StatelessWidget {
  final AppState state;
  const RecipesPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final names = state.pantryNames;
    final expNames = state.expiringSoon.map((e) => e.food.name).toSet();
    var list = rankRecipes(state);
    var hidden = 0;
    if (state.pantry.isNotEmpty) {
      final all = list.length;
      list = list.where((r) => r.ingredients.any((i) => names.contains(i.name))).toList();
      hidden = all - list.length;
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Recipes from your fridge', style: titleStyle), backgroundColor: Colors.transparent),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).padding.bottom), children: [
        if (state.pantry.isEmpty)
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('Your fridge is empty — add products in Search to see what you can cook.', style: TextStyle(color: Colors.grey))),
        for (final e in list.asMap().entries) _card(context, e.value, e.key, names, expNames),
        if (hidden > 0) Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Add more products to unlock $hidden more recipes', style: const TextStyle(color: Colors.grey)))),
      ]),
    );
  }

  Widget _card(BuildContext context, Recipe r, int idx, Set<String> names, Set<String> expNames) {
    final missing = r.missing(names);
    final can = missing.isEmpty;
    final saves = r.ingredients.where((i) => expNames.contains(i.name)).map((i) => i.name).toList();
    return Appear(
      key: ValueKey(r.name),
      index: idx,
      child: Card(
        color: can ? const Color(0xFFE8EFE0) : sand,
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(context, fadeSlide(RecipePage(state: state, recipe: r))),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Flexible(child: Text('${r.emoji} ${r.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: can ? Colors.green.shade800 : Colors.orange.shade800, borderRadius: BorderRadius.circular(20)),
                  child: Text(can ? 'Ready to cook' : '${r.ingredients.length - missing.length}/${r.ingredients.length} in fridge', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              ]),
              const SizedBox(height: 6),
              Text('${r.kcal} kcal/serving • ${r.time} • ${r.servings} servings', style: const TextStyle(color: Colors.grey)),
              if (saves.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('♻️ Saves from waste: ${saves.join(", ")}', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold))),
              if (missing.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text('Buy: ${missing.join(", ")}', style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold))),
            ]),
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
      appBar: AppBar(title: Text(r.name, style: headStyle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 20), children: [
        Appear(
          child: Row(children: [
            Text(r.emoji, style: const TextStyle(fontSize: 52)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${r.kcal * portions} kcal total', style: titleStyle),
                Text('${r.kcal} kcal per serving · ${r.time}', style: const TextStyle(color: Colors.grey)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Appear(
          index: 1,
          child: Row(children: [
            const Text('Servings', style: headStyle),
            const Spacer(),
            IconButton.filledTonal(onPressed: portions > 1 ? () => setState(() => portions--) : null, icon: const Icon(Icons.remove)),
            SizedBox(
              width: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Text('$portions', key: ValueKey(portions), textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton.filledTonal(onPressed: portions < 12 ? () => setState(() => portions++) : null, icon: const Icon(Icons.add)),
          ]),
        ),
        const SizedBox(height: 10),
        const Text('Ingredients', style: headStyle),
        const SizedBox(height: 6),
        for (final e in r.ingredients.asMap().entries)
          Appear(
            index: e.key + 2,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(inFridge.containsKey(e.value.name) ? Icons.check_circle : Icons.cancel, color: inFridge.containsKey(e.value.name) ? Colors.green.shade800 : Colors.red.shade800),
              title: Text('${foodByName[e.value.name]!.emoji} ${e.value.name}'),
              subtitle: Text(inFridge.containsKey(e.value.name) ? 'in fridge · ${inFridge[e.value.name]!.status}' : 'not in fridge — add it in Search'),
              trailing: Text('${(e.value.g * portions / r.servings).round()} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        Padding(padding: const EdgeInsets.only(top: 4), child: Text('Also needed: ${r.staples}', style: const TextStyle(color: Colors.grey))),
        const SizedBox(height: 18),
        const Text('Instructions', style: headStyle),
        const SizedBox(height: 8),
        for (final e in r.steps.asMap().entries)
          Appear(
            index: e.key + 4,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 13, backgroundColor: burgundy, child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12))),
                const SizedBox(width: 12),
                Expanded(child: Text(e.value, style: const TextStyle(height: 1.35))),
              ]),
            ),
          ),
      ]),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: burgundy,
                        content: Text('Bon appétit! ${r.kcal * portions} kcal logged, ingredients used up.'),
                      ));
                    }
                  : () {
                      s.addShopping(missing);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(behavior: SnackBarBehavior.floating, backgroundColor: burgundy, content: Text('${missing.length} items added to your shopping list 🛒')));
                    },
              child: Text(missing.isEmpty ? 'I cooked it · log ${r.kcal * portions} kcal' : 'Add missing to shopping list (${missing.length})'),
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
  bool _loading = false;

  @override
  void dispose() {
    _c.dispose();
    _sc.dispose();
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
    setState(() => _loading = true);
    _scroll();
    String answer;
    try {
      answer = await widget.ai.reply(text, s);
    } catch (e) {
      answer = 'Sorry, something went wrong. Try again.';
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
      appBar: AppBar(title: const Text('NutriMate AI', style: titleStyle), backgroundColor: Colors.transparent),
      body: Column(children: [
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
                builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
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
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final q in ['What can I cook?', 'What expires soon?', 'Another idea', 'Do I have cheese?', 'Calories in potato'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: () => _send(q))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _c,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Ask anything...',
                  filled: true,
                  fillColor: sand,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.send, color: burgundy), onPressed: () => _send()),
          ]),
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom),
      ]),
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
        appBar: AppBar(title: const Text('Profile', style: headStyle)),
        body: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
          Appear(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: burgundy, child: Text(state.name.isEmpty ? '?' : state.name[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
              title: Text(state.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(state.email.isEmpty ? 'Guest account' : state.email),
            ),
          ),
          ListTile(title: Text('Goal: ${state.targetCalories} kcal/day'), leading: const Icon(Icons.track_changes, color: burgundy)),
          SwitchListTile(title: const Text('Male'), value: state.isMan, onChanged: (v) => state.updateProfile(isMan: v)),
          _slider('Weight', '${state.weight.round()} kg', state.weight, 40, 150, (v) => state.updateProfile(weight: v)),
          _slider('Height', '${state.height.round()} cm', state.height, 120, 220, (v) => state.updateProfile(height: v)),
          _slider('Age', '${state.age} y', state.age.toDouble(), 14, 90, (v) => state.updateProfile(age: v.round())),
          const Divider(height: 32),
          const Text('Demo tools', style: headStyle),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            FilledButton.tonalIcon(onPressed: () => state.nextDay(1), icon: const Icon(Icons.skip_next), label: Text('+1 day (now +$dayShift)')),
            OutlinedButton(onPressed: () => state.nextDay(0), child: const Text('Reset time')),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                state.startTutorial();
              },
              icon: const Icon(Icons.school_outlined),
              label: const Text('Replay tutorial'),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Use "+1 day" to watch freshness bars drop and products expire.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(context, fadeSlide(RegisterScreen(state: state, ai: ai)), (_) => false),
            icon: const Icon(Icons.logout, color: burgundy),
            label: const Text('Log out', style: TextStyle(color: burgundy)),
          ),
        ]),
      ),
    );
  }

  Widget _slider(String title, String valueText, double value, double min, double max, ValueChanged<double> onChanged) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 16, top: 8), child: Text('$title: $valueText', style: const TextStyle(fontWeight: FontWeight.bold))),
      Slider(value: value, min: min, max: max, onChanged: onChanged),
    ]);
  }
}
