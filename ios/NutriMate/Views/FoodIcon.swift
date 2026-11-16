import SwiftUI
import UIKit

/// Собственные иконки продуктов (правило «одна иконка = один продукт»).
/// Рисунки — assets/icons/<slug>.svg в репозитории, заранее отрисованные в PNG 180 px
/// (Assets.xcassets/FoodIcons/fi_<slug>, tool/build_svg_icons.py); какой продукт какую иконку получает —
/// поле "icon" в foods.json. Нет своей иконки — показываем системный эмодзи.
enum FoodIconStore {
    private static var cache: [String: UIImage] = [:]
    private static var missing: Set<String> = []
    private static let lock = NSLock()

    /// Картинка по slug; UIImage(named:) вызывается один раз на slug, дальше — из кэша.
    static func image(_ slug: String?) -> UIImage? {
        guard let slug, !slug.isEmpty else { return nil }
        lock.lock(); defer { lock.unlock() }
        if let img = cache[slug] { return img }
        if missing.contains(slug) { return nil }
        if let img = UIImage(named: "fi_" + slug) {
            cache[slug] = img
            return img
        }
        missing.insert(slug)
        return nil
    }

    /// Slug иконки продукта по его (английскому) названию.
    static func slug(for name: String?) -> String? {
        guard let name else { return nil }
        return FoodDB.shared.byName[name]?.icon
    }
}

/// Иконка продукта: своя нарисованная картинка, если есть, иначе эмодзи.
struct FoodIcon: View {
    let emoji: String
    var name: String? = nil
    var size: CGFloat = 28

    init(emoji: String, name: String? = nil, size: CGFloat = 28) {
        self.emoji = emoji
        self.name = name
        self.size = size
    }

    init(food: Food, size: CGFloat = 28) {
        self.init(emoji: food.emoji, name: food.name, size: size)
    }

    var body: some View {
        if let img = FoodIconStore.image(FoodIconStore.slug(for: name)) {
            Image(uiImage: img)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Text(emoji)
                .font(.system(size: size * 0.82))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

/// Иконка + название в одну строку (списки покупок, подсказки, ингредиенты).
struct FoodLabel: View {
    let emoji: String
    let name: String
    var size: CGFloat = 22
    var body: some View {
        HStack(spacing: 6) {
            FoodIcon(emoji: emoji, name: name, size: size)
            Text(N(name))
        }
    }
}
