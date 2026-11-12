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

    static func lang(_ t: String) -> Lang {
        if t.range(of: "[әғқңөұүһі]", options: .regularExpression) != nil { return .kk }
        if t.range(of: "[а-яё]", options: .regularExpression) != nil { return .ru }
        return .en
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
            let sugg = p.unknownWord.map { store.db.search($0, category: nil).prefix(3).map { "\($0.emoji) \($0.name)" } } ?? []
            let tail = sugg.isEmpty
                ? tr("Try: \"add 2 eggs to fridge\".", "Попробуй так: «добавь 2 яйца в холодильник».", "Былай жазып көр: «тоңазытқышқа 2 жұмыртқа қос».")
                : tr("Did you mean: ", "Может, ты имел в виду: ", "Мүмкін, мынау: ") + sugg.joined(separator: ", ") + "?"
            return NutrikReply(text: tr("🙈 I couldn't find that product in my food base, so I didn't change anything. ",
                                        "🙈 Не нашёл такой продукт в базе, поэтому ничего не менял. ",
                                        "🙈 Бұл өнімді базадан таппадым, сондықтан ештеңе өзгертпедім. ") + tail, mood: .sad)
        }

        var lines: [String] = []
        for f in p.foods {
            switch p.kind {
            case .addFridge:
                let place = p.place ?? FoodDB.defaultStorage(f)
                store.add(f, storage: place, count: p.qty, quiet: true)
                let total = store.data.pantry.filter { $0.name == f.name && $0.storage == place }.reduce(0) { $0 + $1.qty }
                let where_ = tr(place.title.lowercased(),
                                place == .fridge ? "холодильник" : place == .freezer ? "морозилку" : "шкаф",
                                place == .fridge ? "тоңазытқышқа" : place == .freezer ? "мұздатқышқа" : "шкафқа")
                lines.append(tr("✅ Added \(f.emoji) \(f.name) ×\(p.qty) to your \(where_)", "✅ Добавил \(f.emoji) \(f.name) ×\(p.qty) в \(where_)",
                                "✅ \(f.emoji) \(f.name) ×\(p.qty) \(where_) қосылды") + (total > p.qty ? tr(" — now ×\(total).", " — теперь ×\(total).", " — енді ×\(total).") : "."))
            case .eat, .discard, .freeze:
                let rows = store.sortedPantry.filter { $0.name == f.name && (p.kind != .freeze || $0.storage != .freezer) }
                guard let g = rows.first else {
                    lines.append(tr("❌ There's no \(f.emoji) \(f.name) in your fridge — I didn't change anything.",
                                    "❌ \(f.emoji) \(f.name) нет в холодильнике — я ничего не менял.",
                                    "❌ Тоңазытқышта \(f.emoji) \(f.name) жоқ — ештеңе өзгертпедім."))
                    continue
                }
                let have = rows.reduce(0) { $0 + $1.qty }
                switch p.kind {
                case .eat:
                    let n = min(p.qty, have)
                    for _ in 0..<n { if let r = store.sortedPantry.first(where: { $0.name == f.name }) { store.eat(r.first.id, grams: 100, finished: true) } }
                    lines.append(tr("🍽️ Logged: you ate \(f.emoji) \(f.name) ×\(n) (≈\(f.kcal * n) kcal, 100 g each). ",
                                    "🍽️ Записал: ты съел \(f.emoji) \(f.name) ×\(n) (≈\(f.kcal * n) ккал, по 100 г). ",
                                    "🍽️ Жазып қойдым: \(f.emoji) \(f.name) ×\(n) жедің (≈\(f.kcal * n) ккал, әрқайсысы 100 г). ") + left(f, store, tr))
                case .discard:
                    let n = min(p.qty, have)
                    for _ in 0..<n {
                        if let r = store.sortedPantry.first(where: { $0.name == f.name }) {
                            store.throwAway(r.first.id, reason: r.daysLeft < 0 ? .expired : .spoiled)
                        }
                    }
                    lines.append(tr("🗑️ Marked \(f.emoji) \(f.name) ×\(n) as thrown away (oldest first). ",
                                    "🗑️ Отметил: \(f.emoji) \(f.name) ×\(n) выброшено (сначала старое). ",
                                    "🗑️ Белгіледім: \(f.emoji) \(f.name) ×\(n) тасталды (алдымен ескісі). ") + left(f, store, tr))
                default:
                    let units = rows.filter { $0.storage == g.storage }.reduce(0) { $0 + $1.qty }
                    store.freeze(g.first.id)
                    lines.append(tr("❄️ Moved \(f.emoji) \(f.name) ×\(units) to the freezer — good for ~3 months.",
                                    "❄️ Переложил \(f.emoji) \(f.name) ×\(units) в морозилку — хватит примерно на 3 месяца.",
                                    "❄️ \(f.emoji) \(f.name) ×\(units) мұздатқышқа салынды — шамамен 3 айға жетеді."))
                }
            }
        }
        let mood: NutrikMood = p.kind == .discard ? .sad : p.kind == .eat ? .eating : .cheer
        return NutrikReply(text: lines.joined(separator: "\n"), mood: mood)
    }

    private static func left(_ f: Food, _ store: AppStore, _ tr: (String, String, String) -> String) -> String {
        let n = store.data.pantry.filter { $0.name == f.name }.reduce(0) { $0 + $1.qty }
        return n > 0 ? tr("×\(n) left.", "Осталось ×\(n).", "×\(n) қалды.") : tr("None left.", "Больше не осталось.", "Енді қалмады.")
    }
}
