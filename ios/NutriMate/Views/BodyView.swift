import SwiftUI

// MARK: - Цвета зон

extension BMICategory {
    var color: Color {
        switch self {
        case .under: return Color(hex: 0x7CC4FF)
        case .normal: return Color(hex: 0x3CCB6C)
        case .over: return Color(hex: 0xFFB020)
        case .obese: return Color(hex: 0xFF4D4D)
        }
    }
}

/// Зона шкалы: от и до (в единицах шкалы) и цвет.
struct GaugeZone: Identifiable {
    let from: Double
    let to: Double
    let color: Color
    var id: Double { from }
}

// MARK: - Приборная стрелка

/// Стрелка прибора. `f` — положение 0…1, анимируется (пружина = как у настоящей стрелки в машине).
struct NeedleShape: Shape {
    var f: Double
    var animatableData: Double {
        get { f }
        set { f = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let g = GaugeGeometry(rect.size)
        let a = Double.pi * (1 - min(1.04, max(-0.04, f)))
        let tip = g.point(a, g.radius - 14)
        let back = g.point(a + .pi, 14)
        let l = g.point(a + .pi / 2, 5)
        let r = g.point(a - .pi / 2, 5)
        var p = Path()
        p.move(to: tip)
        p.addLine(to: l)
        p.addLine(to: back)
        p.addLine(to: r)
        p.closeSubpath()
        return p
    }
}

/// Общая геометрия полукруглого прибора.
struct GaugeGeometry {
    let center: CGPoint
    let radius: CGFloat
    init(_ size: CGSize) {
        let r = min(size.width / 2 - 14, size.height - 22)
        radius = max(10, r)
        center = CGPoint(x: size.width / 2, y: 12 + radius)
    }
    /// Угол в радианах: π — слева, π/2 — сверху, 0 — справа.
    func point(_ angle: Double, _ r: CGFloat) -> CGPoint {
        CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y - r * CGFloat(sin(angle)))
    }
}

/// Полукруглый прибор «как в машине»: цветные зоны, деления, подписи и стрелка с пружиной.
struct DialGauge: View {
    let value: Double
    let range: ClosedRange<Double>
    let zones: [GaugeZone]
    /// Подписи делений: значение → текст
    var labels: [(Double, String)] = []
    var minorStep: Double = 1
    var lineWidth: CGFloat = 16
    @State private var shown: Double = 0
    @State private var appeared = false

    private func frac(_ v: Double) -> Double { (v - range.lowerBound) / (range.upperBound - range.lowerBound) }

