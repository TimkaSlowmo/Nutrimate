import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: AppStore
    @Binding var tab: AppTab
    @State private var showShopping = false
    @State private var showDiary = false
    @State private var showEco = false
    @State private var openItem: PantryItem?

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening"
    }

    private var nutrikLine: (String, NutrikMood) {
        let rescue = store.toRescue
        if store.data.pantry.isEmpty { return ("Your fridge is empty! Let's add what you have 🧺", .sad) }
        if let first = rescue.first {
            return first.daysLeft == 0
                ? ("Psst! \(first.emoji) \(first.name) needs to be eaten today!", .eating)
                : ("\(rescue.count) product\(rescue.count == 1 ? "" : "s") will expire soon — let's rescue them 🦸", .happy)
        }
        if !store.expired.isEmpty { return ("Some food has expired 😿 Check your fridge.", .sad) }
        return ("Everything is fresh! You're a zero-waste star ⭐", .wave)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.subheadline).foregroundStyle(Color.burgundy.opacity(0.65))
                        Text("\(greeting), \(store.data.profile.name)!")
                            .font(.largeTitle.bold()).foregroundStyle(Color.burgundy)
                    }
                    .padding(.top, 8)

                    NutrikSays(text: nutrikLine.0, mood: nutrikLine.1)

                    caloriesCard
                    rescueCard
                    statsRow
                    ecoBanner
                    HStack(spacing: 12) {
                        quick("🛒", "Shopping", "\(store.data.shopping.count) items") { showShopping = true }
                        quick("📒", "Diary", "\(store.todayLog.count) today") { showDiary = true }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(LiveBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showShopping) { ShoppingView() }
            .sheet(isPresented: $showDiary) { DiaryView() }
            .sheet(isPresented: $showEco) { EcoImpactView() }
            .sheet(item: $openItem) { p in ItemSheet(id: p.id) }
        }
    }

    private var caloriesCard: some View {
        let eaten = store.eatenToday
        let target = max(1, store.targetCalories)
        let frac = min(1, Double(eaten) / Double(target))
        return HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.burgundy.opacity(0.1), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: frac)
                    .stroke(AngularGradient(colors: [.burgundyLight, .burgundy, .burgundyLight], center: .center),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: frac)
                VStack(spacing: 0) {
                    Text("\(eaten)").font(.title2.bold()).foregroundStyle(Color.burgundy).contentTransition(.numericText())
                    Text("kcal").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 96, height: 96)
            VStack(alignment: .leading, spacing: 6) {
                Text("Today").font(.headline).foregroundStyle(Color.burgundy)
                Text("Goal \(target) kcal").font(.subheadline).foregroundStyle(.secondary)
                let left = target - eaten
                Text(left >= 0 ? "\(left) kcal left" : "\(-left) kcal over")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(left >= 0 ? Color.freshGreen : Color.warnOrange)
            }
            Spacer(minLength: 0)
        }
        .glassCard()
    }

    @ViewBuilder private var rescueCard: some View {
        let list = store.expiringSoon
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle(text: "Use these first")
                Spacer()
                if store.moneyAtRisk > 0 {
                    Text("$\(store.moneyAtRisk, specifier: "%.1f") at risk").font(.caption.bold()).foregroundStyle(Color.warnOrange)
                }
            }
            if list.isEmpty {
                Text("Nothing is about to expire. 🎉").foregroundStyle(.secondary)
            } else {
                ForEach(list.prefix(5)) { p in
                    Button { openItem = p } label: { PantryRow(item: p) }
                        .buttonStyle(.plain)
                }
                if list.count > 5 {
                    Button("See all \(list.count) in Fridge") { withAnimation { tab = .fridge } }
                        .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .glassCard()
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            stat("🧊", "\(store.data.pantry.count)", "in fridge")
            stat("🦸", "\(store.data.stats.rescued)", "rescued")
            stat("💰", String(format: "$%.0f", store.data.stats.rescuedMoney), "saved")
            stat("🌍", "\(store.ecoScore)", "eco score")
        }
    }

    private var ecoBanner: some View {
        Button { showEco = true } label: {
            HStack(spacing: 12) {
                Text("🌍").font(.system(size: 34))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Eco Impact").font(.headline).foregroundStyle(Color.burgundy)
                    Text(String(format: "%.1f kg food · %.1f kg CO₂ · $%.0f saved", store.rescuedKg, store.co2, store.data.stats.rescuedMoney))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(Color.burgundy.opacity(0.5))
            }
            .glassCard(radius: 18, padding: 14)
        }
        .buttonStyle(.plain)
    }

    private func stat(_ e: String, _ v: String, _ l: String) -> some View {
        VStack(spacing: 2) {
            Text(e).font(.title3)
            Text(v).font(.headline).foregroundStyle(Color.burgundy).lineLimit(1).minimumScaleFactor(0.6)
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 18, padding: 10)
    }

    private func quick(_ e: String, _ title: String, _ sub: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(e).font(.title2)
                VStack(alignment: .leading) {
                    Text(title).font(.headline).foregroundStyle(Color.burgundy)
                    Text(sub).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .glassCard(radius: 18, padding: 14)
        }
        .buttonStyle(.plain)
    }
}

/// Строка продукта: эмодзи, название, статус, полоска свежести.
struct PantryRow: View {
    let item: PantryItem
    var body: some View {
        HStack(spacing: 12) {
            EmojiBadge(emoji: item.emoji)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name).font(.body.weight(.semibold)).foregroundStyle(Color.burgundy).lineLimit(1)
                    Spacer()
                    Text(item.storage.emoji).font(.caption)
                }
                Text(item.status).font(.caption.weight(.semibold)).foregroundStyle(Color.freshness(item.daysLeft))
                FreshBar(fresh: item.fresh, color: Color.freshness(item.daysLeft))
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Дневник калорий за сегодня.
struct DiaryView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekCaloriesChart()
                        .padding(.vertical, 4)
                }
                Section {
                    HStack {
                        Text("Eaten today")
                        Spacer()
                        Text("\(store.eatenToday) / \(store.targetCalories) kcal").bold().foregroundStyle(Color.burgundy)
                    }
                }
                Section("Log") {
                    if store.todayLog.isEmpty {
                        Text("Nothing yet. Eat something from your fridge or log food in Search (long-press a product).")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(store.todayLog.reversed())) { e in
                        HStack {
                            Text(e.emoji)
                            Text(e.name)
                            Spacer()
                            Text("\(e.kcal) kcal").foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) { store.removeLog(e.id) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Food diary")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
