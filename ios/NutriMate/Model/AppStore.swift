import Foundation
import SwiftUI
import UIKit

/// Всё состояние приложения. Каждое изменение `data` сохраняется на диск (с задержкой 0.4 с),
/// поэтому переустановка поверх и перезапуск ничего не стирают.
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet { scheduleSave() }
    }
    @Published var toast: String?
    @Published var newMedal: Medal?

    private let fileURL: URL
    private var saveWork: DispatchWorkItem?

    let db = FoodDB.shared

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("nutrimate.json")
        data = AppStore.load(from: fileURL)
    }

    private static func load(from url: URL) -> AppData {
        guard let raw = try? Data(contentsOf: url) else { return AppData() }
        do {
            return try JSONDecoder().decode(AppData.self, from: raw)
        } catch {
            // Не затираем повреждённый файл — откладываем копию, чтобы данные можно было спасти.
            let backup = url.deletingPathExtension().appendingPathExtension("broken-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.copyItem(at: url, to: backup)
            return AppData()
        }
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        do {
            let raw = try JSONEncoder().encode(data)
            try raw.write(to: fileURL, options: .atomic)
        } catch {
            print("NutriMate save failed: \(error)")
        }
    }

    // MARK: - Вычисляемое

    var pantryNames: Set<String> { Set(data.pantry.map(\.name)) }
    var sortedPantry: [PantryItem] { data.pantry.sorted { $0.daysLeft < $1.daysLeft } }
    var expiringSoon: [PantryItem] { sortedPantry.filter { $0.daysLeft <= 2 } }
    var toRescue: [PantryItem] { expiringSoon.filter { $0.daysLeft >= 0 } }
    var expired: [PantryItem] { data.pantry.filter { $0.daysLeft < 0 } }
    var todayLog: [LogEntry] { data.log.filter { Calendar.current.isDateInToday($0.date) } }
    var eatenToday: Int { todayLog.reduce(0) { $0 + $1.kcal } }
    var targetCalories: Int { data.profile.targetCalories }
    var co2: Double { Double(data.stats.rescued) * 0.3 * 2.5 }
    var ecoScore: Int {
        let s = data.stats
        return s.consumed + s.wasted == 0 ? 100 : Int((100.0 * Double(s.consumed) / Double(s.consumed + s.wasted)).rounded())
    }
    var streakDays: Int { daysBetween(data.stats.streakStart, Date()) }
    var moneyAtRisk: Double { toRescue.reduce(0) { $0 + price($1.category) } }

    func price(_ category: String) -> Double { FoodDB.price[category] ?? 2.0 }
    func item(_ id: UUID) -> PantryItem? { data.pantry.first { $0.id == id } }

    func rankedRecipes() -> [Recipe] {
        let have = pantryNames
        let urgent = Set(toRescue.map(\.name))
        let dislikes = data.dislikes
        func score(_ r: Recipe) -> Int {
            let miss = r.missing(have).count
            return (miss == 0 ? 1000 : 0)
                + r.ingredients.filter { urgent.contains($0.name) }.count * 50
                + r.ingredients.filter { have.contains($0.name) }.count * 10 - miss
        }
        return db.recipes
            .filter { r in !r.ingredients.contains { i in dislikes.contains { i.name.lowercased().contains($0) } } }
            .sorted { score($0) > score($1) }
    }

    // MARK: - Действия

    func say(_ text: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { toast = text }
        let current = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            guard let self, self.toast == current else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.toast = nil }
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func add(_ f: Food, days: Int? = nil, storage: StorageKind? = nil, count: Int = 1, quiet: Bool = false) {
        let now = Date()
        let place = storage ?? FoodDB.defaultStorage(f)
        let exp = Calendar.current.date(byAdding: .day, value: days ?? f.shelf, to: now) ?? now
        for _ in 0..<max(1, count) {
            data.pantry.append(PantryItem(name: f.name, emoji: f.emoji, category: f.category, kcal: f.kcal,
                                          added: now, expiry: exp, storage: place))
        }
        if !quiet {
            haptic()
            say("\(f.emoji) \(count > 1 ? "\(count)× " : "")\(f.name) added to your \(place.title.lowercased())")
        }
        checkMedals()
    }

    private func use(_ p: PantryItem) {
        data.stats.consumed += 1
        if p.daysLeft >= 0 && p.daysLeft <= 2 {
            data.stats.rescued += 1
            data.stats.rescuedMoney += price(p.category)
        }
    }

    func eat(_ id: UUID, grams: Int, finished: Bool) {
        guard let p = item(id) else { return }
        if finished {
            use(p)
            data.pantry.removeAll { $0.id == id }
        }
        data.log.append(LogEntry(emoji: p.emoji, name: "\(p.name) · \(grams) g", kcal: Int((Double(p.kcal) * Double(grams) / 100).rounded())))
        haptic(.medium)
        say("Yum! \(p.emoji) logged")
        checkMedals()
    }

    func logFood(_ f: Food, grams: Int) {
        data.log.append(LogEntry(emoji: f.emoji, name: "\(f.name) · \(grams) g", kcal: Int((Double(f.kcal) * Double(grams) / 100).rounded())))
        haptic()
        say("\(f.emoji) +\(Int((Double(f.kcal) * Double(grams) / 100).rounded())) kcal")
        checkMedals()
    }

    func removeLog(_ id: UUID) { data.log.removeAll { $0.id == id } }

    func throwAway(_ id: UUID, reason: WasteReason) {
        guard let p = item(id) else { return }
        data.pantry.removeAll { $0.id == id }
        data.stats.wasted += 1
        data.stats.wastedMoney += price(p.category)
        data.stats.streakStart = Date()
        data.wasteLog.append(WasteEntry(name: p.name, category: p.category, reason: reason, money: price(p.category)))
        if reason == .disliked && !data.dislikes.contains(p.name.lowercased()) { data.dislikes.append(p.name.lowercased()) }
        haptic(.rigid)
        say("Nutrik is a little sad 😿 Next time we'll save it!")
    }

    func freeze(_ id: UUID) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        let p = data.pantry[i]
        if p.daysLeft >= 0 && p.daysLeft <= 2 {
            data.stats.rescued += 1
            data.stats.rescuedMoney += price(p.category)
        }
        data.pantry[i].storage = .freezer
        data.pantry[i].expiry = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
        data.stats.frozen += 1
        haptic()
        say("❄️ Frozen — good for 3 more months")
        checkMedals()
    }

    func share(_ id: UUID) {
        guard let p = item(id) else { return }
        data.pantry.removeAll { $0.id == id }
        data.stats.shared += 1
        data.stats.rescued += 1
        data.stats.consumed += 1
        data.stats.rescuedMoney += price(p.category)
        haptic(.medium)
        say("🤝 Shared! That's real zero waste")
        checkMedals()
    }

    func delete(_ id: UUID) { data.pantry.removeAll { $0.id == id } }

    func setExpiry(_ id: UUID, _ d: Date) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        data.pantry[i].expiry = d
    }

    func move(_ id: UUID, to s: StorageKind) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        data.pantry[i].storage = s
    }

    func cook(_ r: Recipe, portions: Int) {
        for ing in r.ingredients {
            let matches = data.pantry.filter { $0.name == ing.name }.sorted { $0.daysLeft < $1.daysLeft }
            if let first = matches.first {
                use(first) // сначала то, что скорее испортится
                data.pantry.removeAll { $0.id == first.id }
            }
        }
        data.log.append(LogEntry(emoji: r.emoji, name: "\(r.name) ×\(portions)", kcal: r.kcal * portions))
        data.stats.cooked += 1
        haptic(.medium)
        say("👩‍🍳 Bon appétit! \(r.name) cooked")
        checkMedals()
    }

    func addShopping(_ names: [String]) {
        var added = 0
        for n in names where !data.shopping.contains(n) {
            data.shopping.append(n)
            added += 1
        }
        if added > 0 { say("🛒 \(added) added to shopping list") }
    }

    func removeShopping(_ n: String) { data.shopping.removeAll { $0 == n } }

    func buy(_ n: String) {
        data.shopping.removeAll { $0 == n }
        if let f = db.byName[n] {
            data.stats.bought += 1
            add(f)
        }
    }

    func addWeight(_ kg: Double) {
        data.weights.append(WeightEntry(date: Date(), kg: kg))
        data.profile.weight = kg
        checkMedals()
    }

    func register(name: String, email: String, isMan: Bool, age: Int, weight: Double, height: Double, demo: Bool) {
        data.profile.name = name.isEmpty ? "Friend" : name
        data.profile.email = email
        data.profile.isMan = isMan
        data.profile.age = age
        data.profile.weight = weight
        data.profile.height = height
        data.weights = [WeightEntry(date: Date(), kg: weight)]
        data.stats.streakStart = Date()
        if demo { loadDemo() }
        withAnimation(.easeInOut(duration: 0.5)) { data.profile.registered = true }
        saveNow()
    }

    func loadDemo() {
        let demo: [(String, Int)] = [
            ("Banana", 1), ("Milk", 0), ("Kefir", 2), ("Tomato", 1), ("Bell Pepper", 3), ("Eggs", 12),
            ("Chicken Breast", 1), ("White Bread", 0), ("Apple", 9), ("Potato", 20), ("Carrot", 14),
            ("Onion", 25), ("Cheddar Cheese", 10), ("Spinach", -1), ("Rice", 300), ("Flour", 200),
            ("Sugar", 300), ("Butter", 20), ("Vegetable Oil", 300), ("Strawberry", 2), ("Kurt", 60),
        ]
        for (n, d) in demo {
            if let f = db.byName[n] { add(f, days: d, quiet: true) }
        }
        say("🧺 Demo products added")
    }

    func eraseAll() {
        data = AppData()
        saveNow()
    }

    // MARK: - Достижения

    private func done(_ id: String) -> Bool {
        let s = data.stats
        switch id {
        case "first": return s.consumed >= 1 || s.cooked >= 1
        case "rescue": return s.rescued >= 3
        case "chef": return s.cooked >= 3
        case "fridge": return data.pantry.count >= 10
        case "streak": return streakDays >= 7
        case "shop": return s.bought >= 1
        case "weight": return data.weights.count >= 3
        case "freezer": return s.frozen >= 3
        case "share": return s.shared >= 1
        case "cleanfridge": return data.pantry.count >= 5 && expired.isEmpty
        default: return co2 >= 2
        }
    }

    func checkMedals() {
        for m in Medal.all where !data.unlocked.contains(m.id) && done(m.id) {
            data.unlocked.append(m.id)
            newMedal = m
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
