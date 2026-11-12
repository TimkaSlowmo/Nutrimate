import SwiftUI
import Charts

/// Недельная статистика: калории за 7 дней, дни «в цели», спасённая и выброшенная еда,
/// сравнение с прошлой неделей, любимые продукты и итог от Нутрика.
struct WeekStats {
    let days: [DayValue]
    let target: Int
    let avg: Int
    let loggedDays: Int
    let onTarget: Int
    let saved: Int
    let savedMoney: Double
    let wasted: Int
    let prevSaved: Int
    let prevWasted: Int
    let prevAvg: Int
    let topFoods: [(String, String, Int)]   // эмодзи, название, сколько раз
    let weightDelta: Double?

    init(store: AppStore) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .day, value: -6, to: today) ?? today
        let prevStart = cal.date(byAdding: .day, value: -13, to: today) ?? today
        let all = store.caloriesByDay(14)
        days = Array(all.suffix(7))
        let prev = Array(all.prefix(7))
        target = max(1, store.targetCalories)

        func average(_ v: [DayValue]) -> Int {
            let l = v.filter { $0.value > 0 }
            return l.isEmpty ? 0 : l.reduce(0) { $0 + $1.value } / l.count
        }
        avg = average(days)
        prevAvg = average(prev)
        loggedDays = days.filter { $0.value > 0 }.count
        let t = Double(target)
        onTarget = days.filter { Double($0.value) >= t * 0.8 && Double($0.value) <= t * 1.1 }.count

        let ev = store.data.events
        let good: Set<EcoKind> = [.rescued, .frozen, .shared]
        let week = ev.filter { $0.date >= start }
        let before = ev.filter { $0.date >= prevStart && $0.date < start }
        saved = week.filter { good.contains($0.kind) }.count
        savedMoney = week.filter { good.contains($0.kind) }.reduce(0) { $0 + $1.money }
        wasted = week.filter { $0.kind == .wasted }.count
        prevSaved = before.filter { good.contains($0.kind) }.count
        prevWasted = before.filter { $0.kind == .wasted }.count

        var counts: [String: (String, Int)] = [:]
        for e in store.data.log where e.date >= start && e.name != "Meals" {
            let name = e.name.components(separatedBy: " · ").first ?? e.name
            counts[name, default: (e.emoji, 0)].1 += 1
        }
        topFoods = counts.sorted { $0.value.1 == $1.value.1 ? $0.key < $1.key : $0.value.1 > $1.value.1 }
            .prefix(3).map { ($0.value.0, $0.key, $0.value.1) }

        let w = store.data.weights.sorted { $0.date < $1.date }
        if let last = w.last, let base = w.last(where: { $0.date < start }) ?? (w.count > 1 ? w.first : nil) {
            weightDelta = last.kg - base.kg
        } else {
            weightDelta = nil
        }
    }

    /// 0…100: калории в цели + спасённая еда − выброшенная.
    var score: Int {
        let kcal = loggedDays == 0 ? 0.0 : Double(onTarget) / 7 * 50
        let eco = saved + wasted == 0 ? 25.0 : Double(saved) / Double(saved + wasted) * 50
        return Int((kcal + eco).rounded())
    }

    var verdict: (String, NutrikMood) {
        if loggedDays == 0 && saved == 0 && wasted == 0 {
            return (L("A quiet week! Log what you eat and rescue some food — next week's report will shine ✨"), .sleepy)
        }
        if wasted == 0 && saved > 0 { return (L("Zero food in the bin this week! You saved {0} — I'm so proud 🥹", Lp(saved, "product|products")), .cheer) }
        if score >= 70 { return (L("What a week! Calories on track and food rescued. Keep it up 💪"), .cheer) }
        if wasted > saved { return (L("Oops, more food in the bin than rescued 😿 Check \"Use these first\" every morning — I'll help!"), .sad) }
        if onTarget < 3 && loggedDays >= 3 {
            return avg < target
                ? (L("You often ate less than your goal. Add a snack — your body needs fuel ⛽"), .happy)
                : (L("Some days were a bit over the goal. Smaller portions, same tasty food 🍽️"), .happy)
        }
        return (L("Good week! A little better every week is the Nutrik way 🐾"), .happy)
    }
}

