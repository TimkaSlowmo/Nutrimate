import Foundation

// MARK: - База продуктов и рецептов (генерируется из lib/main.dart скриптом tool/export_data.py)

struct Food: Codable, Hashable, Identifiable {
    let emoji: String
    let name: String
    let kcal: Int      // ккал на 100 г
    let category: String
    let shelf: Int     // срок хранения, дней
    var id: String { name }
}

struct Ing: Codable, Hashable {
    let name: String
    let g: Int
}

struct Recipe: Codable, Hashable, Identifiable {
    let name: String
    let emoji: String
    let time: String
    let servings: Int
    let ingredients: [Ing]
    let steps: [String]
    let staples: String
    let zeroWaste: Bool
    var id: String { name }

    /// ккал на порцию
    var kcal: Int {
        let total = ingredients.reduce(0.0) { s, i in
            s + Double(i.g) * Double(FoodDB.shared.byName[i.name]?.kcal ?? 0) / 100
        }
        return Int((total / Double(max(1, servings))).rounded())
    }

    func missing(_ have: Set<String>) -> [String] {
        ingredients.map(\.name).filter { !have.contains($0) }
    }
}

private struct DBFile: Codable {
    let foods: [Food]
    let recipes: [Recipe]
    let tips: [String: String]?
}

struct FoodDB {
    let foods: [Food]
    let recipes: [Recipe]
    let byName: [String: Food]
    let categories: [String]
    /// Советы по хранению (по названию продукта или категории) — из storageTips в lib/main.dart
    var tips: [String: String] = [:]

    static let shared: FoodDB = {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(DBFile.self, from: data)
        else { return FoodDB(foods: [], recipes: [], byName: [:], categories: [], tips: [:]) }
        var seen = Set<String>()
        var cats: [String] = []
        for f in file.foods where !seen.contains(f.category) {
            seen.insert(f.category)
            cats.append(f.category)
        }
        var map: [String: Food] = [:]
        for f in file.foods where map[f.name] == nil { map[f.name] = f }
        return FoodDB(foods: file.foods, recipes: file.recipes, byName: map, categories: cats, tips: file.tips ?? [:])
    }()

    static let catEmoji: [String: String] = [
        "Vegetables": "🥕", "Fruits": "🍎", "Berries": "🍓", "Dairy": "🧀", "Meat": "🥩", "Seafood": "🐟",
        "Grains": "🌾", "Bakery": "🍞", "Nuts & Legumes": "🥜", "Pantry": "🫙", "Sweets": "🍫", "Drinks": "🥤",
        "Frozen": "🧊", "Spices": "🧂", "Canned": "🥫", "Ready Meals": "🍱", "Snacks": "🍿", "Plant-Based": "🌱",
        "World Foods": "🌏", "Baby Food": "🍼",
    ]

    static let price: [String: Double] = [
        "Meat": 4.5, "Seafood": 5.0, "Dairy": 2.0, "Vegetables": 1.2, "Fruits": 1.5, "Berries": 3.0, "Bakery": 1.5,
        "Grains": 1.2, "Nuts & Legumes": 3.0, "Pantry": 2.5, "Sweets": 2.5, "Drinks": 1.8, "Frozen": 3.5, "Spices": 2.0,
        "Canned": 1.8, "Ready Meals": 4.0, "Snacks": 2.5, "Plant-Based": 3.0, "World Foods": 3.0, "Baby Food": 2.5,
    ]

    static let shelfStable: Set<String> = ["Grains", "Pantry", "Spices", "Canned", "Nuts & Legumes", "Snacks", "Sweets", "Drinks", "World Foods", "Plant-Based", "Baby Food"]
    static let freezable: Set<String> = ["Meat", "Seafood", "Bakery", "Fruits", "Berries", "Vegetables", "Ready Meals", "Dairy", "Plant-Based"]
    static let noFreeze: Set<String> = ["Eggs", "Lettuce", "Cucumber", "Salad Mix", "Yogurt", "Sour Cream", "Mayonnaise"]

    static func defaultStorage(_ f: Food) -> StorageKind {
        if f.category == "Frozen" { return .freezer }
        if shelfStable.contains(f.category) && f.shelf > 14 { return .pantry }
        return .fridge
    }

    static func canFreeze(_ f: Food) -> Bool { freezable.contains(f.category) && !noFreeze.contains(f.name) }

    /// Поиск: сначала совпадение с начала названия, потом с начала слова, потом где угодно.
    func search(_ query: String, category: String?) -> [Food] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let pool = category == nil ? foods : foods.filter { $0.category == category }
        if q.isEmpty { return pool }
        var a: [Food] = [], b: [Food] = [], c: [Food] = []
        for f in pool {
            let n = f.name.lowercased()
            if n.hasPrefix(q) { a.append(f) }
            else if n.contains(" " + q) { b.append(f) }
            else if n.contains(q) || f.category.lowercased().hasPrefix(q) { c.append(f) }
        }
        return a.sorted { $0.name.count < $1.name.count } + b + c
    }
}

