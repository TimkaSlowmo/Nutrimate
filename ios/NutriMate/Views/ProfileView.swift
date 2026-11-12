import SwiftUI

// MARK: - Профиль (v10): шапка с аватаром и уровнем, крупные цифры, секции как в «Настройках» iOS

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var confirmErase = false
    @State private var showEco = false
    @State private var showChat = false
    @State private var showBody = false
    @State private var showWeek = false
    @State private var showAvatar = false
    @State private var path: [ProfileRoute] = (UIShot.enabled ? UIShot.value("-push") : nil).flatMap(ProfileRoute.init(rawValue:)).map { [$0] } ?? []

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 18) {
                    header
                    statsRow
                    medalsStrip

                    SettingsGroup(title: "Body & goal") {
                        SettingsRow(icon: "gauge.with.dots.needle.67percent", tint: Color(hex: 0xD84315), title: "Body dashboard",
                                    value: String(format: "BMI %.1f", store.data.profile.bmi), valueColor: store.data.profile.bmiCategory.color) { showBody = true }
                        RowDivider()
                        SettingsRow(icon: "flame.fill", tint: .warnOrange, title: "Daily goal",
                                    value: "\(store.targetCalories) kcal") { path.append(.edit) }
                        RowDivider()
                        SettingsRow(icon: "scalemass.fill", tint: Color(hex: 0x5E35B1), title: "Weight",
                                    value: String(format: "%.1f kg", store.data.profile.weight)) { path.append(.edit) }
                    }

                    SettingsGroup(title: "Progress") {
                        SettingsRow(icon: "chart.bar.xaxis", tint: .burgundyLight, title: "Weekly report",
                                    value: "score \(WeekStats(store: store).score)") { showWeek = true }
                        RowDivider()
                        SettingsRow(icon: "leaf.fill", tint: .freshGreen, title: "Eco impact",
                                    value: String(format: "%.1f kg CO₂", store.co2)) { showEco = true }
                        RowDivider()
                        SettingsRow(icon: "medal.fill", tint: Color(hex: 0xF9A825), title: "Medals",
                                    value: "\(store.data.unlocked.count)/\(Medal.all.count)") { path.append(.medals) }
                    }

                    SettingsGroup(title: "Nutrik") {
                        SettingsRow(icon: "bubble.left.and.bubble.right.fill", tint: Color(hex: 0x1E88E5), title: "Chat with Nutrik") { showChat = true }
                        RowDivider()
                        SettingsToggle(icon: "sparkles", tint: Color(hex: 0x8E24AA), title: "Smart Nutrik (online AI)",
                                       subtitle: NutrikAI.isConfigured
                                       ? "Free AI answers in chat. AI answers can be wrong. Sends only your name, fridge, today's kcal and the last messages."
                                       : "AI answers can be wrong. The AI server isn't connected yet — Nutrik answers offline for now.",
                                       isOn: $store.data.smartNutrik)
                        RowDivider()
                        SettingsToggle(icon: "pawprint.fill", tint: Color(hex: 0x6D4C41), title: "Nutrik reacts",
                                       subtitle: "Runs in when you eat, cook, freeze or bin food", isOn: $store.data.nutrikBuddy)
                        RowDivider()
                        SettingsRow(icon: "hand.thumbsdown.fill", tint: Color(hex: 0x757575), title: "Skipped in recipes",
                                    value: store.data.dislikes.isEmpty ? "none" : "\(store.data.dislikes.count)") { path.append(.dislikes) }
                        RowDivider()
                        SettingsRow(icon: "graduationcap.fill", tint: Color(hex: 0x00897B), title: "Replay tutorial", chevron: false) { store.replayTutorial() }
                    }

                    SettingsGroup(title: L("Language")) {
                        Menu {
                            Picker(L("Language"), selection: $store.data.language) {
                                ForEach(AppLang.allCases) { lang in
                                    Text("\(lang.flag) \(lang.native)").tag(lang)
                                }
                            }
                        } label: {
                            HStack(spacing: 12) {
                                SettingsIcon(name: "globe", tint: Color(hex: 0x3949AB))
                                Text(L("App language")).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 6)
                                Text("\(store.data.language.flag) \(store.data.language.native)")
                                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down").font(.footnote.bold()).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(RowPressStyle())
                    }

                    SettingsGroup(title: "Notifications") {
                        SettingsToggle(icon: "bell.badge.fill", tint: .badRed, title: "Daily reminders",
                                       subtitle: "At 9:00 Nutrik tells you what expires today and tomorrow",
                                       isOn: Binding(get: { store.data.notifications }, set: { store.setNotifications($0) }))
                    }

                    SettingsGroup(title: "Data", footer: "Everything is saved on this iPhone automatically. Reinstalling the app on top keeps your data.") {
                        SettingsRow(icon: "basket.fill", tint: Color(hex: 0x7CB342), title: "Add demo products", chevron: false) { store.loadDemo() }
                        RowDivider()
                        SettingsRow(icon: "trash.fill", tint: .badRed, title: "Erase all data", titleColor: .badRed, chevron: false) { confirmErase = true }
                    }

                    VStack(spacing: 4) {
                        Text("NutriMate Pro · iOS v\(version)").font(.footnote.bold()).foregroundStyle(Color.burgundy.opacity(0.7))
                        Text("CEE 181 «Fostering Sustainability in Almaty» — fighting food waste. Prof. Alberto Frigerio.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 110)
                    .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .pausesNutrikWhileScrolling()
            .onAppear {
                // режим скриншотов: `-scrollBottom` показывает низ профиля
                if UIShot.enabled && UIShot.args.contains("-scrollBottom") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            }
            .background(LiveBackground())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProfileRoute.self) { r in
                switch r {
                case .edit: EditProfileView()
                case .medals: MedalsView()
                case .dislikes: DislikesView()
                }
            }
            .sheet(isPresented: $showEco) { EcoImpactView() }
            .sheet(isPresented: $showChat) { ChatView() }
            .sheet(isPresented: $showBody) { BodyView() }
            .sheet(isPresented: $showWeek) { WeekReportView() }
            .sheet(isPresented: $showAvatar) {
                AvatarPicker().presentationDetents([.medium]).presentationBackground(Color.cream)
            }
            .alert("Erase all data?", isPresented: $confirmErase) {
                Button("Erase", role: .destructive) { store.eraseAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Fridge, diary, weight, shopping list and medals will be deleted. This cannot be undone.")
            }
        }
    }

    // MARK: шапка

    private var header: some View {
        let lv = store.level
        return VStack(spacing: 12) {
            Button { showAvatar = true } label: {
                AvatarView(size: 104)
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.cream, Color.burgundy)
                            .background(Circle().fill(Color.cream).padding(3))
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change avatar")

            VStack(spacing: 3) {
                Text(store.data.profile.name)
                    .font(.system(.title, design: .serif).bold())
                    .foregroundStyle(Color.burgundy)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(store.daysWithUs == 1 ? "With NutriMate since today 🌱" : "With NutriMate for \(store.daysWithUs) days 🌱")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Badge(text: "Lv \(lv.n) · \(lv.title)", icon: "star.fill", tint: .burgundy)
                if store.streakDays > 0 {
                    Badge(text: "\(store.streakDays)-day streak", icon: "flame.fill", tint: .warnOrange)
                }
            }

            VStack(spacing: 4) {
                ProgressBar(value: lv.progress)
                Text("\(lv.toNext) XP to level \(lv.n + 1) · rescue, cook and freeze food to level up")
                    .font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8)

            Button { path.append(.edit) } label: {
                Label("Edit profile", systemImage: "square.and.pencil")
            }
            .buttonStyle(SoftButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 28, padding: 18)
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(value: "\(store.data.stats.rescued)", label: "products\nsaved", emoji: "🦸")
            StatTile(value: "\(store.streakDays)", label: "days without\nwaste", emoji: "🌱")
            StatTile(value: String(format: "$%.0f", store.data.stats.rescuedMoney), label: "money\nsaved", emoji: "💰")
        }
    }

    private var medalsStrip: some View {
        let got = Medal.all.filter { store.data.unlocked.contains($0.id) }
        return Button { path.append(.medals) } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Medals").font(.headline).foregroundStyle(Color.burgundy)
                    Text("\(got.count) of \(Medal.all.count)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                HStack(spacing: -8) {
                    ForEach(got.suffix(5)) { m in
                        Text(m.emoji).font(.system(size: 22))
                            .frame(width: 38, height: 38)
                            .background(Circle().fill(Color.cream))
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    }
                    if got.isEmpty {
                        Text("Earn your first one 🍽️").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(radius: 20, padding: 14)
    }
}

enum ProfileRoute: String, Hashable { case edit, medals, dislikes }

// MARK: - Кусочки профиля

struct AvatarView: View {
    @EnvironmentObject var store: AppStore
    var size: CGFloat

    var body: some View {
        let a = store.data.profile.avatar
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: 0xFFF7EA), Color.sand], startPoint: .top, endPoint: .bottom))
            if a.isEmpty {
                NutrikView(mood: .wave, size: size * 0.92, clumsy: false).offset(y: size * 0.04)
            } else if a == "initials" {
                Text(initials).font(.system(size: size * 0.38, weight: .bold, design: .serif)).foregroundStyle(Color.burgundy)
            } else {
                Text(a).font(.system(size: size * 0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .top, endPoint: .bottom), lineWidth: 3))
        .shadow(color: Color.burgundy.opacity(0.18), radius: 8, y: 4)
    }

    private var initials: String {
        let parts = store.data.profile.name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
        return s.isEmpty ? "?" : s
    }
}

