import SwiftUI
import Charts

/// Экран Eco Impact: спасённая еда, деньги, CO₂, графики по неделям, причины и категории отходов.
struct EcoImpactView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var nutrikLine: (String, NutrikMood) {
        let s = store.data.stats
        if s.rescued == 0 && s.wasted == 0 { return ("Rescue your first product and I'll start counting your impact 🌱", .happy) }
        if s.wasted > s.rescued { return ("More food went to the bin than we saved 😿 Let's turn it around this week!", .sad) }
        return ("You saved \(String(format: "%.1f", store.rescuedKg)) kg of food — that's \(trees) of a tree's yearly CO₂ work! 🌳", .wave)
    }

    /// Дерево поглощает ≈ 21 кг CO₂ в год
    private var trees: String {
        let frac = store.co2 / 21
        return frac >= 1 ? String(format: "%.1f×", frac) : "\(Int((frac * 100).rounded()))%"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    NutrikSays(text: nutrikLine.0, mood: nutrikLine.1, size: 76)
                    tiles
                    weeklyChart
                    if !store.wasteReasons.isEmpty { reasonsChart }
                    if !store.wasteCategories.isEmpty { categoriesCard }
                    tipsCard
                }
                .padding(16)
            }
            .background(LiveBackground())
            .navigationTitle("Eco Impact")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var tiles: some View {
        let s = store.data.stats
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            tile("🦸", "\(s.rescued)", "products rescued", String(format: "≈ %.1f kg of food", store.rescuedKg))
            tile("💰", String(format: "$%.2f", s.rescuedMoney), "money saved", String(format: "$%.2f lost to the bin", s.wastedMoney))
            tile("🌍", String(format: "%.1f kg", store.co2), "CO₂ avoided", "\(trees) of a tree / year")
            tile("🌱", "\(store.streakDays)", "days without waste", "eco score \(store.ecoScore)")
        }
    }

    private func tile(_ e: String, _ v: String, _ l: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(e).font(.title2)
            Text(v).font(.title2.bold()).foregroundStyle(Color.burgundy).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.caption.weight(.semibold)).foregroundStyle(Color.burgundy.opacity(0.8))
            Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .glassCard(radius: 20, padding: 14)
    }

    private var weeklyChart: some View {
        let weeks = store.ecoByWeek(6)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Saved vs wasted")
            Text("Rescued, frozen or shared products compared with thrown away, by week.")
                .font(.caption).foregroundStyle(.secondary)
            Chart {
                ForEach(weeks) { w in
                    BarMark(x: .value("Week", w.week, unit: .weekOfYear), y: .value("Products", w.saved))
                        .foregroundStyle(by: .value("Type", "Saved"))
                        .position(by: .value("Type", "Saved"))
                        .cornerRadius(5)
                    BarMark(x: .value("Week", w.week, unit: .weekOfYear), y: .value("Products", w.wasted))
                        .foregroundStyle(by: .value("Type", "Wasted"))
                        .position(by: .value("Type", "Wasted"))
                        .cornerRadius(5)
                }
            }
            .chartForegroundStyleScale(["Saved": Color.freshGreen, "Wasted": Color.badRed])
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 190)
        }
        .glassCard()
    }

    private var reasonsChart: some View {
        let reasons = store.wasteReasons
        let palette: [Color] = [.burgundy, .warnOrange, Color(hex: 0xC9A66B), .badRed, Color(hex: 0x8E6C8A)]
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "Why food was thrown away")
            HStack(spacing: 16) {
                Chart(reasons) { r in
                    SectorMark(angle: .value("Count", r.count), innerRadius: .ratio(0.58), angularInset: 2)
                        .cornerRadius(4)
                        .foregroundStyle(by: .value("Reason", r.name))
                }
                .chartForegroundStyleScale(domain: reasons.map(\.name), range: Array(palette.prefix(max(1, reasons.count))))
                .chartLegend(.hidden)
                .frame(width: 130, height: 130)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(reasons.enumerated()), id: \.offset) { i, r in
                        HStack(spacing: 6) {
                            Circle().fill(palette[i % palette.count]).frame(width: 9, height: 9)
                            Text(r.name).font(.caption)
                            Spacer(minLength: 0)
                            Text("\(r.count)").font(.caption.bold()).foregroundStyle(Color.burgundy)
                        }
                    }
                }
            }
            if let top = reasons.max(by: { $0.count < $1.count }) {
                Text(tip(for: top.name)).font(.footnote).foregroundStyle(Color.burgundy.opacity(0.85))
            }
        }
        .glassCard()
    }

    private func tip(for reason: String) -> String {
        if reason == WasteReason.tooMuch.title { return "💡 Most waste comes from buying too much. Check your fridge before shopping and use the shopping list." }
        if reason == WasteReason.forgot.title { return "💡 Food gets forgotten. Turn on Nutrik's 9:00 reminders in Profile." }
        if reason == WasteReason.expired.title { return "💡 Things expire before you eat them. Freeze bread, meat and fruit early ❄️" }
        if reason == WasteReason.disliked.title { return "💡 Nutrik now hides recipes with food you didn't like." }
        return "💡 Store greens in a box with a paper towel and keep the fridge at 2–4 °C."
    }

    private var categoriesCard: some View {
        let cats = Array(store.wasteCategories.prefix(5))
        let top = max(1, cats.first?.count ?? 1)
        return VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "What gets wasted most")
            ForEach(cats) { c in
                HStack(spacing: 10) {
                    Text(FoodDB.catEmoji[c.name] ?? "🍽️")
                    Text(c.name).font(.subheadline).frame(width: 110, alignment: .leading)
                    GeometryReader { g in
                        Capsule().fill(Color.burgundy.opacity(0.75))
                            .frame(width: max(8, g.size.width * Double(c.count) / Double(top)))
                    }
                    .frame(height: 10)
                    Text("\(c.count)").font(.caption.bold()).foregroundStyle(Color.burgundy)
                }
            }
        }
        .glassCard()
    }

    private var tipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(text: "Why it matters in Almaty")
            Text("About a third of all food in the world is lost or wasted. In Kazakhstan most household waste ends up in landfills, where food rots and releases methane. Every product you rescue keeps money in your pocket and CO₂ out of the air above the mountains. 🏔️")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Estimates: 0.3 kg per product, 2.5 kg CO₂ per kg of food.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}

