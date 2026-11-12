import SwiftUI
import QuartzCore

/// Нутрик — маскот NutriMate: чиби-кошечка на коротких ножках, чёрное каре с ушками,
/// бежевая рубашка-оверсайз с красным бантом, хвост и листик-заколка. Немного неряшливая:
/// торчащая прядка, крошка на рубашке, бант чуть набок. Рисуется целиком в Canvas.
/// Настроения: бег, падение (звёздочки), еда с продуктом в лапке, разговор, радость.
enum NutrikMood: Equatable { case happy, sad, eating, wave, sleepy, run, fall, talk, cheer }

struct NutrikView: View {
    var mood: NutrikMood = .happy
    var size: CGFloat = 120
    /// Эмодзи продукта в лапке (для .eating)
    var food: String? = nil
    /// Нутрик неуклюжий: по нажатию иногда спотыкается и падает.
    var clumsy = true
    @State private var hop = false
    @State private var tripping = false
    /// Анимируем только видимого Нутрика (на скрытых вкладках/листах таймер стоит).
    @State private var visible = false
    @Environment(\.scenePhase) private var scenePhase
    /// Экран прокручивается — Нутрик замирает на это время (анимация Canvas во время прокрутки
    /// стоила Home ~40 кадров/с в симуляторе). Отпустил палец — снова двигается.
    @Environment(\.nutrikPaused) private var scrollPaused

    var body: some View {
        let shown: NutrikMood = tripping ? .fall : mood
        // Спокойные настроения — 30 кадров (мультяшно и дёшево), бег/падение/радость/еда — 60.
        // Canvas рисуется асинхронно, вне главного потока: прокрутка экрана не ждёт Нутрика.
        let fast = ([.run, .fall, .cheer, .eating] as [NutrikMood]).contains(shown)
        TimelineView(.animation(minimumInterval: fast ? 1.0 / 60.0 : 1.0 / 30.0, paused: !visible || scrollPaused || scenePhase != .active || UIShot.perfOff.contains("nutrik"))) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas(rendersAsynchronously: !UIShot.perfOff.contains("sync")) { ctx, sz in
                NutrikPainter(t: t, mood: shown, food: food).draw(&ctx, sz)
            } symbols: {
                // эмодзи рендерятся один раз и дальше рисуются как готовые картинки (раньше — текст каждый кадр)
                Text(food ?? "🍎").font(.system(size: 48)).tag(NutrikPainter.foodSymbol)
                Text("⭐️").font(.system(size: 32)).tag(NutrikPainter.starSymbol)
                Text("✨").font(.system(size: 32)).tag(NutrikPainter.sparkSymbol)
            }
            .frame(width: size, height: size * 1.15)
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .rotationEffect(.degrees(tripping ? -78 : 0), anchor: .bottomLeading)
        .offset(y: tripping ? size * 0.08 : 0)
        .scaleEffect(x: hop ? 1.08 : 1, y: hop ? 0.9 : 1, anchor: .bottom)
        .onTapGesture { tap() }
        .accessibilityLabel("Nutrik the mascot")
    }

    private func tap() {
        guard !tripping else { return }
        if clumsy && Int.random(in: 0..<4) == 0 {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { tripping = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { tripping = false }
            }
            return
        }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.18, dampingFraction: 0.4)) { hop = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.35)) { hop = false }
        }
    }
}