struct WeekReportView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var appear = false

    var body: some View {
        let s = WeekStats(store: store)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header(s)
                    NutrikSays(text: s.verdict.0, mood: s.verdict.1)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        tile("🔥", s.avg > 0 ? "\(s.avg)" : "—", L("avg kcal / day"), L("goal {0}", s.target), delta: s.prevAvg > 0 && s.avg > 0 ? s.avg - s.prevAvg : nil, goodWhenUp: nil)
                        tile("🎯", "\(s.onTarget)/7", L("days on target"), L("80–110% of goal"), delta: nil, goodWhenUp: nil)
                        tile("🦸", "\(s.saved)", L("products saved"), L("{0} kept", String(format: "$%.2f", s.savedMoney)), delta: s.saved - s.prevSaved, goodWhenUp: true)
                        tile("🗑️", "\(s.wasted)", L("thrown away"), s.wasted == 0 ? L("perfect!") : L("let's do better"), delta: s.wasted - s.prevWasted, goodWhenUp: false)
                    }
                    WeekCaloriesChart().glassCard()
                    if !s.topFoods.isEmpty { favorites(s) }
                    if let d = s.weightDelta { weight(d) }
                    Text(L("Compared with the 7 days before. Tip: log meals by long-pressing a product in Search."))
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(16)
            }
            .pausesNutrikWhileScrolling()
            .background(LiveBackground())
            .navigationTitle(L("Your week"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
            .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.15)) { appear = true } }
        }
    }

    private func header(_ s: WeekStats) -> some View {
        let first = s.days.first?.day ?? Date()
        let range = "\(first.formatted(.dateTime.day().month(.abbreviated).locale(AppLang.current.locale))) – \(Date().formatted(.dateTime.day().month(.abbreviated).locale(AppLang.current.locale)))"
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.cream.opacity(0.25), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: appear ? CGFloat(s.score) / 100 : 0)
                    .stroke(AngularGradient(colors: [.warnOrange, .yellow, .freshGreen], center: .center), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(s.score)").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(Color.cream)
                    Text(L("score")).font(.caption2).foregroundStyle(Color.cream.opacity(0.7))
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 4) {
                Text(L("WEEKLY REPORT")).font(.caption.bold()).tracking(1.2).foregroundStyle(Color.cream.opacity(0.7))
                Text(range).font(.title3.bold()).foregroundStyle(Color.cream)
                Text(L("{0} logged · {1} saved · {2} wasted", Lp(s.loggedDays, "day|days"), s.saved, s.wasted))
                    .font(.caption).foregroundStyle(Color.cream.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(
            LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: Color.burgundy.opacity(0.25), radius: 14, y: 8)
    }

    private func tile(_ e: String, _ value: String, _ title: String, _ sub: String, delta: Int?, goodWhenUp: Bool?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(e).font(.title3)
                Spacer()
                if let d = delta, d != 0 {
                    let good = goodWhenUp.map { $0 == (d > 0) }
                    Text("\(d > 0 ? "▲" : "▼") \(abs(d))")
                        .font(.caption2.bold())
                        .foregroundStyle(good == nil ? Color.secondary : good! ? Color.freshGreen : Color.badRed)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.white.opacity(0.6), in: Capsule())
                }
            }
            Text(value).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(Color.burgundy)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(title).font(.caption.bold()).foregroundStyle(Color.burgundy.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.75)
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .glassCard(radius: 18, padding: 14)
    }

    private func favorites(_ s: WeekStats) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Most eaten")).font(.headline).foregroundStyle(Color.burgundy)
            ForEach(Array(s.topFoods.enumerated()), id: \.offset) { i, f in
                HStack(spacing: 10) {
                    Text(["🥇", "🥈", "🥉"][min(i, 2)])
                    Text(f.0).font(.title3)
                    Text(N(f.1)).foregroundStyle(Color.burgundy).lineLimit(1)
                    Spacer()
                    Text("×\(f.2)").font(.subheadline.bold()).foregroundStyle(.secondary)
                }
            }
        }
        .glassCard()
    }

    private func weight(_ d: Double) -> some View {
        HStack(spacing: 12) {
            Text("⚖️").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Weight this week")).font(.headline).foregroundStyle(Color.burgundy)
                Text(abs(d) < 0.05 ? L("Stable — no change") : L("{0} kg", String(format: "%@%.1f", d > 0 ? "+" : "−", abs(d))))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .glassCard()
    }
}
