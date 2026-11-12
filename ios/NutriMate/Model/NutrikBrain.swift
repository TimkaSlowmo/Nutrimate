import Foundation

/// «AI-чат» Нутрика: работает без интернета и ключей — правила + данные холодильника (как MockAiService в вебе).
struct NutrikReply {
    var text: String
    var mood: NutrikMood = .talk
    /// Рецепт, который можно открыть кнопкой под ответом
    var recipe: String? = nil
}

enum NutrikBrain {
    /// Подсказки в чате (ключи переводов; показывать и отправлять через L(x) — Нутрик понимает все три языка)
    static let suggestions = [
        LK("What can I cook?"), LK("What expires soon?"), LK("What's in my fridge?"), LK("How to store tomatoes?"),
        LK("Add 2 eggs to fridge"), LK("Can I freeze bread?"), LK("Calories today"), LK("My eco impact"), LK("Add milk to shopping list"),
        LK("I don't like onion"), LK("Tell me a joke"),
    ]

    private static let jokes = [
        LK("Why did the tomato blush? It saw the salad dressing! 🍅"),
        LK("I tried to run to the fridge, but my legs are only 2 cm long. I'm still on my way. 🐾"),
        LK("What do you call cheese that isn't yours? Nacho cheese! 🧀"),
        LK("Bread told me a secret. I can't share it — it's a little crumby. 🍞"),
        LK("Kurt is my favourite snack: it lasts for months, just like my naps. 😴"),
        LK("Why don't eggs tell jokes? They'd crack each other up! 🥚"),
    ]

