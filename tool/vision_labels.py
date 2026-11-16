#!/usr/bin/env python3
"""Словарь «метка Apple Vision → продукт базы» для сканера еды на iOS (v33).

VNClassifyImageRequest (на телефоне, без интернета) возвращает идентификаторы своей таксономии
(«banana», «bell_pepper», «baked_goods»…). Здесь — таблица: какая метка какому продукту из
ios/NutriMate/Resources/foods.json соответствует. Список меток собран вручную по таксономии Vision
(knownClassifications нельзя запустить вне Apple-устройства): фрукты, ягоды, овощи, зелень, грибы,
выпечка, молочное, мясо, рыба и морепродукты, орехи, крупы, напитки, сладости, готовые блюда.
Лишняя метка, которой нет в таксономии, безвредна — она просто никогда не придёт.

Общие метки («food», «fruit», «dessert», «baked_goods»…) продуктом НЕ считаются: результат помечается
«не уверен», а вместо продукта приложение показывает 3 варианта-подсказки из GENERIC.

  python3 tool/vision_labels.py           # проверить цели по foods.json и записать vision_labels.json
  python3 tool/vision_labels.py --check   # только проверить (CI): файл актуален, все цели существуют
"""
import json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOODS = os.path.join(ROOT, "ios", "NutriMate", "Resources", "foods.json")
OUT = os.path.join(ROOT, "ios", "NutriMate", "Resources", "vision_labels.json")

