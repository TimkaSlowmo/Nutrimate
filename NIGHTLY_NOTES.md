# NutriMate — журнал ночного агента

## Текущее состояние
- Веб: **v18** · iOS: **v16** (нумерация продолжает версии из DartPad: v1–v15 были там) · продуктов: **1447** · рецептов: **121** (zero-waste: 49) · переводов ru/kk: **208** (155 продуктов + 53 рецепта)
- ИИ-сервер работает (Cloudflare Workers AI, бесплатно); с v10 предлагает действия только структурированно (`actions`), приложение выполняет само.
- Главная версия — iOS (ios/, журнал ios/NIGHTLY_NOTES_IOS.md, жалобы ios/BUILD_ERRORS.md). Веб — баги и перенос закрытых жалоб.
- Единая база: `python3 tool/export_data.py` проверяет дубли/ингредиенты и пишет ios/NutriMate/Resources/foods.json.
- Локально Flutter недоступен → компиляцию проверяет GitHub Actions.

## 2026-11-12 (день) · веб v18 · iOS v16 (бывшая v10)
- iOS v16 (бывшая v10): новый профиль (жалоба 4), структурированные действия ИИ (жалоба 5 закрыта), переводы 155 названий + поиск на 3 языках.
- Сервер: протокол `ACTIONS` с примерами EN/RU/KK, opt-in `actions:true`, правка холодильник/морозилка, +тесты, smoke-тест.
- Веб v18: честные команды в чате на 3 языках (добавь N в холодильник/морозилку, съел, выбросил, заморозил) + действия ИИ
  выполняются и подтверждаются приложением. +23 продукта: Frisée, Mizuna, Gai Lan, Purple Yam, Beet Greens, Romano Beans,
  Pluot, Prickly Pear, Yellow Watermelon, Black Sapote, Quark, Mortadella, Monkfish, Pumpernickel, Lupini Beans,
  Monk Fruit Sweetener, Epazote, Summer Savory, Canned Ackee, Barley Tea, Kimbap, Fresh Tortellini, Seaweed Salad.
- +3 рецепта: Viral Cottage Cheese Flatbread (zw), Smashed Cucumber Salad (zw), Marry Me Chicken.
- 👀 Симулятор (8f607c2): новый профиль, Edit profile, Medals — без обрезанного текста и наложений, падений нет.
- ⚡ fps (симулятор, автопрокрутка): Home 21, Fridge 60, Search 60, Recipes 57.5. Эксперимент -perfOff: Home без Нутрика — 60,
  без фона/теней — по-прежнему ~20 → тормозит именно анимация Нутрика на Home (жалоба 1 фактически не закрыта).
- Бэклог веба: складывание одинаковых продуктов, три языка (после iOS).

## 2026-11-12 (утро) · веб v17 · iOS v9
- iOS v9: плавность (жалоба 1), складывание одинаковых продуктов (жалоба 2), честные команды-действия в чате на 3 языках (жалоба 5, частично).
- Сервер: не утверждает, что сделал действие; отвечает на языке пользователя.
- Веб v17: только данные. +36 продуктов: Kabocha/Delicata Squash, Celtuce, Salsify, Fiddlehead Ferns, Ramps, Nopales, Tomatillo,
  Shishito/Padron Peppers, Samphire, Garlic Scapes, Pea Shoots, Purple Sweet Potato, Maitake, Lion's Mane, Black Trumpet,
  Lovage, Culantro, Lemon Verbena, Jabuticaba, Acerola, Camu Camu, Cupuacu, Mamey Sapote, Medlar, Pawpaw, Calamansi,
  Buddha's Hand, Finger Lime, Ugli Fruit, Chili Crisp, Hot Honey, Tajin Seasoning, Togarashi, Hearts of Palm.
- +4 рецепта: Chili Crisp Fried Eggs on Rice (zw), Blistered Shishito Peppers, Hot Honey Halloumi Toast (zw), Roasted Kabocha Squash Soup (zw).
- Бэклог веба: складывание продуктов, честные команды в чате, три языка.

