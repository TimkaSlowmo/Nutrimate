import Foundation
import UIKit
import Vision

/// Быстрое добавление (v30): список покупок текстом («2 яйца, молоко, 3 banana») или фото чека.
/// Каждая строка → продукт базы (EN / RU / KK) + количество; ничего не добавляется, пока пользователь не нажмёт кнопку.
enum QuickAdd {
    struct Line: Identifiable, Equatable {
        let id: Int
        let source: String          // исходная строка (как в чеке / списке)
        var food: Food?
        var qty: Int
        var suggestions: [Food]
    }

    /// Служебные строки чека: итоги, оплата, налоги, адрес, название магазина — пропускаем.
    /// Начало слова (длинные, однозначные основы):
    private static let junkPrefix = ["итог", "сумм", "subtotal", "налич", "ндс", "сдач", "барлығы", "жиыны", "спасибо", "кассир",
                                     "скидк", "discount", "жеңілдік", "оплат", "payment", "төлем", "бонус", "bonus", "www", "http",
                                     "кассалық", "чек", "фискал", "дүкен"]
    /// Целое слово (короткие, чтобы «карта» не ловила «картошку», а «cash» — «cashews»):
    private static let junkWord: Set<String> = ["total", "card", "карта", "картой", "cash", "vat", "ққс", "change", "касса", "tax",
                                                "thank", "thanks", "рахмет", "бин", "иин", "инн", "cashier", "тел", "tel", "адрес",
                                                "address", "смена", "фн", "фп", "рнм", "зно", "qr", "receipt", "store", "shop", "магазин",
                                                "тоо", "ип", "ооо", "llp", "ltd", "inc", "visa", "mastercard", "kaspi", "pos"]

