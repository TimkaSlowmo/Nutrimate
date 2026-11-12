import SwiftUI

struct SearchView: View {
    @EnvironmentObject var store: AppStore
    @State private var query = ""
    @State private var category: String?
    @State private var logFood: Food?
    @State private var addFood: Food?
    @FocusState private var focused: Bool

    private let suggestions = ["Kurt", "Baursaks", "Kazy", "Shubat", "Kumys", "Irimshik", "Milk", "Eggs", "Banana", "Chicken Breast", "Tomato", "Bread"]

    private var results: [Food] { store.db.search(query, category: category) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    searchField
                    categories
                    if query.isEmpty && category == nil {
                        home
                    } else {
                        list
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(LiveBackground())
            .navigationTitle(L("Search"))
            .sheet(item: $logFood) { f in LogFoodSheet(food: f) }
            .sheet(item: $addFood) { f in AddFoodSheet(food: f) }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.burgundy)
            TextField(L("Search {0} products…", store.db.foods.count), text: $query)
                .focused($focused)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            }
        }
        .padding(14)
        .background(Color.glassFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.paper.opacity(0.85), lineWidth: 1))
    }

    private var categories: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button { pick(nil) } label: { Chip(text: L("All"), selected: category == nil) }
                ForEach(store.db.categories, id: \.self) { c in
                    Button { pick(c) } label: { Chip(text: "\(FoodDB.catEmoji[c] ?? "🍽️") \(N(c))", selected: category == c) }
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 2)
        }
    }

    private func pick(_ c: String?) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { category = (category == c ? nil : c) }
    }

    private var home: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: L("Popular in Almaty 🇰🇿"))
            FlowChips(items: suggestions.compactMap { store.db.byName[$0] }) { f in
                store.add(f)
            }
            SectionTitle(text: L("Categories"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                ForEach(store.db.categories, id: \.self) { c in
                    Button { pick(c) } label: {
                        VStack(spacing: 6) {
                            Text(FoodDB.catEmoji[c] ?? "🍽️").font(.system(size: 34))
                            Text(N(c)).font(.caption.weight(.semibold)).foregroundStyle(Color.burgundy).lineLimit(1).minimumScaleFactor(0.7)
                            Text("\(store.db.foods.filter { $0.category == c }.count)").font(.caption2).foregroundStyle(.secondary)
                        }
                        .glassCard(radius: 18, padding: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var list: some View {
        let r = results
        return LazyVStack(alignment: .leading, spacing: 8) {
            Text(r.isEmpty ? L("Nothing found 🤔 Try another word.") : L("{0} found", r.count))
                .font(.caption).foregroundStyle(.secondary)
            ForEach(r.prefix(300)) { f in
                FoodRow(food: f, inFridge: store.pantryNames.contains(f.name)) { store.add(f) }
                    .onTapGesture { addFood = f }
                    .contextMenu {
                        Button { store.add(f) } label: { Label(L("Add to fridge"), systemImage: "refrigerator") }
                        Button { logFood = f } label: { Label(L("Log as eaten…"), systemImage: "fork.knife") }
                        Button { store.addShopping([f.name]) } label: { Label(L("Add to shopping list"), systemImage: "cart") }
                    }
            }
        }
    }
}

struct FoodRow: View {
    let food: Food
    var inFridge = false
    let onAdd: () -> Void
    @State private var pressed = false

    var body: some View {
        HStack(spacing: 12) {
            EmojiBadge(emoji: food.emoji, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(N(food.name)).font(.body.weight(.semibold)).foregroundStyle(Color.burgundy)
                Text(L("{0} kcal · keeps {1} · {2}", food.kcal, shelfText(food.shelf), FoodDB.defaultStorage(food).emoji))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if inFridge {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.freshGreen.opacity(0.8))
            }
            Button {
                pressed = true
                onAdd()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.4)) { pressed = false }
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .foregroundStyle(Color.cream)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.brand))
                    .scaleEffect(pressed ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("Add {0}", N(food.name)))
        }
        .glassCard(radius: 16, padding: 10)
    }
}

func shelfText(_ d: Int) -> String {
    if d >= 365 { return L("{0} yr", d / 365) }
    if d >= 60 { return L("{0} mo", d / 30) }
    if d >= 14 { return L("{0} wk", d / 7) }
    return L("{0} d", d)
}

/// Чипсы-подсказки, переносящиеся на новую строку.
struct FlowChips: View {
    let items: [Food]
    let onTap: (Food) -> Void
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { f in
                Button { onTap(f) } label: { Chip(text: "\(f.emoji) \(N(f.name))  ＋") }
                    .buttonStyle(.plain)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW && x > 0 {
                x = 0
                y += rowH + spacing
                rowH = 0
            }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(maxW, widest), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowH + spacing
                rowH = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Записать съеденное в дневник без добавления в холодильник.
struct LogFoodSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let food: Food
    @State private var grams = 100

    var body: some View {
        VStack(spacing: 16) {
            EmojiBadge(emoji: food.emoji, size: 80)
            Text(N(food.name)).font(.title2.bold()).foregroundStyle(Color.burgundy)
            Stepper(L("{0} g · {1} kcal", grams, food.kcal * grams / 100), value: $grams, in: 10...2000, step: 10)
                .padding(.horizontal)
            Button(L("Log as eaten")) { store.logFood(food, grams: grams); dismiss() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.height(320)])
    }
}

/// Добавление с настройками: место хранения, срок, количество.
struct AddFoodSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let food: Food
    @State private var storage: StorageKind = .fridge
    @State private var days = 7
    @State private var count = 1
    @State private var ready = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        EmojiBadge(emoji: food.emoji, size: 64)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(N(food.name)).font(.title3.bold()).foregroundStyle(Color.burgundy)
                            Text(L("{0} · {1} kcal / 100 g", N(food.category), food.kcal)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section(L("Where and how long")) {
                    Picker(L("Stored in"), selection: $storage) {
                        ForEach(StorageKind.allCases) { s in Text("\(s.emoji) \(L(s.title))").tag(s) }
                    }
                    .pickerStyle(.segmented)
                    Stepper(L("Keeps for {0}", Lp(days, "day|days")), value: $days, in: 1...730)
                    Stepper(L("Quantity: {0}", count), value: $count, in: 1...12)
                }
                Section {
                    Button(storage == .fridge ? L("Add to fridge") : storage == .freezer ? L("Add to freezer") : L("Add to pantry")) {
                        store.add(food, days: days, storage: storage, count: count)
                        dismiss()
                    }
                    .bold()
                    Button(L("Add to shopping list")) {
                        store.addShopping([food.name])
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L("Add product"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } } }
            .onAppear {
                guard !ready else { return }
                ready = true
                storage = FoodDB.defaultStorage(food)
                days = food.shelf
            }
            .onChange(of: storage) { _, s in
                if s == .freezer && FoodDB.canFreeze(food) { days = max(days, 90) }
                else if s != .freezer && days == 90 { days = food.shelf }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