# метка Vision → точное английское название продукта в базе
LABELS = {
    # ── фрукты ──
    "apple": "Apple", "green_apple": "Green Apple", "red_apple": "Apple", "crabapple": "Crab Apples",
    "banana": "Banana", "plantain": "Plantain",
    "orange": "Orange", "mandarin": "Tangerine", "tangerine": "Tangerine", "clementine": "Clementine",
    "lemon": "Lemon", "lime": "Lime", "grapefruit": "Grapefruit", "pomelo": "Pomelo", "kumquat": "Kumquat",
    "pear": "Pear", "asian_pear": "Asian Pear", "quince": "Quince",
    "peach": "Peach", "nectarine": "Nectarine", "apricot": "Apricot", "plum": "Plum", "cherry": "Cherry",
    "grape": "Grapes", "grapes": "Grapes", "raisin": "Raisins", "raisins": "Raisins",
    "pineapple": "Pineapple", "mango": "Mango", "papaya": "Papaya", "kiwi": "Kiwi", "kiwifruit": "Kiwi",
    "watermelon": "Watermelon", "melon": "Melon", "cantaloupe": "Cantaloupe", "honeydew": "Honeydew Melon",
    "avocado": "Avocado", "pomegranate": "Pomegranate", "persimmon": "Persimmon", "fig": "Fig",
    "date": "Dates", "dates": "Dates", "date_fruit": "Dates", "coconut": "Coconut",
    "guava": "Guava", "passion_fruit": "Passion Fruit", "passionfruit": "Passion Fruit",
    "dragonfruit": "Dragon Fruit", "dragon_fruit": "Dragon Fruit", "pitaya": "Dragon Fruit",
    "lychee": "Lychee", "litchi": "Lychee", "longan": "Longan", "rambutan": "Rambutan", "mangosteen": "Mangosteen",
    "durian": "Durian", "jackfruit": "Jackfruit", "starfruit": "Star Fruit", "carambola": "Star Fruit",
    "feijoa": "Feijoa", "loquat": "Loquat", "cherimoya": "Cherimoya", "custard_apple": "Sugar Apple",
    "soursop": "Soursop", "breadfruit": "Breadfruit", "tamarillo": "Tamarillo", "jujube": "Jujube",
    "prickly_pear": "Prickly Pear", "medlar": "Medlar", "physalis": "Physalis", "kiwano": "Kiwano",
    "citron": "Citron", "yuzu": "Yuzu", "bergamot": "Bergamot", "prune": "Prunes", "dried_apricot": "Dried Apricots",
    # ── ягоды ──
    "strawberry": "Strawberry", "blueberry": "Blueberry", "raspberry": "Raspberry", "blackberry": "Blackberry",
    "cranberry": "Cranberry", "gooseberry": "Gooseberry", "currant": "Black Currant", "blackcurrant": "Black Currant",
    "redcurrant": "Red Currant", "mulberry": "Mulberry", "elderberry": "Elderberry", "lingonberry": "Lingonberry",
    "goji": "Goji Berries", "acai": "Acai Berries", "rosehip": "Rosehip", "sea_buckthorn": "Sea Buckthorn",
    "huckleberry": "Huckleberries", "boysenberry": "Boysenberry",
    # ── овощи ──
    "tomato": "Tomato", "cherry_tomato": "Cherry Tomato", "cucumber": "Cucumber", "pickle": "Gherkins",
    "potato": "Potato", "sweet_potato": "Sweet Potato", "yam": "Yam", "carrot": "Carrot",
    "onion": "Onion", "red_onion": "Red Onion", "shallot": "Shallot", "scallion": "Spring Onion",
    "green_onion": "Spring Onion", "spring_onion": "Spring Onion", "leek": "Leek", "garlic": "Garlic", "chive": "Chives",
    "cabbage": "Cabbage", "red_cabbage": "Red Cabbage", "napa_cabbage": "Chinese Cabbage", "bok_choy": "Bok Choy",
    "broccoli": "Broccoli", "cauliflower": "Cauliflower", "romanesco": "Romanesco", "brussels_sprout": "Brussels Sprouts",
    "brussels_sprouts": "Brussels Sprouts", "kale": "Kale", "spinach": "Spinach", "lettuce": "Lettuce",
    "romaine": "Romaine Lettuce", "iceberg_lettuce": "Iceberg Lettuce", "arugula": "Arugula", "chard": "Swiss Chard",
    "watercress": "Watercress", "endive": "Endive", "radicchio": "Radicchio", "collard_greens": "Collard Greens",
    "bell_pepper": "Bell Pepper", "pepper": "Bell Pepper", "sweet_pepper": "Bell Pepper",
    "chili_pepper": "Chili Pepper", "chili": "Chili Pepper", "chile": "Chili Pepper", "jalapeno": "Jalapeno",
    "habanero": "Habanero", "eggplant": "Eggplant", "aubergine": "Eggplant", "zucchini": "Zucchini",
    "courgette": "Zucchini", "squash": "Butternut Squash", "butternut_squash": "Butternut Squash", "pumpkin": "Pumpkin",
    "gourd": "Bottle Gourd", "bitter_melon": "Bitter Melon", "corn": "Corn", "maize": "Corn", "corn_cob": "Corn",
    "pea": "Green Peas", "peas": "Green Peas", "snow_pea": "Snow Peas", "green_beans": "Green Beans",
    "green_bean": "Green Beans", "string_bean": "Green Beans", "edamame": "Edamame", "okra": "Okra",
    "asparagus": "Asparagus", "artichoke": "Artichoke", "celery": "Celery", "celeriac": "Celery Root",
    "fennel": "Fennel", "kohlrabi": "Kohlrabi", "beet": "Beetroot", "beetroot": "Beetroot", "radish": "Radish",
    "daikon": "Daikon", "turnip": "Turnip", "rutabaga": "Rutabaga", "parsnip": "Parsnip", "horseradish": "Horseradish",
    "ginger": "Ginger", "turmeric": "Fresh Turmeric Root", "cassava": "Cassava", "taro": "Taro",
    "jicama": "Jicama", "lotus_root": "Lotus Root", "bamboo_shoot": "Fresh Bamboo Shoots", "rhubarb": "Rhubarb",
    "tomatillo": "Tomatillo", "chayote": "Chayote", "sprout": "Bean Sprouts", "bean_sprout": "Bean Sprouts",
    "microgreens": "Microgreens", "olive": "Kalamata Olives", "olives": "Kalamata Olives",
    "salad": "Salad Mix", "greens": "Salad Mix", "leafy_green": "Salad Mix",
    # ── грибы ──
    "mushroom": "Mushrooms", "mushrooms": "Mushrooms", "champignon": "Champignons", "button_mushroom": "Champignons",
    "shiitake": "Shiitake Mushrooms", "oyster_mushroom": "Oyster Mushrooms", "enoki": "Enoki Mushrooms",
    "portobello": "Portobello", "chanterelle": "Chanterelles", "porcini": "Porcini Mushrooms", "morel": "Morels",
    "truffle": "Black Truffle",
    # ── зелень и специи ──
    "basil": "Basil", "mint": "Mint", "parsley": "Parsley", "dill": "Dill", "cilantro": "Cilantro",
    "coriander": "Cilantro", "rosemary": "Rosemary", "thyme": "Thyme", "sage": "Sage", "oregano": "Oregano",
    "lemongrass": "Lemongrass", "bay_leaf": "Bay Leaf", "cinnamon": "Cinnamon", "vanilla": "Vanilla",
    "peppercorn": "Black Pepper", "salt": "Salt", "sugar": "Sugar", "honey": "Honey",
    # ── выпечка и хлеб ──
    "bread": "White Bread", "loaf": "Bread Loaf", "white_bread": "White Bread", "rye_bread": "Rye Bread",
    "sourdough": "Sourdough Bread", "baguette": "Baguette", "croissant": "Croissant", "bagel": "Bagel",
    "bun": "Burger Bun", "roll": "Burger Bun", "pita": "Pita", "naan": "Naan", "flatbread": "Flatbread",
    "tortilla": "Tortilla", "ciabatta": "Ciabatta", "brioche": "Brioche", "focaccia": "Focaccia",
    "toast": "Toast Bread", "pretzel": "Pretzel", "muffin": "Muffin", "english_muffin": "English Muffin",
    "cupcake": "Cupcake", "donut": "Donut", "doughnut": "Donut", "cinnamon_roll": "Cinnamon Roll",
    "challah": "Challah", "cornbread": "Cornbread", "crumpet": "Crumpets", "breadstick": "Breadsticks",
    "cracker": "Salted Crackers", "crackers": "Salted Crackers", "biscotti": "Biscotti",
    "waffle": "Waffles", "pancake": "Blini", "pancakes": "Blini", "crepe": "Blini", "french_toast": "French Toast",
    "pie": "Apple Pie", "apple_pie": "Apple Pie", "quiche": "Quiche", "strudel": "Strudel",
    "puff_pastry": "Puff Pastry", "pain_au_chocolat": "Pain au Chocolat", "scone": "Buttermilk Biscuits",
    # ── молочное и яйца ──
    "milk": "Milk", "cheese": "Cheddar Cheese", "cheddar": "Cheddar Cheese", "mozzarella": "Mozzarella",
    "parmesan": "Parmesan", "brie": "Brie", "camembert": "Camembert", "feta": "Feta", "gouda": "Gouda",
    "blue_cheese": "Blue Cheese", "swiss_cheese": "Swiss Cheese", "cream_cheese": "Cream Cheese",
    "cottage_cheese": "Cottage Cheese", "ricotta": "Ricotta", "halloumi": "Halloumi", "paneer": "Paneer",
    "butter": "Butter", "yogurt": "Yogurt", "yoghurt": "Yogurt", "cream": "Heavy Cream",
    "whipped_cream": "Whipped Cream", "sour_cream": "Sour Cream", "kefir": "Kefir", "ghee": "Ghee",
    "egg": "Eggs", "eggs": "Eggs", "quail_egg": "Quail Eggs", "fried_egg": "Scrambled Eggs",
    "scrambled_eggs": "Scrambled Eggs", "omelet": "Scrambled Eggs", "omelette": "Scrambled Eggs",
    "deviled_egg": "Deviled Eggs",
    # ── мясо ──
    "steak": "Steak", "beef": "Beef", "pork": "Pork", "lamb": "Lamb", "mutton": "Mutton", "veal": "Veal",
    "chicken_breast": "Chicken Breast", "chicken_wing": "Chicken Wings", "chicken_wings": "Chicken Wings",
    "drumstick": "Chicken Drumsticks", "poultry": "Whole Chicken", "roast_chicken": "Whole Chicken",
    "fried_chicken": "Fried Chicken", "turkey_meat": "Turkey", "duck_meat": "Duck",
    "bacon": "Bacon", "ham": "Ham", "sausage": "Sausages", "hot_dog": "Hot Dog", "hotdog": "Hot Dog",
    "salami": "Salami", "pepperoni": "Pepperoni", "prosciutto": "Prosciutto", "chorizo": "Chorizo",
    "meatball": "Meatballs", "meatballs": "Meatballs", "ribs": "Pork Ribs", "spare_ribs": "Pork Ribs",
    "ground_beef": "Ground Beef", "minced_meat": "Ground Beef", "jerky": "Beef Jerky", "liver": "Liver",
    "pastrami": "Pastrami", "roast_beef": "Roast Beef", "meatloaf": "Meatloaf", "pulled_pork": "Pulled Pork",
    "kebab": "Marinated Shashlik", "skewer": "Marinated Shashlik", "shish_kebab": "Marinated Shashlik",
    "barbecue": "Marinated Shashlik", "cutlet": "Cutlets",
    # ── рыба и морепродукты ──
    "salmon": "Salmon", "smoked_salmon": "Smoked Salmon", "tuna": "Tuna Steak", "cod": "Cod", "trout": "Trout",
    "herring": "Herring", "mackerel": "Mackerel", "sardine": "Fresh Sardines", "anchovy": "Anchovies",
    "tilapia": "Tilapia", "halibut": "Halibut", "sea_bass": "Sea Bass", "carp": "Carp", "catfish": "Catfish",
    "eel": "Eel", "shrimp": "Shrimp", "prawn": "Tiger Prawns", "crab": "Crab", "lobster": "Lobster",
    "crayfish": "Crayfish", "crawfish": "Crayfish", "oyster": "Oysters", "mussel": "Mussels", "mussels": "Mussels",
    "clam": "Clams", "scallop": "Scallops", "squid": "Squid", "calamari": "Calamari Rings", "octopus": "Octopus",
    "caviar": "Red Caviar", "roe": "Fish Roe", "sea_urchin": "Sea Urchin", "crab_stick": "Crab Sticks",
    "fish_fillet": "Frozen Fish Fillet", "fish_and_chips": "Fish Fingers", "fish_stick": "Fish Fingers",
    # ── орехи, бобовые, семена ──
    "nut": "Mixed Nuts", "nuts": "Mixed Nuts", "almond": "Almonds", "walnut": "Walnuts", "peanut": "Peanuts",
    "cashew": "Cashews", "pistachio": "Pistachios", "hazelnut": "Hazelnuts", "pecan": "Pecans",
    "macadamia": "Macadamia", "chestnut": "Chestnuts", "pine_nut": "Pine Nuts", "brazil_nut": "Brazil Nuts",
    "peanut_butter": "Peanut Butter", "beans": "Beans", "bean": "Beans", "kidney_bean": "Kidney Beans",
    "black_bean": "Black Beans", "chickpea": "Chickpeas", "chickpeas": "Chickpeas", "lentil": "Lentils",
    "lentils": "Lentils", "soybean": "Soybeans", "sunflower_seed": "Sunflower Seeds",
    "pumpkin_seed": "Pumpkin Seeds", "sesame": "Sesame Seeds", "tofu": "Tofu", "tempeh": "Tempeh",
    # ── крупы, паста ──
    "rice": "Rice", "fried_rice": "Fried Rice", "risotto": "Risotto", "pasta": "Pasta",
    "spaghetti": "Spaghetti", "macaroni": "Macaroni", "penne": "Penne", "noodle": "Egg Noodles",
    "noodles": "Egg Noodles", "ramen": "Ramen Bowl", "udon": "Udon Noodles", "soba": "Soba Noodles",
    "oatmeal": "Oatmeal", "porridge": "Oatmeal", "oats": "Oats", "cereal": "Cornflakes", "granola": "Granola",
    "muesli": "Muesli", "quinoa": "Quinoa", "couscous": "Couscous", "flour": "Flour", "gnocchi": "Gnocchi",
    "polenta": "Polenta", "dough": "Yeast Dough",
    # ── напитки ──
    "coffee": "Ground Coffee", "espresso": "Espresso", "cappuccino": "Cappuccino", "latte": "Cappuccino",
    "iced_coffee": "Iced Coffee", "tea": "Black Tea", "green_tea": "Green Tea", "iced_tea": "Iced Tea",
    "matcha": "Matcha Latte", "bubble_tea": "Bubble Tea", "hot_chocolate": "Hot Chocolate", "cocoa": "Cocoa Powder",
    "juice": "Orange Juice", "orange_juice": "Orange Juice", "apple_juice": "Apple Juice", "lemonade": "Lemonade",
    "smoothie": "Smoothie", "milkshake": "Milkshake", "soda": "Cola", "cola": "Cola", "soft_drink": "Cola",
    "sparkling_water": "Sparkling Water", "mineral_water": "Mineral Water", "kombucha": "Kombucha",
    "beer": "Beer", "wine": "Red Wine", "red_wine": "Red Wine", "white_wine": "White Wine",
    "champagne": "Champagne", "cider": "Cider", "sake": "Sake", "whiskey": "Whiskey", "vodka": "Vodka",
    "gin": "Gin", "rum": "Rum", "cognac": "Cognac", "sangria": "Sangria", "kvass": "Kvass",
    # ── сладости и снеки ──
    "chocolate": "Chocolate", "chocolate_bar": "Chocolate Bar", "candy": "Candy", "lollipop": "Lollipop",
    "gummy": "Gummy Bears", "marshmallow": "Marshmallow", "caramel": "Caramel", "toffee": "Toffee",
    "fudge": "Fudge", "licorice": "Licorice", "jelly_bean": "Jelly Beans", "cotton_candy": "Cotton Candy",
    "cake": "Cake", "birthday_cake": "Cake", "wedding_cake": "Cake", "cheesecake": "Cheesecake",
    "chocolate_cake": "Chocolate Cake", "carrot_cake": "Carrot Cake", "sponge_cake": "Sponge Cake",
    "brownie": "Brownie", "cookie": "Cookies", "cookies": "Cookies", "biscuit": "Cookies",
    "macaron": "Macarons", "macaroon": "Macarons", "eclair": "Eclair", "tiramisu": "Tiramisu",
    "pudding": "Pudding", "custard": "Custard", "flan": "Flan", "creme_brulee": "Creme Brulee",
    "panna_cotta": "Panna Cotta", "mousse": "Pudding", "tart": "Lemon Tart", "baklava": "Baklava",
    "churro": "Churros", "churros": "Churros", "cannoli": "Cannoli", "mochi": "Mochi", "meringue": "Meringues",
    "pavlova": "Pavlova", "halva": "Halva", "nougat": "Nougat", "praline": "Praline", "marzipan": "Marzipan",
    "ice_cream": "Ice Cream", "gelato": "Gelato", "sorbet": "Sorbet", "frozen_yogurt": "Frozen Yogurt",
    "popsicle": "Popsicle", "ice_pop": "Popsicle", "jam": "Jam", "jelly": "Jelly", "marmalade": "Marmalade",
    "chips": "Potato Chips", "potato_chips": "Potato Chips", "crisps": "Potato Chips", "tortilla_chips": "Tortilla Chips",
    "popcorn": "Popcorn", "nachos": "Nachos", "pretzels": "Pretzel Sticks", "granola_bar": "Granola Bar",
    "trail_mix": "Trail Mix", "rice_cake": "Rice Cakes",
    # ── готовые блюда ──
    "pizza": "Margherita Pizza", "burger": "Burger", "hamburger": "Burger", "cheeseburger": "Burger",
    "sandwich": "Sandwich", "club_sandwich": "Club Sandwich", "grilled_cheese": "Grilled Cheese Sandwich",
    "sub_sandwich": "Sandwich", "wrap": "Wrap", "burrito": "Burrito", "taco": "Tacos", "tacos": "Tacos",
    "quesadilla": "Quesadilla", "shawarma": "Shawarma", "gyro": "Gyro", "falafel": "Falafel", "hummus": "Hummus",
    "french_fries": "Takeaway Fries", "fries": "Takeaway Fries", "onion_rings": "Frozen Onion Rings",
    "mashed_potatoes": "Mashed Potatoes", "baked_potato": "Baked Potato", "hash_brown": "Frozen Hash Browns",
    "sushi": "Sushi", "sashimi": "Sushi", "maki": "Sushi Rolls", "sushi_roll": "Sushi Rolls", "onigiri": "Onigiri",
    "bento": "Bento Box", "dim_sum": "Dim Sum", "dumpling": "Dim Sum", "dumplings": "Dim Sum", "gyoza": "Gyoza",
    "pierogi": "Pierogi", "ravioli": "Frozen Ravioli", "tortellini": "Fresh Tortellini", "spring_roll": "Frozen Spring Rolls",
    "samosa": "Frozen Samosas", "tempura": "Tempura", "pho": "Pho", "poke": "Poke Bowl", "kimchi": "Kimchi",
    "curry": "Chicken Curry", "paella": "Paella", "lasagna": "Lasagna", "lasagne": "Lasagna",
    "mac_and_cheese": "Mac and Cheese", "carbonara": "Carbonara", "bolognese": "Spaghetti Bolognese",
    "soup": "Tomato Soup", "chicken_soup": "Chicken Soup", "borscht": "Borscht Soup", "minestrone": "Minestrone",
    "chowder": "Clam Chowder", "stew": "Leftover Stew", "goulash": "Goulash", "chili_con_carne": "Chili Con Carne",
    "caesar_salad": "Caesar Salad", "greek_salad": "Greek Salad", "coleslaw": "Coleslaw",
    "potato_salad": "Potato Salad", "pasta_salad": "Pasta Salad", "guacamole": "Guacamole",
    "nugget": "Chicken Nuggets", "chicken_nuggets": "Chicken Nuggets", "corn_dog": "Corn Dogs",
    "moussaka": "Moussaka", "dolma": "Dolma", "plov": "Plov", "pilaf": "Plov",
    # ── соусы и бакалея (упаковки) ──
    "ketchup": "Ketchup", "mayonnaise": "Mayonnaise", "mustard": "Mustard", "soy_sauce": "Soy Sauce",
    "olive_oil": "Olive Oil", "oil": "Vegetable Oil", "vinegar": "Vinegar", "salsa": "Salsa",
    "pesto": "Pesto", "tomato_sauce": "Tomato Sauce", "canned_food": "Canned Tuna", "nori": "Nori Sheets",
    "seaweed": "Wakame",
}

