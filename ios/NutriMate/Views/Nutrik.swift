import SwiftUI

/// Нутрик — маскот NutriMate: чиби-кошечка на коротких ножках, чёрное каре с ушками,
/// бежевая рубашка-оверсайз с красным бантом, хвост и листик-заколка. Немного неряшливая:
/// торчащая прядка, крошка на рубашке, бант чуть набок. Рисуется целиком в Canvas.
enum NutrikMood { case happy, sad, eating, wave, sleepy }

struct NutrikView: View {
    var mood: NutrikMood = .happy
    var size: CGFloat = 120
    @State private var hop = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, sz in
                NutrikPainter(t: t, mood: mood).draw(&ctx, sz)
            }
            .frame(width: size, height: size * 1.15)
        }
        .scaleEffect(x: hop ? 1.08 : 1, y: hop ? 0.9 : 1, anchor: .bottom)
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { hop = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.35)) { hop = false }
            }
        }
        .accessibilityLabel("Nutrik the mascot")
    }
}

struct NutrikPainter {
    let t: Double
    let mood: NutrikMood

    private let hair = Color(hex: 0x1E1A1D)
    private let skin = Color(hex: 0xFFE6D3)
    private let shirt = Color(hex: 0xE9D7B9)
    private let shirtDark = Color(hex: 0xC9B48F)
    private let bow = Color(hex: 0xC8102E)
    private let leaf = Color(hex: 0x5DA34A)
    private let blush = Color(hex: 0xF4A3A8)