/// Калории за 7 дней со линией цели.
struct WeekCaloriesChart: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        let days = store.caloriesByDay(7)
        let target = store.targetCalories
        let logged = days.filter { $0.value > 0 }
        let avg = logged.isEmpty ? 0 : logged.reduce(0) { $0 + $1.value } / logged.count
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last 7 days").font(.headline).foregroundStyle(Color.burgundy)
                Spacer()
                Text(avg > 0 ? "avg \(avg) kcal" : "no data yet").font(.caption.bold()).foregroundStyle(.secondary)
            }
            Chart {
                ForEach(days) { d in
                    BarMark(x: .value("Day", d.day, unit: .day), y: .value("kcal", d.value))
                        .foregroundStyle(d.value > target ? Color.warnOrange.gradient : Color.burgundy.gradient)
                        .cornerRadius(5)
                }
                RuleMark(y: .value("Goal", target))
                    .foregroundStyle(Color.freshGreen)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("goal \(target)").font(.caption2.bold()).foregroundStyle(Color.freshGreen)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow))
                }
            }
            .frame(height: 150)
        }
    }
}

/// График веса.
struct WeightChart: View {
    let entries: [WeightEntry]

    var body: some View {
        let sorted = entries.sorted { $0.date < $1.date }
        let lo = (sorted.map(\.kg).min() ?? 60) - 2
        let hi = (sorted.map(\.kg).max() ?? 80) + 2
        VStack(alignment: .leading, spacing: 6) {
            if let first = sorted.first, let last = sorted.last, sorted.count > 1 {
                let diff = last.kg - first.kg
                Text((diff > 0 ? "+" : "") + String(format: "%.1f", diff) + " kg since " + first.date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.caption.bold())
                    .foregroundStyle(abs(diff) < 0.05 ? Color.secondary : Color.burgundy)
            }
            Chart {
                ForEach(sorted) { e in
                    AreaMark(x: .value("Date", e.date), yStart: .value("Min", lo), yEnd: .value("kg", e.kg))
                        .foregroundStyle(LinearGradient(colors: [Color.burgundy.opacity(0.25), Color.burgundy.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .foregroundStyle(Color.burgundy)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    PointMark(x: .value("Date", e.date), y: .value("kg", e.kg))
                        .foregroundStyle(Color.burgundy)
                        .symbolSize(30)
                }
            }
            .chartYScale(domain: lo...hi)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                }
            }
            .frame(height: 150)
            if sorted.count < 2 {
                Text("Log your weight a few times to see the trend 📈").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