struct AvatarPicker: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    static let emojis = ["🦊", "🐼", "🐱", "🐸", "🦁", "🐻", "🐨", "🐯", "🐰", "🐧", "🥑", "🍓", "🍋", "🥕", "🌱", "🍕"]

    var body: some View {
        VStack(spacing: 16) {
            Text("Choose your avatar").font(.headline).foregroundStyle(Color.burgundy).padding(.top, 20)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                    option("") { NutrikView(mood: .happy, size: 56, clumsy: false) }
                    option("initials") {
                        Text(String(store.data.profile.name.prefix(1)).uppercased())
                            .font(.system(size: 28, weight: .bold, design: .serif)).foregroundStyle(Color.burgundy)
                    }
                    ForEach(Self.emojis, id: \.self) { e in option(e) { Text(e).font(.system(size: 34)) } }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func option<V: View>(_ id: String, @ViewBuilder _ content: () -> V) -> some View {
        let sel = store.data.profile.avatar == id
        return Button {
            store.data.profile.avatar = id
            dismiss()
        } label: {
            content()
                .frame(width: 66, height: 66)
                .background(Circle().fill(Color.white.opacity(0.8)))
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(sel ? Color.burgundy : Color.white, lineWidth: sel ? 3 : 1))
        }
        .buttonStyle(.plain)
    }
}

