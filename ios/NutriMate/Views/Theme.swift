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

/// Стеклянная карточка. Раньше — .ultraThinMaterial + тень на всём содержимом: материал пересчитывает
/// размытие фона под каждой карточкой каждый кадр (а фон живой), из-за этого был ~20 fps.
/// Теперь — полупрозрачная кремово-белая заливка с бликом-обводкой и тенью только у формы:
/// визуально то же «стекло» на мягком фоне, но GPU почти ничего не стоит.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 22
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape
                    .fill(LinearGradient(colors: [Color.white.opacity(0.72), Color(hex: 0xFBF8F1, opacity: 0.58)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: Color.burgundy.opacity(UIShot.perfOff.contains("shadow") ? 0 : 0.07), radius: 10, x: 0, y: 5)
            }
            .overlay(
                shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
    }
}

/// Дешёвая «стеклянная» заливка для строк списков и чипов (вместо Material).
extension Color {
    static let glassFill = Color.white.opacity(0.62)
}

extension View {
    func glassCard(radius: CGFloat = 22, padding: CGFloat = 16) -> some View {
        modifier(GlassCard(radius: radius, padding: padding))
    }
}

/// Живой фон: медленно плывущие мягкие пятна в фирменных тонах.
/// Пятна — радиальные градиенты (уже «размытые», без blur-фильтра), рисуются один раз;
/// движение — offset/scale через repeatForever-анимацию, её выполняет Core Animation на GPU
/// без пересчёта body. Раньше тут был Canvas + blur(50) на весь экран 20 раз в секунду.
struct LiveBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    private struct Blob {
        let color: Color, x: CGFloat, y: CGFloat, size: CGFloat, dx: CGFloat, dy: CGFloat, scale: CGFloat, duration: Double
    }
    private static let blobs: [Blob] = [
        Blob(color: Color.burgundy.opacity(0.11), x: 0.20, y: 0.15, size: 0.95, dx: 0.10, dy: 0.06, scale: 1.10, duration: 9),
        Blob(color: Color.sand, x: 0.85, y: 0.30, size: 1.05, dx: -0.09, dy: 0.07, scale: 0.92, duration: 13),
        Blob(color: Color(hex: 0xE9B8A8).opacity(0.38), x: 0.30, y: 0.75, size: 1.00, dx: 0.09, dy: -0.06, scale: 1.08, duration: 11),
        Blob(color: Color(hex: 0xC9D8B6).opacity(0.42), x: 0.80, y: 0.85, size: 0.90, dx: -0.08, dy: -0.05, scale: 1.12, duration: 15),
    ]

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Color.cream
                ForEach(0..<Self.blobs.count, id: \.self) { i in
                    let b = Self.blobs[i]
                    let d = w * b.size
                    Circle()
                        .fill(RadialGradient(colors: [b.color, b.color.opacity(0)], center: .center, startRadius: 0, endRadius: d / 2))
                        .frame(width: d, height: d)
                        .scaleEffect(drift ? b.scale : 1)
                        .position(x: w * b.x, y: h * b.y)
                        .offset(x: drift ? w * b.dx : 0, y: drift ? h * b.dy : 0)
                        .animation(reduceMotion ? nil : .easeInOut(duration: b.duration).repeatForever(autoreverses: true), value: drift)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear { if !reduceMotion && !UIShot.perfOff.contains("bg") { drift = true } }
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
                Capsule().fill(selected ? Color.burgundy : Color.glassFill)
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
