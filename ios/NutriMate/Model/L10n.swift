import Foundation

/// Язык интерфейса: English / Русский / Қазақша. Меняется сразу, без перезапуска
/// (RootView пересоздаёт экраны по `.id(language)`).
enum AppLang: String, CaseIterable, Identifiable, Codable {
    case en, ru, kk
    var id: String { rawValue }

    var flag: String {
        switch self {
        case .en: return "🇬🇧"
        case .ru: return "🇷🇺"
        case .kk: return "🇰🇿"
        }
    }

    /// Название языка на нём самом
    var native: String {
        switch self {
        case .en: return "English"
        case .ru: return "Русский"
        case .kk: return "Қазақша"
        }
    }

    /// Приветствие Нутрика на этом языке (первый шаг регистрации)
    var hello: String {
        switch self {
        case .en: return "Hi! I'm Nutrik 🐾 Let's pick your language."
        case .ru: return "Привет! Я Нутрик 🐾 Давай выберем язык."
        case .kk: return "Сәлем! Мен Нутрикпін 🐾 Тілді таңдайық."
        }
    }

    var locale: Locale {
        switch self {
        case .en: return Locale(identifier: "en_US")
        case .ru: return Locale(identifier: "ru_RU")
        case .kk: return Locale(identifier: "kk_KZ")
        }
    }

    /// Язык системы, если он русский или казахский, иначе английский.
    static var system: AppLang {
        for code in Locale.preferredLanguages {
            let c = code.prefix(2).lowercased()
            if c == "ru" { return .ru }
            if c == "kk" { return .kk }
            if c == "en" { return .en }
        }
        return .en
    }

    /// Текущий язык (выставляет AppStore при загрузке и при смене в профиле)
    static var current: AppLang = .en
}

/// Таблица переводов: Resources/strings.json — { "English key": { "ru": "…", "kk": "…" } }.
/// Проверка, что у каждой строки L("…") в коде есть перевод: `python3 tool/check_strings.py`.
enum L10n {
    static let table: [String: [String: String]] = {
        guard let url = Bundle.main.url(forResource: "strings", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let t = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
        return t
    }()

    static func raw(_ key: String, _ lang: AppLang = AppLang.current) -> String {
        guard lang != .en, let s = table[key]?[lang.rawValue], !s.isEmpty else { return key }
        return s
    }

    /// Форма множественного числа: forms = "one|few|many" (ru), "one|other" (en), одна форма (kk).
    static func plural(_ n: Int, _ forms: String) -> String {
        let f = forms.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        guard f.count > 1 else { return f.first ?? "" }
        let a = abs(n)
        if f.count >= 3 {
            let m10 = a % 10, m100 = a % 100
            if m10 == 1 && m100 != 11 { return f[0] }
            if (2...4).contains(m10) && !(12...14).contains(m100) { return f[1] }
            return f[2]
        }
        return a == 1 ? f[0] : f[1]
    }
}

/// Перевод строки интерфейса. Ключ — английский текст; `{0}`, `{1}`… — подстановки.
///     L("Expires in {0} days", 3)
func L(_ key: String, _ args: Any...) -> String {
    var s = L10n.raw(key)
    for (i, a) in args.enumerated() {
        s = s.replacingOccurrences(of: "{\(i)}", with: "\(a)")
    }
    return s
}

/// Метка «это ключ перевода» для строк, которые хранятся в данных/массивах и переводятся при показе через L(x).
/// Сама ничего не делает; tool/check_strings.py по ней находит ключи, которым нужен перевод.
func LK(_ key: String) -> String { key }

/// Слово с числом в правильной форме: Lp(3, "product|products") → «3 продукта» / «3 өнім».
/// Ключ — английские формы «one|other»; в strings.json ru — «one|few|many», kk — одна форма.
func Lp(_ n: Int, _ forms: String, withNumber: Bool = true) -> String {
    let word = L10n.plural(n, L10n.raw(forms))
    return withNumber ? "\(n) \(word)" : word
}

/// Название продукта или рецепта на языке приложения (в данных всегда хранится английское).
func N(_ englishName: String) -> String {
    let lang = AppLang.current
    guard lang != .en else { return englishName }
    let db = FoodDB.shared
    if let f = db.byName[englishName] {
        let t = lang == .ru ? f.ru : f.kk
        if let t, !t.isEmpty { return t }
        return englishName
    }
    if let r = db.recipeByName[englishName] {
        let t = lang == .ru ? r.ru : r.kk
        if let t, !t.isEmpty { return t }
        return englishName
    }
    // Категории, места хранения и пр. — из общей таблицы
    return L10n.raw(englishName, lang)
}
