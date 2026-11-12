import SwiftUI

/// Лист «План: доедаем всё» (v29) — открывается с Главной («Использовать в первую очередь») и с вкладки Рецепты.
struct PlanView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let plan = UseUpPlan(store: store)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NutrikSays(text: headline(plan), mood: plan.isEmpty ? .wave : .happy, size: 76)
                    if plan.isEmpty {
                        emptyCard
                    } else {
                        ForEach(plan.days) { d in dayCard(d) }
                        if !plan.freeze.isEmpty { freezeCard(plan.freeze) }
                        if !plan.eatAsIs.isEmpty { eatCard(plan.eatAsIs) }
                        if !plan.allMissing.isEmpty {
                            Button { store.addShopping(plan.allMissing) } label: {
                                Label(L("Add {0} missing to shopping list", plan.allMissing.count), systemImage: "cart.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(SoftButtonStyle())
                        }
                        Text(L("The plan updates by itself when your fridge changes."))
                            .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(LiveBackground())
            .navigationTitle(L("Use-it-up plan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
            .navigationDestination(for: Recipe.self) { r in RecipeDetail(recipe: r) }
        }
    }

    private func headline(_ p: UseUpPlan) -> String {
        if p.isEmpty { return L("Nothing is about to expire. 🎉") }
        return L("{0} expire in the next {1} days — here's a plan so nothing goes to waste:",
                 Lp(p.atRisk.count, "product|products"), UseUpPlan.window)
    }

    private func dayTitle(_ n: Int) -> String {
        switch n {
        case 0: return L("Today")
        case 1: return L("Tomorrow")
        default:
            let d = Calendar.current.date(byAdding: .day, value: n, to: Date()) ?? Date()
            return d.formatted(.dateTime.weekday(.wide).locale(AppLang.current.locale)).capitalized(with: AppLang.current.locale)
        }
    }

    private func dayCard(_ d: UseUpPlan.Day) -> some View {
        let r = d.recipe
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dayTitle(d.id).uppercased(with: AppLang.current.locale))
                    .font(.caption.weight(.heavy)).foregroundStyle(d.id == 0 ? Color.warnOrange : Color.burgundy.opacity(0.6))
                Spacer()
                Text(L("⏱ {0} · {1} kcal/serving", r.localTime, r.kcal)).font(.caption).foregroundStyle(.secondary)
            }
            NavigationLink(value: r) {
                HStack(spacing: 12) {
                    Text(r.emoji).font(.system(size: 36)).frame(width: 56, height: 56)
                        .background(Circle().fill(Color.paper.opacity(0.65)))
                    Text(N(r.name)).font(.headline).foregroundStyle(Color.burgundy)
                        .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(Color.burgundy.opacity(0.5))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(L("Rescues")).font(.caption.bold()).foregroundStyle(.secondary)
            StatusChips(items: d.rescues.map { g in ("\(g.emoji) \(N(g.name))", Color.freshness(g.daysLeft), shortStatus(g)) })
            if !d.missing.isEmpty {
                Text(L("To buy: {0}", d.missing.map { N($0) }.joined(separator: ", ")))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .glassCard(radius: 20, padding: 14)
    }

    private func shortStatus(_ g: PantryGroup) -> String {
        g.daysLeft == 0 ? L("today") : g.daysLeft == 1 ? L("tomorrow") : L("in {0}", Lp(g.daysLeft, "day|days"))
    }

    private func freezeCard(_ list: [PantryGroup]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("❄️ Freeze today"))
            Text(L("No recipe for these right now — the freezer keeps them for months."))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(list) { g in
                HStack(spacing: 10) {
                    EmojiBadge(emoji: g.emoji)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(g.title).font(.subheadline.weight(.semibold)).foregroundStyle(Color.burgundy)
                        Text(g.status).font(.caption).foregroundStyle(Color.freshness(g.daysLeft))
                    }
                    Spacer()
                    Button { store.freeze(g.first.id) } label: {
                        Label(L("Freeze"), systemImage: "snowflake").font(.caption.bold())
                    }
                    .buttonStyle(.bordered).tint(Color.burgundy)
                }
            }
        }
        .glassCard(radius: 20, padding: 14)
    }

    private func eatCard(_ list: [PantryGroup]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: L("🍎 Just eat these"))
            Text(L("A snack, a side or breakfast — no recipe needed."))
                .font(.caption).foregroundStyle(.secondary)
            StatusChips(items: list.map { g in ("\(g.emoji) \(g.title)", Color.freshness(g.daysLeft), shortStatus(g)) })
        }
        .glassCard(radius: 20, padding: 14)
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            NutrikView(mood: .cheer, size: 96)
            Text(L("Everything is fresh! You're a zero-waste star ⭐"))
                .font(.headline).foregroundStyle(Color.burgundy).multilineTextAlignment(.center)
            Text(L("When something is about to expire, I'll plan what to cook with it here."))
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

/// Чипы «🍌 Banana · today», переносятся на новую строку.
struct StatusChips: View {
    let items: [(String, Color, String)]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, it in
                HStack(spacing: 4) {
                    Text(it.0).font(.caption.weight(.semibold)).foregroundStyle(Color.burgundy).lineLimit(1)
                    Text("· " + it.2).font(.caption2.weight(.bold)).foregroundStyle(it.1).lineLimit(1)
                }
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(it.1.opacity(0.12)))
            }
        }
    }
}

/// Карточка-вход в план (Главная и Рецепты)
struct PlanEntryCard: View {
    let count: Int
    var body: some View {
        HStack(spacing: 12) {
            Text("🗓️").font(.system(size: 30)).frame(width: 50, height: 50)
                .background(Circle().fill(Color.cream.opacity(0.18)))
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Use-it-up plan")).font(.headline).foregroundStyle(Color.cream)
                Text(L("What to cook in the next 3 days so {0} don't go to waste", Lp(count, "product|products")))
                    .font(.caption).foregroundStyle(Color.cream.opacity(0.8)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(Color.cream.opacity(0.7))
        }
        .padding(14)
        .background(LinearGradient(colors: [.brandLight, .brand], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .contentShape(Rectangle())
    }
}