    var body: some View {
        GeometryReader { geo in
            let g = GaugeGeometry(geo.size)
            ZStack {
                Canvas { ctx, size in
                    let g = GaugeGeometry(size)
                    // фон дуги
                    ctx.stroke(arc(g, 0, 1, g.radius), with: .color(.white.opacity(0.08)), style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round))
                    // зоны со «свечением»
                    for z in zones {
                        let p = arc(g, frac(z.from), frac(z.to), g.radius)
                        var glow = ctx
                        glow.addFilter(.blur(radius: 6))
                        glow.stroke(p, with: .color(z.color.opacity(0.55)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                        ctx.stroke(p, with: .color(z.color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
                    }
                    // мелкие деления
                    var v = range.lowerBound
                    while v <= range.upperBound + 0.0001 {
                        let a = Double.pi * (1 - frac(v))
                        var tick = Path()
                        tick.move(to: g.point(a, g.radius - lineWidth / 2 - 4))
                        tick.addLine(to: g.point(a, g.radius - lineWidth / 2 - 9))
                        ctx.stroke(tick, with: .color(.white.opacity(0.35)), lineWidth: 1)
                        v += minorStep
                    }
                    // крупные деления и подписи
                    for (lv, text) in labels {
                        let a = Double.pi * (1 - frac(lv))
                        var tick = Path()
                        tick.move(to: g.point(a, g.radius + lineWidth / 2 + 1))
                        tick.addLine(to: g.point(a, g.radius - lineWidth / 2 - 13))
                        ctx.stroke(tick, with: .color(.white.opacity(0.9)), lineWidth: 2)
                        ctx.draw(Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(Color.cream.opacity(0.85)),
                                 at: g.point(a, g.radius - lineWidth / 2 - 26))
                    }
                }
                // стрелка с тенью
                NeedleShape(f: frac(shown))
                    .fill(LinearGradient(colors: [Color(hex: 0xFFE7A3), Color(hex: 0xFF6B3D)], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Color(hex: 0xFF6B3D).opacity(0.8), radius: 6)
                // ступица
                Circle()
                    .fill(RadialGradient(colors: [Color.cream, Color(hex: 0x9C8E7A)], center: .topLeading, startRadius: 1, endRadius: 18))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().fill(Color.burgundy).frame(width: 8, height: 8))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    .position(g.center)
            }
        }
        .onAppear {
            // стрелка «просыпается» как в машине: до упора и обратно на значение
            guard !appeared else { return }
            appeared = true
            shown = range.lowerBound
            withAnimation(.easeOut(duration: 0.45)) { shown = range.upperBound }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 1.1, dampingFraction: 0.45)) { shown = clamped(value) }
            }
        }
        .onChange(of: value) {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.5)) { shown = clamped(value) }
        }
        .accessibilityElement()
        .accessibilityValue(Text(String(format: "%.1f", value)))
    }

    private func clamped(_ v: Double) -> Double { min(range.upperBound, max(range.lowerBound, v)) }

    private func arc(_ g: GaugeGeometry, _ f0: Double, _ f1: Double, _ r: CGFloat) -> Path {
        var p = Path()
        let steps = 48
        for i in 0...steps {
            let f = f0 + (f1 - f0) * Double(i) / Double(steps)
            let pt = g.point(Double.pi * (1 - f), r)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// Тёмная «приборная панель» в фирменном бордовом.
struct DashboardPanel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0x4A0314), Color(hex: 0x22010A)], startPoint: .top, endPoint: .bottom))
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.12), .clear], startPoint: .top, endPoint: .center))
                    .allowsHitTesting(false)
            }
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.35), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
            .shadow(color: Color.burgundy.opacity(0.35), radius: 16, y: 8)
    }
}

extension View {
    func dashboardPanel() -> some View { modifier(DashboardPanel()) }
}

// MARK: - Экран «Body»

