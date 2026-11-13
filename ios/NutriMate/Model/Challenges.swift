import Foundation

/// Одно задание недели.
struct Challenge: Identifiable, Equatable {
    enum Kind: String { case rescue, cook, eatUp, freeze, buyList, leftovers, share, zeroWaste }
    let kind: Kind
    let target: Int
    let progress: Int
    /// Задание уже не выполнить на этой неделе (например, слишком много дней с отходами)
    var missed = false
    var id: String { kind.rawValue }
    var done: Bool { progress >= target }
    var fraction: Double { min(1, Double(progress) / Double(max(1, target))) }

    var emoji: String {
        switch kind {
        case .rescue: return "🦸"
        case .cook: return "👩‍🍳"
        case .eatUp: return "🍎"
        case .freeze: return "❄️"
        case .buyList: return "🛒"
        case .leftovers: return "🥡"
        case .share: return "🤝"
        case .zeroWaste: return "🌱"
        }
    }

    var title: String {
        switch kind {
        case .rescue: return L("Rescue {0} that are about to expire", Lp(target, "product|products"))
        case .cook: return L("Cook {0} from your fridge", Lp(target, "recipe|recipes"))
        case .eatUp: return L("Eat {0} from your fridge", Lp(target, "product|products"))
        case .freeze: return L("Freeze {0} before they spoil", Lp(target, "product|products"))
        case .buyList: return L("Buy {0} from your shopping list", Lp(target, "item|items"))
        case .leftovers: return L("Save {0} of leftovers for later", Lp(target, "portion|portions"))
        case .share: return L("Share food with someone instead of binning it")
        case .zeroWaste: return L("{0} without throwing food away", Lp(target, "day|days"))
        }
    }

    /// Подсказка, как выполнить
    var hint: String {
        switch kind {
        case .rescue: return L("Eat or cook something from “Use these first” on Home — items with 0–2 days left count.")
        case .cook: return L("Open Recipes → “Cook now” and tap “I cooked it!” in a recipe.")
        case .eatUp: return L("Tap a product in your fridge → “Ate it”.")
        case .freeze: return L("Bread, meat, berries and bananas freeze well — product card → “Freeze”.")
        case .buyList: return L("Tick items in the shopping list when you buy them, or scan your receipt.")
        case .leftovers: return L("Cooked too much? Keep the leftovers in the fridge when you tap “I cooked it!”.")
        case .share: return L("Product card → “Share” — a neighbour, friend or food-sharing fridge.")
        case .zeroWaste: return L("Every day without “Throw away” counts. Check “Use these first” each morning.")
        }
    }
}

/// Недельные задания (v32): три задания на неделю (пн–вс), меняются каждую неделю.
/// Прогресс считается из уже сохранённых событий (Eco-события и `acts`), поэтому отдельного состояния нет;
/// выполненные запоминаются в `questsDone` (для XP и медали).
struct Challenges {
    static let xpPerQuest = 40
    static let xpBonusAll = 60

    let items: [Challenge]
    let weekStart: Date
    let weekNumber: Int
    let year: Int

    static var calendar: Calendar {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }

    init(data: AppData, now: Date = Date()) {
        let cal = Challenges.calendar
        let start = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? cal.startOfDay(for: now)
        weekStart = start
        let wn = cal.component(.weekOfYear, from: now)
        weekNumber = wn
        year = cal.component(.yearForWeekOfYear, from: now)

        let ev = data.events.filter { $0.date >= start && $0.date <= now }
        let acts = data.acts.filter { $0.date >= start && $0.date <= now }
        func events(_ k: EcoKind...) -> Int { ev.filter { k.contains($0.kind) }.count }
        func actCount(_ k: String) -> Int { acts.filter { $0.kind == k }.reduce(0) { $0 + $1.n } }

        // Дни недели до сегодня включительно без «выбросил»
        let today = cal.startOfDay(for: now)
        let elapsed = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
        let wasteDays = Set(ev.filter { $0.kind == .wasted }.map { cal.startOfDay(for: $0.date) }).count
        let clean = max(0, elapsed - wasteDays)

        func make(_ k: Challenge.Kind) -> Challenge {
            switch k {
            case .rescue: return Challenge(kind: k, target: 3, progress: events(.rescued))
            case .cook: return Challenge(kind: k, target: 2, progress: actCount("cook"))
            case .eatUp: return Challenge(kind: k, target: 6, progress: events(.eaten, .rescued))
            case .freeze: return Challenge(kind: k, target: 2, progress: events(.frozen))
            case .buyList: return Challenge(kind: k, target: 3, progress: actCount("buy"))
            case .leftovers: return Challenge(kind: k, target: 2, progress: actCount("leftover"))
            case .share: return Challenge(kind: k, target: 1, progress: events(.shared))
            case .zeroWaste: return Challenge(kind: k, target: 5, progress: clean, missed: 7 - wasteDays < 5)
            }
        }
        // Слот A — спасти/приготовить/съесть, слот B — заморозить/купить по списку/остатки/поделиться, C — дни без отходов
        let a: [Challenge.Kind] = [.rescue, .cook, .eatUp]
        let b: [Challenge.Kind] = [.freeze, .buyList, .leftovers, .share]
        items = [make(a[wn % a.count]), make(b[wn % b.count]), make(.zeroWaste)]
    }

    var doneCount: Int { items.filter(\.done).count }
    var allDone: Bool { doneCount == items.count }
    var weekKey: String { "\(year)-\(weekNumber)" }
    func key(_ c: Challenge) -> String { "\(weekKey):\(c.kind.rawValue)" }
    var allKey: String { "\(weekKey):all" }

    /// Сколько дней осталось до конца недели (включая сегодня)
    var daysLeft: Int {
        let cal = Challenges.calendar
        let end = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        return max(1, cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: end).day ?? 1)
    }

    /// XP за выполненные задания
    static func xp(_ done: [String]) -> Int {
        done.reduce(0) { $0 + ($1.hasSuffix(":all") ? xpBonusAll : xpPerQuest) }
    }

    /// Итоги за всё время: выполнено заданий и «чемпионских» недель
    static func history(_ done: [String]) -> (quests: Int, weeks: Int) {
        (done.filter { !$0.hasSuffix(":all") }.count, done.filter { $0.hasSuffix(":all") }.count)
    }
}