    func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        // Логические координаты 100 × 115
        let s = min(size.width / 100, size.height / 115)
        let ox = (size.width - 100 * s) / 2
        let oy = (size.height - 115 * s) / 2
        let bob = mood == .sleepy ? sin(t * 1.2) * 0.8 : abs(sin(t * 2.6)) * -2.2
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + (y + bob) * s) }
        func pf(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) } // без подпрыгивания
        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            CGRect(x: ox + x * s, y: oy + (y + bob) * s, width: w * s, height: h * s)
        }

        // Тень
        let shadowW = 44 - bob * 2
        ctx.fill(Path(ellipseIn: CGRect(x: ox + (50 - shadowW / 2) * s, y: oy + 108 * s, width: shadowW * s, height: 6 * s)),
                 with: .color(Color.black.opacity(0.10)))

        // Хвост (виляет)
        let wag = sin(t * 3.2) * 6
        var tail = Path()
        tail.move(to: p(66, 92))
        tail.addCurve(to: p(86 + wag, 70), control1: p(82, 96), control2: p(90, 84))
        ctx.stroke(tail, with: .color(hair), style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round))

        // Ножки — короткие, переступают
        let step = mood == .sleepy ? 0 : sin(t * 5.2) * 1.3
        for (x, ph) in [(40.0, step), (54.0, -step)] {
            ctx.fill(Path(roundedRect: CGRect(x: ox + x * s, y: oy + (98 + ph * 0.5 + bob * 0.4) * s, width: 7 * s, height: 10 * s), cornerRadius: 3 * s), with: .color(skin))
            ctx.fill(Path(ellipseIn: CGRect(x: ox + (x - 1.5) * s, y: oy + (105 + ph * 0.5) * s, width: 10 * s, height: 5 * s)), with: .color(Color(hex: 0x6A041C)))
        }

        // Рубашка-оверсайз (трапеция со скруглением), чуть мятая
        var body = Path()
        body.move(to: p(36, 64))
        body.addQuadCurve(to: p(64, 64), control: p(50, 60))
        body.addQuadCurve(to: p(72, 100), control: p(71, 80))
        body.addQuadCurve(to: p(28, 100), control: p(50, 104))
        body.addQuadCurve(to: p(36, 64), control: p(29, 80))
        ctx.fill(body, with: .linearGradient(Gradient(colors: [shirt, shirtDark]), startPoint: p(50, 62), endPoint: p(50, 102)))
        ctx.stroke(body, with: .color(shirtDark.opacity(0.9)), lineWidth: 0.8 * s)
        // складки и пуговицы
        var fold = Path()
        fold.move(to: p(44, 80)); fold.addQuadCurve(to: p(42, 96), control: p(41, 88))
        fold.move(to: p(58, 82)); fold.addQuadCurve(to: p(60, 95), control: p(61, 88))
        ctx.stroke(fold, with: .color(shirtDark), lineWidth: 0.7 * s)
        for y in [76.0, 84.0, 92.0] {
            ctx.fill(Path(ellipseIn: r(49.2, y, 1.8, 1.8)), with: .color(shirtDark))
        }
        // крошка на рубашке (неряшливость)
        ctx.fill(Path(ellipseIn: r(55, 88, 1.6, 1.3)), with: .color(Color(hex: 0xB07A3A)))

        // Ручки: в режиме wave одна машет
        let waveA = mood == .wave ? sin(t * 9) * 14 : sin(t * 2.6) * 3
        var armL = Path()
        armL.move(to: p(36, 70)); armL.addQuadCurve(to: p(27, 86), control: p(28, 76))
        ctx.stroke(armL, with: .color(shirt), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
        ctx.fill(Path(ellipseIn: r(23.5, 84, 6, 6)), with: .color(skin))
        var armR = Path()
        let hand = mood == .wave ? p(80 + waveA * 0.3, 52 - abs(waveA) * 0.2) : p(73, 86 + waveA * 0.2)
        armR.move(to: p(64, 70)); armR.addQuadCurve(to: hand, control: mood == .wave ? p(76, 66) : p(72, 76))
        ctx.stroke(armR, with: .color(shirt), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: hand.x - 3 * s, y: hand.y - 3 * s, width: 6 * s, height: 6 * s)), with: .color(skin))

        // Бант (чуть набок)
        var bowPath = Path()
        bowPath.move(to: p(50, 66))
        bowPath.addLine(to: p(42, 61)); bowPath.addLine(to: p(42.5, 70)); bowPath.closeSubpath()
        bowPath.move(to: p(50, 66))
        bowPath.addLine(to: p(58.5, 62.5)); bowPath.addLine(to: p(57, 71)); bowPath.closeSubpath()
        ctx.fill(bowPath, with: .color(bow))
        ctx.fill(Path(ellipseIn: r(47.8, 63.8, 4.6, 4.6)), with: .color(Color(hex: 0x9E0B24)))

        // Голова
        let tilt = sin(t * 1.4) * 2.5
        var head = ctx
        head.translateBy(x: p(50, 40).x, y: p(50, 40).y)
        head.rotate(by: .degrees(tilt))
        head.translateBy(x: -p(50, 40).x, y: -p(50, 40).y)

        // Ушки (кончики чуть подрагивают)
        let twitch = sin(t * 4) * 0.8
        let ears: [[(Double, Double)]] = [
            [(23, 30), (29, 5 + twitch), (43, 19)],
            [(77, 30), (71, 5 - twitch), (57, 19)],
        ]
        let inners: [[(Double, Double)]] = [
            [(27.5, 25), (30, 11), (38, 20)],
            [(72.5, 25), (70, 11), (62, 20)],
        ]
        for (outer, inner) in zip(ears, inners) {
            var ear = Path()
            ear.move(to: p(outer[0].0, outer[0].1))
            ear.addLine(to: p(outer[1].0, outer[1].1))
            ear.addLine(to: p(outer[2].0, outer[2].1))
            ear.closeSubpath()
            head.fill(ear, with: .color(hair))
            var inn = Path()
            inn.move(to: p(inner[0].0, inner[0].1))
            inn.addLine(to: p(inner[1].0, inner[1].1))
            inn.addLine(to: p(inner[2].0, inner[2].1))
            inn.closeSubpath()
            head.fill(inn, with: .color(blush.opacity(0.9)))
        }

        // Затылок / каре
        head.fill(Path(roundedRect: r(22, 16, 56, 50), cornerRadius: 22 * s), with: .color(hair))
        // Лицо
        head.fill(Path(ellipseIn: r(27, 22, 46, 42)), with: .color(skin))
        // Чёлка
        var bangs = Path()
        bangs.move(to: p(25, 36))
        bangs.addQuadCurve(to: p(50, 16), control: p(26, 15))
        bangs.addQuadCurve(to: p(75, 36), control: p(74, 15))
        bangs.addLine(to: p(70, 31)); bangs.addLine(to: p(65, 35)); bangs.addLine(to: p(59, 29))
        bangs.addLine(to: p(52, 34)); bangs.addLine(to: p(45, 28)); bangs.addLine(to: p(38, 34))
        bangs.addLine(to: p(32, 29)); bangs.closeSubpath()
        head.fill(bangs, with: .color(hair))
        // Пряди каре по бокам
        head.fill(Path(roundedRect: r(22, 30, 9, 32), cornerRadius: 4.5 * s), with: .color(hair))
        head.fill(Path(roundedRect: r(69, 30, 9, 32), cornerRadius: 4.5 * s), with: .color(hair))
        // Торчащая прядка (неряшливость)
        var strand = Path()
        strand.move(to: p(52, 17)); strand.addQuadCurve(to: p(60, 8 + sin(t * 3) * 1.2), control: p(52, 9))
        head.stroke(strand, with: .color(hair), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
        // Листик-заколка
        var leafPath = Path()
        leafPath.move(to: p(64, 24))
        leafPath.addQuadCurve(to: p(76, 16), control: p(66, 14))
        leafPath.addQuadCurve(to: p(64, 24), control: p(75, 26))
        head.fill(leafPath, with: .color(leaf))
        var vein = Path()
        vein.move(to: p(65, 23)); vein.addLine(to: p(74, 17.5))
        head.stroke(vein, with: .color(Color.white.opacity(0.6)), lineWidth: 0.6 * s)

        // Глаза (моргают)
        let cycle = t.truncatingRemainder(dividingBy: 3.6)
        let blink: Double = mood == .sleepy ? 0.12 : (cycle < 0.14 ? 0.1 : 1)
        let look = sin(t * 0.7) * 1.2
        for x in [39.0, 61.0] {
            let eh = 9 * blink
            if mood == .happy && blink > 0.5 && cycle > 1.8 && cycle < 2.6 {
                // счастливые глазки-дуги
                var arc = Path()
                arc.move(to: p(x - 4, 44)); arc.addQuadCurve(to: p(x + 4, 44), control: p(x, 38))
                head.stroke(arc, with: .color(hair), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
            } else {
                head.fill(Path(ellipseIn: r(x - 3.6 + look, 44 - eh / 2, 7.2, max(0.8, eh))), with: .color(hair))
                if blink > 0.5 {
                    head.fill(Path(ellipseIn: r(x - 1.8 + look, 41, 2.6, 2.6)), with: .color(.white))
                    head.fill(Path(ellipseIn: r(x + 0.8 + look, 45.5, 1.2, 1.2)), with: .color(.white.opacity(0.8)))
                }
            }
        }
        // Румянец
        head.fill(Path(ellipseIn: r(29, 50, 8, 4.5)), with: .color(blush.opacity(0.7)))
        head.fill(Path(ellipseIn: r(63, 50, 8, 4.5)), with: .color(blush.opacity(0.7)))
        // Рот
        var mouth = Path()
        switch mood {
        case .sad:
            mouth.move(to: p(46, 56)); mouth.addQuadCurve(to: p(54, 56), control: p(50, 52.5))
            head.stroke(mouth, with: .color(hair), style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
        case .eating:
            let open = 1.5 + abs(sin(t * 10)) * 3
            head.fill(Path(ellipseIn: r(47, 53, 6, open)), with: .color(Color(hex: 0x8B2635)))
        case .sleepy:
            head.fill(Path(ellipseIn: r(48.5, 54, 3, 2.4)), with: .color(Color(hex: 0x8B2635)))
        default:
            mouth.move(to: p(46, 53.5)); mouth.addQuadCurve(to: p(50, 55.5), control: p(48, 56))
            mouth.addQuadCurve(to: p(54, 53.5), control: p(52, 56))
            head.stroke(mouth, with: .color(hair), style: StrokeStyle(lineWidth: 1.3 * s, lineCap: .round))
        }
        _ = pf(0, 0)
    }
}

/// Нутрик с облачком реплики.
struct NutrikSays: View {
    let text: String
    var mood: NutrikMood = .happy
    var size: CGFloat = 86

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NutrikView(mood: mood, size: size)
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.burgundy)
                .padding(12)
                .background(.regularMaterial, in: BubbleShape())
                .overlay(BubbleShape().stroke(Color.white.opacity(0.9), lineWidth: 1))
                .id(text)
                .transition(.asymmetric(insertion: .scale(scale: 0.85, anchor: .leading).combined(with: .opacity), removal: .opacity))
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: text)
    }
}

/// Облачко с хвостиком слева.
struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: 16, style: .continuous)
        p.move(to: CGPoint(x: rect.minX + 1, y: rect.midY - 6))
        p.addLine(to: CGPoint(x: rect.minX - 8, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + 1, y: rect.midY + 6))
        p.closeSubpath()
        return p
    }
}
