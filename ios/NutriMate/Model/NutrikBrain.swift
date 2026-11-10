import Foundation

/// «AI-чат» Нутрика: работает без интернета и ключей — правила + данные холодильника (как MockAiService в вебе).
struct NutrikReply {
    var text: String
    var mood: NutrikMood = .talk
    /// Рецепт, который можно открыть кнопкой под ответом
    var recipe: String? = nil
}

enum NutrikBrain {
    static let suggestions = [
        "What can I cook?", "What expires soon?", "What's in my fridge?", "How to store tomatoes?",
        "Can I freeze bread?", "Calories today", "My eco impact", "Add milk to shopping list",
        "I don't like onion", "Tell me a joke",
    ]

    private static let jokes = [
        "Why did the tomato blush? It saw the salad dressing! 🍅",
        "I tried to run to the fridge, but my legs are only 2 cm long. I'm still on my way. 🐾",
        "What do you call cheese that isn't yours? Nacho cheese! 🧀",
        "Bread told me a secret. I can't share it — it's a little crumby. 🍞",
        "Kurt is my favourite snack: it lasts for months, just like my naps. 😴",
        "Why don't eggs tell jokes? They'd crack each other up! 🥚",
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

    static func reply(to message: String, store: AppStore) -> NutrikReply {
        let t = message.lowercased()
        let db = store.db
        let name = store.data.profile.name
        func has(_ words: [String]) -> Bool { words.contains { t.contains($0) } }
        let foods = mentioned(t, db: db)

        // «I don't like onion» → больше не предлагать рецепты с этим продуктом
        if let r = t.range(of: #"(don't like|dont like|do not like|hate|allergic to|не люблю|без)\s+([^\s,.!?]+)"#, options: .regularExpression) {
            let phrase = String(t[r])
            var w = String(phrase.split(separator: " ").last ?? "")
            if w.hasSuffix("oes") { w = String(w.dropLast(2)) } else if w.hasSuffix("s") && w.count > 3 { w = String(w.dropLast()) }
            if !w.isEmpty && !store.data.dislikes.contains(w) { store.data.dislikes.append(w) }
            return NutrikReply(text: "Got it, \(name)! I'll skip recipes with \"\(w)\" from now on. 👍\nChanged your mind? Say \"I like \(w) again\".", mood: .happy)
        }
        if let r = t.range(of: #"i (like|love) ([^\s,.!?]+) again"#, options: .regularExpression) {
            let words = t[r].split(separator: " ")
            let w = words.count >= 3 ? String(words[2]) : ""
            store.data.dislikes.removeAll { $0 == w || $0.hasPrefix(w) || w.hasPrefix($0) }
            return NutrikReply(text: "Yay! \(w.capitalized) is back on the menu 🎉", mood: .cheer)
        }

        // Список покупок
        if has(["shopping", "to buy", "need to buy", "купить", "add "]) && (has(["shopping list", "list", "buy", "купить"])) {
            if !foods.isEmpty && has(["add", "buy", "купить", "need"]) {
                store.addShopping(foods.map(\.name))
                return NutrikReply(text: "🛒 Added to your shopping list: \(foods.map { "\($0.emoji) \($0.name)" }.joined(separator: ", ")). I'll put them in the fridge when you tap them in the list!", mood: .cheer)
            }
            let list = store.data.shopping
            return NutrikReply(text: list.isEmpty
                ? "Your shopping list is empty. Try: \"add eggs to shopping list\" 📝"
                : "🛒 On your list (\(list.count)): \(list.prefix(12).joined(separator: ", "))\(list.count > 12 ? "…" : "").", mood: .happy)
        }

        if t.range(of: #"\b(hi|hello|hey|yo|hiya|sup)\b"#, options: .regularExpression) != nil || has(["привет", "салем", "сәлем"]) {
            let n = store.data.pantry.count
            let plural = n == 1 ? "" : "s"
            let rescue = store.toRescue.isEmpty ? "" : " and \(store.toRescue.count) need rescuing soon"
            return NutrikReply(text: "Hi, \(name)! 👋 You have \(n) product\(plural) at home\(rescue). Ask me what to cook!", mood: .wave)
        }
        if has(["thank", "thx", "спасибо", "рахмет"]) { return NutrikReply(text: "Anytime! Happy cooking 🍳 (I'll be here, probably tripping over a carrot)", mood: .cheer) }
        if has(["joke", "funny", "шутк", "laugh"]) { return NutrikReply(text: jokes.randomElement() ?? jokes[0], mood: .cheer) }
        if has(["who are you", "your name", "what are you", "кто ты"]) {
            return NutrikReply(text: "I'm Nutrik! A small, slightly messy food buddy with very short legs 🐾 I watch your fridge, cook ideas from leftovers and cheer every time you save food from the bin.", mood: .wave)
        }
        if has(["help", "what can you do", "помощь", "помоги"]) {
            return NutrikReply(text: "I can:\n• suggest recipes from your fridge (\"what can I cook?\", \"another\")\n• tell what expires soon\n• explain how to store or freeze food\n• count calories (\"calories in banana\")\n• check your fridge (\"do I have milk?\")\n• add to the shopping list\n• show your eco impact and weight\n• remember what you don't like", mood: .happy)
        }

        if has(["calorie", "kcal", "калор"]) {
            if !foods.isEmpty {
                return NutrikReply(text: foods.map { "\($0.emoji) \($0.name): \($0.kcal) kcal per 100 g" }.joined(separator: "\n"), mood: .eating)
            }
            let eaten = store.eatenToday, target = store.targetCalories
            let left = target - eaten
            let hint = left > 600 ? "time for a proper meal! 🍲" : "a light snack fits 🍎"
            let tail = left > 0 ? "\(left) kcal left — \(hint)" : "Goal reached! 🎯"
            return NutrikReply(text: "Today: \(eaten) of \(target) kcal. \(tail)", mood: .happy)
        }

        if has(["weight", "weigh", "bmi", "вес"]) {
            let w = store.data.weights.sorted { $0.date < $1.date }
            guard let last = w.last else { return NutrikReply(text: "No weigh-ins yet. Add one in Profile → Weight ⚖️", mood: .happy) }
            let diff = last.kg - (w.first?.kg ?? last.kg)
            let sign = diff > 0 ? "+" : ""
            let trend = abs(diff) < 0.05 ? "stable since your first weigh-in" : sign + String(format: "%.1f", diff) + " kg since your first weigh-in"
            let pr = store.data.profile
            let bmi = String(format: "%.1f", pr.bmi)
            let r = pr.healthyRange
            let range = "\(Int(r.lowerBound.rounded()))–\(Int(r.upperBound.rounded())) kg"
            return NutrikReply(text: String(format: "⚖️ Latest: %.1f kg, ", last.kg) + trend + ". BMI \(bmi) — \(pr.bmiCategory.title.lowercased()) (healthy for your height: \(range)). Open Profile → Body dashboard for the full gauge 📟", mood: .happy)
        }

        if has(["co2", "co₂", "impact", "saved", "planet", "money", "экол"]) || t.range(of: #"\beco\b"#, options: .regularExpression) != nil {
            let s = store.data.stats
            let kg = String(format: "%.1f", store.rescuedKg)
            let money = String(format: "%.0f", s.rescuedMoney)
            let co2 = String(format: "%.1f", store.co2)
            let days = store.streakDays
            let streak = days > 0 ? "\(days) day\(days == 1 ? "" : "s") without waste! 🌱" : "Let's start a zero-waste streak today! 🌱"
            let text = "🌍 You rescued \(s.rescued) products (≈ \(kg) kg of food), saved $\(money) and avoided \(co2) kg of CO₂. Eco score: \(store.ecoScore)%. \(streak)"
            return NutrikReply(text: text, mood: .cheer)
        }

        if has(["do i have", "have i got", "is there", "есть ли", "got any"]) && !foods.isEmpty {
            return NutrikReply(text: foods.map { f in
                let m = store.data.pantry.filter { $0.name == f.name }.sorted { $0.daysLeft < $1.daysLeft }
                return m.isEmpty ? "\(f.emoji) No \(f.name) at home." : "\(f.emoji) \(f.name): \(m.count) pcs in the \(m[0].storage.title.lowercased()), soonest — \(m[0].status.lowercased())."
            }.joined(separator: "\n"), mood: .happy)
        }

        if has(["in my fridge", "what do i have", "my fridge", "what's in", "whats in", "в холодильнике"]) {
            let p = store.sortedPantry
            if p.isEmpty { return NutrikReply(text: "Your fridge is empty 😿 Add products in the Search tab!", mood: .sad) }
            let shown = p.prefix(15).map { "\($0.emoji) \($0.name)" }.joined(separator: ", ")
            return NutrikReply(text: "You have \(p.count) product\(p.count == 1 ? "" : "s"): \(shown)\(p.count > 15 ? "…" : ""). Freshest go last, soonest first!", mood: .happy)
        }

        if has(["freeze", "freezer", "замороз"]) && !foods.isEmpty {
            let yes = foods.filter { FoodDB.canFreeze($0) || $0.category == "Frozen" }
            let no = foods.filter { f in !yes.contains(f) }
            var lines: [String] = []
            if !yes.isEmpty { lines.append("❄️ \(yes.map(\.name).joined(separator: ", ")): yes! Frozen it keeps about 3 months. Tip: portion it first, so you thaw only what you need.") }
            if !no.isEmpty { lines.append("🚫 \(no.map(\.name).joined(separator: ", ")): better not — the texture gets watery or it simply keeps fine without freezing. Use it fresh.") }
            return NutrikReply(text: lines.joined(separator: "\n"), mood: .happy)
        }

        if has(["store", "keep", "хран", "last longer", "storage"]) && !foods.isEmpty {
            return NutrikReply(text: foods.map { f in
                "\(f.emoji) \(f.name): \(db.tips[f.name] ?? db.tips[f.category] ?? "keep it cool and dry"). Usually lasts about \(f.shelf) day\(f.shelf == 1 ? "" : "s")."
            }.joined(separator: "\n"), mood: .happy)
        }

        if has(["still good", "still ok", "safe to eat", "can i eat", "gone bad", "испорт"]) {
            return NutrikReply(text: "Trust your senses for \"best before\" products: look, smell, taste a little. ⚠️ But never risk it with meat, fish or dairy past the \"use by\" date. When in doubt — throw it out (and tell me, I'll learn the reason).", mood: .happy)
        }

        if has(["expire", "waste", "spoil", "soon", "rescue", "срок", "go bad"]) {
            let exp = store.expiringSoon
            if exp.isEmpty { return NutrikReply(text: "Nothing is expiring soon. Great job! 🎉", mood: .cheer) }
            let best = store.rankedRecipes().first { r in r.ingredients.contains { i in exp.contains { $0.name == i.name } } }
            let items = exp.prefix(8).map { p in "\(p.emoji) \(p.name) (\(p.status.lowercased()))" }.joined(separator: ", ")
            var text = "Use these first: \(items)."
            if let b = best { text += "\nIdea: \(b.emoji) \(b.name) rescues some of them!" }
            return NutrikReply(text: text, mood: .eating, recipe: best?.name)
        }

        if has(["cook", "recipe", "eat", "dinner", "lunch", "breakfast", "hungry", "suggest", "make", "more", "another", "else", "idea", "приготов", "рецепт"]) {
            if store.data.pantry.isEmpty && foods.isEmpty {
                return NutrikReply(text: "Your fridge is empty 😿 Add some products in the Search tab first — then I'll find you a recipe!", mood: .sad)
            }
            var list = store.rankedRecipes()
            if !foods.isEmpty {
                list = list.filter { r in r.ingredients.contains { i in foods.contains { $0.name == i.name } } }
            }
            if has(["quick", "fast", "быстр"]) {
                list = list.filter { r in Int(r.time.prefix { $0.isNumber }).map { $0 <= 20 && r.time.contains("min") } ?? false }
            }
            if has(["zero waste", "zero-waste", "leftover"]) { list = list.filter(\.zeroWaste) }
            if list.isEmpty { return NutrikReply(text: "I couldn't find a recipe with that. Try another product! 🤔", mood: .sad) }
            store.data.suggestIndex = has(["more", "another", "else", "other"]) ? store.data.suggestIndex + 1 : 0
            let r = list[store.data.suggestIndex % list.count]
            let miss = r.missing(store.pantryNames)
            let zw = r.zeroWaste ? " ♻️ Zero-waste!" : ""
            let need = miss.isEmpty ? "You have everything!" : "You still need: \(miss.joined(separator: ", "))."
            return NutrikReply(text: "\(r.emoji) \(r.name) — \(r.kcal) kcal per serving, \(r.time).\(zw) \(need) Say \"another\" for more ideas.",
                               mood: .eating, recipe: r.name)
        }

        if !foods.isEmpty {
            let f = foods[0]
            let tip = db.tips[f.name] ?? db.tips[f.category]
            let storeTip = tip.map { ". Store it \($0)" } ?? ""
            return NutrikReply(text: "\(f.emoji) \(f.name): \(f.kcal) kcal per 100 g, keeps about \(f.shelf) day\(f.shelf == 1 ? "" : "s")\(storeTip). Ask \"what can I cook with \(f.name.lowercased())?\"", mood: .happy)
        }
        return NutrikReply(text: "Hmm, I didn't quite get \"\(message)\" 🙈 Try: \"what can I cook?\", \"what expires soon?\", \"how to store tomatoes\", \"can I freeze bread?\", \"do I have milk?\" or \"help\".", mood: .sad)
    }
}
