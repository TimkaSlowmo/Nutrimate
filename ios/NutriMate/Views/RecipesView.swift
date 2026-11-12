import SwiftUI

struct RecipesView: View {
    @EnvironmentObject var store: AppStore
    @State private var mode = 0 // 0 все, 1 можно готовить, 2 zero-waste
    @State private var query = ""

    private var list: [Recipe] {
        let have = store.pantryNames
        var r = store.rankedRecipes()
        if mode == 1 { r = r.filter { $0.missing(have).isEmpty } }
        if mode == 2 { r = r.filter(\.zeroWaste) }
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            // по-английски, по-русски и по-казахски (название рецепта и ингредиентов)
            func hit(_ names: String?...) -> Bool { names.contains { ($0 ?? "").lowercased().contains(q) } }
            r = r.filter { rec in
                hit(rec.name, rec.ru, rec.kk) || rec.ingredients.contains { i in
                    let f = store.db.byName[i.name]
                    return hit(i.name, f?.ru, f?.kk)
                }
            }
        }
        return r
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Picker(L("Show"), selection: $mode) {
                        Text(L("For you")).tag(0)
                        Text(L("Cook now")).tag(1)
                        Text(L("♻️ Zero-waste")).tag(2)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.burgundy)
                        TextField(L("Recipe or ingredient"), text: $query).autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.glassFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    let items = list
                    let have = store.pantryNames
                    let urgent = Set(store.toRescue.map(\.name))
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            NutrikView(mood: .sad, size: 100)
                            Text(mode == 1 ? L("Nothing can be cooked only from your fridge yet. Try \"For you\" — I'll show what's missing.") : L("No recipes found."))
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 20)
                    }
                    ForEach(items) { r in
                        NavigationLink(value: r) { RecipeCard(recipe: r, have: have, urgent: urgent) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(LiveBackground())
            .navigationTitle(L("Recipes"))
            .navigationDestination(for: Recipe.self) { r in RecipeDetail(recipe: r) }
        }
    }
}

/// Карточка рецепта — без доступа к store: множества «есть в холодильнике» и «спасти» считаются
/// один раз на весь список (раньше — заново в каждой карточке на каждом кадре прокрутки).
struct RecipeCard: View, Equatable {
    let recipe: Recipe
    let have: Set<String>
    let urgent: Set<String>

    var body: some View {
        let haveCount = recipe.ingredients.filter { have.contains($0.name) }.count
        let rescues = recipe.ingredients.filter { urgent.contains($0.name) }.count
        HStack(spacing: 12) {
            Text(recipe.emoji).font(.system(size: 38)).frame(width: 58, height: 58)
                .background(Circle().fill(Color.paper.opacity(0.6)))
            VStack(alignment: .leading, spacing: 4) {
                Text(N(recipe.name)).font(.headline).foregroundStyle(Color.burgundy).lineLimit(2)
                Text(L("⏱ {0} · {1} kcal/serving", recipe.localTime, recipe.kcal)).font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    tag(L("{0}/{1} in fridge", haveCount, recipe.ingredients.count), haveCount == recipe.ingredients.count ? .freshGreen : .burgundy)
                    if rescues > 0 { tag(L("rescues {0} 🦸", rescues), .warnOrange) }
                    if recipe.zeroWaste { tag("♻️", .freshGreen) }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Color.burgundy.opacity(0.4))
        }
        .glassCard(radius: 20, padding: 12)
    }

    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption2.weight(.bold)).foregroundStyle(c).lineLimit(1).minimumScaleFactor(0.75)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(c.opacity(0.12)))
    }
}