    /// Разбить текст на строки-позиции: переносы строк, запятые, «;», «•».
    static func split(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: "\n;•·"))
            .flatMap { line -> [String] in
                // запятая — разделитель в списке («молоко, яйца»), но не в цене «520,00» и не в «2,5%»
                line.replacingOccurrences(of: #"(?<!\d),|,(?!\d)"#, with: "\n", options: .regularExpression)
                    .components(separatedBy: "\n")
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Количество в строке: «2 eggs», «яйца 10 шт», «×3», «2 x 520,00»; «1 кг», «200 г», «2,5%» — не штуки.
    static func quantity(_ raw: String) -> Int {
        let t = raw.lowercased()
        func first(_ pattern: String) -> Int? {
            guard let r = t.range(of: pattern, options: .regularExpression) else { return nil }
            return Int(t[r].filter(\.isNumber))
        }
        let unit = #"(?!\s*(kg|кг|g\b|г\b|гр|l\b|л\b|ml|мл|%|[.,]\d))"#
        let candidates: [Int?] = [
            first(#"\d{1,2}(?=\s*(шт|pcs|pc\b|pieces|дана|штук))"#),        // 10 шт
            first(#"\b\d{1,2}(?=\s*[x×х*]\s*\d+[.,]\d{2})"#),             // 2 x 520,00
            first(#"(?<=[x×х*])\s*\d{1,2}\b(?![.,]\d)"#),                 // ×3
            first(#"^\d{1,2}\b"# + unit),                                  // 2 eggs
        ]
        let n = candidates.compactMap { $0 }.first ?? 1
        return min(max(n, 1), 99)
    }

    /// Строка без цен, процентов, единиц и количеств — только слова для поиска продукта.
    static func words(_ raw: String) -> String {
        var t = raw.lowercased().replacingOccurrences(of: "ё", with: "е")
        let patterns = [#"\d+[.,]\d+"#, #"\d+\s*(%|kg|кг|гр|g\b|г\b|ml|мл|l\b|л\b|шт|pcs|дана)"#, #"[x×*]\s*\d+"#, #"\d+"#]
        for p in patterns { t = t.replacingOccurrences(of: p, with: " ", options: .regularExpression) }
        t = t.replacingOccurrences(of: #"[^\p{L}\s]"#, with: " ", options: .regularExpression)
        return t.split(separator: " ").joined(separator: " ")
    }

    private static func isJunk(_ raw: String) -> Bool {
        let t = raw.lowercased()
        let letters = t.filter(\.isLetter).count
        if letters < 3 { return true }                                   // одни цены / номера
        let w = NutrikActions.words(t)
        return w.contains { word in
            junkWord.contains(word) || word.contains("market") || word.contains("маркет")
                || junkPrefix.contains { word.hasPrefix($0) }
        }
    }

    /// Названия продуктов в нижнем регистре (EN, RU, KK) — считаются один раз.
    private static var names: [[String]] = []

    /// Лучший продукт для строки: самое длинное целое название (EN / RU / KK, с начала слова), иначе — разбор как в чате.
    static func match(_ t: String, db: FoodDB) -> [Food] {
        guard !t.isEmpty else { return [] }
        let padded = " " + t
        var best: [(Food, Int)] = []
        if names.count != db.foods.count {
            names = db.foods.map { f in [f.name, f.ru, f.kk].compactMap { $0?.lowercased().replacingOccurrences(of: "ё", with: "е") } }
        }
        for (f, ns) in zip(db.foods, names) {
            if let hit = ns.filter({ $0.count >= 3 && padded.contains(" " + $0) }).max(by: { $0.count < $1.count }) {
                best.append((f, hit.count))
            }
        }
        var out = best.sorted { $0.1 > $1.1 }.map(\.0)
        for f in NutrikActions.foods(in: t, db: db) where !out.contains(f) { out.append(f) }
        return Array(out.prefix(4))
    }

    /// Разобрать весь текст. Один и тот же продукт в нескольких строках складывается (как в холодильнике).
    static func parse(_ text: String, db: FoodDB) -> [Line] {
        var out: [Line] = []
        for (i, raw) in split(text).prefix(80).enumerated() {
            // «2 x 520,00» отдельной строкой под названием — это количество для предыдущей позиции
            if raw.range(of: #"^\s*\d{1,2}\s*[x×х*]\s*\d+([.,]\d{2})?\s*$"#, options: .regularExpression) != nil, !out.isEmpty {
                out[out.count - 1].qty = quantity(raw)
                continue
            }
            if isJunk(raw) { continue }
            let t = words(raw)
            guard t.filter(\.isLetter).count >= 2 else { continue }
            let found = match(t, db: db)
            let qty = quantity(raw)
            if let f = found.first {
                if let j = out.firstIndex(where: { $0.food == f }) {
                    out[j].qty = min(99, out[j].qty + qty)
                    continue
                }
                out.append(Line(id: i, source: raw, food: f, qty: qty, suggestions: Array(found.dropFirst().prefix(3))))
            } else {
                let longest = t.split(separator: " ").map(String.init).filter { $0.count >= 3 }.max { $0.count < $1.count } ?? t
                var sugg = Array(db.search(longest, category: nil).prefix(3))
                if sugg.isEmpty, longest.count > 4 { sugg = Array(db.search(String(longest.prefix(4)), category: nil).prefix(3)) }
                out.append(Line(id: i, source: raw, food: nil, qty: qty, suggestions: sugg))
            }
        }
        return out
    }

    // MARK: - Распознавание текста на фото (Vision, на телефоне, без интернета)

    /// Текст с фото чека или списка. Слова одной строки чека (название слева, цена справа) собираются в одну строку.
    static func recognize(_ image: UIImage) async -> String {
        guard let cg = image.cgImage else { return "" }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) { () -> String in
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.usesLanguageCorrection = true
            let supported = (try? req.supportedRecognitionLanguages()) ?? ["en-US"]
            let langs = ["ru-RU", "en-US", "uk-UA"].filter { supported.contains($0) }
            if !langs.isEmpty { req.recognitionLanguages = langs }
            do { try VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req]) } catch { return "" }
            return joinLines(req.results ?? [])
        }.value
    }

    private static func joinLines(_ obs: [VNRecognizedTextObservation]) -> String {
        struct Piece { let text: String; let box: CGRect }
        let pieces = obs.compactMap { o in o.topCandidates(1).first.map { Piece(text: $0.string, box: o.boundingBox) } }
            .sorted { $0.box.midY > $1.box.midY }          // сверху вниз (у Vision y снизу)
        var rows: [[Piece]] = []
        for p in pieces {
            if let last = rows.last?.first, abs(last.box.midY - p.box.midY) < max(last.box.height, p.box.height) * 0.55 {
                rows[rows.count - 1].append(p)
            } else {
                rows.append([p])
            }
        }
        return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }.joined(separator: "\n")
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