## 2026-11-12 (ночь 6) · веб v15 · iOS v6
- iOS v6: онлайн-ИИ Нутрик через бесплатный Cloudflare Worker (код готов, ждёт настройки), офлайн — запасной.
- Веб v15: только данные. +31 продукт: Longan, Salak, Soursop, Lotus Root, Jicama, Bitter Melon, Shimeji/Wood Ear Mushrooms,
  Thai Basil, Shiso, Galangal, Kaffir Lime/Pandan Leaves, Tapioca Pearls, Panko, Dashi Granules, Red Bean Paste, Ube Powder, Kataifi,
  Pistachio Cream, Lard, Shortening, Gochugaru, Furikake, Guajillo Chiles, Yakult, Cotija Cheese, Corn Tortillas, Beef Chuck,
  Chipotle in Adobo, Cannellini Beans. +5 советов хранения.
- +4 рецепта: Brown Sugar Boba Milk Tea, Dubai Chocolate Bar, Quesabirria Tacos, Viral Baked Feta Pasta (zw). Всего 1357 / 110.

## 2026-11-11 · симулятор
- Новый workflow «iOS screenshots (simulator)»: приложение запускается на iPhone 16 Pro Max (iOS 18) с демо-данными,
  12 снимков экранов + видео → ветка `ios-screens` (https://github.com/TimkaSlowmo/Nutrimate/tree/ios-screens).
  Режим скриншотов — ios/NutriMate/App/UIShot.swift (`-uiShot`, `-tab`, `-sheet`, `-onboarding`, `-tutorial`).
  Первый прогон: все экраны открылись, падений нет.

## 2026-11-10 (днём) · веб v14 · iOS v5
- iOS v5: Body dashboard (ИМТ-спидометр, топливо калорий, активность и цель). Цель калорий теперь BMR × активность ± цель.
- Веб v14: цель калорий = BMR × 1.375 (раньше был голый BMR — занижено).
- Новое правило базы: национальные продукты больше не добавляем; дальше — базовые продукты мира, экзотика, трендовые рецепты (моти и т.п.).

## 2026-11-10 (ночь 5) · веб v13 · iOS v4
- **iOS v4**: офлайн-чат с Нутриком (рецепты, сроки, хранение, заморозка, калории, покупки, нелюбимые продукты), история сохраняется.
- **Веб v13**: только данные (багов не поступало).
- +25 продуктов: Khvorost, Churchkhela, Zharkoe, Mimosa Salad, Shalgam Salad, Sirne, Orama, Sochniki, Mutton, Lamb Liver,
  Jida Berries, Alycha Cherry Plum, Vobla, Caspian Kilka, Koktal, Bryndza; США: Snickerdoodle Cookies, Grilled Cheese Sandwich,
  BLT Sandwich, Chicken Noodle Soup, Fish Tacos, Sweet Potato Casserole, Breakfast Burrito, Kettle Corn, Hush Puppies.
- +5 рецептов: Leftover Zharkoe Pot Roast (zw), Shalgam Turnip Salad, Sour Kefir Khvorost (zw), Leftover Chicken Noodle Soup (zw),
  Dorm Grilled Cheese with Tomato. Всего: 1326 продуктов, 106 рецептов (42 zero-waste).

## 2026-11-09 (ночь 4) · веб v12 · iOS v3
- **iOS v3**: Нутрик бегает, ест продукт в лапке, спотыкается и падает, радуется, говорит; сценки на действия; «рецепт дня» на Home; рецепт в утреннем уведомлении.
- **Веб v12**: только данные (багов не поступало).
- +29 продуктов: Suzma, Snezhok, Zhal, Lamb Ribs, Pastrami, Tandyr Samsa, Kystyby, Bublik, Dimlama, Chuchvara, Korean Carrot Salad,
  Funchoza Salad, Heh Fish, Achichuk Salad, Lula Kebab, Buckwheat Porridge, Oladi, Mannik, Medovik, Kisel; США: French Toast, Quesadilla,
  Buffalo Wings, Chicken Pot Pie, Biscuits and Gravy, Philly Cheesesteak, Peach Cobbler, Banana Pudding, S'mores.
- +5 рецептов: Leftover Plov Fried Rice (zw), Kystyby with Leftover Mash (zw), One-Pot Dimlama, Stale Bread French Toast (zw),
  Homemade Korean Carrot Salad. Всего: 1301 продукт, 101 рецепт (39 zero-waste).

## 2026-11-08 (ночь 3) · веб v11 · iOS v2
- **iOS v2**: экран Eco Impact с графиками, графики веса и калорий за неделю, туториал с Нутриком, уведомления в 9:00.
- **Веб v11**: только данные (сохранение уже работает с v10, багов не поступало).
- +26 продуктов: Sary Mai (топлёное масло), Chuchuk, Tary, Kattama, Chalap, Kozhe, Varenets, Aport Apple, Rowan Berry, Uzvar, Sbiten,
  Lobio, Bone Broth, Oatmeal, Overnight Oats; США: Hamburger Buns, Zucchini Bread, Funnel Cake, Key Lime Pie, Sweet Tea, Meatloaf,
  Clam Chowder, Jambalaya, Gumbo, Deviled Eggs, Sloppy Joe.
- +5 рецептов: Tary with Milk & Butter, Katyk Kozhe with Millet (zw), Stale Baursak Bread Pudding (zw), Dorm Lobio with Walnuts,
  Bruised Aport Apple Pastila (zw).

## 2026-11-07 (ночь 2) · веб v10 · iOS v1
- **Веб: данные больше не сбрасываются** — shared_preferences (localStorage): профиль, холодильник, дневник,
  вес, покупки, медали, статистика, отходы. Зарегистрированный пользователь сразу попадает на главный экран.
  Дневник калорий теперь по реальным датам (а не по сдвигу дня). В профиле — кнопка «Erase all data».
- **iOS v1** (SwiftUI): 5 вкладок, стеклянный таб-бар с «желейной» капсулой, живой фон, Нутрик на Canvas,
  холодильник со свежестью и свайпами, поиск по 1246 продуктам с категориями, рецепты из холодильника,
  дневник, список покупок, медали, сохранение в JSON. Сборка и релиз ios-latest — зелёные.
- +28 продуктов (сузбе, каймак, балкаймак, сулугуни, верблюжатина, карта, курдючный жир, сур-ет, лагман и кеспе,
  беляши, голубцы, холодец, тушпара, нарын, компот, казахский чай с молоком, пряники; США: American/Pimento Cheese,
  Buttermilk Biscuits, Pecan Pie, Pulled Pork, Grape Jelly, Pancake Mix, Cranberry Sauce…).
- +4 рецепта: Homemade Naryn, Tushpara Soup, Student Lagman Stir-Fry, Leftover Fruit Kompot (zw).

## 2026-11-07 · v9
- Проект иконок, этап 1: виджеты `Emo` / `FoodIcon` (lib/food_icons.dart, генерируется), 159 иконок Fluent 3D
  (128 px, ~5 КБ), предзагрузка в кэш при входе на главный экран. Заменены эмодзи в поиске, холодильнике,
  рецептах, покупках, логе, карточке продукта, достижениях, плитках главной.
- Свои 3D-иконки (tool/make_icons.py): редис, свёкла, репа, дайкон, гранат, карамбола, тофу ×3, темпе,
  чёрная икра, курт, баурсаки, иримшик, казы — вместо заглушек ⚪🟣🔴⭐⬜🟫⚫.
- +32 продукта (казахские: курт, иримшик, катык, кумыс, шубат, казы, шужук, жая, конина, баурсаки, тандырная лепёшка,
  шелпек, сушки, чак-чак, жент, бешбармак, куырдак, сорпа, талкан; США: Cream Soda, Graham Crackers, Toaster Pastries,
  Peanut Butter Cups, Tater Tots, Corn Dogs; новая категория **Baby Food** — 5 шт + Baby Yogurt).
- +5 рецептов: Home-Style Kuyrdak, Homemade Beshbarmak, Fluffy Baursaks, Savory Bread Strata (zw), Banana Oat Cookies (zw).

## Бэклог (по приоритету)
1. (пауза) Иконки, этап 2: убрать дубли по категориям. Идея: цветовые варианты Fluent-иконок (сдвиг оттенка для перцев,
   яблок, винограда), свои иконки для рыбы (55 шт на 🐟), трав 🌿 (52), консервов 🥫 (48), молочки 🥛 (42), сыров 🧀 (41), мяса 🥩.
3. Напоминание/баннер «съешь сегодня» + «рецепт дня» из того, что скоро испортится.
4. Тёмная тема в фирменных цветах.
5. Сканер штрихкодов + Open Food Facts (для полноценной версии).

## Известные проблемы
- Эмодзи внутри текстов (чат, снекбары) остаются шрифтовыми — это нормально.
