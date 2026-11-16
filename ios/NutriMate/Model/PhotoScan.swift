import Foundation
import UIKit
import Vision
import CoreML

/// Сканер по фото (v33): одна камера понимает и чек (текст), и сами продукты (бананы, яблоки…).
/// 1) На телефоне, бесплатно и без интернета: Apple Vision — текст (VNRecognizeTextRequest) +
///    классификатор картинок (VNClassifyImageRequest) + «заметные объекты» (несколько продуктов в кадре).
/// 2) Если телефон не уверен и в профиле включён «Умный Нутрик» — уменьшенная копия фото (≤768 px, без EXIF/GPS)
///    уходит на наш сервер (POST /vision) только для распознавания и нигде не хранится.
/// Ничего не добавляется само: результат всегда показывается на листе проверки.

/// Подсказка пользователя: что на фото.
enum ScanHint: String, CaseIterable, Identifiable {
    case auto, receipt, products
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return L("Auto")
        case .receipt: return L("Receipt")
        case .products: return L("Products")
        }
    }
}

/// Метка классификатора Vision (идентификатор таксономии Apple) и уверенность 0…1.
struct VisionLabel: Equatable {
    let id: String
    let confidence: Double
}

/// Найденный на фото продукт.
struct ScanItem: Identifiable, Equatable {
    var id: String { food.name }
    let food: Food
    var qty: Int
    let confidence: Double
    /// Откуда: метка Vision («banana») или имя от Умного Нутрика
    let source: String
}

struct ScanResult: Identifiable {
    enum Kind: Equatable { case receipt, products, nothing }
    let id = UUID()
    var kind: Kind = .nothing
    /// Текст с фото (для чека)
    var text = ""
    var items: [ScanItem] = []
    /// Телефон не уверен: продукты не отмечаются сами, вместо них — кнопки-варианты
    var uncertain = false
    var alternatives: [Food] = []
    /// Что подставить в поиск для «Найти вручную»
    var query = ""
    /// Что увидел Vision (для лога скриншотов): всё фото и вырезанные объекты
    var labels: [VisionLabel] = []
    var cropLabels: [[VisionLabel]] = []
    var viaServer = false
    var image: UIImage?
}

// MARK: - Словарь «метка Vision → продукт» (Resources/vision_labels.json, делает tool/vision_labels.py)

enum VisionLabels {
    struct File: Decodable {
        let labels: [String: String]
        let generic: [String: [String]]
    }

    static let file: File = {
        guard let url = Bundle.main.url(forResource: "vision_labels", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let f = try? JSONDecoder().decode(File.self, from: data) else { return File(labels: [:], generic: [:]) }
        return f
    }()

    /// «Bell Pepper» / «bell-pepper» → «bell_pepper»
    static func key(_ id: String) -> String {
        id.lowercased().trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "-", with: "_")
    }

    static func food(for id: String, db: FoodDB) -> Food? {
        file.labels[key(id)].flatMap { db.byName[$0] }
    }

    /// Общая метка («fruit», «food», «baked_goods») — продуктом не считается
    static func isGeneric(_ id: String) -> Bool { file.generic[key(id)] != nil }

    static func suggestions(for id: String, db: FoodDB) -> [Food] {
        (file.generic[key(id)] ?? []).compactMap { db.byName[$0] }
    }
}

// MARK: - Имя продукта (от сервера, по-английски / по-русски / по-казахски) → продукт базы

