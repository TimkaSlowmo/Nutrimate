import SwiftUI

struct FridgeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var tab: AppTab
    @State private var filter: StorageKind?
    @State private var openItem: PantryItem?
    @State private var wasteItem: PantryItem?

    private var items: [PantryItem] {
        store.sortedPantry.filter { filter == nil || $0.storage == filter }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip(nil, "All · \(store.data.pantry.count)")
                            ForEach(StorageKind.allCases) { s in
                                chip(s, "\(s.emoji) \(s.title) · \(store.data.pantry.filter { $0.storage == s }.count)")
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
                            Text(store.data.pantry.isEmpty ? "Your fridge is empty" : "Nothing here")
                                .font(.headline).foregroundStyle(Color.burgundy)
                            Text("Find products in Search and tap ＋ to add them.")
                                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                            Button("Open Search") { withAnimation { tab = .search } }.buttonStyle(PrimaryButtonStyle())
                            if store.data.pantry.isEmpty {
                                Button("Add demo products") { store.loadDemo() }.buttonStyle(SoftButtonStyle())
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
                                    Button { wasteItem = p } label: { Label("Bin", systemImage: "trash") }.tint(.badRed)
                                    if DBCanFreeze(p) {
                                        Button { store.freeze(p.id) } label: { Label("Freeze", systemImage: "snowflake") }.tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { store.eat(p.id, grams: 100, finished: true) } label: { Label("Ate it", systemImage: "fork.knife") }
                                        .tint(.freshGreen)
                                }
                        }
                    } footer: {
                        Text("Swipe right — ate it · swipe left — freeze or bin. Tap for details.")
                            .font(.caption)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(LiveBackground())
            .navigationTitle("My Fridge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { tab = .search } } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
            }
            .sheet(item: $openItem) { p in ItemSheet(id: p.id) }
            .confirmationDialog("Why is it going in the bin?", isPresented: Binding(get: { wasteItem != nil }, set: { if !$0 { wasteItem = nil } }), titleVisibility: .visible) {
                ForEach(WasteReason.allCases) { r in
                    Button(r.title) {
                        if let w = wasteItem { store.throwAway(w.id, reason: r) }
                        wasteItem = nil
                    }
                }
                Button("Cancel", role: .cancel) { wasteItem = nil }
            }
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 0).fill(.ultraThinMaterial)
    }

    private func DBCanFreeze(_ p: PantryItem) -> Bool { p.storage != .freezer && FoodDB.canFreeze(p.food) }

    private func chip(_ s: StorageKind?, _ title: String) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { filter = s }
        } label: { Chip(text: title, selected: filter == s) }
        .buttonStyle(.plain)
    }
}

/// Карточка продукта: срок, место хранения, «съел», заморозить, поделиться, выбросить.
struct ItemSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let id: UUID
    @State private var grams = 100
    @State private var askReason = false

    var body: some View {
        NavigationStack {
            if let p = store.item(id) {
                ScrollView {
                    VStack(spacing: 16) {
                        EmojiBadge(emoji: p.emoji, size: 96)
                        VStack(spacing: 4) {
                            Text(p.name).font(.title.bold()).foregroundStyle(Color.burgundy)
                            Text("\(p.category) · \(p.kcal) kcal / 100 g").foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(p.status).font(.headline).foregroundStyle(Color.freshness(p.daysLeft))
                            FreshBar(fresh: p.fresh, color: Color.freshness(p.daysLeft))
                            DatePicker("Best before", selection: Binding(get: { p.expiry }, set: { store.setExpiry(id, $0) }), displayedComponents: .date)
                            Picker("Stored in", selection: Binding(get: { p.storage }, set: { store.move(id, to: $0) })) {
                                ForEach(StorageKind.allCases) { s in Text("\(s.emoji) \(s.title)").tag(s) }
                            }
                            .pickerStyle(.segmented)
                        }
                        .glassCard()

                        VStack(alignment: .leading, spacing: 10) {
                            Text("I ate some").font(.headline).foregroundStyle(Color.burgundy)
                            Stepper("\(grams) g · \(Int(Double(p.kcal * grams) / 100)) kcal", value: $grams, in: 10...2000, step: 10)
                            HStack {
                                Button("Ate a part") { store.eat(id, grams: grams, finished: false) }
                                    .buttonStyle(SoftButtonStyle())
                                Button("Finished it") { store.eat(id, grams: grams, finished: true); dismiss() }
                                    .buttonStyle(PrimaryButtonStyle())
                            }
                        }
                        .glassCard()

                        HStack(spacing: 10) {
                            if p.storage != .freezer && FoodDB.canFreeze(p.food) {
                                Button { store.freeze(id) } label: { Label("Freeze", systemImage: "snowflake") }
                                    .buttonStyle(SoftButtonStyle())
                            }
                            Button { store.share(id); dismiss() } label: { Label("Share", systemImage: "hand.raised.fill") }
                                .buttonStyle(SoftButtonStyle())
                            Button { askReason = true } label: { Label("Bin", systemImage: "trash") }
                                .buttonStyle(SoftButtonStyle())
                        }
                        Button("Remove without counting", role: .destructive) { store.delete(id); dismiss() }
                            .font(.footnote)
                    }
                    .padding(20)
                }
                .background(LiveBackground())
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Why is it going in the bin?", isPresented: $askReason, titleVisibility: .visible) {
                    ForEach(WasteReason.allCases) { r in
                        Button(r.title) { store.throwAway(id, reason: r); dismiss() }
                    }
                }
            } else {
                Text("This product is gone 🍽️").onAppear { dismiss() }
            }
        }
        .presentationDetents([.large])
    }
}
