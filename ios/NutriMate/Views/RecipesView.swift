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
                    Picker("Show", selection: $mode) {
                        Text("For you").tag(0)
                        Text("Cook now").tag(1)
                        Text("♻️ Zero-waste").tag(2)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.burgundy)
                        TextField("Recipe or ingredient", text: $query).autocorrectionDisabled()
                    }
                    .padding(12)
                    .background(Color.glassFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    let items = list
                    if items.isEmpty {
                        VStack(spacing: 10) {
                            NutrikView(mood: .sad, size: 100)
                            Text(mode == 1 ? "Nothing can be cooked only from your fridge yet. Try \"For you\" — I'll show what's missing." : "No recipes found.")
                                .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 20)
                    }
                    ForEach(items) { r in
                        NavigationLink(value: r) { RecipeCard(recipe: r) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(LiveBackground())
            .navigationTitle("Recipes")
            .navigationDestination(for: Recipe.self) { r in RecipeDetail(recipe: r) }
        }
    }
}

struct RecipeCard: View {
    @EnvironmentObject var store: AppStore
    let recipe: Recipe

    var body: some View {
        let have = store.pantryNames
        let urgent = Set(store.toRescue.map(\.name))
        let haveCount = recipe.ingredients.filter { have.contains($0.name) }.count
        let rescues = recipe.ingredients.filter { urgent.contains($0.name) }.count
        HStack(spacing: 12) {
            Text(recipe.emoji).font(.system(size: 38)).frame(width: 58, height: 58)
                .background(Circle().fill(Color.white.opacity(0.6)))
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.name).font(.headline).foregroundStyle(Color.burgundy).lineLimit(2)
                Text("⏱ \(recipe.time) · \(recipe.kcal) kcal/serving").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    tag("\(haveCount)/\(recipe.ingredients.count) in fridge", haveCount == recipe.ingredients.count ? .freshGreen : .burgundy)
                    if rescues > 0 { tag("rescues \(rescues) 🦸", .warnOrange) }
                    if recipe.zeroWaste { tag("♻️", .freshGreen) }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").foregroundStyle(Color.burgundy.opacity(0.4))
        }
        .glassCard(radius: 20, padding: 12)
    }

    private func tag(_ t: String, _ c: Color) -> some View {
        Text(t).font(.caption2.weight(.bold)).foregroundStyle(c)
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
                    Text(recipe.name).font(.title.bold()).foregroundStyle(Color.burgundy).multilineTextAlignment(.center)
                    Text("⏱ \(recipe.time) · \(recipe.servings) servings · \(recipe.kcal) kcal each")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if recipe.zeroWaste {
                        Text("♻️ Zero-waste recipe — rescues leftovers").font(.caption.bold()).foregroundStyle(Color.freshGreen)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle(text: "Ingredients")
                    ForEach(recipe.ingredients, id: \.name) { i in
                        HStack {
                            Text(store.db.byName[i.name]?.emoji ?? "•")
                            Text(i.name)
                            Spacer()
                            Text("\(i.g) g").foregroundStyle(.secondary)
                            Image(systemName: have.contains(i.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(have.contains(i.name) ? Color.freshGreen : Color.burgundy.opacity(0.35))
                        }
                    }
                    Text("Also: \(recipe.staples)").font(.caption).foregroundStyle(.secondary)
                    if !missing.isEmpty {
                        Button { store.addShopping(missing) } label: {
                            Label("Add \(missing.count) missing to shopping list", systemImage: "cart.badge.plus")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                .glassCard()

                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: "Steps")
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { n, s in
                        Button {
                            UISelectionFeedbackGenerator().selectionChanged()
                            if done.contains(n) { done.remove(n) } else { done.insert(n) }
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(n + 1)")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.cream)
                                    .frame(width: 26, height: 26)
                                    .background(Circle().fill(done.contains(n) ? Color.freshGreen : Color.burgundy))
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
                    Stepper("Portions eaten: \(portions) · \(recipe.kcal * portions) kcal", value: $portions, in: 1...max(1, recipe.servings))
                    Button("I cooked it! 👩‍🍳") {
                        store.cook(recipe, portions: portions)
                        dismiss()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("Ingredients from your fridge are used up — the ones expiring first.")
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