enum FoodMatch {
    /// Частые имена, которые даёт ИИ, а в базе продукт называется иначе
    static let synonyms: [String: String] = [
        "red apple": "Apple", "yellow apple": "Apple", "apples": "Apple", "green apples": "Green Apple",
        "egg": "Eggs", "chicken egg": "Eggs", "chicken eggs": "Eggs", "grape": "Grapes", "bunch of grapes": "Grapes",
        "mushroom": "Mushrooms", "button mushroom": "Champignons", "cheese": "Cheddar Cheese", "hard cheese": "Cheddar Cheese",
        "bread": "White Bread", "loaf of bread": "Bread Loaf", "sweet pepper": "Bell Pepper", "red pepper": "Red Bell Pepper",
        "green pepper": "Green Bell Pepper", "yellow pepper": "Yellow Bell Pepper", "scallion": "Spring Onion",
        "green onion": "Spring Onion", "aubergine": "Eggplant", "courgette": "Zucchini", "chicken": "Whole Chicken",
        "raw chicken": "Whole Chicken", "minced meat": "Ground Beef", "mince": "Ground Beef", "yoghurt": "Yogurt",
        "juice": "Orange Juice", "water": "Mineral Water", "bottled water": "Mineral Water", "soda": "Cola",
        "coffee": "Ground Coffee", "tea": "Black Tea", "oil": "Vegetable Oil", "sausage": "Sausages",
        "hot dogs": "Hot Dog Sausages", "beet": "Beetroot", "beets": "Beetroot", "lemons": "Lemon",
        "mandarin": "Tangerine", "mandarins": "Tangerine", "noodles": "Egg Noodles", "cream": "Heavy Cream",
        "chili": "Chili Pepper", "hot pepper": "Chili Pepper", "peas": "Green Peas", "corn on the cob": "Corn",
        "sweetcorn": "Corn", "cherry tomatoes": "Cherry Tomato", "baby carrots": "Baby Carrots", "nuts": "Mixed Nuts",
    ]

    private static var index: [String: String] = [:]
    private static var indexed = -1

    static func norm(_ s: String) -> String {
        s.lowercased().replacingOccurrences(of: "ё", with: "е")
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s'-]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func exact(_ s: String, _ db: FoodDB) -> Food? {
        if indexed != db.foods.count {
            var m: [String: String] = [:]
            for f in db.foods {
                for n in [f.name, f.ru, f.kk].compactMap({ $0 }) where !n.isEmpty {
                    let k = norm(n)
                    if m[k] == nil { m[k] = f.name }
                }
            }
            index = m
            indexed = db.foods.count
        }
        if let n = synonyms[s], let f = db.byName[n] { return f }
        if let n = index[s], let f = db.byName[n] { return f }
        if let f = VisionLabels.food(for: s, db: db) { return f }
        return nil
    }

    /// Множественное ↔ единственное: «strawberries» → «strawberry», «tomatoes» → «tomato», «egg» → «eggs»
    private static func variants(_ s: String) -> [String] {
        var v: [String] = []
        if s.hasSuffix("ies") { v.append(String(s.dropLast(3)) + "y") }
        if s.hasSuffix("oes") || s.hasSuffix("ches") || s.hasSuffix("shes") { v.append(String(s.dropLast(2))) }
        if s.hasSuffix("s") && !s.hasSuffix("ss") { v.append(String(s.dropLast())) }
        v.append(s + "s")
        v.append(s + "es")
        return v
    }

    private static func lookup(_ s: String, _ db: FoodDB) -> Food? {
        if let f = exact(s, db) { return f }
        for v in variants(s) { if let f = exact(v, db) { return f } }
        return nil
    }

    /// Продукт базы для имени («Banana», «Red Apple», «Bananas», «молоко», «сүт»). Нет уверенного совпадения — nil.
    static func food(named raw: String, db: FoodDB) -> Food? {
        let n = norm(raw)
        guard n.filter(\.isLetter).count >= 2 else { return nil }
        if let f = lookup(n, db) { return f }
        // лишние прилагательные спереди: «fresh red apple» → «red apple» → «apple»
        var words = n.split(separator: " ").map(String.init)
        while words.count > 1 {
            words.removeFirst()
            if let f = lookup(words.joined(separator: " "), db) { return f }
        }
        // самое длинное целое название внутри фразы (как строки чека)
        if let f = QuickAdd.match(QuickAdd.words(n), db: db).first { return f }
        return fuzzy(n, db)
    }

