# NutriMate — журнал ночного агента

## Текущее состояние
- Веб: **v34** · iOS: **v31** (нумерация продолжает версии из DartPad: v1–v15 были там) · продуктов: **1882** · рецептов: **176** (zero-waste: 80) · переводы ru/kk: **все** названия продуктов и рецептов + шаги всех рецептов · строк интерфейса: iOS 648 ключей, веб ~280 своих + общие
- ИИ-сервер работает (Cloudflare Workers AI, бесплатно); с v10 предлагает действия только структурированно (`actions`), приложение выполняет само.
- Главная версия — iOS (ios/, журнал ios/NIGHTLY_NOTES_IOS.md, жалобы ios/BUILD_ERRORS.md). Веб — баги и перенос закрытых жалоб.
- Единая база: `python3 tool/export_data.py` проверяет дубли/ингредиенты и пишет ios/NutriMate/Resources/foods.json.
- Локально Flutter недоступен → компиляцию проверяет GitHub Actions.

## 2026-11-13 (двенадцатый запуск) · веб v34 · iOS v31
- **iOS v31: умный список покупок** — по отделам магазина, «🏠 Дома: ×3 · осталось 2 дня» у того, что уже есть, баннер
  «Уже дома: N — убрать из списка» (с оценкой сэкономленных денег), «🗑️ недавно выброшено 2 раза — возьми упаковку поменьше».
- **Веб v34:** те же подсказки в строках списка покупок («дома ×N · срок», «выброшено N раз»).
- +27 продуктов, +3 рецепта (Cowboy Caviar, Stale Tortilla Chilaquiles (zw), Soft-Eggplant Baba Ganoush (zw)), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: тёмная тема, «поделиться неделей», «шт.» в ингредиентах, остатки, группировка списка по отделам.

## 2026-11-13 (одиннадцатый запуск) · веб v33 · iOS v30
- **iOS v30: добавить списком или по фото чека** (распознавание на телефоне, EN/RU/KK, количество, место, галочки, «Отменить»).
- **Веб v33: «Списком»** на вкладке Поиск — вставляешь «2 яйца, молоко, хлеб», проверяешь количество, всё добавляется сразу
  (`QuickAddParse` — тот же разбор, что в iOS, без фото). Покупки из списка считаются купленными.
- +25 продуктов, +3 рецепта (Leftover Rice Tuna Bowl (zw), Sheet-Pan Chickpea Shawarma Bowl (zw), Overripe Banana Baked Oats (zw)), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: тёмная тема, «поделиться неделей», «шт.» в ингредиентах, остатки.

## 2026-11-12 (десятый запуск) · веб v32 · iOS v29
- **iOS v29 / веб v32: план «доедаем всё»** — продукты со сроком 0–4 дня раскладываются по 3 дням: рецепт дня (спасает самое срочное,
  докупить ≤ 2), «заморозь сегодня», «просто съешь», кнопка «недостающее — в покупки». Веб: класс `UseUpPlan` + `planSheet`,
  вход — бордовая карточка над рецептами (фильтр «Все»). Алгоритм одинаковый с iOS.
- +27 продуктов, +3 рецепта (Crispy Rice Paper Dumplings (zw), Gochujang Butter Noodles, Spanakopita Quesadilla (zw)), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: тёмная тема (цвета — const по всему файлу, нужен аккуратный перевод на тему), «поделиться неделей», «шт.» в ингредиентах, остатки.

## 2026-11-12 (девятый запуск) · веб v31 · iOS v28
- **iOS v28 / веб v31: «Я открыл(а)»** — открытая упаковка получает срок «после вскрытия» (молоко 5 дней, консервы 3, сок 7,
  колбаса 4…), метку «🔓 открыто», из шкафа переезжает в холодильник; правила одинаковые в iOS (`FoodDB.openedRule`) и вебе
  (`openedDays`). Веб хранит дату вскрытия 6-м полем строки холодильника (старые сохранения читаются как раньше).
- +29 продуктов, +4 рецепта (Crispy Pork Katsu Bowl, Whole Roasted Branzino with Herb Stems (zw), Sheet-Pan Andouille Shrimp Bake,
  Leftover-Veg Masoor Khichdi (zw)), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: тёмная тема, «поделиться неделей», «шт.» в ингредиентах.