# общие метки: продуктом не считаются, результат «не уверен»; значения — 3 подсказки-кнопки
GENERIC = {
    "food": [], "meal": [], "dish": [], "cuisine": [], "snack": [], "produce": [], "ingredient": [],
    "fruit": ["Apple", "Banana", "Orange"], "citrus_fruit": ["Orange", "Lemon", "Tangerine"],
    "berry": ["Strawberry", "Blueberry", "Raspberry"], "berries": ["Strawberry", "Blueberry", "Raspberry"],
    "tropical_fruit": ["Mango", "Pineapple", "Papaya"], "stone_fruit": ["Peach", "Plum", "Apricot"],
    "dried_fruit": ["Raisins", "Dried Apricots", "Prunes"],
    "vegetable": ["Tomato", "Cucumber", "Carrot"], "vegetables": ["Tomato", "Cucumber", "Carrot"],
    "root_vegetable": ["Carrot", "Potato", "Beetroot"], "leaf_vegetable": ["Lettuce", "Spinach", "Cabbage"],
    "cruciferous_vegetable": ["Broccoli", "Cauliflower", "Cabbage"], "legume": ["Beans", "Lentils", "Chickpeas"],
    "herb": ["Parsley", "Dill", "Basil"], "herbs": ["Parsley", "Dill", "Basil"], "spice": ["Black Pepper", "Cinnamon", "Paprika"],
    "baked_goods": ["White Bread", "Croissant", "Bagel"], "pastry": ["Croissant", "Cinnamon Roll", "Puff Pastry"],
    "dessert": ["Cake", "Ice Cream", "Cookies"], "sweets": ["Chocolate", "Candy", "Cookies"],
    "confectionery": ["Chocolate", "Candy", "Marshmallow"], "frozen_dessert": ["Ice Cream", "Gelato", "Popsicle"],
    "dairy": ["Milk", "Yogurt", "Cheddar Cheese"], "meat": ["Beef", "Pork", "Chicken Breast"],
    "red_meat": ["Beef", "Lamb", "Pork"], "poultry_meat": ["Chicken Breast", "Turkey", "Whole Chicken"],
    "cold_cuts": ["Ham", "Salami", "Boiled Sausage"], "chicken": ["Chicken Breast", "Whole Chicken", "Chicken Thighs"],
    "turkey": ["Turkey", "Turkey Breast", "Ground Turkey"], "duck": ["Duck", "Duck Breast", "Duck Eggs"],
    "fish": ["Salmon", "Cod", "Mackerel"], "seafood": ["Shrimp", "Mussels", "Squid"], "shellfish": ["Shrimp", "Mussels", "Oysters"],
    "grain": ["Rice", "Buckwheat", "Oats"], "grains": ["Rice", "Buckwheat", "Oats"], "wheat": ["Flour", "Wheat Groats", "Bulgur"],
    "beverage": ["Orange Juice", "Black Tea", "Ground Coffee"], "drink": ["Orange Juice", "Black Tea", "Ground Coffee"],
    "alcoholic_beverage": ["Beer", "Red Wine", "White Wine"], "liquor": ["Whiskey", "Vodka", "Rum"],
    "cocktail": [], "condiment": ["Ketchup", "Mayonnaise", "Mustard"], "sauce": ["Ketchup", "Tomato Sauce", "Soy Sauce"],
    "salad_dressing": [], "breakfast": ["Oatmeal", "Scrambled Eggs", "Cornflakes"], "fast_food": ["Burger", "Takeaway Fries", "Hot Dog"],
    "street_food": ["Shawarma", "Hot Dog", "Burger"], "packaged_goods": [], "groceries": [], "grocery": [],
}