    /// Продукты из базы, упомянутые в сообщении: сначала самые длинные совпадения названий.
    static func mentioned(_ t: String, db: FoodDB) -> [Food] {
        var exact: [Food] = []
        for f in db.foods.sorted(by: { $0.name.count > $1.name.count }) {
            let n = f.name.lowercased()
            if t.contains(n) && !exact.contains(where: { $0.name.lowercased().contains(n) }) {
                exact.append(f)
                if exact.count == 3 { break }
            }
        }
        if !exact.isEmpty { return exact }
        // мягкое совпадение: «tomatoes» → Tomato, «eggs» → Eggs
        let words = t.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count > 3 }
        let stems = words.map { w -> String in
            if w.hasSuffix("oes") { return String(w.dropLast(2)) }
            if w.hasSuffix("ies") { return String(w.dropLast(3)) + "y" }
            if w.hasSuffix("s") { return String(w.dropLast()) }
            return w
        }
        var soft: [Food] = []
        for stem in stems {
            var found: Food? = db.foods.first { $0.name.lowercased() == stem }
            if found == nil {
                let partial: [Food] = db.foods.filter { f in
                    f.name.lowercased().split(separator: " ").contains { w in w.hasPrefix(stem) }
                }
                found = partial.min { $0.name.count < $1.name.count }
            }
            if let f = found, !soft.contains(f) { soft.append(f) }
            if soft.count == 3 { break }
        }
        return soft
    }

    /// Команды, которые меняют данные или читают список покупок, — всегда локально (не тратят лимит ИИ).
    static func isLocalCommand(_ message: String) -> Bool {
        let t = message.lowercased()
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        if t.range(of: dislikePattern, options: .regularExpression) != nil || t.contains("ұнамайды") { return true }
        if t.range(of: likeAgainPattern, options: .regularExpression) != nil { return true }
        if isShopping(t) { return true }
        return NutrikActions.isAction(message, db: FoodDB.shared)
    }

    static let dislikePattern = #"(don't like|dont like|do not like|hate|allergic to|не люблю|без)\s+([^\s,.!?]+)"#
    static let likeAgainPattern = #"(i (like|love) ([^\s,.!?]+) again|снова люблю|опять люблю|қайта ұнайды)"#

    /// «add milk to shopping list», «добавь молоко в список покупок», «сүтті сатып алу тізіміне қос», «что в списке покупок?»
    static func isShopping(_ t: String) -> Bool {
        let a = ["shopping", "to buy", "need to buy", "купить", "add ", "добав", "покуп", "сатып", "қос"]
        let b = ["shopping list", "list", "buy", "купить", "список", "покуп", "тізім"]
        return a.contains { t.contains($0) } && b.contains { t.contains($0) }
    }

    static func reply(to message: String, store: AppStore) -> NutrikReply {
        let t = message.lowercased()
        let db = store.db
        let name = store.data.profile.name
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        // Язык ответа: язык сообщения (ru/kk/en), для коротких «hi»/эмодзи — язык приложения
        let rl = NutrikActions.replyLang(message)
        let al: NutrikActions.Lang = rl == .ru ? .ru : rl == .kk ? .kk : .en
        // Локальные L / Lp: те же ключи strings.json, но на языке ответа
        func L(_ key: String, _ args: Any...) -> String {
            var out = L10n.raw(key, rl)
            for (i, a) in args.enumerated() { out = out.replacingOccurrences(of: "{\(i)}", with: "\(a)") }
            return out
        }
        func Lp(_ n: Int, _ forms: String) -> String { "\(n) \(L10n.plural(n, L10n.raw(forms, rl)))" }
        func nm(_ f: Food) -> String { NutrikActions.display(f, al) }
        func nmS(_ englishName: String) -> String {
            if let f = db.byName[englishName] { return nm(f) }
            if rl != .en, let r = db.recipeByName[englishName] {
                let tr = rl == .ru ? r.ru : r.kk
                if let tr, !tr.isEmpty { return tr }
            }
            return englishName
        }
        func tip(_ f: Food) -> String? { (db.tips[f.name] ?? db.tips[f.category]).map { L10n.raw($0, rl) } }

        // Действия (добавить / съел / выбросил / заморозить) — выполняются по-настоящему, ответ по факту
        if let done = NutrikActions.handle(message, store: store) { return done }
        let foods = NutrikActions.foods(in: t, db: db)

        // «I don't like onion» / «не люблю лук» / «маған пияз ұнамайды» → больше не предлагать рецепты с этим продуктом
        let dislikeHit = t.range(of: dislikePattern, options: .regularExpression)
        if dislikeHit != nil || t.contains("ұнамайды") {
            var w: String
            if let f = foods.first {
                w = f.name.lowercased()
            } else if let r = dislikeHit {
                w = String(String(t[r]).split(separator: " ").last ?? "")
                if w.hasSuffix("oes") { w = String(w.dropLast(2)) } else if w.hasSuffix("s") && w.count > 3 { w = String(w.dropLast()) }
            } else {
                w = ""
            }
            guard !w.isEmpty else { return NutrikReply(text: L("Which product don't you like? Try: \"I don't like onion\"."), mood: .happy) }
            if !store.data.dislikes.contains(w) { store.data.dislikes.append(w) }
            let shown = foods.first.map { nm($0) } ?? w
            return NutrikReply(text: L("Got it, {0}! I'll skip recipes with \"{1}\" from now on. 👍\nChanged your mind? Say \"I like {1} again\".", name, shown), mood: .happy)
        }
        if let r = t.range(of: likeAgainPattern, options: .regularExpression) {
            var w = foods.first?.name.lowercased() ?? ""
            if w.isEmpty {
                let words = t[r].split(separator: " ")
                w = words.count >= 3 ? String(words[2]) : ""
            }
            guard !w.isEmpty else { return NutrikReply(text: L("Which product? Try: \"I like onion again\"."), mood: .happy) }
            store.data.dislikes.removeAll { $0 == w || $0.hasPrefix(w) || w.hasPrefix($0) }
            let shown = foods.first.map { nm($0) } ?? w.capitalized
            return NutrikReply(text: L("Yay! {0} is back on the menu 🎉", shown), mood: .cheer)
        }

        // Список покупок
        if isShopping(t) {
            if !foods.isEmpty && has(["add", "buy", "купить", "need", "добав", "қос", "сатып ал"]) {
                store.addShopping(foods.map(\.name))
                return NutrikReply(text: L("🛒 Added to your shopping list: {0}. I'll put them in the fridge when you tap them in the list!",
                                           foods.map { "\($0.emoji) \(nm($0))" }.joined(separator: ", ")), mood: .cheer)
            }
            let list = store.data.shopping
            return NutrikReply(text: list.isEmpty
                ? L("Your shopping list is empty. Try: \"add eggs to shopping list\" 📝")
                : L("🛒 On your list ({0}): {1}", list.count, list.prefix(12).map { nmS($0) }.joined(separator: ", ") + (list.count > 12 ? "…" : ".")), mood: .happy)
        }

        if t.range(of: #"\b(hi|hello|hey|yo|hiya|sup)\b"#, options: .regularExpression) != nil
            || has(["привет", "здравств", "салем", "сәлем", "салам", "қалайсың"]) {
            let n = store.unitCount
            let rescue = store.toRescue.isEmpty ? "" : L(" and {0} need rescuing soon", store.toRescue.count)
            return NutrikReply(text: L("Hi, {0}! 👋 You have {1} at home{2}. Ask me what to cook!", name, Lp(n, "product|products"), rescue), mood: .wave)
        }
        if has(["thank", "thx", "спасибо", "благодар", "рахмет", "рақмет"]) {
            return NutrikReply(text: L("Anytime! Happy cooking 🍳 (I'll be here, probably tripping over a carrot)"), mood: .cheer)
        }
        if has(["joke", "funny", "шутк", "анекдот", "laugh", "әзіл", "күлдір"]) {
            return NutrikReply(text: L(jokes.randomElement() ?? jokes[0]), mood: .cheer)
        }
        if has(["who are you", "your name", "what are you", "кто ты", "как тебя зовут", "сен кімсің", "атың кім"]) {
            return NutrikReply(text: L("I'm Nutrik! A small, slightly messy food buddy with very short legs 🐾 I watch your fridge, cook ideas from leftovers and cheer every time you save food from the bin."), mood: .wave)
        }
        if has(["help", "what can you do", "помощь", "помоги", "что ты умеешь", "көмек", "не істей аласың"]) {
            return NutrikReply(text: L("I can:\n• suggest recipes from your fridge (\"what can I cook?\", \"another\")\n• tell what expires soon\n• explain how to store or freeze food\n• count calories (\"calories in banana\")\n• check your fridge (\"do I have milk?\")\n• really add, eat, bin or freeze food: \"add 2 eggs to fridge\", \"I ate a banana\"\n• add to the shopping list\n• show your eco impact and weight\n• remember what you don't like"), mood: .happy)
        }

        if has(["calorie", "kcal", "калор", "ккал"]) {
            if !foods.isEmpty {
                return NutrikReply(text: foods.map { L("{0} {1}: {2} kcal per 100 g", $0.emoji, nm($0), $0.kcal) }.joined(separator: "\n"), mood: .eating)
            }
            let eaten = store.eatenToday, target = store.targetCalories
            let left = target - eaten
            let hint = left > 600 ? L("time for a proper meal! 🍲") : L("a light snack fits 🍎")
            let tail = left > 0 ? L("{0} kcal left — {1}", left, hint) : L("Goal reached! 🎯")
            return NutrikReply(text: L("Today: {0} of {1} kcal. {2}", eaten, target, tail), mood: .happy)
        }

        if has(["weight", "weigh", "bmi", "вес", "имт", "салмақ", "дене массасы"]) {
            let w = store.data.weights.sorted { $0.date < $1.date }
            guard let last = w.last else { return NutrikReply(text: L("No weigh-ins yet. Add one in Profile → Edit profile → Weight ⚖️"), mood: .happy) }
            let diff = last.kg - (w.first?.kg ?? last.kg)
            let sign = diff > 0 ? "+" : ""
            let trend = abs(diff) < 0.05 ? L("stable since your first weigh-in") : L("{0} kg since your first weigh-in", sign + String(format: "%.1f", diff))
            let pr = store.data.profile
            let r = pr.healthyRange
            let range = "\(Int(r.lowerBound.rounded()))–\(Int(r.upperBound.rounded()))"
            return NutrikReply(text: L("⚖️ Latest: {0} kg, {1}. BMI {2} — {3} (healthy for your height: {4} kg). Open Profile → Body dashboard for the full gauge 📟",
                                       String(format: "%.1f", last.kg), trend, String(format: "%.1f", pr.bmi), L(pr.bmiCategory.key).lowercased(), range), mood: .happy)
        }

        if has(["co2", "co₂", "impact", "saved", "planet", "money", "экол", "эко", "вклад", "үлес", "планет"]) || t.range(of: #"\beco\b"#, options: .regularExpression) != nil {
            let s = store.data.stats
            let days = store.streakDays
            let streak = days > 0 ? L("{0} without waste! 🌱", Lp(days, "day|days")) : L("Let's start a zero-waste streak today! 🌱")
            let text = L("🌍 You rescued {0} (≈ {1} kg of food), saved ${2} and avoided {3} kg of CO₂. Eco score: {4}%. {5}",
                         Lp(s.rescued, "product|products"), String(format: "%.1f", store.rescuedKg), String(format: "%.0f", s.rescuedMoney),
                         String(format: "%.1f", store.co2), store.ecoScore, streak)
            return NutrikReply(text: text, mood: .cheer)
        }

        if has(["do i have", "have i got", "is there", "есть ли", "у меня есть", "got any", "бар ма"]) && !foods.isEmpty {
            return NutrikReply(text: foods.map { f in
                let m = store.data.pantry.filter { $0.name == f.name }.sorted { $0.daysLeft < $1.daysLeft }
                let pcs = m.reduce(0) { $0 + $1.qty }
                guard let first = m.first else { return L("{0} No {1} at home.", f.emoji, nm(f)) }
                return L("{0} {1}: ×{2} in the {3}, soonest — {4}.", f.emoji, nm(f), pcs, L(first.storage.key).lowercased(), status(first, rl).lowercased())
            }.joined(separator: "\n"), mood: .happy)
        }

        if has(["in my fridge", "what do i have", "my fridge", "what's in", "whats in", "в холодильнике", "что у меня есть", "тоңазытқышымда", "тоңазытқышта не"]) {
            let p = store.sortedPantry
            if p.isEmpty { return NutrikReply(text: L("Your fridge is empty 😿 Add products in the Search tab!"), mood: .sad) }
            let shown = p.prefix(15).map { g in "\(g.emoji) \(nmS(g.name))" + (g.qty > 1 ? " ×\(g.qty)" : "") }.joined(separator: ", ")
            return NutrikReply(text: L("You have {0}: {1}. Freshest go last, soonest first!", Lp(p.count, "product|products"), shown + (p.count > 15 ? "…" : "")), mood: .happy)
        }

        if has(["freeze", "freezer", "замороз", "морозил", "мұздат"]) && !foods.isEmpty {
            let yes = foods.filter { FoodDB.canFreeze($0) || $0.category == "Frozen" }
            let no = foods.filter { f in !yes.contains(f) }
            var lines: [String] = []
            if !yes.isEmpty { lines.append(L("❄️ {0}: yes! Frozen it keeps about 3 months. Tip: portion it first, so you thaw only what you need.", yes.map { nm($0) }.joined(separator: ", "))) }
            if !no.isEmpty { lines.append(L("🚫 {0}: better not — the texture gets watery or it simply keeps fine without freezing. Use it fresh.", no.map { nm($0) }.joined(separator: ", "))) }
            return NutrikReply(text: lines.joined(separator: "\n"), mood: .happy)
        }

        if has(["store", "keep", "хран", "last longer", "storage", "сақта"]) && !foods.isEmpty {
            return NutrikReply(text: foods.map { f in
                L("{0} {1}: {2}. Usually lasts about {3}.", f.emoji, nm(f), tip(f) ?? L("keep it cool and dry"), Lp(f.shelf, "day|days"))
            }.joined(separator: "\n"), mood: .happy)
        }

        if has(["still good", "still ok", "safe to eat", "can i eat", "gone bad", "можно ли есть", "можно есть", "не испортил", "жеуге бола"]) {
            return NutrikReply(text: L("Trust your senses for \"best before\" products: look, smell, taste a little. ⚠️ But never risk it with meat, fish or dairy past the \"use by\" date. When in doubt — throw it out (and tell me, I'll learn the reason)."), mood: .happy)
        }

        if has(["expire", "waste", "spoil", "soon", "rescue", "go bad", "срок", "испорт", "скоро", "пропад", "бұзыл", "мерзім", "жақында"]) {
            let exp = store.expiringSoon
            if exp.isEmpty { return NutrikReply(text: L("Nothing is expiring soon. Great job! 🎉"), mood: .cheer) }
            let best = store.rankedRecipes().first { r in r.ingredients.contains { i in exp.contains { $0.name == i.name } } }
            let items = exp.prefix(8).map { p in "\(p.emoji) \(nmS(p.name)) (\(status(p.first, rl).lowercased()))" }.joined(separator: ", ")
            var text = L("Use these first: {0}.", items)
            if let b = best { text += "\n" + L("Idea: {0} {1} rescues some of them!", b.emoji, nmS(b.name)) }
            return NutrikReply(text: text, mood: .eating, recipe: best?.name)
        }

        let more = has(["more", "another", "else", "other", "ещё", "еще", "другой", "другое", "тағы", "басқа"])
        if more || has(["cook", "recipe", "eat", "dinner", "lunch", "breakfast", "hungry", "suggest", "make", "idea",
                        "приготов", "рецепт", "ужин", "обед", "завтрак", "голод", "поесть", "пісір", "тамақ", "кешкі ас", "түскі ас", "таңғы ас"]) {
            if store.data.pantry.isEmpty && foods.isEmpty {
                return NutrikReply(text: L("Your fridge is empty 😿 Add some products in the Search tab first — then I'll find you a recipe!"), mood: .sad)
            }
            var list = store.rankedRecipes()
            if !foods.isEmpty {
                list = list.filter { r in r.ingredients.contains { i in foods.contains { $0.name == i.name } } }
            }
            if has(["quick", "fast", "быстр", "жылдам", "тез"]) {
                list = list.filter { r in Int(r.time.prefix { $0.isNumber }).map { $0 <= 20 && r.time.contains("min") } ?? false }
            }
            if has(["zero waste", "zero-waste", "leftover", "остатк", "қалдық"]) { list = list.filter(\.zeroWaste) }
            if list.isEmpty { return NutrikReply(text: L("I couldn't find a recipe with that. Try another product! 🤔"), mood: .sad) }
            store.data.suggestIndex = more ? store.data.suggestIndex + 1 : 0
            let r = list[store.data.suggestIndex % list.count]
            let miss = r.missing(store.pantryNames)
            let zw = r.zeroWaste ? L(" ♻️ Zero-waste!") : ""
            let need = miss.isEmpty ? L("You have everything!") : L("You still need: {0}.", miss.map { nmS($0) }.joined(separator: ", "))
            let time = rl == .en ? r.time : r.time.replacingOccurrences(of: "min", with: L("min"))
            return NutrikReply(text: L("{0} {1} — {2} kcal per serving, {3}.{4} {5} Say \"another\" for more ideas.", r.emoji, nmS(r.name), r.kcal, time, zw, need),
                               mood: .eating, recipe: r.name)
        }

        if !foods.isEmpty {
            let f = foods[0]
            let storeTip = tip(f).map { L(". Store it {0}", $0) } ?? ""
            return NutrikReply(text: L("{0} {1}: {2} kcal per 100 g, keeps about {3}{4}. Ask \"what can I cook with {5}?\"",
                                       f.emoji, nm(f), f.kcal, Lp(f.shelf, "day|days"), storeTip, nm(f).lowercased()), mood: .happy)
        }
        // Похоже на просьбу-действие, но ни ИИ, ни разбор её не поняли — честно, без выдуманного «сделал»
        let actionHints = ["add ", "put ", "i ate", "threw", "freeze", "remove", "delete", "добав", "полож", "съел", "выбро", "выкин", "замороз", "удали", "убери",
                           "қос", "жедім", "тастадым", "мұздат"]
        if has(actionHints) {
            switch rl {
            case .ru: return NutrikReply(text: "🙈 Не получилось понять, что сделать, — я ничего не менял. Попробуй так: «добавь 2 яйца в холодильник», «съел банан», «выбросил кефир», «заморозь курицу» или «добавь молоко в список покупок».", mood: .sad)
            case .kk: return NutrikReply(text: "🙈 Не істеу керегін түсінбедім — ештеңе өзгертпедім. Былай жазып көр: «тоңазытқышқа 2 жұмыртқа қос», «банан жедім», «кефирді тастадым», «сүтті сатып алу тізіміне қос».", mood: .sad)
            case .en: return NutrikReply(text: "🙈 I couldn't work out what to do, so I didn't change anything. Try: \"add 2 eggs to fridge\", \"I ate a banana\", \"threw away kefir\", \"freeze the chicken\" or \"add milk to shopping list\".", mood: .sad)
            }
        }
        return NutrikReply(text: L("Hmm, I didn't quite get \"{0}\" 🙈 Try: \"what can I cook?\", \"what expires soon?\", \"how to store tomatoes\", \"can I freeze bread?\", \"do I have milk?\" or \"help\".", message), mood: .sad)
    }

    /// Срок продукта на языке ответа (те же ключи, что PantryItem.status).
    private static func status(_ p: PantryItem, _ rl: AppLang) -> String {
        func word(_ n: Int) -> String { "\(n) \(L10n.plural(n, L10n.raw("day|days", rl)))" }
        let d = p.daysLeft
        if d < 0 { return L10n.raw("Expired {0} ago", rl).replacingOccurrences(of: "{0}", with: word(-d)) }
        if d == 0 { return L10n.raw("Use today!", rl) }
        if d == 1 { return L10n.raw("Expires tomorrow", rl) }
        return L10n.raw("{0} left", rl).replacingOccurrences(of: "{0}", with: word(d))
    }
}
