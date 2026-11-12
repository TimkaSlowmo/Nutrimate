import SwiftUI

struct FridgeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var tab: AppTab
    @State private var filter: StorageKind?
    @State private var openItem: PantryGroup?
    @State private var wasteItem: PantryGroup?

    private var items: [PantryGroup] {
        store.sortedPantry.filter { filter == nil || $0.storage == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip(nil, L("All · {0}", store.sortedPantry.count))
                            ForEach(StorageKind.allCases) { s in
                                chip(s, "\(s.emoji) \(L(s.title)) · \(store.sortedPantry.filter { $0.storage == s }.count)")
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }

                if items.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            NutrikView(mood: .sad, size: 110)
                            Text(store.data.pantry.isEmpty ? L("Your fridge is empty") : L("Nothing here"))
                                .font(.headline).foregroundStyle(Color.burgundy)
                            Text(L("Find products in Search and tap ＋ to add them."))
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button(L("Open Search")) { withAnimation { tab = .search } }.buttonStyle(PrimaryButtonStyle())
                            if store.data.pantry.isEmpty {
                                Button(L("Add demo products")) { store.loadDemo() }.buttonStyle(SoftButtonStyle())
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(items) { p in
                            Button { openItem = p } label: { PantryRow(item: p) }
                                .buttonStyle(.plain)
                                .listRowBackground(rowBackground)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button { wasteItem = p } label: { Label(L("Bin"), systemImage: "trash") }.tint(.badRed)
                                    if DBCanFreeze(p) {
                                        Button { store.freeze(p.first.id) } label: { Label(L("Freeze"), systemImage: "snowflake") }.tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { store.eat(p.first.id, grams: 100, finished: true) } label: { Label(p.qty > 1 ? L("Ate 1") : L("Ate it"), systemImage: "fork.knife") }
                                        .tint(.freshGreen)
                                }
                        }
                    } footer: {
                        Text(L("Same products stack into one row (×2). Swipe right — ate one · swipe left — freeze or bin. Tap for details."))
                            .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LiveBackground())
            .navigationTitle(L("My Fridge"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { tab = .search } } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
            }
            .sheet(item: $openItem) { p in ItemSheet(key: p.id) }
            .confirmationDialog(L("Why is it going in the bin?"), isPresented: Binding(get: { wasteItem != nil }, set: { if !$0 { wasteItem = nil } }), titleVisibility: .visible) {
                ForEach(WasteReason.allCases) { r in
                    Button(L(r.title)) {
                        if let w = wasteItem { store.throwAway(w.first.id, reason: r) }
                        wasteItem = nil
                    }
                }
                Button(L("Cancel"), role: .cancel) { wasteItem = nil }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 0).fill(Color.glassFill)
    }

    private func DBCanFreeze(_ p: PantryGroup) -> Bool { p.storage != .freezer && FoodDB.canFreeze(p.food) }

    private func chip(_ s: StorageKind?, _ title: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { filter = s }
        } label: { Chip(text: title, selected: filter == s) }
        .buttonStyle(.plain)
    }
}

