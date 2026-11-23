import SwiftUI

/// Лист проверки после фото продуктов (v33): «Нашёл: 🍌 Банан ×5 — добавить?».
/// Галочки, количество, место (холодильник / морозилка / шкаф), срок хранения. Ничего не добавляется без кнопки.
/// Не уверен — 3 варианта-кнопки и «Найти вручную»; ничего не узнал — честно говорит и предлагает поиск.
struct ScanResultView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let result: ScanResult
    /// После «Добавить» закрыть и экран, с которого открыли
    var onAdded: () -> Void = {}

    @State private var rows: [ScanItem] = []
    @State private var off: Set<String> = []
    @State private var place: [String: StorageKind] = [:]
    @State private var started = false
    @State private var showSearch = false

    private var selected: [ScanItem] { rows.filter { !off.contains($0.food.name) } }
    private var units: Int { selected.reduce(0) { $0 + $1.qty } }
    private func storage(_ f: Food) -> StorageKind { place[f.name] ?? FoodDB.defaultStorage(f) }
    /// Варианты, которые ещё не в списке
    private var chips: [Food] {
        var out: [Food] = []
        let pool = (result.uncertain ? result.items.map(\.food) : []) + result.alternatives
        for f in pool where !out.contains(f) && !rows.contains(where: { $0.food == f }) { out.append(f) }
        return Array(out.prefix(3))
    }
    private var nothing: Bool { rows.isEmpty && chips.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NutrikSays(text: headline, mood: mood, size: 72, food: rows.first?.food.emoji)
                    if !rows.isEmpty { foundCard }
                    if !chips.isEmpty || rows.isEmpty { guessCard }
                    Label(result.viaServer ? L("Smart Nutrik looked at a small copy of the photo — it isn't stored.")
                                           : L("Recognized right on your phone — the photo wasn't uploaded."),
                          systemImage: result.viaServer ? "sparkles" : "lock.fill")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: rows)
            }
            .background(LiveBackground())
            .safeAreaInset(edge: .bottom) { if !rows.isEmpty { addBar } }
            .navigationTitle(L("Photo scan"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
            }
            .sheet(isPresented: $showSearch) { SearchView(initialQuery: result.query, inSheet: true) }
            .onAppear {
                guard !started else { return }
                started = true
                // уверенно узнанное — сразу в списке (с галочками); неуверенное — только кнопками-вариантами
                if !result.uncertain { rows = result.items }
            }
        }
    }

    private var headline: String {
        if !rows.isEmpty {
            let list = rows.prefix(3).map { "\($0.food.emoji) \(N($0.food.name)) ×\($0.qty)" }.joined(separator: ", ")
            return L("Found: {0} — add?", list + (rows.count > 3 ? " …" : ""))
        }
        if !chips.isEmpty { return L("Hmm, I'm not sure what this is 🤔 Is it one of these?") }
        return L("Couldn't recognize it — try closer or with more light 📸")
    }

    private var mood: NutrikMood { !rows.isEmpty ? .cheer : chips.isEmpty ? .sad : .happy }

    // MARK: - Найдено

    private var foundCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let img = result.image {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityHidden(true)
                }
                Text(L("Found")).font(.headline).foregroundStyle(Color.burgundy)
                Text("\(rows.count)").font(.caption.bold()).foregroundStyle(Color.cream)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color.brand))
                Spacer()
            }
            ForEach(rows) { r in
                row(r)
                if r.id != rows.last?.id { Divider().opacity(0.5) }
            }
            Button { showSearch = true } label: {
                Label(L("Add another product"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
        }
        .glassCard()
    }

    private func row(_ r: ScanItem) -> some View {
        let f = r.food
        let isOn = !off.contains(f.name)
        return VStack(spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    if isOn { off.insert(f.name) } else { off.remove(f.name) }
                } label: {
                    Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(isOn ? Color.freshGreen : Color.secondary)
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel(isOn ? L("Don't add") : L("Add"))
                EmojiBadge(emoji: f.emoji, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(N(f.name)).font(.headline).foregroundStyle(Color.burgundy).lineLimit(2)
                    Text(L("keeps ~{0}", ScanResultView.shelfText(f.shelf)))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if store.data.shopping.contains(f.name) {
                        Text(L("🛒 on your list")).font(.caption2.weight(.semibold)).foregroundStyle(Color.freshGreen)
                    }
                }
                Spacer(minLength: 4)
                Button { withAnimation { rows.removeAll { $0.food == f } } } label: {
                    Image(systemName: "xmark").font(.subheadline.weight(.bold)).foregroundStyle(Color.burgundy.opacity(0.7))
                        .frame(width: 34, height: 34).background(Circle().fill(Color.burgundy.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L("Not this"))
            }
            HStack(spacing: 10) {
                Menu {
                    ForEach(StorageKind.allCases) { k in
                        Button { place[f.name] = k } label: { Text("\(k.emoji) \(L(k.title))") }
                    }
                } label: {
                    Text("\(storage(f).emoji) \(L(storage(f).title))").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.burgundy)
                        .padding(.horizontal, 12).frame(height: 40)
                        .background(Capsule().fill(Color.burgundy.opacity(0.08)))
                }
                Spacer(minLength: 4)
                HStack(spacing: 0) {
                    Button { setQty(f, r.qty - 1) } label: { Image(systemName: "minus").font(.headline).frame(width: 44, height: 40) }
                        .disabled(r.qty <= 1)
                    Text("×\(r.qty)").font(.headline.weight(.bold)).monospacedDigit().frame(minWidth: 40)
                    Button { setQty(f, r.qty + 1) } label: { Image(systemName: "plus").font(.headline).frame(width: 44, height: 40) }
                }
                .foregroundStyle(Color.burgundy)
                .background(Capsule().fill(Color.burgundy.opacity(0.08)))
                .buttonStyle(.plain)
            }
            .padding(.leading, 46)
        }
        .opacity(isOn ? 1 : 0.45)
    }

    private func setQty(_ f: Food, _ n: Int) {
        guard let i = rows.firstIndex(where: { $0.food == f }) else { return }
        rows[i].qty = min(99, max(1, n))
    }

    /// «5 дней», «3 месяца», «1 год» — сколько продукт обычно хранится
    static func shelfText(_ days: Int) -> String {
        if days < 60 { return Lp(max(1, days), "day|days") }
        if days < 365 { return Lp(days / 30, "month|months") }
        return Lp(days / 365, "year|years")
    }

    // MARK: - Варианты / не узнал

    private var guessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if nothing {
                HStack(alignment: .top, spacing: 10) {
                    if let img = result.image {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .accessibilityHidden(true)
                    } else {
                        Image(systemName: "camera.metering.unknown").font(.title2).foregroundStyle(Color.burgundy)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("Couldn't recognize")).font(.headline).foregroundStyle(Color.burgundy)
                        Text(L("Hold the camera closer, add light and keep 1–4 products in the frame. Or find the product in search."))
                            .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else if !chips.isEmpty {
                Text(rows.isEmpty ? L("Is it one of these?") : L("Something else in the photo?"))
                    .font(.headline).foregroundStyle(Color.burgundy)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chips) { f in
                            Button { pick(f) } label: {
                                Text("\(f.emoji) \(N(f.name))").font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .foregroundStyle(Color.burgundy)
                                    .background(Capsule().fill(Color.glassFill))
                                    .overlay(Capsule().strokeBorder(Color.burgundy.opacity(0.2), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button { showSearch = true } label: {
                    Label(L("Find manually"), systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                if nothing {
                    Button { dismiss() } label: {
                        Label(L("Try again"), systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .glassCard()
    }

    private func pick(_ f: Food) {
        UISelectionFeedbackGenerator().selectionChanged()
        let qty = result.items.first { $0.food == f }?.qty ?? 1
        withAnimation { rows.append(ScanItem(food: f, qty: qty, confidence: 1, source: "picked")) }
    }

    // MARK: - Кнопка

    private var addBar: some View {
        Button {
            store.addBatch(selected.map { (food: $0.food, qty: $0.qty, storage: storage($0.food)) })
            dismiss()
            onAdded()
        } label: {
            Label(units == 0 ? L("Nothing to add yet") : L("Add all ({0})", units), systemImage: "refrigerator.fill")
                .font(.title3.weight(.bold)).frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(units == 0)
        .opacity(units == 0 ? 0.55 : 1)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            LinearGradient(colors: [Color.appBackground.opacity(0), Color.appBackground.opacity(0.92)], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }
}