struct Badge: View {
    let text: String
    let icon: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .lineLimit(1)
            .foregroundStyle(tint)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.1)))
    }
}

struct ProgressBar: View {
    let value: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.burgundy.opacity(0.1))
                Capsule().fill(LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, g.size.width * min(1, max(0, value))))
            }
        }
        .frame(height: 8)
    }
}

struct StatTile: View {
    let value: String
    let label: String
    let emoji: String
    var body: some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title3)
            Text(value).font(.system(.title2, design: .rounded).bold()).foregroundStyle(Color.burgundy)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .glassCard(radius: 20, padding: 12)
    }
}

/// Группа строк как в «Настройках» iOS: заголовок, карточка, подпись.
struct SettingsGroup<Content: View>: View {
    let title: String
    var footer: String? = nil
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 16)
            VStack(spacing: 0) { content }
                .glassCard(radius: 18, padding: 0)
            if let footer {
                Text(footer).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 16)
            }
        }
    }
}

struct SettingsIcon: View {
    let name: String
    let tint: Color
    var body: some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(tint.gradient))
    }
}

struct SettingsRow: View {
    let icon: String
    let tint: Color
    let title: String
    var value: String? = nil
    var valueColor: Color = .secondary
    var titleColor: Color = .primary
    var chevron = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIcon(name: icon, tint: tint)
                Text(title).foregroundStyle(titleColor).lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 6)
                if let value { Text(value).font(.subheadline).foregroundStyle(valueColor).lineLimit(1) }
                if chevron { Image(systemName: "chevron.right").font(.footnote.bold()).foregroundStyle(.tertiary) }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowPressStyle())
    }
}