    /// Опечатки и неточные формы: расстояние Левенштейна ≤ 1 (короткие) / ≤ 2 (длинные) до английского названия
    private static func fuzzy(_ s: String, _ db: FoodDB) -> Food? {
        guard s.count >= 4 else { return nil }
        let limit = s.count <= 6 ? 1 : 2
        var best: (Food, Int)?
        let a = Array(s)
        for f in db.foods {
            let b = Array(norm(f.name))
            if abs(b.count - a.count) > limit { continue }
            let d = distance(a, b, limit: limit)
            if d <= limit, best == nil || d < best!.1 { best = (f, d) }
        }
        return best?.0
    }

    static func distance(_ a: [Character], _ b: [Character], limit: Int) -> Int {
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count)
        for i in 1...a.count {
            var cur = [i] + Array(repeating: 0, count: b.count)
            var rowMin = cur[0]
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
                rowMin = min(rowMin, cur[j])
            }
            if rowMin > limit { return limit + 1 }
            prev = cur
        }
        return prev[b.count]
    }
}

// MARK: - Распознавание

enum PhotoScan {
    /// Ниже этой уверенности телефон считается «не уверен» (и может спросить Умного Нутрика)
    static let confident = 0.45

    /// Похоже на чек или список: много строк с текстом, цены, или ≥2 строки уже узнаны как продукты.
    static func looksLikeReceipt(_ text: String, db: FoodDB) -> Bool {
        let lines = text.components(separatedBy: "\n")
        let rows = lines.filter { $0.filter(\.isLetter).count >= 3 }.count
        let priced = lines.filter {
            $0.range(of: #"\d+[.,]\d{2}(?!\d)"#, options: .regularExpression) != nil
                || $0.range(of: #"(?<!\d)\d{3,}(?!\d)"#, options: .regularExpression) != nil
        }.count
        if rows >= 6 { return true }
        if rows >= 3 && priced >= 2 { return true }
        guard rows >= 2 else { return false }
        return QuickAdd.parse(text, db: db).filter { $0.food != nil }.count >= 2
    }

    /// Решение по меткам Vision: всё фото + вырезанные заметные объекты (каждый объект — отдельный продукт).
    static func decide(full: [VisionLabel], crops: [[VisionLabel]], db: FoodDB)
        -> (items: [ScanItem], uncertain: Bool, alternatives: [Food], query: String) {
        let minLabel = 0.12
        func mapped(_ obs: [VisionLabel]) -> [(Food, VisionLabel)] {
            var out: [(Food, VisionLabel)] = []
            for o in obs.sorted(by: { $0.confidence > $1.confidence }) where o.confidence >= minLabel {
                if let f = VisionLabels.food(for: o.id, db: db), !out.contains(where: { $0.0 == f }) { out.append((f, o)) }
            }
            return out
        }
        var conf: [String: Double] = [:]
        var count: [String: Int] = [:]
        var source: [String: String] = [:]
        var order: [Food] = []
        func record(_ f: Food, _ o: VisionLabel, counted: Bool) {
            if !order.contains(f) { order.append(f) }
            if o.confidence > conf[f.name] ?? -1 { conf[f.name] = o.confidence; source[f.name] = o.id }
            if counted { count[f.name, default: 0] += 1 }
        }
        // каждый заметный объект: его лучший продукт (уверенно) — плюс один к количеству
        for c in crops {
            if let m = mapped(c).first, m.1.confidence >= 0.3 { record(m.0, m.1, counted: true) }
        }
        // всё фото: лучший продукт и ещё до двух уверенных
        let whole = mapped(full)
        for (i, (f, o)) in whole.enumerated() where i == 0 || (o.confidence >= 0.3 && i < 3) {
            record(f, o, counted: false)
        }
        func c(_ f: Food) -> Double { conf[f.name] ?? 0 }
        let top: Double = order.map(c).max() ?? 0
        let minConf: Double = max(minLabel, top * 0.4)
        var kept: [Food] = order.filter { c($0) >= minConf }
        kept.sort { c($0) > c($1) }
        var items: [ScanItem] = []
        for f in kept.prefix(4) {
            let n: Int = max(1, count[f.name] ?? 0)
            items.append(ScanItem(food: f, qty: n, confidence: c(f), source: source[f.name] ?? ""))
        }
        let uncertain = items.isEmpty || top < confident
        // варианты: что ещё похоже + подсказки общих меток («fruit» → яблоко, банан, апельсин)
        var alts: [Food] = uncertain ? items.map(\.food) : []
        for (f, o) in whole where o.confidence >= 0.05 && !items.contains(where: { $0.food == f }) && !alts.contains(f) {
            alts.append(f)
        }
        // общие метки подсказывают, только когда продукт не узнан уверенно (иначе к бананам липли бы «яблоко, апельсин»)
        if uncertain {
            for o in full.sorted(by: { $0.confidence > $1.confidence }) where o.confidence >= 0.1 && VisionLabels.isGeneric(o.id) {
                for f in VisionLabels.suggestions(for: o.id, db: db) where !alts.contains(f) { alts.append(f) }
            }
        }
        let query = uncertain ? (alts.first.map { N($0.name) } ?? "") : ""
        return (items, uncertain, Array(alts.prefix(3)), query)
    }

    /// Ответ сервера → продукты базы (одинаковые складываются). Неизвестные имена — отдельно (для поиска).
    static func mapServer(_ items: [NutrikVision.Item], db: FoodDB) -> (items: [ScanItem], unknown: [String]) {
        var out: [ScanItem] = []
        var unknown: [String] = []
        for it in items {
            guard let f = FoodMatch.food(named: it.name, db: db) else { unknown.append(it.name); continue }
            let q = min(50, max(1, it.qty ?? 1))
            if let i = out.firstIndex(where: { $0.food == f }) {
                out[i].qty = min(99, out[i].qty + q)
            } else {
                out.append(ScanItem(food: f, qty: q, confidence: min(1, max(0, it.confidence ?? 0.5)), source: it.name))
            }
        }
        return (out, unknown)
    }

    // MARK: Vision (на телефоне)

    struct Local {
        var text = ""
        var labels: [VisionLabel] = []
        var crops: [[VisionLabel]] = []
    }

    /// Фото → ровная картинка (ориентация «вверх») не больше maxSide пикселей по длинной стороне.
    /// Перерисовка из пикселей: в результате нет EXIF/GPS.
    static func normalized(_ image: UIImage, maxSide: CGFloat) -> CGImage? {
        let px = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard px.width >= 1, px.height >= 1 else { return nil }
        let k = min(1, maxSide / max(px.width, px.height))
        let size = CGSize(width: max(1, (px.width * k).rounded()), height: max(1, (px.height * k).rounded()))
        let fmt = UIGraphicsImageRendererFormat()
        fmt.scale = 1
        fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    /// Копия для сервера: длинная сторона ≤ 768 px, JPEG ≈ 0.7, без метаданных.
    static func uploadJPEG(_ image: UIImage) -> Data? {
        guard let cg = normalized(image, maxSide: 768) else { return nil }
        let img = UIImage(cgImage: cg)
        guard var data = img.jpegData(compressionQuality: 0.7) else { return nil }
        if data.count > 300_000, let smaller = img.jpegData(compressionQuality: 0.45) { data = smaller }
        return data.count <= 300_000 ? data : nil
    }

    /// В симуляторе нейросети Vision работают только на CPU
    private static func prepare(_ req: VNRequest) {
        #if targetEnvironment(simulator)
        if let devices = try? req.supportedComputeStageDevices, let main = devices[.main],
           let cpu = main.first(where: { if case .cpu = $0 { return true } else { return false } }) {
            req.setComputeDevice(cpu, for: .main)
        }
        #endif
    }

    private static func labels(_ req: VNClassifyImageRequest) -> [VisionLabel] {
        (req.results ?? [])
            .filter { $0.confidence >= 0.02 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(25)
            .map { VisionLabel(id: $0.identifier, confidence: Double($0.confidence)) }
    }

    static func local(_ image: UIImage, hint: ScanHint) -> Local {
        var out = Local()
        guard let cg = normalized(image, maxSide: 2048) else { return out }
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        let supported = (try? text.supportedRecognitionLanguages()) ?? ["en-US"]
        let langs = ["ru-RU", "en-US", "uk-UA"].filter { supported.contains($0) }
        if !langs.isEmpty { text.recognitionLanguages = langs }
        let classify = VNClassifyImageRequest()
        prepare(classify)
        let saliency = VNGenerateObjectnessBasedSaliencyImageRequest()
        prepare(saliency)
        var reqs: [VNRequest] = []
        if hint != .products { reqs.append(text) }
        if hint != .receipt { reqs += [classify, saliency] }
        // каждая проверка отдельно: если одна не сработала (например, нет модели в симуляторе), остальные всё равно работают
        for r in reqs { try? handler.perform([r]) }
        out.text = QuickAdd.joinLines(text.results ?? [])
        guard hint != .receipt else { return out }
        out.labels = labels(classify)

        // несколько продуктов в кадре: вырезаем до 4 заметных объектов и классифицируем каждый
        let W = CGFloat(cg.width), H = CGFloat(cg.height)
        func area(_ r: CGRect) -> CGFloat { r.width * r.height }
        let objects: [VNRectangleObservation] = saliency.results?.first?.salientObjects ?? []
        var rects: [CGRect] = objects.map { $0.boundingBox }
        rects = rects.filter { (r: CGRect) -> Bool in area(r) >= 0.02 && area(r) <= 0.85 }
        rects.sort { (a: CGRect, b: CGRect) -> Bool in area(a) > area(b) }
        let boxes = Array(rects.prefix(4))
        let single: Bool = boxes.count == 1 && area(boxes[0]) < 0.5
        guard boxes.count >= 2 || single else { return out }
        for b in boxes {
            let pad: CGFloat = 0.08
            let nb = b.insetBy(dx: -b.width * pad, dy: -b.height * pad).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            let x: CGFloat = nb.minX * W
            let y: CGFloat = (1 - nb.maxY) * H
            let w: CGFloat = nb.width * W
            let h: CGFloat = nb.height * H
            let rect = CGRect(x: x, y: y, width: w, height: h).integral
            guard rect.width >= 48, rect.height >= 48, let crop = cg.cropping(to: rect) else { continue }
            let req = VNClassifyImageRequest()
            prepare(req)
            try? VNImageRequestHandler(cgImage: crop, orientation: .up).perform([req])
            let l = labels(req)
            if !l.isEmpty { out.crops.append(l) }
        }
        return out
    }

    // MARK: Всё вместе

    @MainActor
    static func analyze(_ image: UIImage, hint: ScanHint, store: AppStore) async -> ScanResult {
        let db = store.db
        let loc = await Task.detached(priority: .userInitiated) { PhotoScan.local(image, hint: hint) }.value
        var r = ScanResult()
        r.image = image
        r.labels = loc.labels
        r.cropLabels = loc.crops
        let text = loc.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = decide(full: loc.labels, crops: loc.crops, db: db)

        func products(_ d: (items: [ScanItem], uncertain: Bool, alternatives: [Food], query: String)) {
            r.kind = d.items.isEmpty && d.alternatives.isEmpty ? .nothing : .products
            r.items = d.items
            r.uncertain = d.uncertain
            r.alternatives = d.alternatives
            r.query = d.query
        }
        /// Умный Нутрик: true — сервер что-то узнал, результат заменён
        func askServer(_ mode: String) async -> Bool {
            guard let answer = await NutrikVision.recognize(image, mode: mode, store: store) else { return false }
            let m = mapServer(answer, db: db)
            if m.items.isEmpty {
                // сервер назвал то, чего нет в базе: подскажем похожее и подставим имя в поиск
                if let name = m.unknown.first {
                    var merged: [Food] = Array(db.search(name, category: nil).prefix(3))
                    for f in r.alternatives where !merged.contains(f) { merged.append(f) }
                    r.alternatives = Array(merged.prefix(3))
                    r.query = name
                    if r.kind == .nothing && !r.alternatives.isEmpty { r.kind = .products; r.uncertain = true }
                }
                return false
            }
            r.kind = .products
            r.items = m.items
            r.uncertain = m.items.allSatisfy { $0.confidence < 0.5 }
            r.alternatives = Array(d.items.map(\.food).filter { f in !m.items.contains { $0.food == f } }.prefix(3))
            r.query = ""
            r.viaServer = true
            return true
        }

        let receipt = hint == .receipt || (hint == .auto && !text.isEmpty && looksLikeReceipt(text, db: db))
        if receipt {
            let usable = !text.isEmpty && QuickAdd.parse(text, db: db).contains { $0.food != nil }
            if usable {
                r.kind = .receipt
                r.text = text
                return r
            }
            // текст не прочитался или в нём нет продуктов — спросим Умного Нутрика в режиме чека
            if await askServer("receipt") { return r }
            if hint == .auto && !d.items.isEmpty {
                products(d)
                return r
            }
            if !text.isEmpty {
                r.kind = .receipt
                r.text = text
            }
            return r
        }
        products(d)
        if d.uncertain { _ = await askServer("food") }
        return r
    }

    /// Режим скриншотов: что увидел Vision — в Documents/scan.txt (CI кладёт в screens/scan.txt).
    static func log(_ r: ScanResult, name: String) {
        func fmt(_ l: [VisionLabel]) -> String {
            l.prefix(8).map { "\($0.id) \(String(format: "%.2f", $0.confidence))" }.joined(separator: ", ")
        }
        var s = "[\(name)] kind=\(r.kind) uncertain=\(r.uncertain) server=\(r.viaServer)\n"
        s += "  labels: \(fmt(r.labels))\n"
        for (i, c) in r.cropLabels.enumerated() { s += "  crop \(i + 1): \(fmt(c))\n" }
        let found: [String] = r.items.map { (it: ScanItem) -> String in
            let c = String(format: "%.2f", it.confidence)
            return "\(it.food.name) ×\(it.qty) (\(it.source) \(c))"
        }
        s += "  items: " + found.joined(separator: ", ") + "\n"
        s += "  alternatives: " + r.alternatives.map(\.name).joined(separator: ", ") + "\n"
        if !r.text.isEmpty { s += "  text: " + String(r.text.replacingOccurrences(of: "\n", with: " | ").prefix(300)) + "\n" }
        print(s)
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = dir.appendingPathComponent("scan.txt")
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        try? (old + s).write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Умный Нутрик: распознавание фото на сервере (POST /vision)

enum NutrikVision {
    struct Item: Decodable, Equatable {
        let name: String
        let qty: Int?
        let confidence: Double?
    }
    private struct Answer: Decodable {
        let items: [Item]
        let model: String?
    }
    private struct Payload: Encodable {
        let deviceId: String
        let image: String
        let mode: String
        let language: String
    }

    /// Сервер сказал «лимит на сегодня» — до завтра (до перезапуска приложения) фото не отправляем
    @MainActor private static var pausedDay: String?

    private static func dayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    /// Доступно ли: Умный Нутрик включён в профиле, сервер настроен, не режим скриншотов.
    static func available(_ store: AppStore) -> Bool {
        store.data.smartNutrik && !UIShot.enabled && NutrikAI.isConfigured
    }

    /// nil — выключено / нет сети / лимит / ошибка / 12 с без ответа: тогда молча остаётся результат телефона.
    @MainActor
    static func recognize(_ image: UIImage, mode: String, store: AppStore) async -> [Item]? {
        guard available(store), let base = URL(string: NutrikServer.url), pausedDay != dayKey() else { return nil }
        guard let jpeg = await Task.detached(priority: .userInitiated, operation: { PhotoScan.uploadJPEG(image) }).value else { return nil }
        let payload = Payload(deviceId: store.data.deviceId, image: jpeg.base64EncodedString(),
                              mode: mode == "receipt" ? "receipt" : "food", language: store.data.language.rawValue)
        var req = URLRequest(url: base.appendingPathComponent("vision"), timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")", forHTTPHeaderField: "X-NutriMate-Client")
        guard let body = try? JSONEncoder().encode(payload) else { return nil }
        req.httpBody = body
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 429 { pausedDay = dayKey(); return nil }
            guard code == 200, let a = try? JSONDecoder().decode(Answer.self, from: data) else { return nil }
            return a.items
        } catch {
            return nil
        }
    }
}
