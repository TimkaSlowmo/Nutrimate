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
    /// Сценка Нутрика (выбегает снизу слева, ест / падает / радуется)
    @Published var reaction: NutrikReaction?

    private let fileURL: URL
    private var saveWork: DispatchWorkItem?
    private var reminderWork: DispatchWorkItem?

    let db = FoodDB.shared

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if UIShot.enabled {
            // режим скриншотов: демо-данные в отдельном файле, настоящие данные не трогаем
            fileURL = dir.appendingPathComponent("nutrimate-uishot.json")
            data = UIShot.demoData()
            return
        }
        fileURL = dir.appendingPathComponent("nutrimate.json")
        data = AppStore.load(from: fileURL)
        if data.notifications { Reminders.reschedule(data) }
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
        reminderWork?.cancel()
        let rw = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Reminders.reschedule(self.data)
        }
        reminderWork = rw
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: rw)
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

    /// Реакция Нутрика вместо обычного тоста (если сценки включены и туториал пройден).
    func react(_ kind: NutrikReaction.Kind, _ text: String, emoji: String? = nil) {
        if data.nutrikBuddy && data.profile.tutorialDone {
            reaction = NutrikReaction(kind: kind, text: text, emoji: emoji)
        } else {
            say(text)
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
            data.events.append(EcoEvent(kind: .rescued, money: price(p.category)))
        } else {
            data.events.append(EcoEvent(kind: .eaten, money: 0))
        }
    }

    // MARK: - Eco Impact и статистика

    /// Калории по дням за последние `days` дней (включая сегодня).
    func caloriesByDay(_ days: Int = 7) -> [DayValue] {
        let today = dayStart(Date())
        var out: [DayValue] = []
        for back in stride(from: days - 1, through: 0, by: -1) {
            let d = Calendar.current.date(byAdding: .day, value: -back, to: today) ?? today
            let k = data.log.filter { dayStart($0.date) == d }.reduce(0) { $0 + $1.kcal }
            out.append(DayValue(day: d, value: k))
        }
        return out
    }

    /// Спасено / выброшено по неделям (последние `weeks` недель).
    func ecoByWeek(_ weeks: Int = 6) -> [WeekEco] {
        let cal = Calendar.current
        let thisWeek = cal.dateInterval(of: .weekOfYear, for: Date())?.start ?? dayStart(Date())
        var out: [WeekEco] = []
        for back in stride(from: weeks - 1, through: 0, by: -1) {
            let start = cal.date(byAdding: .weekOfYear, value: -back, to: thisWeek) ?? thisWeek
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let inWeek = data.events.filter { $0.date >= start && $0.date < end }
            let saved = inWeek.filter { $0.kind == .rescued || $0.kind == .frozen || $0.kind == .shared }.count
            let lost = inWeek.filter { $0.kind == .wasted }.count
            out.append(WeekEco(week: start, saved: saved, wasted: lost))
        }
        return out
    }

    var wasteReasons: [NamedCount] {
        var out: [NamedCount] = []
        for r in WasteReason.allCases {
            let n = data.wasteLog.filter { $0.reason == r }.count
            if n > 0 { out.append(NamedCount(name: r.title, count: n)) }
        }
        return out
    }

    var wasteCategories: [NamedCount] {
        var counts: [String: Int] = [:]
        for w in data.wasteLog { counts[w.category, default: 0] += 1 }
        return counts.map { NamedCount(name: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    /// Сколько кг еды спасено (≈ 0.3 кг на продукт, как в веб-версии)
    var rescuedKg: Double { Double(data.stats.rescued) * 0.3 }
    var wastedKg: Double { Double(data.stats.wasted) * 0.3 }

    func eat(_ id: UUID, grams: Int, finished: Bool) {
        guard let p = item(id) else { return }
        if finished {
            use(p)
            data.pantry.removeAll { $0.id == id }
        }
        data.log.append(LogEntry(emoji: p.emoji, name: "\(p.name) · \(grams) g", kcal: Int((Double(p.kcal) * Double(grams) / 100).rounded())))
        haptic(.medium)
        react(.eat, finished && p.daysLeft >= 0 && p.daysLeft <= 2 ? "Rescued & yummy! \(p.name) logged 🦸" : "Yum! \(p.name) logged", emoji: p.emoji)
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
        data.events.append(EcoEvent(kind: .wasted, money: price(p.category)))
        if reason == .disliked && !data.dislikes.contains(p.name.lowercased()) { data.dislikes.append(p.name.lowercased()) }
        haptic(.rigid)
        react(.sad, "Oops… \(p.emoji) went to the bin 😿 Next time we'll save it!")
    }

    func freeze(_ id: UUID) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        let p = data.pantry[i]
        if p.daysLeft >= 0 && p.daysLeft <= 2 {
            data.stats.rescued += 1
            data.stats.rescuedMoney += price(p.category)
        }
        data.events.append(EcoEvent(kind: .frozen, money: price(p.category)))
        data.pantry[i].storage = .freezer
        data.pantry[i].expiry = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
        data.stats.frozen += 1
        haptic()
        react(.cheer, "❄️ Frozen — good for 3 more months!")
        checkMedals()
    }

    func share(_ id: UUID) {
        guard let p = item(id) else { return }
        data.pantry.removeAll { $0.id == id }
        data.stats.shared += 1
        data.stats.rescued += 1
        data.stats.consumed += 1
        data.stats.rescuedMoney += price(p.category)
        data.events.append(EcoEvent(kind: .shared, money: price(p.category)))
        haptic(.medium)
        react(.cheer, "🤝 Shared! That's real zero waste")
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
        react(.eat, "Bon appétit! \(r.name) cooked 👩‍🍳", emoji: r.emoji)
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
        Reminders.clear()
    }

    // MARK: - Туториал и уведомления

    func finishTutorial() {
        withAnimation(.easeInOut(duration: 0.4)) { data.profile.tutorialDone = true }
    }

    func replayTutorial() {
        withAnimation(.easeInOut(duration: 0.4)) { data.profile.tutorialDone = false }
    }

    func setNotifications(_ on: Bool) {
        if !on {
            data.notifications = false
            Reminders.clear()
            return
        }
        Reminders.requestPermission { [weak self] granted in
            guard let self else { return }
            self.data.notifications = granted
            if granted {
                Reminders.reschedule(self.data)
                self.say("🔔 Nutrik will remind you at 9:00")
            } else {
                self.say("Notifications are off in iPhone Settings")
            }
        }
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
        case "chatty": return data.chat.filter(\.fromUser).count >= 5
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

/// Сценка Нутрика для оверлея `NutrikBuddy`.
struct NutrikReaction: Identifiable, Equatable {
    enum Kind: Equatable { case eat, sad, cheer }
    let id = UUID()
    let kind: Kind
    let text: String
    let emoji: String?
}