struct BodyView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newWeight = ""
    @FocusState private var weightFocused: Bool

    static let bmiZones = [
        GaugeZone(from: 14, to: 18.5, color: BMICategory.under.color),
        GaugeZone(from: 18.5, to: 25, color: BMICategory.normal.color),
        GaugeZone(from: 25, to: 30, color: BMICategory.over.color),
        GaugeZone(from: 30, to: 40, color: BMICategory.obese.color),
    ]

    private var p: Profile { store.data.profile }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    bmiPanel
                    nutrikAdvice
                    fuelPanel
                    planCard
                    weightCard
                    Text("BMI is a quick screening number for adults 18+. It doesn't see muscles or body shape — this isn't medical advice. If you're worried about your weight, talk to a doctor.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                }
                .padding(16)
            }
            .pausesNutrikWhileScrolling()
            .background(LiveBackground())
            .navigationTitle("Body dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { weightFocused = false }
                }
            }
        }
        .tint(Color.burgundy)
    }

    // ИМТ-спидометр
    private var bmiPanel: some View {
        let cat = p.bmiCategory
        return VStack(spacing: 4) {
            HStack {
                Text("BODY MASS INDEX").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(1.5)
                    .foregroundStyle(Color.cream.opacity(0.7))
                Spacer()
                Text("\(Int(p.height)) cm · " + String(format: "%.1f kg", p.weight))
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(Color.cream.opacity(0.7))
            }
            DialGauge(value: p.bmi, range: 14...40, zones: Self.bmiZones,
                      labels: [(14, "14"), (18.5, "18.5"), (25, "25"), (30, "30"), (40, "40")], minorStep: 1)
                .frame(height: 180)
            VStack(spacing: 2) {
                Text(String(format: "%.1f", p.bmi))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.cream)
                    .contentTransition(.numericText())
                    .shadow(color: cat.color.opacity(0.6), radius: 10)
                Text("\(cat.emoji) \(cat.title)")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Capsule().fill(cat.color.opacity(0.22)))
                    .overlay(Capsule().strokeBorder(cat.color.opacity(0.8), lineWidth: 1))
                    .foregroundStyle(cat.color)
            }
            HStack(spacing: 0) {
                legend("Under", BMICategory.under.color)
                legend("Healthy", BMICategory.normal.color)
                legend("Over", BMICategory.over.color)
                legend("Obesity", BMICategory.obese.color)
            }
            .padding(.top, 8)
            rangeBar
                .padding(.top, 10)
        }
        .dashboardPanel()
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: p.bmi)
    }

    private func legend(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(Color.cream.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
    }

    /// Полоса «здоровый вес для твоего роста» с маркером текущего веса.
    private var rangeBar: some View {
        let r = p.healthyRange
        let lo = r.lowerBound - 12, hi = r.upperBound + 12
        let f = min(1, max(0, (p.weight - lo) / (hi - lo)))
        let f0 = (r.lowerBound - lo) / (hi - lo), f1 = (r.upperBound - lo) / (hi - lo)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Healthy weight for \(Int(p.height)) cm: \(Int(r.lowerBound.rounded()))–\(Int(r.upperBound.rounded())) kg")
                .font(.footnote.weight(.semibold)).foregroundStyle(Color.cream)
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule().fill(BMICategory.normal.color.opacity(0.85))
                        .frame(width: w * (f1 - f0))
                        .offset(x: w * f0)
                    Circle().fill(Color.cream).frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(p.bmiCategory.color, lineWidth: 3))
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .offset(x: w * f - 8)
                }
            }
            .frame(height: 16)
            Text(distanceText).font(.caption).foregroundStyle(Color.cream.opacity(0.75))
        }
    }

    private var distanceText: String {
        let r = p.healthyRange
        if p.weight < r.lowerBound { return String(format: "You're %.1f kg below the healthy range.", r.lowerBound - p.weight) }
        if p.weight > r.upperBound { return String(format: "You're %.1f kg above the healthy range.", p.weight - r.upperBound) }
        return "You're inside the healthy range 🎉"
    }

    private var nutrikAdvice: some View {
        let cat = p.bmiCategory
        let line: (String, NutrikMood)
        switch cat {
        case .under:
            line = p.goal > 0
                ? ("Great plan! Add an extra snack: nuts, kurt, yogurt, peanut butter toast 🥜 Small steps every day.", .eating)
                : ("You're a bit light. Try the \"Gain\" goal — I'll add ~300 kcal a day with tasty, filling food 🍲", .happy)
        case .normal:
            line = ("Your weight is in the healthy zone! Keep eating well and wasting nothing 💚", .cheer)
        case .over:
            line = p.goal < 0
                ? ("Nice! Fill half the plate with veggies, drink water, and keep moving 🥗 No crash diets.", .happy)
                : ("A little above the healthy zone. A gentle \"Lose\" goal and more walks can help 🚶", .happy)
        case .obese:
            line = ("Let's take care of you step by step 🤝 A gentle \"Lose\" goal and a chat with a doctor are a great start.", .happy)
        }
        return NutrikSays(text: line.0, mood: line.1, size: 70)
    }

    // «Топливо» на сегодня
    private var fuelPanel: some View {
        let target = max(1, store.targetCalories)
        let eaten = store.eatenToday
        let f = Double(eaten) / Double(target)
        let status = f < 0.25 ? "Tank almost empty ⛽ — time to eat" : f < 0.85 ? "Refuel during the day 🍽️" : f <= 1.1 ? "Tank full — goal reached 🎯" : "Over the goal today 🛑"
        return HStack(spacing: 14) {
            DialGauge(value: min(1.3, f), range: 0...1.3,
                      zones: [GaugeZone(from: 0, to: 0.25, color: Color(hex: 0xFF4D4D)),
                              GaugeZone(from: 0.25, to: 0.85, color: Color(hex: 0xFFB020)),
                              GaugeZone(from: 0.85, to: 1.1, color: Color(hex: 0x3CCB6C)),
                              GaugeZone(from: 1.1, to: 1.3, color: Color(hex: 0xFF6B3D))],
                      labels: [(0, "E"), (0.5, "½"), (1, "F")], minorStep: 0.1, lineWidth: 10)
                .frame(width: 150, height: 95)
            VStack(alignment: .leading, spacing: 4) {
                Text("FUEL TODAY").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(1.5).foregroundStyle(Color.cream.opacity(0.7))
                Text("\(eaten) / \(target)").font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit().foregroundStyle(Color.cream)
                Text("kcal").font(.caption).foregroundStyle(Color.cream.opacity(0.7))
                Text(status).font(.caption.weight(.semibold)).foregroundStyle(Color.cream.opacity(0.9))
            }
            Spacer(minLength: 0)
        }
        .dashboardPanel()
    }

    // Как считается цель
    private var planCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Your daily plan")
            Text("Goal").font(.subheadline.weight(.semibold)).foregroundStyle(Color.burgundy)
            Picker("Goal", selection: $store.data.profile.goal) {
                Text("📉 Lose").tag(-1)
                Text("⚖️ Keep").tag(0)
                Text("📈 Gain").tag(1)
            }
            .pickerStyle(.segmented)
            Text("Activity").font(.subheadline.weight(.semibold)).foregroundStyle(Color.burgundy)
            Menu {
                Picker("Activity", selection: $store.data.profile.activity) {
                    ForEach(0..<Profile.activityTitles.count, id: \.self) { i in Text(Profile.activityTitles[i]).tag(i) }
                }
            } label: {
                HStack {
                    Text(Profile.activityTitles[min(4, max(0, p.activity))]).foregroundStyle(Color.burgundy)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(Color.burgundy.opacity(0.6))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.burgundy.opacity(0.07)))
            }
            Divider()
            planRow("🔥 Body at rest (BMR)", "\(p.bmr) kcal")
            planRow("🏃 × activity \(Profile.activityFactor[min(4, max(0, p.activity))])", "\(p.maintenance) kcal")
            if p.goalAdjust != 0 {
                planRow(p.goalAdjust > 0 ? "📈 + for gaining" : "📉 − for losing", "\(p.goalAdjust > 0 ? "+" : "")\(p.goalAdjust) kcal")
            }
            HStack {
                Text("Daily goal").font(.headline).foregroundStyle(Color.burgundy)
                Spacer()
                Text("\(store.targetCalories) kcal")
                    .font(.title3.bold()).foregroundStyle(Color.burgundy)
                    .contentTransition(.numericText())
            }
            Text("Keeping your weight needs about \(p.maintenance) kcal a day. The rest-only number (\(p.bmr)) is what your body burns lying in bed.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .glassCard()
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: store.targetCalories)
    }

    private func planRow(_ l: String, _ r: String) -> some View {
        HStack {
            Text(l).font(.subheadline)
            Spacer()
            Text(r).font(.subheadline.weight(.semibold)).monospacedDigit().foregroundStyle(Color.burgundy)
        }
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Weight tracker")
            HStack(spacing: 10) {
                TextField("Today's weight, kg", text: $newWeight)
                    .keyboardType(.decimalPad)
                    .focused($weightFocused)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.burgundy.opacity(0.07)))
                Button {
                    if let kg = Double(newWeight.replacingOccurrences(of: ",", with: ".")), kg > 25, kg < 300 {
                        withAnimation { store.addWeight(kg) }
                        newWeight = ""
                        weightFocused = false
                        store.say("⚖️ " + String(format: "%.1f", kg) + " kg logged")
                    }
                } label: { Text("Log").padding(.horizontal, 10) }
                .buttonStyle(SoftButtonStyle())
                .disabled(newWeight.isEmpty)
            }
            HStack {
                Stepper("Height: \(Int(p.height)) cm", value: $store.data.profile.height, in: 120...220, step: 1)
            }
            Stepper("Age: \(p.age)", value: $store.data.profile.age, in: 10...100)
            WeightChart(entries: store.data.weights)
        }
        .glassCard()
    }
}

/// Мини-приборчик на Home: ИМТ и цель калорий, тап — открыть Body dashboard.
struct BodyMiniCard: View {
    @EnvironmentObject var store: AppStore
    var body: some View {
        let p = store.data.profile
        let cat = p.bmiCategory
        HStack(spacing: 14) {
            DialGauge(value: p.bmi, range: 14...40, zones: BodyView.bmiZones, labels: [], minorStep: 2, lineWidth: 8)
                .frame(width: 96, height: 58)
            VStack(alignment: .leading, spacing: 3) {
                Text("BMI " + String(format: "%.1f", p.bmi)).font(.headline).foregroundStyle(Color.cream)
                Text("\(cat.emoji) \(cat.title)").font(.caption.weight(.bold)).foregroundStyle(cat.color)
                Text("Goal \(store.targetCalories) kcal · \(Profile.activityShort[min(4, max(0, p.activity))])")
                    .font(.caption).foregroundStyle(Color.cream.opacity(0.75))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Color.cream.opacity(0.6))
        }
        .dashboardPanel()
    }
}
