import SwiftUI
import PhotosUI

/// «Добавить списком или по чеку» (v30): пишешь/вставляешь список или фотографируешь чек —
/// Нутрик находит каждый продукт (EN / RU / KK), количество и место; ничего не меняется, пока не нажмёшь «Добавить».
struct QuickAddView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var initialText = ""
    var demoReceipt = false

    @State private var text = ""
    @State private var lines: [QuickAdd.Line] = []
    @State private var chosen: [String: String] = [:]          // строка → продукт, выбранный вручную
    @State private var off: Set<String> = []                    // снятые галочки (по продукту)
    @State private var qty: [String: Int] = [:]                 // изменённое количество (по продукту)
    @State private var place: [String: StorageKind] = [:]       // изменённое место (по продукту)
    @State private var reading = false
    @State private var photo: PhotosPickerItem?
    @State private var showCamera = false
    @State private var scanned: UIImage?
    @FocusState private var focused: Bool

    private struct Row: Identifiable {
        let line: QuickAdd.Line
        let food: Food
        var id: Int { line.id }
    }

    private var rows: [Row] {
        var out: [Row] = []
        for l in lines {
            guard let f = chosen[l.source].flatMap({ store.db.byName[$0] }) ?? l.food else { continue }
            if out.contains(where: { $0.food == f }) { continue }
            out.append(Row(line: l, food: f))
        }
        return out
    }
    private var unknown: [QuickAdd.Line] { lines.filter { $0.food == nil && chosen[$0.source] == nil } }
    private func count(_ r: Row) -> Int { qty[r.food.name] ?? r.line.qty }
    private func storage(_ f: Food) -> StorageKind { place[f.name] ?? FoodDB.defaultStorage(f) }
    private var selected: [Row] { rows.filter { !off.contains($0.food.name) } }
    private var units: Int { selected.reduce(0) { $0 + count($1) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NutrikSays(text: headline, mood: reading ? .talk : rows.isEmpty ? .wave : .cheer, size: 72)
                    inputCard
                    if !rows.isEmpty { foundCard }
                    if !unknown.isEmpty { unknownCard }
                    Label(L("Photos are read right on your phone — nothing is uploaded."), systemImage: "lock.fill")
                        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: lines)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LiveBackground())
            .safeAreaInset(edge: .bottom) { addBar }
            .navigationTitle(L("Add a list or receipt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L("Cancel")) { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button(L("Done")) { focused = false } }
            }
            .task(id: text) {
                do { try await Task.sleep(for: .milliseconds(text.isEmpty ? 0 : 250)) } catch { return }
                lines = QuickAdd.parse(text, db: store.db)
            }
            .onChange(of: photo) { _, item in
                guard let item else { return }
                Task {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d) { await read(img) }
                    photo = nil
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in Task { await read(img) } }.ignoresSafeArea()
            }
            .onAppear {
                if text.isEmpty { text = initialText }
            }
            .task {
                if demoReceipt, UIShot.enabled {
                    let img = QuickAddDemo.receipt()
                    await read(img)
                }
            }
        }
    }

    private var headline: String {
        if reading { return L("Reading the photo… 🔍") }
        if rows.isEmpty && unknown.isEmpty {
            return L("Type or paste your shopping list — or snap the receipt. I'll find every product!")
        }
        if rows.isEmpty { return L("Hmm, I didn't recognize these. Pick a suggestion or write it differently.") }
        return L("Found {0}. Check the amounts and tap Add 👇", Lp(rows.count, "product|products"))
    }

    // MARK: - Ввод

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(L("e.g. 2 eggs, milk, 3 bananas, bread"))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .padding(.horizontal, 5).padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .focused($focused)
                    .scrollContentBackground(.hidden)
                    .autocorrectionDisabled()
                    .frame(minHeight: 96, maxHeight: 180)
            }
            .font(.body)
            .padding(8)
            .background(Color.paper.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !text.isEmpty {
                    Button { text = ""; chosen = [:]; off = []; qty = [:]; place = [:]; scanned = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).padding(8)
                    }
                    .accessibilityLabel(L("Clear"))
                }
            }

            HStack(spacing: 8) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: { tile("camera.fill", L("Scan receipt")) }
                }
                PhotosPicker(selection: $photo, matching: .images) { tile("photo.on.rectangle", L("From photo")) }
                Button {
                    if let s = UIPasteboard.general.string, !s.isEmpty { text = text.isEmpty ? s : text + "\n" + s }
                } label: { tile("doc.on.clipboard", L("Paste")) }
            }
            .buttonStyle(.plain)
            .disabled(reading)

            if let img = scanned {
                HStack(spacing: 10) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 44, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    if reading { ProgressView().tint(Color.burgundy) }
                    Text(reading ? L("Reading the photo… 🔍") : L("Text from the photo is in the box above — you can fix it."))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }

    private func tile(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3)
            Text(title).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .foregroundStyle(Color.burgundy)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.burgundy.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Найдено

    private var foundCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("Found")).font(.headline).foregroundStyle(Color.burgundy)
                Text("\(rows.count)").font(.caption.bold()).foregroundStyle(Color.cream)
                    .padding(.horizontal, 7).padding(.vertical, 2).background(Capsule().fill(Color.brand))
                Spacer()
                Button(off.isEmpty ? L("Uncheck all") : L("Check all")) {
                    off = off.isEmpty ? Set(rows.map(\.food.name)) : []
                }
                .font(.caption.weight(.semibold))
            }
            ForEach(rows) { r in
                row(r)
                if r.id != rows.last?.id { Divider().opacity(0.5) }
            }
            Text(L("Tap the place icon to switch fridge / freezer / pantry. Hold a row if I picked the wrong product."))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .glassCard()
    }

    private func row(_ r: Row) -> some View {
        let f = r.food
        let isOn = !off.contains(f.name)
        let n = count(r)
        return HStack(spacing: 10) {
            Button {
                UISelectionFeedbackGenerator().selectionChanged()
                if isOn { off.insert(f.name) } else { off.remove(f.name) }
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(isOn ? Color.freshGreen : Color.secondary)
            }
            .accessibilityLabel(isOn ? L("Don't add") : L("Add"))
            EmojiBadge(emoji: f.emoji, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(N(f.name)).font(.subheadline.weight(.semibold)).foregroundStyle(Color.burgundy).lineLimit(2)
                HStack(spacing: 4) {
                    if store.data.shopping.contains(f.name) {
                        Text(L("🛒 on your list")).font(.caption2.weight(.semibold)).foregroundStyle(Color.freshGreen)
                    }
                    Text("“\(r.line.source)”").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            Menu {
                ForEach(StorageKind.allCases) { k in
                    Button { place[f.name] = k } label: { Text("\(k.emoji) \(k.title)") }
                }
            } label: {
                Text(storage(f).emoji).font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.burgundy.opacity(0.08)))
            }
            .accessibilityLabel(storage(f).title)
            HStack(spacing: 0) {
                Button { qty[f.name] = max(1, n - 1) } label: { Image(systemName: "minus").frame(width: 28, height: 32) }
                    .disabled(n <= 1)
                Text("×\(n)").font(.subheadline.weight(.bold)).monospacedDigit().frame(minWidth: 30)
                Button { qty[f.name] = min(99, n + 1) } label: { Image(systemName: "plus").frame(width: 28, height: 32) }
            }
            .foregroundStyle(Color.burgundy)
            .background(Capsule().fill(Color.burgundy.opacity(0.08)))
            .buttonStyle(.plain)
        }
        .opacity(isOn ? 1 : 0.45)
        .contextMenu {
            if !r.line.suggestions.isEmpty {
                Section(L("Not this? Maybe:")) {
                    ForEach(r.line.suggestions) { s in
                        Button { chosen[r.line.source] = s.name } label: { Text("\(s.emoji) \(N(s.name))") }
                    }
                }
            }
            Button(role: .destructive) { off.insert(f.name) } label: { Label(L("Don't add"), systemImage: "minus.circle") }
        }
    }

    // MARK: - Не распознано

    private var unknownCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Didn't recognize")).font(.headline).foregroundStyle(Color.burgundy)
            ForEach(unknown) { l in
                VStack(alignment: .leading, spacing: 6) {
                    Text("“\(l.source)”").font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    if l.suggestions.isEmpty {
                        Text(L("Not in my food base — it won't be added.")).font(.caption2).foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                Text(L("Maybe:")).font(.caption).foregroundStyle(.secondary)
                                ForEach(l.suggestions) { s in
                                    Button { withAnimation { chosen[l.source] = s.name } } label: {
                                        Text("\(s.emoji) \(N(s.name))").font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10).padding(.vertical, 6)
                                            .foregroundStyle(Color.burgundy)
                                            .background(Capsule().fill(Color.glassFill))
                                            .overlay(Capsule().strokeBorder(Color.burgundy.opacity(0.2), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
            }
        }
        .glassCard()
    }

    // MARK: - Кнопка

    private var addBar: some View {
        Button {
            let items = selected.map { (food: $0.food, qty: count($0), storage: storage($0.food)) }
            store.addBatch(items)
            dismiss()
        } label: {
            Label(units == 0 ? L("Nothing to add yet") : L("Add {0}", Lp(units, "product|products")), systemImage: "refrigerator.fill")
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

    private func read(_ img: UIImage) async {
        scanned = img
        reading = true
        let s = await QuickAdd.recognize(img)
        reading = false
        let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.isEmpty {
            store.say(L("I couldn't read any text — try a sharper photo with more light 📸"))
        } else {
            text = text.isEmpty ? clean : text + "\n" + clean
        }
    }
}

/// Камера для фото чека (UIImagePickerController).
private struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = .camera
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Демо для скриншотов: список на языке приложения и «фото чека», нарисованное в коде (проверяет распознавание в CI).
enum QuickAddDemo {
    static var list: String {
        switch AppLang.current {
        case .ru: return "яйца 10 шт\nмолоко ×2\nбананы, хлеб\nкуриная грудка 500 г\nпомидоры\nчипсы со вкусом краба"
        case .kk: return "жұмыртқа 10 дана\nсүт ×2\nбанан, нан\nтауық төсі 500 г\nқызанақ\nбір нәрсе"
        case .en: return "2 eggs\nmilk x2\n3 bananas, bread\nchicken breast 500 g\ntomatoes\nyogurt\nmystery snack"
        }
    }

    static func receipt() -> UIImage {
        let lines = ["SUPERMARKET #12", "ЧЕК 004512", "", "МОЛОКО 2,5% 1Л     2 x 520,00", "ЯЙЦО С1 10ШТ          890,00",
                     "БАНАНЫ ВЕС 1,2 КГ     640,00", "ХЛЕБ БЕЛЫЙ            230,00", "ПОМИДОРЫ              780,00",
                     "СЫР ЧЕДДЕР 200Г      1450,00", "YOGURT GREEK          560,00", "", "ИТОГО                5090,00", "КАРТА                5090,00"]
        let size = CGSize(width: 720, height: 980)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let font = UIFont.monospacedSystemFont(ofSize: 30, weight: .medium)
            for (i, s) in lines.enumerated() {
                (s as NSString).draw(at: CGPoint(x: 40, y: 50 + CGFloat(i) * 66), withAttributes: [.font: font, .foregroundColor: UIColor.black])
            }
        }
    }
}
