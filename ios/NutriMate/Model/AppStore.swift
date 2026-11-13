import Foundation
import SwiftUI
import UIKit

/// Всё состояние приложения. Каждое изменение `data` сохраняется на диск (с задержкой 0.4 с),
/// поэтому переустановка поверх и перезапуск ничего не стирают.
final class AppStore: ObservableObject {
    @Published var data: AppData {
        didSet {
            if AppLang.current != data.language { AppLang.current = data.language }
            if AppCurrency.current != data.effectiveCurrency { AppCurrency.current = data.effectiveCurrency }
            groupsCache = nil
            rankCache = nil
            scheduleSave()
        }
    }
    // Кэши тяжёлых вычислений: пересчитываются только после изменения данных, а не в каждом body.
    private var groupsCache: [PantryGroup]?
    private var rankCache: [Recipe]?
    @Published var toast: String?
    @Published var newMedal: Medal?
    /// Сценка Нутрика (выбегает снизу слева, ест / падает / радуется)
    @Published var reaction: NutrikReaction?
    /// «Отменить» после съел/выбросил/заморозил/поделился/убрал/приготовил (6 секунд).
    @Published var undo: UndoInfo?
    private var undoSnapshot: AppData?

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
            AppLang.current = data.language
            AppCurrency.current = data.effectiveCurrency
            if UIShot.args.contains("-undo"), let p = data.pantry.first {
                undoSnapshot = data
                undo = UndoInfo(icon: "trash", text: L("Thrown away: {0}", "\(p.emoji) \(N(p.name))"))
            }
            return
        }
        fileURL = dir.appendingPathComponent("nutrimate.json")
        data = AppStore.load(from: fileURL)
        AppLang.current = data.language
        AppCurrency.current = data.effectiveCurrency
        // v9: одинаковые продукты складываются в одну строку — мягко объединяем старые сохранения
        let merged = AppStore.normalized(data.pantry)
        if merged.count != data.pantry.count { data.pantry = merged }
        // v10: дата начала для профиля — один раз берём самую раннюю запись
        if data.profile.registered && data.profile.joined == nil { data.profile.joined = joinedDate }
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
    /// Сколько штук/упаковок продукта есть дома (все места хранения).
    func count(of name: String) -> Int { data.pantry.reduce(0) { $0 + ($1.name == name ? $1.qty : 0) } }
    /// Строки холодильника (одинаковые продукты сложены), от ближайшего срока к дальнему.
    var sortedPantry: [PantryGroup] {
        if let c = groupsCache { return c }
        let g = PantryGroup.make(data.pantry).sorted { $0.expiry < $1.expiry }
        groupsCache = g
        return g
    }
    /// Сколько всего штук/упаковок дома
    var unitCount: Int { data.pantry.reduce(0) { $0 + $1.qty } }
    var expiringSoon: [PantryGroup] { sortedPantry.filter { $0.daysLeft <= 2 } }
    var toRescue: [PantryGroup] { expiringSoon.filter { $0.daysLeft >= 0 } }
    /// Сколько строк холодильника попадёт в план «доедаем всё» (не морозилка, срок 0…4 дня)
    var planRiskCount: Int { sortedPantry.filter { $0.storage != .freezer && $0.daysLeft >= 0 && $0.daysLeft <= UseUpPlan.window }.count }
    var expired: [PantryGroup] { sortedPantry.filter { $0.daysLeft < 0 } }
    func group(_ key: String) -> PantryGroup? { sortedPantry.first { $0.id == key } }
    var todayLog: [LogEntry] { data.log.filter { Calendar.current.isDateInToday($0.date) } }
    var eatenToday: Int { todayLog.reduce(0) { $0 + $1.kcal } }
    var targetCalories: Int { data.profile.targetCalories }
    var co2: Double { Double(data.stats.rescued) * 0.3 * 2.5 }
    var ecoScore: Int {
        let s = data.stats
        return s.consumed + s.wasted == 0 ? 100 : Int((100.0 * Double(s.consumed) / Double(s.consumed + s.wasted)).rounded())
    }
    var streakDays: Int { daysBetween(data.stats.streakStart, Date()) }
    var moneyAtRisk: Double {
        var sum = 0.0
        for g in toRescue {
            for b in g.batches where b.daysLeft <= 2 { sum += price(b.category) * Double(b.qty) }
        }
        return sum
    }

    func price(_ category: String) -> Double { FoodDB.price[category] ?? 2.0 }

    /// Подсказка к строке списка покупок (v31): сколько уже есть дома (несрочно-просроченное)
    /// и сколько раз этот продукт выбрасывали за 60 дней — «купи меньше».
    struct ShopHint: Equatable {
        var homeQty = 0
        var homeDays: Int? = nil
        var wasted = 0
        var isEmpty: Bool { homeQty == 0 && wasted == 0 }
    }

    func shopHint(_ name: String) -> ShopHint {
        var h = ShopHint()
        for g in sortedPantry where g.name == name && !g.isLeftover {
            for b in g.batches where b.daysLeft >= 0 {
                h.homeQty += b.qty
                h.homeDays = min(h.homeDays ?? b.daysLeft, b.daysLeft)
            }
        }
        let since = Calendar.current.date(byAdding: .day, value: -60, to: Date()) ?? Date()
        h.wasted = data.wasteLog.filter { $0.name == name && $0.date >= since }.count
        return h
    }

    /// Убрать из списка всё, что уже есть дома (свежее). Возвращает, сколько убрано.
    @discardableResult
    func removeShoppingAtHome() -> Int {
        let home = data.shopping.filter { shopHint($0).homeQty > 0 }
        guard !home.isEmpty else { return 0 }
        withAnimation { data.shopping.removeAll { home.contains($0) } }
        say(L("🏠 {0} removed — you already have them", Lp(home.count, "product|products")))
        return home.count
    }
    func item(_ id: UUID) -> PantryItem? { data.pantry.first { $0.id == id } }

    func rankedRecipes() -> [Recipe] {
        if let c = rankCache { return c }
        let r = computeRankedRecipes()
        rankCache = r
        return r
    }

    private func computeRankedRecipes() -> [Recipe] {
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

    /// Запомнить состояние до действия — кнопка «Отменить» вернёт всё как было (кроме чата и настроек).
    private func remember(_ icon: String, _ text: String) {
        undoSnapshot = data
        let u = UndoInfo(icon: icon, text: text)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { undo = u }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            guard let self, self.undo?.id == u.id else { return }
            withAnimation(.easeOut(duration: 0.3)) { self.undo = nil }
            self.undoSnapshot = nil
        }
    }

    func performUndo() {
        guard var s = undoSnapshot else { return }
        s.chat = data.chat
        s.language = data.language
        s.appearance = data.appearance
        s.notifications = data.notifications
        s.nutrikBuddy = data.nutrikBuddy
        undoSnapshot = nil
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            data = s
            undo = nil
            reaction = nil
        }
        haptic(.soft)
        say(L("↩️ Undone — everything is back"))
    }

    func dismissUndo() {
        withAnimation(.easeOut(duration: 0.25)) { undo = nil }
        undoSnapshot = nil
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func add(_ f: Food, days: Int? = nil, storage: StorageKind? = nil, count: Int = 1, quiet: Bool = false) {
        let now = Date()
        let place = storage ?? FoodDB.defaultStorage(f)
        let exp = Calendar.current.date(byAdding: .day, value: days ?? f.shelf, to: now) ?? now
        let n = max(1, count)
        // та же партия (тот же продукт, место и срок ±1 день) → просто +n; иначе новая партия в той же строке
        if let i = data.pantry.firstIndex(where: { $0.name == f.name && !$0.leftover && $0.opened == nil && $0.storage == place && abs(daysBetween($0.expiry, exp)) <= 1 }) {
            data.pantry[i].qty += n
        } else {
            data.pantry.append(PantryItem(name: f.name, emoji: f.emoji, category: f.category, kcal: f.kcal,
                                          added: now, expiry: exp, storage: place, qty: n))
        }
        if !quiet {
            haptic()
            let total = data.pantry.filter { $0.name == f.name && !$0.leftover && $0.storage == place }.reduce(0) { $0 + $1.qty }
            let what = n > 1 ? "\(n)× \(N(f.name))" : N(f.name)
            let msg = L("{0} {1} added to your {2}", f.emoji, what, place.title.lowercased())
            say(total > n ? msg + L(" · now ×{0}", total) : msg)
        }
        checkMedals()
    }

    /// Объединяет партии одного продукта в одном месте с одинаковым сроком (±1 день) — ничего не теряя.
    static func normalized(_ items: [PantryItem]) -> [PantryItem] {
        var out: [PantryItem] = []
        for p in items {
            if let i = out.firstIndex(where: { $0.groupKey == p.groupKey && abs(daysBetween($0.expiry, p.expiry)) <= 1 }) {
                out[i].qty += p.qty
                if p.expiry < out[i].expiry { out[i].expiry = p.expiry }   // осторожно: берём более ранний срок
                if p.added < out[i].added { out[i].added = p.added }
            } else {
                out.append(p)
            }
        }
        return out
    }

    /// Списать одну штуку из партии `id` (партия исчезает, когда кончилась).
    private func takeOne(_ id: UUID) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        if data.pantry[i].qty > 1 { data.pantry[i].qty -= 1 } else { data.pantry.remove(at: i) }
    }

    /// Самая старая партия того же продукта в том же месте (FIFO): «съел»/«выбросил» списывают сначала её.
    private func oldest(_ id: UUID) -> PantryItem? {
        guard let p = item(id) else { return nil }
        return data.pantry.filter { $0.groupKey == p.groupKey }.min { $0.expiry < $1.expiry }
    }

    /// ＋ в карточке: ещё одна штука в самую свежую партию (без статистики).
    func increment(_ key: String) {
        guard let g = group(key), let newest = g.batches.last,
              let i = data.pantry.firstIndex(where: { $0.id == newest.id }) else { return }
        data.pantry[i].qty += 1
        haptic()
    }

    /// − в карточке: убрать одну штуку из самой свежей партии (исправление количества, без статистики).
    func decrement(_ key: String) {
        guard let g = group(key), let newest = g.batches.last else { return }
        takeOne(newest.id)
        haptic()
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
        guard let p = oldest(id) else { return }
        remember("fork.knife", L("Eaten: {0}", "\(p.emoji) \(N(p.name))"))
        if finished {
            use(p)
            takeOne(p.id)
        }
        data.log.append(LogEntry(emoji: p.emoji, name: "\(N(p.name)) · \(grams) \(L("g"))", kcal: Int((Double(p.kcal) * Double(grams) / 100).rounded())))
        haptic(.medium)
        react(.eat, finished && p.daysLeft >= 0 && p.daysLeft <= 2 ? L("Rescued & yummy! {0} logged 🦸", N(p.name)) : L("Yum! {0} logged", N(p.name)), emoji: p.emoji)
        checkMedals()
    }

    func logFood(_ f: Food, grams: Int) {
        data.log.append(LogEntry(emoji: f.emoji, name: "\(N(f.name)) · \(grams) \(L("g"))", kcal: Int((Double(f.kcal) * Double(grams) / 100).rounded())))
        haptic()
        say(L("{0} +{1} kcal", f.emoji, Int((Double(f.kcal) * Double(grams) / 100).rounded())))
        checkMedals()
    }

    func removeLog(_ id: UUID) { data.log.removeAll { $0.id == id } }

    func throwAway(_ id: UUID, reason: WasteReason) {
        guard let p = oldest(id) else { return }
        remember("trash", L("Thrown away: {0}", "\(p.emoji) \(N(p.name))"))
        takeOne(p.id)
        data.stats.wasted += 1
        data.stats.wastedMoney += price(p.category)
        data.stats.streakStart = Date()
        data.wasteLog.append(WasteEntry(name: p.name, category: p.category, reason: reason, money: price(p.category)))
        data.events.append(EcoEvent(kind: .wasted, money: price(p.category)))
        if reason == .disliked && !data.dislikes.contains(p.name.lowercased()) { data.dislikes.append(p.name.lowercased()) }
        haptic(.rigid)
        react(.sad, L("Oops… {0} went to the bin 😿 Next time we'll save it!", p.emoji))
    }

    /// Заморозить всю строку (все партии этого продукта из холодильника/шкафа); статистика — по штукам.
    func freeze(_ id: UUID) {
        guard let p = item(id) else { return }
        remember("snowflake", L("Frozen: {0}", "\(p.emoji) \(N(p.name))"))
        let batch = data.pantry.filter { $0.groupKey == p.groupKey }
        var units = 0
        for b in batch {
            for _ in 0..<b.qty {
                if b.daysLeft >= 0 && b.daysLeft <= 2 {
                    data.stats.rescued += 1
                    data.stats.rescuedMoney += price(b.category)
                }
                data.events.append(EcoEvent(kind: .frozen, money: price(b.category)))
                data.stats.frozen += 1
                units += 1
            }
        }
        let exp = Calendar.current.date(byAdding: .day, value: 90, to: Date()) ?? Date()
        var pantry = data.pantry
        for i in pantry.indices where pantry[i].groupKey == p.groupKey {
            pantry[i].storage = .freezer
            pantry[i].expiry = exp
            pantry[i].opened = nil   // в морозилке «открытая» и целая упаковка — одно и то же
        }
        data.pantry = AppStore.normalized(pantry)
        haptic()
        react(.cheer, units > 1 ? L("❄️ {0}× {1} frozen — good for 3 more months!", units, N(p.name)) : L("❄️ Frozen — good for 3 more months!"))
        checkMedals()
    }

    func share(_ id: UUID) {
        guard let p = oldest(id) else { return }
        remember("hand.raised", L("Shared: {0}", "\(p.emoji) \(N(p.name))"))
        takeOne(p.id)
        data.stats.shared += 1
        data.stats.rescued += 1
        data.stats.consumed += 1
        data.stats.rescuedMoney += price(p.category)
        data.events.append(EcoEvent(kind: .shared, money: price(p.category)))
        haptic(.medium)
        react(.cheer, L("🤝 Shared! That's real zero waste"))
        checkMedals()
    }

    /// «Открыл(а)» (v28): одна штука из самой старой партии становится открытой — отдельной строкой со сроком
    /// «после вскрытия» (молоко ~5 дней, консервы 3); из шкафа переезжает в холодильник. Возвращает срок в днях.
    @discardableResult
    func open(_ id: UUID) -> Int? {
        guard let p = oldest(id), p.opened == nil, p.storage != .freezer, !p.leftover,
              let days = FoodDB.openedDays(p.food, daysLeft: p.daysLeft) else { return nil }
        remember("lock.open", L("Opened: {0}", "\(p.emoji) \(N(p.name))"))
        takeOne(p.id)
        let now = Date()
        var o = p
        o.id = UUID()
        o.qty = 1
        o.opened = now
        o.added = now
        o.expiry = min(p.expiry, Calendar.current.date(byAdding: .day, value: days, to: now) ?? now)
        let moved = o.storage == .pantry && FoodDB.fridgeWhenOpened(p.food)
        if moved { o.storage = .fridge }
        data.pantry.append(o)
        haptic()
        let left = max(1, o.daysLeft)
        say(moved ? L("🔓 {0} opened and moved to the fridge — use within {1}", "\(p.emoji) \(N(p.name))", Lp(left, "day|days"))
                  : L("🔓 {0} opened — use within {1}", "\(p.emoji) \(N(p.name))", Lp(left, "day|days")))
        return days
    }

    /// Убрать строку целиком без статистики (ошибся при добавлении).
    func delete(_ id: UUID) {
        guard let p = item(id) else { return }
        remember("xmark.bin", L("Removed: {0}", "\(p.emoji) \(N(p.name))"))
        data.pantry.removeAll { $0.groupKey == p.groupKey }
    }

    func setExpiry(_ id: UUID, _ d: Date) {
        guard let i = data.pantry.firstIndex(where: { $0.id == id }) else { return }
        data.pantry[i].expiry = d
    }

    /// Переложить всю строку в другое место (там сложится с таким же продуктом).
    func move(_ id: UUID, to s: StorageKind) {
        guard let p = item(id), p.storage != s else { return }
        var pantry = data.pantry
        for i in pantry.indices where pantry[i].groupKey == p.groupKey { pantry[i].storage = s }
        data.pantry = AppStore.normalized(pantry)
    }

    /// Сколько дней хранятся остатки приготовленного в холодильнике (правило 3–4 дней, берём осторожно 3).
    static let leftoverDays = 3

    func cook(_ r: Recipe, portions: Int, leftovers: Int = 0) {
        remember("frying.pan", L("Cooked: {0}", "\(r.emoji) \(N(r.name))"))
        for ing in r.ingredients {
            // Штучные продукты (яйца, бананы…) списываются по количеству из рецепта (омлет на двоих — 6 яиц),
            // остальные — одна упаковка, как раньше. Меньше половины штуки (зубчик чеснока) — головка остаётся.
            var need = ing.pieces ?? 1
            var first = true
            while need > 0, let p = data.pantry.filter({ $0.name == ing.name && !$0.leftover }).min(by: { $0.expiry < $1.expiry }) {
                if first { use(p); first = false } // сначала то, что скорее испортится
                takeOne(p.id)
                need -= 1
            }
        }
        data.log.append(LogEntry(emoji: r.emoji, name: "\(N(r.name)) ×\(portions)", kcal: r.kcal * portions))
        data.stats.cooked += 1
        haptic(.medium)
        if leftovers > 0 {
            // Остатки — в холодильник отдельной строкой «🍳 Омлет ×2» (порции), срок 3 дня; Нутрик напомнит
            let now = Date()
            let exp = Calendar.current.date(byAdding: .day, value: AppStore.leftoverDays, to: now) ?? now
            if let i = data.pantry.firstIndex(where: { $0.leftover && $0.name == r.name && $0.storage == .fridge && abs(daysBetween($0.expiry, exp)) <= 1 }) {
                data.pantry[i].qty += leftovers
            } else {
                data.pantry.append(PantryItem(name: r.name, emoji: r.emoji, category: "Ready Meals", kcal: r.kcalPer100,
                                              added: now, expiry: exp, storage: .fridge, qty: leftovers, leftover: true))
            }
            data.stats.leftoversSaved += leftovers
            react(.cheer, L("Bon appétit! 🥡 {0} saved in the fridge — eat within 3 days", Lp(leftovers, "portion|portions")), emoji: r.emoji)
        } else {
            react(.eat, L("Bon appétit! {0} cooked 👩‍🍳", N(r.name)), emoji: r.emoji)
        }
        checkMedals()
    }

    /// Быстрое добавление списком / по чеку (v30): всё одним действием, с «Отменить».
    /// Продукты из списка покупок считаются купленными и уходят из списка.
    func addBatch(_ items: [(food: Food, qty: Int, storage: StorageKind)]) {
        guard !items.isEmpty else { return }
        let units = items.reduce(0) { $0 + $1.qty }
        remember("cart.badge.plus", L("Added: {0}", Lp(units, "product|products")))
        for it in items {
            add(it.food, storage: it.storage, count: it.qty, quiet: true)
            if data.shopping.contains(it.food.name) {
                data.shopping.removeAll { $0 == it.food.name }
                data.stats.bought += 1
            }
        }
        haptic(.medium)
        react(.cheer, L("{0} put away — I'll watch the dates 👀", Lp(units, "product|products")), emoji: items.first?.food.emoji)
        checkMedals()
    }

    func addShopping(_ names: [String]) {
        var added = 0
        for n in names where !data.shopping.contains(n) {
            data.shopping.append(n)
            added += 1
        }
        let home = (added == 1 && names.count == 1) ? shopHint(names[0]).homeQty : 0
        if home > 0 {
            say(L("🛒 Added. Heads up: you already have {0} ×{1} at home", N(names[0]), home))
        } else if added > 0 { say(L("🛒 {0} added to shopping list", added)) }
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

    func register(name: String, email: String, isMan: Bool, age: Int, weight: Double, height: Double,
                  activity: Int = 1, goal: Int = 0, demo: Bool) {
        data.profile.name = name.isEmpty ? "Friend" : name
        data.profile.email = email
        data.profile.isMan = isMan
        data.profile.age = age
        data.profile.weight = weight
        data.profile.height = height
        data.profile.activity = min(4, max(0, activity))
        data.profile.goal = min(1, max(-1, goal))
        data.weights = [WeightEntry(date: Date(), kg: weight)]
        data.stats.streakStart = Date()
        data.profile.joined = Date()
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
        say(L("🧺 Demo products added"))
    }

    /// Дата начала: сохранённая или самая ранняя запись (мягкая миграция старых сохранений)
    var joinedDate: Date {
        if let j = data.profile.joined { return j }
        let dates = data.weights.map(\.date) + data.log.map(\.date) + data.events.map(\.date)
            + data.pantry.map(\.added) + [data.stats.streakStart]
        return dates.min() ?? Date()
    }
    var daysWithUs: Int { max(1, daysBetween(joinedDate, Date()) + 1) }

    /// Очки опыта и уровень — за полезные действия, не за отходы
    var xp: Int {
        let s = data.stats
        return s.consumed * 2 + s.rescued * 10 + s.cooked * 15 + s.frozen * 5 + s.shared * 10 + s.bought * 3 + data.unlocked.count * 25
    }
    var level: (n: Int, title: String, progress: Double, toNext: Int) {
        // порог уровня n: 50·(n−1)²  → 0, 50, 200, 450, 800…
        var n = 1
        while 50 * n * n <= xp { n += 1 }
        let lo = 50 * (n - 1) * (n - 1), hi = 50 * n * n
        let titles = [LK("Sprout"), LK("Saver"), LK("Rescuer"), LK("Eco Hero"), LK("Zero-Waste Pro"), LK("Planet Keeper"), LK("Legend")]
        return (n, L(titles[min(n - 1, titles.count - 1)]), Double(xp - lo) / Double(hi - lo), hi - xp)
    }

    func eraseAll() {
        let lang = data.language
        data = AppData()
        data.language = lang   // язык интерфейса после сброса не меняем
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
                self.say(L("🔔 Nutrik will remind you at 9:00"))
            } else {
                self.say(L("Notifications are off in iPhone Settings"))
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
        case "fridge": return unitCount >= 10
        case "streak": return streakDays >= 7
        case "shop": return s.bought >= 1
        case "weight": return data.weights.count >= 3
        case "freezer": return s.frozen >= 3
        case "share": return s.shared >= 1
        case "cleanfridge": return unitCount >= 5 && expired.isEmpty
        case "chatty": return data.chat.filter(\.fromUser).count >= 5
        case "leftovers": return s.leftoversSaved >= 3
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