struct SettingsToggle: View {
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                SettingsIcon(name: icon, tint: tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }
            }
        }
        .tint(Color.burgundy)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

struct RowDivider: View {
    var body: some View { Divider().padding(.leading, 56) }
}

struct RowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.background(Color.burgundy.opacity(configuration.isPressed ? 0.07 : 0))
    }
}

// MARK: - Edit profile

struct EditProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var newWeight = ""
    @State private var showAvatar = false
    @FocusState private var focused: Bool

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    Button { showAvatar = true } label: {
                        VStack(spacing: 6) {
                            AvatarView(size: 84)
                            Text("Change avatar").font(.footnote.weight(.semibold)).foregroundStyle(Color.burgundy)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("Name") {
                TextField("Your name", text: $store.data.profile.name)
                    .textInputAutocapitalization(.words)
                    .focused($focused)
            }
            .listRowBackground(Color.white.opacity(0.6))

            Section("Body") {
                Picker("Sex", selection: $store.data.profile.isMan) {
                    Text("Male").tag(true)
                    Text("Female").tag(false)
                }
                .pickerStyle(.segmented)
                Stepper(value: $store.data.profile.age, in: 10...100) { valueRow("Age", "\(store.data.profile.age)") }
                Stepper(value: $store.data.profile.height, in: 120...220, step: 1) { valueRow("Height", "\(Int(store.data.profile.height)) cm") }
            }
            .listRowBackground(Color.white.opacity(0.6))

            Section {
                valueRow("Current", String(format: "%.1f kg", store.data.profile.weight))
                HStack {
                    TextField("New weight, kg", text: $newWeight)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                    Button("Log") { logWeight() }
                        .buttonStyle(SoftButtonStyle())
                        .disabled(parsedWeight == nil)
                }
                if store.data.weights.count > 1 {
                    WeightChart(entries: store.data.weights).padding(.vertical, 4)
                }
            } header: {
                Text("Weight")
            } footer: {
                Text("Log your weight once a week — Nutrik keeps the history and the trend.")
            }
            .listRowBackground(Color.white.opacity(0.6))

            Section {
                Picker("Activity", selection: $store.data.profile.activity) {
                    ForEach(0..<Profile.activityTitles.count, id: \.self) { i in Text(Profile.activityTitles[i]).tag(i) }
                }
                .pickerStyle(.navigationLink)
                Picker("Goal", selection: $store.data.profile.goal) {
                    Text("Lose").tag(-1)
                    Text("Keep").tag(0)
                    Text("Gain").tag(1)
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("Daily goal")
                    Spacer()
                    Text("\(store.targetCalories) kcal").bold().foregroundStyle(Color.burgundy)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.targetCalories)
                }
            } header: {
                Text("Activity & goal")
            } footer: {
                Text("Base metabolism \(store.data.profile.bmr) kcal × activity, ±\u{2009}goal. Losing never goes below your base metabolism.")
            }
            .listRowBackground(Color.white.opacity(0.6))
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focused = false }
            }
        }
        .sheet(isPresented: $showAvatar) {
            AvatarPicker().presentationDetents([.medium]).presentationBackground(Color.cream)
        }
        .onDisappear {
            let n = store.data.profile.name.trimmingCharacters(in: .whitespaces)
            store.data.profile.name = n.isEmpty ? "Friend" : n
        }
    }

    private var parsedWeight: Double? {
        guard let kg = Double(newWeight.replacingOccurrences(of: ",", with: ".")), kg > 25, kg < 300 else { return nil }
        return kg
    }

    private func logWeight() {
        guard let kg = parsedWeight else { return }
        withAnimation { store.addWeight(kg) }
        newWeight = ""
        focused = false
    }

    private func valueRow(_ l: String, _ v: String) -> some View {
        HStack { Text(l); Spacer(); Text(v).foregroundStyle(Color.burgundy).bold() }
    }
}