struct NutrikPainter {
    static let foodSymbol = 0, starSymbol = 1, sparkSymbol = 2
    let t: Double
    let mood: NutrikMood
    var food: String? = nil

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
        let bob: Double
        switch mood {
        case .sleepy: bob = sin(t * 1.2) * 0.8
        case .run: bob = abs(sin(t * 9)) * -3.5
        case .cheer: bob = abs(sin(t * 5)) * -6
        case .fall: bob = 0
        default: bob = abs(sin(t * 2.6)) * -2.2
        }
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + (y + bob) * s) }
        func pf(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) } // без подпрыгивания
        func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
            CGRect(x: ox + x * s, y: oy + (y + bob) * s, width: w * s, height: h * s)
        }

        // Тень
        let shadowW = 44 - bob * 2
        ctx.fill(Path(ellipseIn: CGRect(x: ox + (50 - shadowW / 2) * s, y: oy + 108 * s, width: shadowW * s, height: 6 * s)),
                 with: .color(Color.black.opacity(0.10)))

        // Пыль из-под ножек при беге
        if mood == .run {
            for k in 0..<3 {
                let ph = (t * 2.2 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let d = 4 + ph * 7
                ctx.fill(Path(ellipseIn: CGRect(x: ox + (30 - ph * 22 - d / 2) * s, y: oy + (104 - ph * 6 - d / 2) * s, width: d * s, height: d * s)),
                         with: .color(Color(hex: 0xC9B48F).opacity(0.45 * (1 - ph))))
            }
        }

        // Хвост (виляет)
        let wag = sin(t * (mood == .run ? 9 : 3.2)) * 6
        var tail = Path()
        tail.move(to: p(66, 92))
        tail.addCurve(to: p(86 + wag, 70), control1: p(82, 96), control2: p(90, 84))
        ctx.stroke(tail, with: .color(hair), style: StrokeStyle(lineWidth: 4.5 * s, lineCap: .round))

        // Ножки — короткие, переступают
        let running = mood == .run
        let step = (mood == .sleepy || mood == .fall) ? 0 : sin(t * (running ? 18 : 5.2)) * (running ? 4 : 1.3)
        for (x, ph) in [(40.0, step), (54.0, -step)] {
            let dx = running ? ph : 0
            let lift = running ? max(0, ph) * 0.9 : 0
            ctx.fill(Path(roundedRect: CGRect(x: ox + (x + dx) * s, y: oy + (98 + ph * 0.5 + bob * 0.4 - lift) * s, width: 7 * s, height: 10 * s), cornerRadius: 3 * s), with: .color(skin))
            ctx.fill(Path(ellipseIn: CGRect(x: ox + (x - 1.5 + dx) * s, y: oy + (105 + ph * 0.5 - lift) * s, width: 10 * s, height: 5 * s)), with: .color(Color(hex: 0x6A041C)))
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

        // Ручки: wave — машет, run — размахивает, cheer — обе вверх, eating — подносит еду ко рту
        let sway = sin(t * 2.6) * 3
        var handL = p(27, 87 + sway * 0.2), ctrlL = p(28, 76)
        var handR = p(73, 86 + sway * 0.2), ctrlR = p(72, 76)
        let bite = (sin(t * 4) + 1) / 2 // 0 — лапка внизу, 1 — у рта
        switch mood {
        case .wave:
            let w = sin(t * 9) * 14
            handR = p(80 + w * 0.3, 52 - abs(w) * 0.2); ctrlR = p(76, 66)
        case .run:
            let sw = sin(t * 18) * 7
            handL = p(28 + sw, 84 - abs(sw) * 0.3); handR = p(72 - sw, 84 - abs(sw) * 0.3)
        case .cheer:
            let w = sin(t * 10) * 5
            handL = p(20 - w * 0.4, 50 + w * 0.3); ctrlL = p(24, 64)
            handR = p(80 + w * 0.4, 50 - w * 0.3); ctrlR = p(76, 64)
        case .fall:
            handL = p(22, 78); ctrlL = p(26, 70)
            handR = p(78, 78); ctrlR = p(74, 70)
        case .eating where food != nil:
            handR = p(73 - 17 * bite, 86 - 30 * bite); ctrlR = p(70, 72 - 6 * bite)
        default: break
        }
        for (start, ctrl, hand) in [(p(36, 70), ctrlL, handL), (p(64, 70), ctrlR, handR)] {
            var arm = Path()
            arm.move(to: start); arm.addQuadCurve(to: hand, control: ctrl)
            ctx.stroke(arm, with: .color(shirt), style: StrokeStyle(lineWidth: 7 * s, lineCap: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: hand.x - 3 * s, y: hand.y - 3 * s, width: 6 * s, height: 6 * s)), with: .color(skin))
        }

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
        let look = mood == .run ? 1.8 : sin(t * 0.7) * 1.2
        for x in [39.0, 61.0] {
            let eh = 9 * blink
            if mood == .fall {
                // глазки-крестики после падения
                var xx = Path()
                xx.move(to: p(x - 3, 41)); xx.addLine(to: p(x + 3, 47))
                xx.move(to: p(x + 3, 41)); xx.addLine(to: p(x - 3, 47))
                head.stroke(xx, with: .color(hair), style: StrokeStyle(lineWidth: 1.8 * s, lineCap: .round))
            } else if mood == .cheer || (mood == .happy && blink > 0.5 && cycle > 1.8 && cycle < 2.6) {
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
        head.fill(Path(ellipseIn: r(29, 50, 8, 4.5)), with: .color(blush.opacity(mood == .cheer ? 0.95 : 0.7)))
        head.fill(Path(ellipseIn: r(63, 50, 8, 4.5)), with: .color(blush.opacity(mood == .cheer ? 0.95 : 0.7)))
        // Рот
        let mouthColor = Color(hex: 0x8B2635)
        var mouth = Path()
        switch mood {
        case .sad:
            mouth.move(to: p(46, 56)); mouth.addQuadCurve(to: p(54, 56), control: p(50, 52.5))
            head.stroke(mouth, with: .color(hair), style: StrokeStyle(lineWidth: 1.4 * s, lineCap: .round))
        case .eating:
            let open = food != nil ? 1 + bite * 4 : 1.5 + abs(sin(t * 10)) * 3
            head.fill(Path(ellipseIn: r(47, 53, 6, open)), with: .color(mouthColor))
        case .talk:
            let open = 0.8 + abs(sin(t * 11)) * abs(sin(t * 3.1)) * 4
            head.fill(Path(ellipseIn: r(46.8, 53, 6.4, open)), with: .color(mouthColor))
        case .run:
            head.fill(Path(ellipseIn: r(47.5, 53.5, 5, 2.5 + abs(sin(t * 9)))), with: .color(mouthColor))
        case .fall:
            head.stroke(Path(ellipseIn: r(48, 53, 4, 4)), with: .color(hair), lineWidth: 1.3 * s)
        case .cheer:
            var d = Path()
            d.move(to: p(45, 53)); d.addLine(to: p(55, 53))
            d.addQuadCurve(to: p(45, 53), control: p(50, 61))
            head.fill(d, with: .color(mouthColor))
        case .sleepy:
            head.fill(Path(ellipseIn: r(48.5, 54, 3, 2.4)), with: .color(mouthColor))
        default:
            mouth.move(to: p(46, 53.5)); mouth.addQuadCurve(to: p(50, 55.5), control: p(48, 56))
            mouth.addQuadCurve(to: p(54, 53.5), control: p(52, 56))
            head.stroke(mouth, with: .color(hair), style: StrokeStyle(lineWidth: 1.3 * s, lineCap: .round))
        }

        // Капелька пота при беге
        if mood == .run {
            let dy = (t * 1.5).truncatingRemainder(dividingBy: 1) * 6
            var drop = Path()
            drop.move(to: p(76, 28 + dy))
            drop.addQuadCurve(to: p(76, 35 + dy), control: p(72, 33 + dy))
            drop.addQuadCurve(to: p(76, 28 + dy), control: p(80, 33 + dy))
            ctx.fill(drop, with: .color(Color(hex: 0x8FD3F4).opacity(0.9)))
        }
        // Звёздочки над головой после падения
        if mood == .fall {
            for k in 0..<3 {
                let a = t * 3 + Double(k) * 2.094
                let c = p(50 + cos(a) * 22, 12 + sin(a) * 5)
                emoji(&ctx, Self.starSymbol, at: c, size: 7 * s)
            }
        }
        // Искорки радости
        if mood == .cheer {
            for k in 0..<4 {
                let ph = (t * 0.9 + Double(k) / 4).truncatingRemainder(dividingBy: 1)
                let x = [14.0, 86.0, 22.0, 80.0][k]
                emoji(&ctx, Self.sparkSymbol, at: pf(x, 40 - ph * 30), size: (5 + ph * 4) * s)
            }
        }
        // Еда в лапке
        if mood == .eating, let food {
            _ = food
            emoji(&ctx, Self.foodSymbol, at: CGPoint(x: handR.x, y: handR.y - 4 * s), size: 13 * s)
            if bite > 0.92 {
                ctx.fill(Path(ellipseIn: r(44, 60, 1.6, 1.4)), with: .color(Color(hex: 0xB07A3A)))
                ctx.fill(Path(ellipseIn: r(57, 62, 1.3, 1.2)), with: .color(Color(hex: 0xB07A3A)))
            }
        }
        _ = pf(0, 0)
    }

    /// Готовый символ-эмодзи (из `symbols:` у Canvas) по центру точки, высотой ≈ размер шрифта.
    private func emoji(_ ctx: inout GraphicsContext, _ id: Int, at c: CGPoint, size: CGFloat) {
        guard let sym = ctx.resolveSymbol(id: id), sym.size.height > 0 else { return }
        let k = size * 1.2 / sym.size.height
        let w = sym.size.width * k, h = sym.size.height * k
        ctx.draw(sym, in: CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h))
    }
}

