import Foundation

/// Честные команды-действия в чате (EN / RU / KK): «add 2 eggs to fridge», «добавь 2 яйца в холодильник»,
/// «тоңазытқышқа 2 жұмыртқа қос», «съел банан», «выбросил кефир», «заморозь курицу».
/// Действие реально выполняется в AppStore, а подтверждение пишется по факту (с количеством).
/// Если продукт не найден — честно говорим и предлагаем похожие. ИИ-сервер такие сообщения не получает.
enum NutrikActions {
    enum Kind { case addFridge, eat, discard, freeze }
    enum Lang { case en, ru, kk }

    struct Parsed {
        let kind: Kind
        let place: StorageKind?
        let qty: Int
        let foods: [Food]
        let lang: Lang
        let unknownWord: String?
    }

    // MARK: - Словарь: основы слов на русском и казахском → продукт базы (совпадение по началу слова)

    static let aliases: [(String, String)] = [
        // русский
        ("яйц", "Eggs"), ("яичк", "Eggs"), ("молок", "Milk"), ("хлеб", "White Bread"), ("батон", "White Bread"),
        ("яблок", "Apple"), ("картош", "Potato"), ("картоф", "Potato"), ("лук", "Onion"), ("морков", "Carrot"),
        ("помидор", "Tomato"), ("томат", "Tomato"), ("огур", "Cucumber"), ("куриц", "Chicken Breast"), ("курин", "Chicken Breast"),
        ("рис", "Rice"), ("сыр", "Cheddar Cheese"), ("сливочн", "Butter"), ("масл", "Butter"), ("сахар", "Sugar"),
        ("банан", "Banana"), ("кефир", "Kefir"), ("йогурт", "Yogurt"), ("мук", "Flour"), ("чай", "Black Tea"),
        ("греч", "Buckwheat"), ("макарон", "Pasta"), ("творог", "Cottage Cheese"), ("сметан", "Sour Cream"),
        ("апельсин", "Orange"), ("лимон", "Lemon"), ("чеснок", "Garlic"), ("капуст", "Cabbage"), ("говядин", "Beef"),
        ("свинин", "Pork"), ("фарш", "Ground Beef"), ("гриб", "Mushrooms"), ("клубник", "Strawberry"), ("авокадо", "Avocado"),
        ("шпинат", "Spinach"), ("перец", "Bell Pepper"), ("перц", "Bell Pepper"), ("пельмен", "Pelmeni"), ("айран", "Ayran"),
        ("лосос", "Salmon"), ("семг", "Salmon"), ("овсян", "Oats"), ("мёд", "Honey"), ("мед", "Honey"), ("арбуз", "Watermelon"),
        ("виноград", "Grapes"), ("груш", "Pear"), ("салат", "Lettuce"), ("кукуруз", "Corn"), ("свекл", "Beetroot"),
        ("свёкл", "Beetroot"), ("майонез", "Mayonnaise"), ("соль", "Salt"), ("курт", "Kurt"),
        // қазақша
        ("жұмыртқа", "Eggs"), ("сүт", "Milk"), ("нан", "White Bread"), ("алма", "Apple"), ("картоп", "Potato"),
        ("пияз", "Onion"), ("сәбіз", "Carrot"), ("қызанақ", "Tomato"), ("қияр", "Cucumber"), ("тауық", "Chicken Breast"),
        ("күріш", "Rice"), ("ірімшік", "Cheddar Cheese"), ("қант", "Sugar"), ("ұн", "Flour"), ("шай", "Black Tea"),
        ("қарақұмық", "Buckwheat"), ("сүзбе", "Cottage Cheese"), ("қаймақ", "Sour Cream"), ("сарымсақ", "Garlic"),
        ("қырыққабат", "Cabbage"), ("сиыр", "Beef"), ("саңырауқұлақ", "Mushrooms"), ("құлпынай", "Strawberry"),
        ("қарбыз", "Watermelon"), ("жүзім", "Grapes"), ("алмұрт", "Pear"), ("жүгері", "Corn"), ("қызылша", "Beetroot"),
        ("тұз", "Salt"), ("құрт", "Kurt"),
    ]

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10, "a dozen": 12, "dozen": 12,
        "один": 1, "одну": 1, "одна": 1, "два": 2, "две": 2, "три": 3, "четыре": 4, "пять": 5, "шесть": 6, "десяток": 10, "десять": 10,
        "бір": 1, "екі": 2, "үш": 3, "төрт": 4, "бес": 5, "алты": 6,
    ]

    static func words(_ t: String) -> [String] {
        t.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    /// Язык ответа: казахские буквы → kk; кириллица → ru (или kk, если приложение на казахском);
    /// латиница → en, но короткое «hi / ok / thanks» или одни эмодзи → язык приложения.
    static func replyLang(_ message: String) -> AppLang {
        let t = message.lowercased()
        if t.range(of: "[әғқңөұүһі]", options: .regularExpression) != nil { return .kk }
        if t.range(of: "[а-яё]", options: .regularExpression) != nil { return AppLang.current == .kk ? .kk : .ru }
        let letters = t.filter(\.isLetter)
        if letters.isEmpty { return AppLang.current }
        if letters.count <= 12, t.range(of: #"^\W*(hi|hello|hey|yo|ok|okay|thanks|thank you|thx|lol|yes|no)\W*$"#, options: .regularExpression) != nil {
            return AppLang.current
        }
        return .en
    }

    static func lang(_ t: String) -> Lang {
        switch replyLang(t) {
        case .kk: return .kk
        case .ru: return .ru
        case .en: return .en
        }
    }

    /// Название продукта на языке ответа (перевод из базы; нет — английское).
    static func display(_ f: Food, _ L: Lang) -> String {
        switch L {
        case .ru: return (f.ru?.isEmpty == false ? f.ru : nil) ?? f.name
        case .kk: return (f.kk?.isEmpty == false ? f.kk : nil) ?? f.name
        case .en: return f.name
        }
    }

    /// Продукты по переводам названий из базы (foods.json ru/kk): целиком или по основе слова.
    static func translatedFoods(_ t: String, db: FoodDB) -> [Food] {
        let ws = words(t)
        var hits: [(Food, Int)] = []
        for f in db.foods {
            for tr in [f.ru, f.kk].compactMap({ $0?.lowercased() }) where tr.count >= 3 {
                if t.contains(tr) { hits.append((f, tr.count + 10)); break }
                let parts = words(tr)
                // одно слово: «помидоры» ↔ «помидор», «яйца» ↔ «яйцо» — общая основа (без 1–2 последних букв)
                if parts.count == 1, tr.count >= 5 {
                    let stem = String(tr.prefix(tr.count - 2))
                    if ws.contains(where: { $0.hasPrefix(stem) && $0.count <= tr.count + 3 }) { hits.append((f, stem.count)); break }
                }
            }
        }
        var out: [Food] = []
        for (f, _) in hits.sorted(by: { $0.1 > $1.1 }) where !out.contains(f) { out.append(f) }
        return Array(out.prefix(3))
    }

    /// Продукты, названные по-русски или по-казахски (по началу слова, «яйца» → Eggs).
    static func aliasFoods(_ t: String, db: FoodDB) -> [Food] {
        var out: [Food] = []
        for w in words(t) {
            guard let hit = aliases.filter({ w.hasPrefix($0.0) }).max(by: { $0.0.count < $1.0.count }),
                  let f = db.byName[hit.1], !out.contains(f) else { continue }
            // «лук» не должен ловить «лукошко»: короткие основы — только почти целое слово
            if hit.0.count <= 3 && w.count > hit.0.count + 3 { continue }
            out.append(f)
        }
        return out
    }

    /// Все продукты в сообщении: английские названия базы + русские/казахские.
    static func foods(in t: String, db: FoodDB) -> [Food] {
        var list = NutrikBrain.mentioned(t, db: db)
        for f in aliasFoods(t, db: db) where !list.contains(f) { list.append(f) }
        if list.isEmpty || t.range(of: "[а-яёәғқңөұүһі]", options: .regularExpression) != nil {
            for f in translatedFoods(t, db: db) where !list.contains(f) { list.append(f) }
        }
        return Array(list.prefix(3))
    }

    // MARK: - Разбор

    static func parse(_ message: String, db: FoodDB) -> Parsed? {
        let t = message.lowercased()
        let ws = words(t)
        // "=слово" — только целое слово, "a b" — подстрока, иначе — начало любого слова
        func has(_ keys: [String]) -> Bool {
            keys.contains { k in
                if k.hasPrefix("=") { return ws.contains(String(k.dropFirst())) }
                return k.contains(" ") ? t.contains(k) : ws.contains { $0.hasPrefix(k) }
            }
        }
        let question = t.contains("?") || has(["=can", "=how", "=should", "=what", "=why", "можно", "=как", "=что", "=почему", "стоит", "=бола", "қалай", "=не", "неге"])

        let fridgeWords = ["fridge", "холодильник", "тоңазытқыш"]
        let freezerWords = ["freezer", "морозилк", "морозильник", "мұздатқыш"]
        let pantryWords = ["pantry", "cupboard", "шкаф", "кладов"]
        let place: StorageKind? = has(freezerWords) ? .freezer : has(fridgeWords) ? .fridge : has(pantryWords) ? .pantry : nil

        let shopping = has(["shopping", "=list", "список", "покуп", "тізім"])
        let addVerbs = ["=add", "=put", "=bought", "добавь", "добавить", "добавил", "положи", "положил", "=купил", "=купила", "=қос", "=қосу", "=сал", "=салдым", "=салып", "сатып алдым"]
        let kind: Kind?
        if question {
            kind = nil
        } else if has(["=threw", "throw away", "thrown", "=binned", "=trashed", "выбросил", "выкинул", "выброси", "тастадым", "тастап"]) {
            kind = .discard
        } else if has(["i ate", "=ate", "=eaten", "i had", "съел", "скушал", "=поел", "=поела", "жедім", "жеп қойдым"]) {
            kind = .eat
        } else if has(["=freeze", "=froze", "заморозь", "заморозил", "заморозить", "мұздат"]) && place != .fridge {
            kind = .freeze
        } else if !shopping && has(addVerbs) {
            kind = .addFridge
        } else {
            kind = nil
        }
        guard let kind else { return nil }

        // количество: первое число 1…99 или слово-число
        var qty = 1
        if let n = ws.compactMap({ Int($0) }).first(where: { $0 > 0 && $0 < 100 }) { qty = n }
        else if let w = numberWords.first(where: { $0.key.contains(" ") ? t.contains($0.key) : ws.contains($0.key) }) { qty = w.value }

        let found = foods(in: t, db: db)
        // без продукта: только явное «добавь …» отвечаем честно «не нашёл»; «съел что-то» отдаём обычному чату
        if found.isEmpty && kind != .addFridge { return nil }

        let stop: Set<String> = ["add", "put", "to", "my", "the", "in", "into", "fridge", "freezer", "pantry", "please", "i", "ate", "threw", "away",
                                 "freeze", "bought", "добавь", "в", "мой", "холодильник", "морозилку", "положи", "пожалуйста", "съел", "выбросил",
                                 "заморозь", "купил", "қос", "тоңазытқышқа", "мұздатқышқа", "жедім", "тастадым"]
        let unknown = ws.filter { !stop.contains($0) && Int($0) == nil && numberWords[$0] == nil && $0.count > 2 }.max { $0.count < $1.count }
        return Parsed(kind: kind, place: place, qty: qty, foods: found, lang: lang(t), unknownWord: unknown)
    }

    static func isAction(_ message: String, db: FoodDB) -> Bool { parse(message, db: db) != nil }

    // MARK: - Выполнение (по факту, с честным текстом)

    static func handle(_ message: String, store: AppStore) -> NutrikReply? {
        guard let p = parse(message, db: store.db) else { return nil }
        let L = p.lang
        func tr(_ en: String, _ ru: String, _ kk: String) -> String { L == .ru ? ru : L == .kk ? kk : en }

        guard !p.foods.isEmpty else {
            let sugg = p.unknownWord.map { store.db.search($0, category: nil).prefix(3).map { "\($0.emoji) \(display($0, L))" } } ?? []
            let tail = sugg.isEmpty
                ? tr("Try: \"add 2 eggs to fridge\".", "Попробуй так: «добавь 2 яйца в холодильник».", "Былай жазып көр: «тоңазытқышқа 2 жұмыртқа қос».")
                : tr("Did you mean: ", "Может, ты имел в виду: ", "Мүмкін, мынау: ") + sugg.joined(separator: ", ") + "?"
            return NutrikReply(text: tr("🙈 I couldn't find that product in my food base, so I didn't change anything. ",
                                        "🙈 Не нашёл такой продукт в базе, поэтому ничего не менял. ",
                                        "🙈 Бұл өнімді базадан таппадым, сондықтан ештеңе өзгертпедім. ") + tail, mood: .sad)
        }

        let lines = p.foods.map { run(p.kind, place: p.place, qty: p.qty, food: $0, lang: L, store: store) }
        let mood: NutrikMood = p.kind == .discard ? .sad : p.kind == .eat ? .eating : .cheer
        return NutrikReply(text: lines.joined(separator: "\n"), mood: mood)
    }

    /// Одно действие с одним продуктом — выполняется по-настоящему, текст пишется по факту.
    static func run(_ kind: Kind, place: StorageKind?, qty: Int, food f: Food, lang L: Lang, store: AppStore) -> String {
        func tr(_ en: String, _ ru: String, _ kk: String) -> String { L == .ru ? ru : L == .kk ? kk : en }
        let nm = display(f, L)
        switch kind {
        case .addFridge:
            let place = place ?? FoodDB.defaultStorage(f)
            store.add(f, storage: place, count: qty, quiet: true)
            let total = store.data.pantry.filter { $0.name == f.name && $0.storage == place }.reduce(0) { $0 + $1.qty }
            let where_ = tr(place.key.lowercased(),
                            place == .fridge ? "холодильник" : place == .freezer ? "морозилку" : "шкаф",
                            place == .fridge ? "тоңазытқышқа" : place == .freezer ? "мұздатқышқа" : "шкафқа")
            return (tr("✅ Added \(f.emoji) \(nm) ×\(qty) to your \(where_)", "✅ Добавил \(f.emoji) \(nm) ×\(qty) в \(where_)",
                            "✅ \(f.emoji) \(nm) ×\(qty) \(where_) қосылды") + (total > qty ? tr(" — now ×\(total).", " — теперь ×\(total).", " — енді ×\(total).") : "."))
        case .eat, .discard, .freeze:
            let rows = store.sortedPantry.filter { $0.name == f.name && (kind != .freeze || $0.storage != .freezer) }
            guard let g = rows.first else {
                return (tr("❌ There's no \(f.emoji) \(nm) in your fridge — I didn't change anything.",
                                "❌ \(f.emoji) \(nm) нет в холодильнике — я ничего не менял.",
                                "❌ Тоңазытқышта \(f.emoji) \(nm) жоқ — ештеңе өзгертпедім."))
            }
            let have = rows.reduce(0) { $0 + $1.qty }
            switch kind {
            case .eat:
                let n = min(qty, have)
                for _ in 0..<n { if let r = store.sortedPantry.first(where: { $0.name == f.name }) { store.eat(r.first.id, grams: 100, finished: true) } }
                return (tr("🍽️ Logged: you ate \(f.emoji) \(nm) ×\(n) (≈\(f.kcal * n) kcal, 100 g each). ",
                                "🍽️ Записал: ты съел \(f.emoji) \(nm) ×\(n) (≈\(f.kcal * n) ккал, по 100 г). ",
                                "🍽️ Жазып қойдым: \(f.emoji) \(nm) ×\(n) жедің (≈\(f.kcal * n) ккал, әрқайсысы 100 г). ") + left(f, store, tr))
            case .discard:
                let n = min(qty, have)
                for _ in 0..<n {
                    if let r = store.sortedPantry.first(where: { $0.name == f.name }) {
                        store.throwAway(r.first.id, reason: r.daysLeft < 0 ? .expired : .spoiled)
                    }
                }
                return (tr("🗑️ Marked \(f.emoji) \(nm) ×\(n) as thrown away (oldest first). ",
                                "🗑️ Отметил: \(f.emoji) \(nm) ×\(n) выброшено (сначала старое). ",
                                "🗑️ Белгіледім: \(f.emoji) \(nm) ×\(n) тасталды (алдымен ескісі). ") + left(f, store, tr))
            default:
                let units = rows.filter { $0.storage == g.storage }.reduce(0) { $0 + $1.qty }
                store.freeze(g.first.id)
                return (tr("❄️ Moved \(f.emoji) \(nm) ×\(units) to the freezer — good for ~3 months.",
                                "❄️ Переложил \(f.emoji) \(nm) ×\(units) в морозилку — хватит примерно на 3 месяца.",
                                "❄️ \(f.emoji) \(nm) ×\(units) мұздатқышқа салынды — шамамен 3 айға жетеді."))
            }
        }
    }

    // MARK: - Действия, предложенные ИИ-сервером ({type, name, qty}); имя проверяем по базе

    struct ServerAction: Decodable { let type: String; let name: String; let qty: Int? }

    static func resolve(_ name: String, db: FoodDB) -> Food? {
        let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let f = db.byName[n] { return f }
        let low = n.lowercased()
        if let f = db.foods.first(where: { $0.name.lowercased() == low }) { return f }
        // множественное / единственное число: "egg" → "Eggs", "tomatoes" → "Tomato"
        for v in [low + "s", low + "es", String(low.dropLast()), String(low.dropLast(2))] where v.count > 2 {
            if let f = db.foods.first(where: { $0.name.lowercased() == v }) { return f }
        }
        return aliasFoods(low, db: db).first ?? NutrikBrain.mentioned(low, db: db).first
    }

    /// Выполнить действия ИИ. Возвращает честное подтверждение (что реально сделано / что нет).
    static func perform(_ actions: [ServerAction], userText: String, store: AppStore) -> NutrikReply? {
        let L = lang(userText.lowercased())
        func tr(_ en: String, _ ru: String, _ kk: String) -> String { L == .ru ? ru : L == .kk ? kk : en }
        var lines: [String] = []
        var kinds: [Kind] = []
        for a in actions.prefix(5) {
            let qty = min(99, max(1, a.qty ?? 1))
            guard let f = resolve(a.name, db: store.db) else {
                let sugg = store.db.search(a.name, category: nil).prefix(3).map { "\($0.emoji) \(display($0, L))" }
                lines.append(tr("🙈 I couldn't find \"\(a.name)\" in my food base, so I didn't change anything.",
                                "🙈 Не нашёл «\(a.name)» в базе продуктов, поэтому ничего не менял.",
                                "🙈 «\(a.name)» өнімін базадан таппадым, сондықтан ештеңе өзгертпедім.")
                             + (sugg.isEmpty ? "" : tr(" Did you mean: ", " Может, это: ", " Мүмкін, мынау: ") + sugg.joined(separator: ", ") + "?"))
                continue
            }
            switch a.type {
            case "add_fridge": lines.append(run(.addFridge, place: .fridge, qty: qty, food: f, lang: L, store: store)); kinds.append(.addFridge)
            case "add_freezer": lines.append(run(.addFridge, place: .freezer, qty: qty, food: f, lang: L, store: store)); kinds.append(.addFridge)
            case "eat": lines.append(run(.eat, place: nil, qty: qty, food: f, lang: L, store: store)); kinds.append(.eat)
            case "discard": lines.append(run(.discard, place: nil, qty: qty, food: f, lang: L, store: store)); kinds.append(.discard)
            case "freeze": lines.append(run(.freeze, place: nil, qty: qty, food: f, lang: L, store: store)); kinds.append(.freeze)
            case "add_shopping":
                let had = store.data.shopping.contains(f.name)
                if !had { store.addShopping([f.name]) }
                lines.append(had ? tr("🛒 \(f.emoji) \(display(f, L)) is already on your shopping list.", "🛒 \(f.emoji) \(display(f, L)) уже есть в списке покупок.", "🛒 \(f.emoji) \(display(f, L)) сатып алу тізімінде бар.")
                                 : tr("🛒 Added \(f.emoji) \(display(f, L)) to your shopping list.", "🛒 Добавил \(f.emoji) \(display(f, L)) в список покупок.", "🛒 \(f.emoji) \(display(f, L)) сатып алу тізіміне қосылды."))
            default: continue
            }
        }
        guard !lines.isEmpty else { return nil }
        let mood: NutrikMood = kinds.contains(.discard) ? .sad : kinds.contains(.eat) ? .eating : .cheer
        return NutrikReply(text: lines.joined(separator: "\n"), mood: mood)
    }

    private static func left(_ f: Food, _ store: AppStore, _ tr: (String, String, String) -> String) -> String {
        let n = store.data.pantry.filter { $0.name == f.name }.reduce(0) { $0 + $1.qty }
        return n > 0 ? tr("×\(n) left.", "Осталось ×\(n).", "×\(n) қалды.") : tr("None left.", "Больше не осталось.", "Енді қалмады.")
    }
}