## 2026-11-12 (восьмой запуск) · веб v30 · iOS v27
- iOS v27: остатки после готовки — «🥡 Убрать N порций в холодильник» (отдельная строка, 3 дня, по порциям), медаль «Герой остатков».
- Веб v30: только данные — +23 продукта, +3 рецепта (Green Goddess Salad, Sheet-Pan Crispy Gnocchi (zw), Za'atar Labneh Flatbread), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: остатки (нужен «съели N из M порций» в рецепте), тёмная тема, «поделиться неделей», «шт.» в ингредиентах.

## 2026-11-12 (седьмой запуск) · веб v29 · iOS v26
- iOS v26 и **веб v29: валюта** — деньги (спасено, под угрозой, выброшено) в ₸ / $ / € / ₽. Хранятся по-прежнему в долларах,
  показ по примерному курсу (520 ₸, 0.86 €, 80 ₽ за $). По умолчанию тенге для ru/kk (и для региона KZ на iOS), иначе доллар;
  выбор — Profile → «Язык и валюта» (iOS) / чипы «Валюта» в профиле (веб). Новое поле `currency` (мягко, старые сохранения не ломаются).
- +35 продуктов, +5 рецептов (Feta Fried Eggs, Cottage Cheese Ice Cream (zw), Crispy Rice Salad (zw), Cabbage Okonomiyaki (zw),
  Flank Steak Tacos with Zhoug), ru/kk + шаги.
- ИИ-сервер без изменений (последний деплой и smoke-тест — успешно).
- Бэклог веба: тёмная тема, «поделиться неделей», «шт.» в ингредиентах.

## 2026-11-12 (шестой запуск) · веб v28 · iOS v25
- iOS v25: рецепт на 1–12 порций (граммы, режим готовки и списание по масштабу), штучные продукты списываются по количеству.
- **Веб v28**: «Я приготовил(а)» списывает штучные продукты по количеству с учётом выбранных порций (`pieceGrams`, как в iOS):
  омлет на двоих — 6 яиц; зубчик чеснока не съедает всю головку.
- +32 продукта, +4 рецепта (Crispy Smashed Sunchokes, Broccoli Stem Fritters (zw), Rainbow Chard Frittata (zw), Pesto Eggs on Sourdough), ru/kk.
- ИИ-сервер без изменений, последний деплой и smoke-тест — успешно.
- Бэклог веба: тёмная тема, «поделиться неделей», «шт.» в ингредиентах.

## 2026-11-12 (пятый запуск) · веб v27 · iOS v24
- iOS v24 и **веб v27: режим готовки по шагам** — на вебе кнопка «Готовить по шагам» в рецепте → `CookModePage`: шаг крупно,
  листание/«Далее», таймеры из текста шага (обратный отсчёт, +1 мин, отмена, Нутрик говорит «время вышло»), финиш —
  «Я приготовил(а) · N ккал» (те же порции, что выбраны в рецепте), отмена через плашку как обычно.
- +32 продукта, +4 рецепта (Dense Bean Salad (zw), Jerk Chicken Thighs, Shirataki Leftover-Veg Stir-Fry (zw), Garlic Butter Enoki), ru/kk.
- ИИ-сервер без изменений, последний деплой и smoke-тест — успешно.
- Бэклог веба: тёмная тема, «поделиться неделей».

## 2026-11-12 (четвёртый запуск) · веб v26 · iOS v23
- iOS v23 и **веб v26: «Отменить»** после съел / выбросил / заморозил / отдал / приготовил (на вебе — кнопка в плашке снизу,
  5 с; снимок состояния через toJson → `AppState.undo()`, разбор сохранения вынесен в `_apply`).
- +25 продуктов, +4 рецепта (Roasted Red Pepper Pasta, Muhammara (zw), Frisée Salad with Bacon and Egg (zw), Fregola with Clams), ru/kk.
- Бэклог веба: тёмная тема, «поделиться неделей».

## 2026-11-12 (третий запуск) · веб v25 · iOS v22
- iOS v22: «Поделиться неделей» картинкой, список покупок — «Поделиться» и чипы «Часто ешь — а дома нет».
- Веб v25: +32 продукта, +5 рецептов (Tteokbokki, Carrot-Top Pesto Pasta (zw), Fresh Spring Rolls, Pearl Couscous
  Leftover-Veg Salad (zw), Buffalo Cauliflower Bites (zw)), ru/kk названия и шаги.
- Бэклог веба: тёмная тема, «поделиться неделей», вёрстка длинных ru/kk строк.

## 2026-11-12 (ночь на 13.11, второй запуск) · веб v23–v24 · iOS v21
- **Веб v24**: календарь «Срок на упаковке» и системные кнопки Flutter — на языке приложения (flutter_localizations, ru/kk).
- Веб v23 / iOS v21: +34 продукта, +4 рецепта (Mentaiko Spaghetti, Orecchiette with Broccoli Rabe (zw), Little Gem Caesar
  with Stale-Bread Croutons (zw), Roasted Carrots with Pomegranate Molasses (zw)), ru/kk названия и шаги.
- Бэклог веба: тёмная тема, проверить вёрстку длинных ru/kk строк.

## 2026-11-12 (ночь на 13.11) · веб v22 · iOS v20
- iOS v20: тёмная тема (Profile → Оформление: Day / Night / Auto).
- **Веб v22**: офлайн-ответы Нутрика (MockAiService) — на русском и казахском; понимает вопросы на трёх языках
  (привет/сәлем, калории, «есть ли…/бар ма», заморозка, хранение, сроки, «что приготовить/не пісірейін», «ещё/тағы»,
  «не люблю X / X ұнамайды») и названия продуктов на любом языке (короткие — только целым словом: «oca» ≠ «avocado»).
- +30 продуктов, +4 рецепта (Smashed Potatoes with Aioli, Chana Dal Tadka, Steak with Herb-Stem Chimichurri (zw),
  XO Sauce Egg Noodles), ru/kk.
- Бэклог веба: тёмная тема, проверить вёрстку длинных ru/kk строк.

## 2026-11-12 (поздний вечер) · веб v21 · iOS v19
- **Веб v21 — три языка (EN/RU/KK)**: `lib/l10n.dart` (`tr('English', [args])` с `{0}`, `trp(n, 'one|other')` — русские формы
  «день/дня/дней», `tn(name)` — продукт/рецепт/категория, `trSteps`, `trTime`, `trStaples`, `fmtDate` по-русски/казахски) +
  `lib/l10n_data.dart` (генерирует `python3 tool/export_web_l10n.py` из tool/l10n/*.json, translations_src.txt и
  recipe_steps_l10n.json; падает, если у tr('…') в коде нет перевода). Первый экран регистрации — крупные карточки
  🇬🇧/🇷🇺/🇰🇿, Нутрик здоровается на выбранном; Profile → Language — смена сразу. Поле `language` в сохранении
  (мягко; по умолчанию язык браузера, если ru/kk). Переведены: регистрация, туториал, реплики Нутрика, Home, Fridge,
  Search (ищет на 3 языках), Recipes + шаги, Eco, Weight, Shopping, Medals, Profile, советы, причины выброса.
  ИИ получает `context.language`. Пока по-английски: офлайн-ответы веб-чата (MockAiService), системный выбор даты.
- iOS v19: +25 продуктов, +3 рецепта, специи/время рецепта на языке приложения, снимок 18-recipe.
- +25 продуктов (Burdock Root, Yardlong Beans, Water Spinach, Luffa, Garlic Chives, Lemon Balm, Black Truffle, Nameko,
  Chicken of the Woods, Jujube, Wax Apple, Pepino Melon, Kiwiberries, Saskatoon Berries, Guanciale, Nduja, Beef Short Ribs,
  Oxtail, Barramundi, Cuttlefish, Sea Urchin, Ancho Chiles, Peanut Oil, Corn Syrup, Spam); +3 рецепта: Spam Musubi,
  Nduja Burrata Rigatoni, Garlic Water Spinach Stir-Fry (zw).
- Бэклог веба: офлайн-ответы чата на ru/kk, проверить вёрстку длинных русских/казахских строк (снимков веба нет — сайт
  из песочницы не открывается).

## 2026-11-12 (вечер) · веб v20 · iOS v18
- iOS v18: переведены все оставшиеся ~950 названий продуктов и шаги всех рецептов (ru/kk); Recipes легче; Edit profile — подпись не под таб-баром.
- Веб v20: одинаковые продукты складываются (жалоба 2 на вебе): одна строка «×N», −/＋, «N batches», съел/выбросил — сначала старая партия;
  данные не мигрируют (каждая штука — по-прежнему отдельная запись, складывается только отображение).
- +33 продукта (Sugar Apple, Sudachi, Greengage, Damson, Sloe Berries, Nettles, Beech Mushrooms, Sea Grapes, Borlotti Beans,
  Sichuan Peppercorns, Nigella Seeds, Ajwain, Asafoetida, Annatto Seeds, Kewpie Mayo, Mole Paste, Shrimp Paste, Doubanjiang,
  Shaoxing Wine, Chinkiang Vinegar, Moringa/Spirulina Powder, Lap Cheong, Char Siu Pork, Hojicha, Horchata, Comté, Fontina,
  Taleggio, Raclette Cheese, Queso Fresco, Okara, Yuba); +3 рецепта: Mapo Tofu, Char Siu Leftover Fried Rice (zw), Viral Cucumber Kewpie Salad (zw).
- Бэклог веба: три языка интерфейса (названия уже переведены в базе).

## 2026-11-12 (ночь) · веб v19 · iOS v17
- iOS v17: три языка EN/RU/KK во всём приложении (жалоба 3 — все жалобы 12.11 закрыты), Home 21 → 60 fps (Нутрик замирает при прокрутке).
- Сервер: язык приложения в промпте; метка ACTIONS кириллицей больше не теряет действие (казахский smoke-тест ✅).
- Веб v19 (только данные): +25 продуктов — Watermelon Radish, Dandelion Greens, Purslane, Persian Cucumbers, Tatsoi,
  Anaheim Pepper, Mini Sweet Peppers, Cremini Mushrooms, Escarole, Matsutake, Holy Basil, Cara Cara Orange, Cotton Candy
  Grapes, Red Banana, Tayberry, Stracciatella, Oaxaca Cheese, Langoustines, Bucatini, Pappardelle, Fonio, Milk Bread,
  Calabrian Chili Paste, Coconut Aminos, Preserved Lemons, Aleppo Pepper; +3 рецепта: Viral Pasta alla Vodka,
  Stracciatella Tomato Toast (zw), Clean-Out Egg Muffins (zw). Переводы: +374 продукта, все рецепты.
  export_data.py: рецепт с тем же названием, что и продукт, теперь тоже получает перевод.
- Бэклог веба: складывание одинаковых продуктов, три языка интерфейса.

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