// MARK: - Данные пользователя (сохраняются в Application Support/nutrimate.json)

enum StorageKind: String, Codable, CaseIterable, Identifiable {
    case fridge, freezer, pantry
    var id: String { rawValue }
    var title: String {
        switch self {
        case .fridge: return "Fridge"
        case .freezer: return "Freezer"
        case .pantry: return "Pantry"
        }
    }
    var emoji: String {
        switch self {
        case .fridge: return "🧊"
        case .freezer: return "❄️"
        case .pantry: return "🫙"
        }
    }
}

enum WasteReason: String, Codable, CaseIterable, Identifiable {
    case expired, forgot, tooMuch, spoiled, disliked
    var id: String { rawValue }
    var title: String {
        switch self {
        case .expired: return "⏰ It expired"
        case .forgot: return "🙈 Forgot about it"
        case .tooMuch: return "🛒 Bought too much"
        case .spoiled: return "🦠 Went bad early"
        case .disliked: return "😖 Did not like it"
        }
    }
}

func dayStart(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }
func daysBetween(_ a: Date, _ b: Date) -> Int {
    Calendar.current.dateComponents([.day], from: dayStart(a), to: dayStart(b)).day ?? 0
}

struct PantryItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var emoji: String
    var category: String
    var kcal: Int
    var added: Date
    var expiry: Date
    var storage: StorageKind

    var food: Food { FoodDB.shared.byName[name] ?? Food(emoji: emoji, name: name, kcal: kcal, category: category, shelf: 7) }
    var daysLeft: Int { daysBetween(Date(), expiry) }
    var shelf: Int { max(1, daysBetween(added, expiry)) }
    var fresh: Double { min(1, max(0, Double(daysLeft) / Double(shelf))) }
    var status: String {
        if daysLeft < 0 { return "Expired \(-daysLeft) \(daysLeft == -1 ? "day" : "days") ago" }
        if daysLeft == 0 { return "Use today!" }
        if daysLeft == 1 { return "Expires tomorrow" }
        return "\(daysLeft) days left"
    }
}

struct LogEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var emoji: String
    var name: String
    var kcal: Int
    var date: Date = Date()
}

/// Сообщение в чате с Нутриком. `recipe` — название рецепта, который можно открыть из ответа.
struct ChatMessage: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var text: String
    var fromUser: Bool
    var recipe: String? = nil
    var date: Date = Date()
}

struct WeightEntry: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var kg: Double
}

/// Событие для экрана Eco Impact (по датам): съел, спас, заморозил, поделился, выбросил.
enum EcoKind: String, Codable { case eaten, rescued, frozen, shared, wasted }

struct EcoEvent: Codable, Hashable {
    var kind: EcoKind
    var money: Double
    var date: Date = Date()
}

struct DayValue: Identifiable {
    let day: Date
    let value: Int
    var id: Date { day }
}

struct WeekEco: Identifiable {
    let week: Date
    let saved: Int
    let wasted: Int
    var id: Date { week }
}

struct NamedCount: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct WasteEntry: Codable, Hashable {
    var name: String
    var category: String
    var reason: WasteReason
    var money: Double
    var date: Date = Date()
}

// Все структуры ниже декодируются «мягко»: новые поля в будущих версиях не ломают старые сохранения.

struct Profile: Codable {
    var registered = false
    var tutorialDone = false
    var name = "Friend"
    var email = ""
    var isMan = true
    var age = 20
    var weight = 70.0
    var height = 175.0

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Profile()
        registered = (try? c.decodeIfPresent(Bool.self, forKey: .registered)) ?? d.registered
        tutorialDone = (try? c.decodeIfPresent(Bool.self, forKey: .tutorialDone)) ?? d.tutorialDone
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? d.name
        email = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? d.email
        isMan = (try? c.decodeIfPresent(Bool.self, forKey: .isMan)) ?? d.isMan
        age = (try? c.decodeIfPresent(Int.self, forKey: .age)) ?? d.age
        weight = (try? c.decodeIfPresent(Double.self, forKey: .weight)) ?? d.weight
        height = (try? c.decodeIfPresent(Double.self, forKey: .height)) ?? d.height
    }

    /// Формула Миффлина — Сан-Жеора (как в веб-версии)
    var targetCalories: Int {
        Int((10 * weight + 6.25 * height - 5 * Double(age) + (isMan ? 5 : -161)).rounded())
    }
}