/// Карточка продукта (строка холодильника): количество −/＋, партии, срок, место, «съел», заморозить, поделиться, выбросить.
struct ItemSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let key: String
    @State private var grams = 100
    @State private var askReason = false

    var body: some View {
        NavigationStack {
            if let g = store.group(key) {
                let p = g.first
                let id = p.id
                ScrollView {
                    VStack(spacing: 16) {
                        EmojiBadge(emoji: g.emoji, size: 96)
                        VStack(spacing: 4) {
                            Text(N(g.name)).font(.title.bold()).foregroundStyle(Color.burgundy).multilineTextAlignment(.center)
                            Text(L("{0} · {1} kcal / 100 g", N(g.category), g.kcal)).foregroundStyle(.secondary)
                        }

                        // Количество: одинаковые продукты сложены в одну строку
                        HStack(spacing: 14) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L("Quantity")).font(.headline).foregroundStyle(Color.burgundy)
                                Text(g.batches.count > 1 ? L("{0} · oldest goes first", Lp(g.batches.count, "batch|batches")) : L("pieces / packs"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            qtyButton("minus") { store.decrement(key) }
                            Text("×\(g.qty)")
                                .font(.title2.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.burgundy)
                                .frame(minWidth: 52)
                                .contentTransition(.numericText())
                                .animation(.snappy, value: g.qty)
                            qtyButton("plus") { store.increment(key) }
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 8) {
                            Text(g.status).font(.headline).foregroundStyle(Color.freshness(g.daysLeft))
                            FreshBar(fresh: g.fresh, color: Color.freshness(g.daysLeft))
                            if g.batches.count > 1 {
                                ForEach(g.batches) { b in
                                    HStack {
                                        Text("📦 ×\(b.qty)").font(.subheadline.weight(.semibold))
                                        Spacer()
                                        Text(b.status).font(.subheadline).foregroundStyle(Color.freshness(b.daysLeft))
                                    }
                                }
                            }
                            DatePicker(g.batches.count > 1 ? L("Oldest batch best before") : L("Best before"),
                                       selection: Binding(get: { p.expiry }, set: { store.setExpiry(id, $0) }), displayedComponents: .date)
                            Picker(L("Stored in"), selection: Binding(get: { g.storage }, set: { s in
                                store.move(id, to: s)
                                dismiss() // строка переехала (и могла сложиться с другой)
                            })) {
                                ForEach(StorageKind.allCases) { s in Text("\(s.emoji) \(L(s.title))").tag(s) }
                            }
                            .pickerStyle(.segmented)
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            Text(L("I ate some")).font(.headline).foregroundStyle(Color.burgundy)
                            Stepper(L("{0} g · {1} kcal", grams, Int(Double(g.kcal * grams) / 100)), value: $grams, in: 10...2000, step: 10)
                            HStack {
                                Button(L("Ate a part")) { store.eat(id, grams: grams, finished: false) }
                                    .buttonStyle(SoftButtonStyle())
                                Button(g.qty > 1 ? L("Finished 1") : L("Finished it")) {
                                    let last = g.qty <= 1
                                    store.eat(id, grams: grams, finished: true)
                                    if last { dismiss() }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        .glassCard()

                        HStack(spacing: 10) {
                            if g.storage != .freezer && FoodDB.canFreeze(g.food) {
                                Button { store.freeze(id); dismiss() } label: { Label(g.qty > 1 ? L("Freeze all") : L("Freeze"), systemImage: "snowflake") }
                                    .buttonStyle(SoftButtonStyle())
                            }
                            Button {
                                let last = g.qty <= 1
                                store.share(id)
                                if last { dismiss() }
                            } label: { Label(g.qty > 1 ? L("Share 1") : L("Share"), systemImage: "hand.raised.fill") }
                                .buttonStyle(SoftButtonStyle())
                            Button { askReason = true } label: { Label(g.qty > 1 ? L("Bin 1") : L("Bin"), systemImage: "trash") }
                                .buttonStyle(SoftButtonStyle())
                        }
                        Button(L("Remove without counting"), role: .destructive) { store.delete(id); dismiss() }
                            .font(.footnote)
                    }
                    .padding(20)
                }
                .background(LiveBackground())
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
                .confirmationDialog(L("Why is it going in the bin?"), isPresented: $askReason, titleVisibility: .visible) {
                    ForEach(WasteReason.allCases) { r in
                        Button(L(r.title)) {
                            let last = g.qty <= 1
                            store.throwAway(id, reason: r)
                            if last { dismiss() }
                        }
                    }
                }
            } else {
                Text(L("This product is gone 🍽️")).onAppear { dismiss() }
            }
        }
        .presentationDetents([.large])
    }

    private func qtyButton(_ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.burgundy)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.burgundy.opacity(0.09)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(icon == "plus" ? L("One more") : L("One less"))
    }
}