/// Нутрик с облачком реплики. Когда реплика меняется, Нутрик «говорит» (рот двигается).
struct NutrikSays: View {
    let text: String
    var mood: NutrikMood = .happy
    var size: CGFloat = 86
    var food: String? = nil
    /// Нажатие на облачко (например, следующий совет)
    var onTap: (() -> Void)? = nil
    @State private var talking = false
    @State private var talkToken = 0

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            NutrikView(mood: talking ? .talk : mood, size: size, food: food)
            Text(text)
                .font(.callout)
                .foregroundStyle(Color.burgundy)
                .padding(12)
                .background(Color.white.opacity(0.8), in: BubbleShape())
                .overlay(BubbleShape().stroke(Color.white.opacity(0.9), lineWidth: 1))
                .id(text)
                .transition(.asymmetric(insertion: .scale(scale: 0.85, anchor: .leading).combined(with: .opacity), removal: .opacity))
                .onTapGesture { onTap?() }
            Spacer(minLength: 0)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.7), value: text)
        .onAppear { talk() }
        .onChange(of: text) { talk() }
    }

    private func talk() {
        talkToken += 1
        let token = talkToken
        talking = true
        let secs = min(3.0, 0.6 + Double(text.count) * 0.035)
        DispatchQueue.main.asyncAfter(deadline: .now() + secs) {
            if token == talkToken { talking = false }
        }
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

// MARK: - Пауза Нутрика во время прокрутки

private struct NutrikPausedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var nutrikPaused: Bool {
        get { self[NutrikPausedKey.self] }
        set { self[NutrikPausedKey.self] = newValue }
    }
}

/// Пока ScrollView двигается (пальцем или программно), Нутрики внутри не перерисовываются.
private final class ScrollClock { var last: CFTimeInterval = 0 }

private struct PauseNutrikWhileScrolling: ViewModifier {
    @State private var scrolling = false
    @State private var clock = ScrollClock()

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !UIShot.perfOff.contains("nopause") {
            content
                .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }) { _, _ in moved() }
                .environment(\.nutrikPaused, scrolling)
        } else {
            content
        }
    }

    private func moved() {
        clock.last = CACurrentMediaTime()
        guard !scrolling else { return }
        scrolling = true
        watch()
    }

    /// Проверяем 5 раз в секунду: 0.25 с без движения — прокрутка закончилась.
    private func watch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if CACurrentMediaTime() - clock.last > 0.25 { scrolling = false } else { watch() }
        }
    }
}

extension View {
    /// Ставится на ScrollView, внутри которого есть Нутрик.
    func pausesNutrikWhileScrolling() -> some View { modifier(PauseNutrikWhileScrolling()) }
}
