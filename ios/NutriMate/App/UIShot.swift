import Foundation

/// Режим скриншотов для CI (симулятор): запуск с аргументами
/// `-uiShot` (демо-данные, ничего не сохраняет), `-tab fridge`, `-sheet body`, `-onboarding`, `-tutorial`, `-lang ru|kk|en`, `-dark`.
/// На телефоне владельца эти аргументы никогда не передаются, поэтому режим не мешает обычной работе.
enum UIShot {
    static let args = ProcessInfo.processInfo.arguments
    static var enabled: Bool { args.contains("-uiShot") }
    static func value(_ key: String) -> String? {
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    static var tab: AppTab {
        switch value("-tab") {
        case "fridge": return .fridge
        case "search": return .search
        case "recipes": return .recipes
        case "profile": return .profile
        default: return .home
        }
    }
    static var sheet: String? { value("-sheet") }
    /// Эксперименты с плавностью: `-perfOff nutrik,bg,shadow` отключает части экрана, чтобы найти дорогую.
    static let perfOff: Set<String> = enabled ? Set((value("-perfOff") ?? "").split(separator: ",").map(String.init)) : []

    /// Правдоподобный пользователь: продукты разной свежести, дневник, вес, статистика, чат.
    static func demoData() -> AppData {
        var d = AppData()
        let onboarding = args.contains("-onboarding")
        d.profile.registered = !onboarding
        d.profile.tutorialDone = !args.contains("-tutorial")
        d.profile.name = "Alex"
        d.language = AppLang(rawValue: value("-lang") ?? "") ?? .en
        AppLang.current = d.language   // демо-тексты ниже — уже на выбранном языке
        if args.contains("-dark") { d.appearance = .dark }
        d.profile.isMan = true
        d.profile.age = 19
        d.profile.height = 176
        d.profile.weight = 52
        d.profile.activity = 1
        d.notifications = false
        d.profile.joined = Calendar.current.date(byAdding: .day, value: -34, to: Date())
        if onboarding { return d }
        let db = FoodDB.shared
        let now = Date()
        func day(_ n: Int) -> Date { Calendar.current.date(byAdding: .day, value: n, to: now) ?? now }
        let items: [(String, Int, StorageKind?)] = [
            ("Banana", 0, nil), ("Milk", 1, nil), ("Spinach", -1, nil), ("Tomato", 2, nil), ("Chicken Breast", 1, nil),
            ("Eggs", 12, nil), ("Cheddar Cheese", 9, nil), ("Kefir", 3, nil), ("Apple", 10, nil), ("Carrot", 14, nil),
            ("Potato", 20, nil), ("Onion", 25, nil), ("Rice", 300, nil), ("Butter", 18, nil), ("White Bread", 2, nil),
            ("Strawberry", 1, nil), ("Pelmeni", 120, .freezer), ("Kurt", 60, nil),
        ]
        for (n, left, place) in items {
            guard let f = db.byName[n] else { continue }
            d.pantry.append(PantryItem(name: f.name, emoji: f.emoji, category: f.category, kcal: f.kcal,
                                       added: day(-max(1, f.shelf - left)), expiry: day(left),
                                       storage: place ?? FoodDB.defaultStorage(f)))
        }
        // складывание одинаковых продуктов: яйца ×10, бананы ×3, вторая партия молока (купил позже)
        for i in d.pantry.indices {
            switch d.pantry[i].name {
            case "Eggs": d.pantry[i].qty = 10
            case "Banana": d.pantry[i].qty = 3
            case "Apple": d.pantry[i].qty = 4
            default: break
            }
        }
        if let milk = db.byName["Milk"] {
            d.pantry.append(PantryItem(name: milk.name, emoji: milk.emoji, category: milk.category, kcal: milk.kcal,
                                       added: now, expiry: day(7), storage: .fridge, qty: 2))
        }
        // остатки приготовленного (v27): 2 порции карри со вчера
        if let r = db.recipeByName["Chicken Curry"] {
            d.pantry.append(PantryItem(name: r.name, emoji: r.emoji, category: "Ready Meals", kcal: r.kcalPer100,
                                       added: day(-1), expiry: day(2), storage: .fridge, qty: 2, leftover: true))
            d.stats.leftoversSaved = 2
        }
        d.log = [
            LogEntry(emoji: "🥣", name: "Oatmeal · 250 g", kcal: 220, date: now.addingTimeInterval(-5 * 3600)),
            LogEntry(emoji: "🍌", name: "Banana · 120 g", kcal: 107, date: now.addingTimeInterval(-4 * 3600)),
            LogEntry(emoji: "🍗", name: "Chicken Breast · 200 g", kcal: 330, date: now.addingTimeInterval(-2 * 3600)),
        ]
        for back in 1...13 {
            d.log.append(LogEntry(emoji: "🍽️", name: "Meals", kcal: back < 7 ? 1500 + back * 90 : 1350 + back * 40, date: day(-back)))
        }
        d.log += [
            LogEntry(emoji: "🍌", name: "Banana · 120 g", kcal: 107, date: day(-1)),
            LogEntry(emoji: "🥚", name: "Eggs · 100 g", kcal: 155, date: day(-2)),
            LogEntry(emoji: "🍌", name: "Banana · 120 g", kcal: 107, date: day(-3)),
            LogEntry(emoji: "🍗", name: "Chicken Breast · 150 g", kcal: 248, date: day(-4)),
        ]
        d.weights = [WeightEntry(date: day(-28), kg: 51.2), WeightEntry(date: day(-21), kg: 51.5),
                     WeightEntry(date: day(-14), kg: 51.6), WeightEntry(date: day(-7), kg: 51.9),
                     WeightEntry(date: now, kg: 52)]
        d.shopping = ["Yogurt", "Oats", "Peanut Butter"]
        d.stats.consumed = 24; d.stats.rescued = 9; d.stats.wasted = 2; d.stats.cooked = 4
        d.stats.frozen = 3; d.stats.shared = 1; d.stats.bought = 2
        d.stats.rescuedMoney = 21.5; d.stats.wastedMoney = 4
        d.stats.streakStart = day(-5)
        for back in 0..<30 {
            let kind: EcoKind = back % 9 == 4 ? .wasted : back % 3 == 0 ? .rescued : back % 4 == 1 ? .frozen : .eaten
            d.events.append(EcoEvent(kind: kind, money: 2, date: day(-back)))
        }
        d.wasteLog = [WasteEntry(name: "Lettuce", category: "Vegetables", reason: .forgot, money: 1.2, date: day(-9)),
                      WasteEntry(name: "Yogurt", category: "Dairy", reason: .expired, money: 2, date: day(-18))]
        d.unlocked = ["first", "rescue", "chef", "fridge", "freezer", "share", "shop"]
        d.chat = [
            ChatMessage(text: L("What can I cook?"), fromUser: true),
            ChatMessage(text: L("🍳 Rescue omelette — 310 kcal per serving, 10 min. ♻️ Zero-waste! You have everything! Say \"another\" for more ideas."),
                        fromUser: false, recipe: db.recipes.first?.name),
            ChatMessage(text: L("My spinach looks sad. Ideas?"), fromUser: true),
            ChatMessage(text: L("Don't bin it yet! 🥬 Wilted spinach is perfect cooked: toss it into an omelette with your eggs and cheddar, or blend it into a smoothie with the banana that needs eating today 🍌"),
                        fromUser: false, ai: true),
        ]
        return d
    }
}