struct RecipeDetail: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    @State private var portions = 1
    @State private var done = Set<Int>()

    var body: some View {
        let have = store.pantryNames
        let missing = recipe.missing(have)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 6) {
                    Text(recipe.emoji).font(.system(size: 72))
                    Text(N(recipe.name)).font(.title.bold()).foregroundStyle(Color.burgundy).multilineTextAlignment(.center)
                    Text(L("⏱ {0} · {1} · {2} kcal each", recipe.localTime, Lp(recipe.servings, "serving|servings"), recipe.kcal))
                        .font(.subheadline).foregroundStyle(.secondary)
                    if recipe.zeroWaste {
                        Text(L("♻️ Zero-waste recipe — rescues leftovers")).font(.caption.bold()).foregroundStyle(Color.freshGreen)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: L("Ingredients"))
                    ForEach(recipe.ingredients, id: \.name) { i in
                        HStack {
                            Text(store.db.byName[i.name]?.emoji ?? "•")
                            Text(N(i.name))
                            Spacer()
                            Text(L("{0} g", i.g)).foregroundStyle(.secondary)
                            Image(systemName: have.contains(i.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(have.contains(i.name) ? Color.freshGreen : Color.burgundy.opacity(0.35))
                        }
                    }
                    Text(L("Also: {0}", recipe.localStaples)).font(.caption).foregroundStyle(.secondary)
                    if !missing.isEmpty {
                        Button { store.addShopping(missing) } label: {
                            Label(L("Add {0} missing to shopping list", missing.count), systemImage: "cart.badge.plus")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                .glassCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: L("Steps"))
                    ForEach(Array(recipe.localizedSteps.enumerated()), id: \.offset) { n, s in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            if done.contains(n) { done.remove(n) } else { done.insert(n) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(n + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.cream)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(done.contains(n) ? Color.freshGreen : Color.brand))
                                Text(s)
                                    .strikethrough(done.contains(n))
                                    .foregroundStyle(done.contains(n) ? Color.secondary : Color.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .glassCard()

                VStack(spacing: 10) {
                    Stepper(L("Portions eaten: {0} · {1} kcal", portions, recipe.kcal * portions), value: $portions, in: 1...max(1, recipe.servings))
                    Button(L("I cooked it! 👩‍🍳")) {
                        store.cook(recipe, portions: portions)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text(L("Ingredients from your fridge are used up — the ones expiring first."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .glassCard()
            }
            .padding(16)
            .padding(.bottom, 10)
        }
        .background(LiveBackground())
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Recipe {
    /// Время приготовления из данных («15 min») с переведённой единицей.
    var localTime: String {
        guard AppLang.current != .en else { return time }
        return time.split(separator: " ").map { w -> String in
            switch w {
            case "min": return L("min")
            case "h": return L("h")
            case "night": return L("night")
            case "chill": return L("chill")
            default: return String(w)
            }
        }.joined(separator: " ")
    }

    /// «salt, pepper, oil» → «соль, перец, масло» (незнакомые слова остаются как есть).
    var localStaples: String {
        guard AppLang.current != .en else { return staples }
        let i = AppLang.current == .ru ? 0 : 1
        return staples.split(separator: ",").map { part -> String in
            var core = part.trimmingCharacters(in: .whitespaces)
            var prefix = ""
            if core.lowercased().hasPrefix("optional: ") {
                core = String(core.dropFirst(10))
                prefix = i == 0 ? "по желанию: " : "қаласаңыз: "
            }
            return prefix + (Recipe.stapleNames[core.lowercased()]?[i] ?? core)
        }.joined(separator: ", ")
    }

    static let stapleNames: [String: [String]] = [
        "salt": ["соль", "тұз"], "pepper": ["перец", "бұрыш"], "black pepper": ["чёрный перец", "қара бұрыш"],
        "oil": ["масло", "май"], "bay leaf": ["лавровый лист", "лавр жапырағы"], "cumin": ["зира", "зире"],
        "paprika": ["паприка", "паприка"], "cinnamon": ["корица", "даршын"], "water": ["вода", "су"],
        "oregano": ["орегано", "орегано"], "lemon": ["лимон", "лимон"], "chili": ["чили", "чили"],
        "chili flakes": ["хлопья чили", "чили үгіндісі"], "vanilla": ["ваниль", "ваниль"], "baking soda": ["сода", "сода"],
        "sesame seeds": ["кунжут", "күнжіт"], "dill": ["укроп", "аскөк"], "thyme": ["тимьян", "тимьян"],
        "nutmeg": ["мускатный орех", "мускат жаңғағы"], "vinegar": ["уксус", "сірке суы"],
        "pinch of salt": ["щепотка соли", "бір шымшым тұз"], "herbs": ["зелень", "көк шөп"],
        "dried herbs": ["сушёные травы", "кептірілген шөптер"], "mustard": ["горчица", "қыша"], "stock": ["бульон", "сорпа"],
        "baking powder": ["разрыхлитель", "қопсытқыш"], "garlic": ["чеснок", "сарымсақ"], "sugar": ["сахар", "қант"],
        "soy sauce": ["соевый соус", "соя соусы"], "oil for frying": ["масло для жарки", "қуыруға май"],
        "ice": ["лёд", "мұз"], "nothing else": ["больше ничего", "басқа ештеңе"],
    ]
}
