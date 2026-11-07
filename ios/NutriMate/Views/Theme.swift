import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
    // Фирменные цвета NutriMate — не менять
    static let burgundy = Color(hex: 0x6A041C)
    static let burgundyLight = Color(hex: 0x8E1230)
    static let cream = Color(hex: 0xF5F1E5)
    static let sand = Color(hex: 0xEAE2CF)
    static let freshGreen = Color(hex: 0x2E7D32)
    static let warnOrange = Color(hex: 0xE65100)
    static let badRed = Color(hex: 0xC62828)

    static func freshness(_ daysLeft: Int) -> Color {
        daysLeft < 0 ? .badRed : daysLeft <= 2 ? .warnOrange : .freshGreen
    }
}

/// Стеклянная карточка: материал + светлая обводка-блик + мягкая тень.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.85), .white.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.burgundy.opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

extension View {
    func glassCard(radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius, padding: padding))
    }
}

/// Живой фон: медленно плывущие размытые пятна в фирменных тонах.
struct LiveBackground: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.cream))
                ctx.addFilter(.blur(radius: 50))
                let blobs: [(Color, Double, Double, Double, Double)] = [
                    (Color.burgundy.opacity(0.10), 0.20, 0.15, 0.55, 0.11),
                    (Color.sand.opacity(0.95), 0.85, 0.30, 0.65, 0.07),
                    (Color(hex: 0xE9B8A8).opacity(0.30), 0.30, 0.75, 0.60, 0.09),
                    (Color(hex: 0xC9D8B6).opacity(0.35), 0.80, 0.85, 0.50, 0.05),
                ]
                for (i, b) in blobs.enumerated() {
                    let ph = t * b.4 + Double(i) * 1.7
                    let cx = size.width * (b.1 + 0.08 * sin(ph))
                    let cy = size.height * (b.2 + 0.06 * cos(ph * 1.3))
                    let r = size.width * b.3 * (1 + 0.06 * sin(ph * 2))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - r / 2, y: cy - r / 2, width: r, height: r)), with: .color(b.0))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Полоска свежести продукта.
struct FreshBar: View {
    let fresh: Double
    let color: Color
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.burgundy.opacity(0.08))
                Capsule().fill(LinearGradient(colors: [color.opacity(0.75), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(6, g.size.width * fresh))
            }
        }
        .frame(height: 6)
    }
}

/// Кружок с эмодзи продукта.
struct EmojiBadge: View {
    let emoji: String
    var size: CGFloat = 44
    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.58))
            .frame(width: size, height: size)
            .background(Circle().fill(Color.white.opacity(0.65)))
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
    }
}

struct Chip: View {
    let text: String
    var selected = false
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(selected ? Color.cream : Color.burgundy)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(Color.burgundy) : AnyShapeStyle(Material.ultraThinMaterial))
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(selected ? 0.25 : 0.8), lineWidth: 1))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.cream)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: Color.burgundy.opacity(0.3), radius: 10, y: 5)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.burgundy)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Capsule().fill(Color.burgundy.opacity(0.09)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.title3.weight(.bold)).foregroundStyle(Color.burgundy)
    }
}