struct Stats: Codable {
    var consumed = 0, rescued = 0, wasted = 0, cooked = 0, bought = 0, frozen = 0, shared = 0
    var rescuedMoney = 0.0, wastedMoney = 0.0
    var streakStart = Date()

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func i(_ k: CodingKeys) -> Int { (try? c.decodeIfPresent(Int.self, forKey: k)) ?? 0 }
        func m(_ k: CodingKeys) -> Double { (try? c.decodeIfPresent(Double.self, forKey: k)) ?? 0 }
        consumed = i(.consumed); rescued = i(.rescued); wasted = i(.wasted); cooked = i(.cooked)
        bought = i(.bought); frozen = i(.frozen); shared = i(.shared)
        rescuedMoney = m(.rescuedMoney); wastedMoney = m(.wastedMoney)
        streakStart = (try? c.decodeIfPresent(Date.self, forKey: .streakStart)) ?? Date()
    }
}

struct AppData: Codable {
    var schema = 1
    var profile = Profile()
    var pantry: [PantryItem] = []
    var log: [LogEntry] = []
    var shopping: [String] = []
    var weights: [WeightEntry] = []
    var unlocked: [String] = []
    var dislikes: [String] = []
    var wasteLog: [WasteEntry] = []
    var stats = Stats()
    var events: [EcoEvent] = []
    var notifications = false
    /// Нутрик выбегает и реагирует на действия (съел, выбросил, заморозил…)
    var nutrikBuddy = true
    /// История чата с Нутриком (последние 80 сообщений)
    var chat: [ChatMessage] = []
    /// Какой по счёту рецепт предлагать на «another»
    var suggestIndex = 0

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schema = (try? c.decodeIfPresent(Int.self, forKey: .schema)) ?? 1
        profile = (try? c.decodeIfPresent(Profile.self, forKey: .profile)) ?? Profile()
        pantry = (try? c.decodeIfPresent([PantryItem].self, forKey: .pantry)) ?? []
        log = (try? c.decodeIfPresent([LogEntry].self, forKey: .log)) ?? []
        shopping = (try? c.decodeIfPresent([String].self, forKey: .shopping)) ?? []
        weights = (try? c.decodeIfPresent([WeightEntry].self, forKey: .weights)) ?? []
        unlocked = (try? c.decodeIfPresent([String].self, forKey: .unlocked)) ?? []
        dislikes = (try? c.decodeIfPresent([String].self, forKey: .dislikes)) ?? []
        wasteLog = (try? c.decodeIfPresent([WasteEntry].self, forKey: .wasteLog)) ?? []
        stats = (try? c.decodeIfPresent(Stats.self, forKey: .stats)) ?? Stats()
        events = (try? c.decodeIfPresent([EcoEvent].self, forKey: .events)) ?? []
        notifications = (try? c.decodeIfPresent(Bool.self, forKey: .notifications)) ?? false
        nutrikBuddy = (try? c.decodeIfPresent(Bool.self, forKey: .nutrikBuddy)) ?? true
        chat = (try? c.decodeIfPresent([ChatMessage].self, forKey: .chat)) ?? []
        suggestIndex = (try? c.decodeIfPresent(Int.self, forKey: .suggestIndex)) ?? 0
    }
}

struct Medal: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let desc: String

    static let all: [Medal] = [
        Medal(id: "first", emoji: "🍽️", title: "First Bite", desc: "Eat or cook your first product"),
        Medal(id: "rescue", emoji: "🦸", title: "Rescuer", desc: "Save 3 products that were about to expire"),
        Medal(id: "chef", emoji: "👨‍🍳", title: "Home Chef", desc: "Cook 3 recipes"),
        Medal(id: "fridge", emoji: "🧊", title: "Fridge Master", desc: "Have 10 products in your fridge"),
        Medal(id: "streak", emoji: "🌱", title: "Zero Waste Week", desc: "7 days without throwing food away"),
        Medal(id: "shop", emoji: "🛒", title: "Smart Shopper", desc: "Buy a product from your shopping list"),
        Medal(id: "weight", emoji: "⚖️", title: "Weigh-in", desc: "Log your weight 3 times"),
        Medal(id: "planet", emoji: "🌍", title: "Planet Hero", desc: "Avoid 2 kg of CO₂ by rescuing food"),
        Medal(id: "freezer", emoji: "❄️", title: "Ice Saver", desc: "Freeze 3 products before they spoil"),
        Medal(id: "share", emoji: "🤝", title: "Good Neighbor", desc: "Share food with someone instead of binning it"),
        Medal(id: "cleanfridge", emoji: "✨", title: "Clean Fridge", desc: "5+ products and nothing expired"),
        Medal(id: "chatty", emoji: "💬", title: "Chatterbox", desc: "Ask Nutrik 5 questions"),
    ]
}