def build():
    foods = json.load(open(FOODS, encoding="utf-8"))["foods"]
    names = {f["name"] for f in foods}
    errors = []
    for k, v in LABELS.items():
        if k != k.lower() or " " in k:
            errors.append(f"метка «{k}»: только нижний регистр и _")
        if v not in names:
            errors.append(f"«{k}» → «{v}»: нет в foods.json")
        if k in GENERIC:
            errors.append(f"«{k}» одновременно в LABELS и GENERIC")
    for k, alts in GENERIC.items():
        for v in alts:
            if v not in names:
                errors.append(f"общая «{k}» → подсказка «{v}»: нет в foods.json")
    data = {
        "_comment": "Generated by tool/vision_labels.py — Apple Vision VNClassifyImageRequest identifier → food base product (English name). generic: labels that are not a product (result is uncertain) with 3 suggestions.",
        "labels": dict(sorted(LABELS.items())),
        "generic": dict(sorted(GENERIC.items())),
    }
    return data, errors


def main():
    data, errors = build()
    for e in errors:
        print("❌", e)
    text = json.dumps(data, ensure_ascii=False, indent=1, sort_keys=False) + "\n"
    if "--check" in sys.argv:
        cur = open(OUT, encoding="utf-8").read() if os.path.exists(OUT) else ""
        if cur != text:
            print("❌ vision_labels.json устарел — запусти python3 tool/vision_labels.py")
            errors.append("stale")
    elif not errors:
        open(OUT, "w", encoding="utf-8").write(text)
    targets = len(set(LABELS.values()))
    print(f"vision_labels.json: {len(LABELS)} меток → {targets} продуктов, {len(GENERIC)} общих меток; ошибок {len(errors)}")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
