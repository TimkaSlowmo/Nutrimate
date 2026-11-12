import Foundation

/// План «доедаем всё» (v29): что приготовить в ближайшие 3 дня, чтобы не выбросить ничего из того,
/// что скоро испортится, а что лучше заморозить или просто съесть. Считается на лету из холодильника,
/// ничего не хранит — поэтому миграция данных не нужна.
struct UseUpPlan {
    struct Day: Identifiable {
        let id: Int              // 0 — сегодня, 1 — завтра…
        let recipe: Recipe
        let rescues: [PantryGroup]
        let missing: [String]
    }

    /// Окно «скоро испортится» (дней)
    static let window = 4
    static let maxDays = 3

    let atRisk: [PantryGroup]
    let days: [Day]
    let freeze: [PantryGroup]
    let eatAsIs: [PantryGroup]

    var isEmpty: Bool { atRisk.isEmpty }
    var allMissing: [String] {
        var seen = Set<String>()
        return days.flatMap(\.missing).filter { seen.insert($0).inserted }
    }

    init(store: AppStore) {
        let risk = store.sortedPantry.filter { $0.storage != .freezer && $0.daysLeft >= 0 && $0.daysLeft <= Self.window }
        atRisk = risk
        let cookable = risk.filter { !$0.isLeftover }
        var left = Dictionary(cookable.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
        let have = store.pantryNames
        let ranked = store.rankedRecipes()

        // жадно: каждый день — рецепт, который спасает больше всего (и самое срочное), докупать ≤ 2 продуктов
        var picked: [(Recipe, [PantryGroup], [String])] = []
        var used = Set<String>()
        for _ in 0..<Self.maxDays where !left.isEmpty {
            var best: (Recipe, Int, [PantryGroup], [String])?
            for r in ranked where !used.contains(r.name) {
                let saves = r.ingredients.compactMap { left[$0.name] }
                guard !saves.isEmpty else { continue }
                let miss = r.missing(have)
                guard miss.count <= 2 else { continue }
                let score = saves.reduce(0) { $0 + (Self.window + 2 - $1.daysLeft) * 10 } - miss.count * 12
                if best == nil || score > best!.1 { best = (r, score, saves, miss) }
            }
            guard let b = best else { break }
            used.insert(b.0.name)
            for s in b.2 { left[s.name] = nil }
            picked.append((b.0, b.2.sorted { $0.daysLeft < $1.daysLeft }, b.3))
        }
        // самое срочное — раньше
        picked.sort { ($0.1.first?.daysLeft ?? 99) < ($1.1.first?.daysLeft ?? 99) }
        days = picked.enumerated().map { Day(id: $0.offset, recipe: $0.element.0, rescues: $0.element.1, missing: $0.element.2) }

        // что не вошло в рецепты: можно заморозить → в морозилку, иначе — съесть как есть (остатки — тоже)
        let rest = risk.filter { $0.isLeftover || left[$0.name] != nil }
        freeze = rest.filter { !$0.isLeftover && FoodDB.canFreeze($0.food) && $0.daysLeft <= 2 }
        let fz = Set(freeze.map(\.id))
        eatAsIs = rest.filter { !fz.contains($0.id) }
    }
}