// MARK: - Медали и нелюбимые продукты

struct MedalsView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("\(store.data.unlocked.count) of \(Medal.all.count) unlocked")
                    .font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(Medal.all) { m in
                        let got = store.data.unlocked.contains(m.id)
                        VStack(spacing: 6) {
                            Text(m.emoji).font(.system(size: 42))
                                .grayscale(got ? 0 : 1).opacity(got ? 1 : 0.35)
                            Text(m.title).font(.subheadline.bold())
                                .foregroundStyle(got ? Color.burgundy : Color.secondary)
                            Text(m.desc).font(.caption).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                            if got {
                                Label("Unlocked", systemImage: "checkmark.seal.fill").font(.caption2.bold()).foregroundStyle(Color.freshGreen)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .glassCard(radius: 20, padding: 12)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
        .background(LiveBackground())
        .navigationTitle("Medals")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DislikesView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        List {
            Section {
                if store.data.dislikes.isEmpty {
                    Text("Nothing here. Tell Nutrik \"I don't like onion\" in chat and recipes with it go to the end of the list.")
                        .foregroundStyle(.secondary)
                }
                ForEach(store.data.dislikes, id: \.self) { d in
                    Text("\(store.db.byName[d]?.emoji ?? "🙅") \(d)")
                        .swipeActions {
                            Button(role: .destructive) { remove(d) } label: { Label("Remove", systemImage: "trash") }
                        }
                }
            } footer: {
                if !store.data.dislikes.isEmpty { Text("Swipe left to like a product again.") }
            }
            .listRowBackground(Color.white.opacity(0.6))
        }
        .scrollContentBackground(.hidden)
        .background(Color.cream.ignoresSafeArea())
        .navigationTitle("Skipped in recipes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func remove(_ d: String) {
        withAnimation { store.data.dislikes.removeAll { $0 == d } }
    }
}

struct ShoppingView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    private var hints: [Food] {
        text.count < 2 ? [] : Array(store.db.search(text, category: nil).prefix(5))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add product…", text: $text).autocorrectionDisabled()
                        Button { addTyped() } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    ForEach(hints) { f in
                        Button { store.addShopping([f.name]); text = "" } label: {
                            Text("\(f.emoji) \(f.name)").foregroundStyle(Color.burgundy)
                        }
                    }
                }
                Section {
                    if store.data.shopping.isEmpty {
                        Text("The list is empty. Add missing ingredients from any recipe 🍲").foregroundStyle(.secondary)
                    }
                    ForEach(store.data.shopping, id: \.self) { n in
                        HStack {
                            Button { store.buy(n) } label: {
                                Image(systemName: "circle").font(.title3).foregroundStyle(Color.burgundy)
                            }
                            .buttonStyle(.plain)
                            Text("\(store.db.byName[n]?.emoji ?? "🛒") \(n)")
                            Spacer()
                        }
                        .swipeActions {
                            Button(role: .destructive) { store.removeShopping(n) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                } footer: {
                    Text("Tap the circle when you bought it — it goes straight into your fridge.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.cream)
            .navigationTitle("Shopping list")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func addTyped() {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        let match = store.db.foods.first { $0.name.lowercased() == t.lowercased() }
        store.addShopping([match?.name ?? t])
        text = ""
    }
}
