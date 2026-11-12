import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var store: AppStore
    @State private var confirmErase = false
    @State private var newWeight = ""
    @State private var showEco = false
    @State private var showChat = false
    @State private var showBody = false

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        NutrikView(mood: .wave, size: 70)
                        VStack(alignment: .leading) {
                            TextField("Name", text: $store.data.profile.name)
                                .font(.title3.bold()).foregroundStyle(Color.burgundy)
                            Text(store.data.profile.email.isEmpty ? "Local account" : store.data.profile.email)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section("Body & goal") {
                    Picker("Sex", selection: $store.data.profile.isMan) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }
                    Stepper("Age: \(store.data.profile.age)", value: $store.data.profile.age, in: 10...100)
                    Stepper("Height: \(Int(store.data.profile.height)) cm", value: $store.data.profile.height, in: 120...220, step: 1)
                    HStack {
                        Text("Weight: \(store.data.profile.weight, specifier: "%.1f") kg")
                        Spacer()
                        TextField("kg", text: $newWeight)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                        Button("Log") {
                            if let kg = Double(newWeight.replacingOccurrences(of: ",", with: ".")), kg > 25, kg < 300 {
                                store.addWeight(kg)
                                newWeight = ""
                            }
                        }
                        .disabled(newWeight.isEmpty)
                    }
                    Picker("Activity", selection: $store.data.profile.activity) {
                        ForEach(0..<Profile.activityShort.count, id: \.self) { i in Text(Profile.activityShort[i]).tag(i) }
                    }
                    Picker("Goal", selection: $store.data.profile.goal) {
                        Text("Lose").tag(-1)
                        Text("Keep").tag(0)
                        Text("Gain").tag(1)
                    }
                    HStack {
                        Text("Daily goal")
                        Spacer()
                        Text("\(store.targetCalories) kcal").bold().foregroundStyle(Color.burgundy)
                    }
                    Button { showBody = true } label: {
                        HStack {
                            Text("📟 Body dashboard (BMI)").bold().foregroundStyle(Color.burgundy)
                            Spacer()
                            Text(String(format: "BMI %.1f", store.data.profile.bmi)).font(.subheadline).foregroundStyle(store.data.profile.bmiCategory.color)
                        }
                    }
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section("Weight trend") {
                    WeightChart(entries: store.data.weights)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section("Eco impact") {
                    Button { showEco = true } label: {
                        HStack {
                            Text("🌍 Open Eco Impact").bold().foregroundStyle(Color.burgundy)
                            Spacer()
                            Image(systemName: "chart.bar.fill").foregroundStyle(Color.burgundy)
                        }
                    }
                    row("🦸 Products rescued", "\(store.data.stats.rescued)")
                    row("💰 Money saved", String(format: "$%.2f", store.data.stats.rescuedMoney))
                    row("🌍 CO₂ avoided", String(format: "%.1f kg", store.co2))
                    row("🗑️ Thrown away", "\(store.data.stats.wasted)")
                    row("🌱 Days without waste", "\(store.streakDays)")
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section("Medals · \(store.data.unlocked.count)/\(Medal.all.count)") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92))], spacing: 12) {
                        ForEach(Medal.all) { m in
                            let got = store.data.unlocked.contains(m.id)
                            VStack(spacing: 4) {
                                Text(m.emoji).font(.system(size: 34))
                                    .grayscale(got ? 0 : 1)
                                    .opacity(got ? 1 : 0.35)
                                Text(m.title).font(.caption2.bold()).multilineTextAlignment(.center)
                                    .foregroundStyle(got ? Color.burgundy : Color.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section {
                    Toggle(isOn: Binding(get: { store.data.notifications }, set: { store.setNotifications($0) })) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🔔 Daily reminders")
                            Text("At 9:00 Nutrik tells you what expires today and tomorrow").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $store.data.nutrikBuddy) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("🐾 Nutrik reacts")
                            Text("Runs in when you eat, cook, freeze or bin food").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle(isOn: $store.data.smartNutrik) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("✨ Smart Nutrik (online AI)")
                            Text(NutrikAI.isConfigured
                                 ? "Free AI answers in chat. AI answers can be wrong. Sends only your name, fridge, today's kcal and the last messages."
                                 : "AI answers can be wrong. The AI server isn't connected yet — Nutrik answers offline for now.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Button("💬 Chat with Nutrik") { showChat = true }
                    if !store.data.dislikes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🙅 Skipped in recipes").font(.subheadline)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(store.data.dislikes, id: \.self) { d in
                                        Button {
                                            withAnimation { store.data.dislikes.removeAll { $0 == d } }
                                        } label: { Chip(text: "\(d) ✕") }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    Button("🎓 Replay tutorial") { store.replayTutorial() }
                } header: {
                    Text("Nutrik")
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section {
                    Button("Add demo products") { store.loadDemo() }
                    Button("Erase all data", role: .destructive) { confirmErase = true }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Everything is saved on this iPhone automatically. Reinstalling the app on top keeps your data.")
                }
                .listRowBackground(Color.white.opacity(0.55))

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NutriMate Pro · iOS v\(version)").font(.footnote.bold())
                        Text("CEE 181 «Fostering Sustainability in Almaty» — fighting food waste. Prof. Alberto Frigerio.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
            .background(LiveBackground())
            .navigationTitle("Profile")
            .sheet(isPresented: $showEco) { EcoImpactView() }
            .sheet(isPresented: $showChat) { ChatView() }
            .sheet(isPresented: $showBody) { BodyView() }
            .alert("Erase all data?", isPresented: $confirmErase) {
                Button("Erase", role: .destructive) { store.eraseAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Fridge, diary, weight, shopping list and medals will be deleted. This cannot be undone.")
            }
        }
    }

    private func row(_ l: String, _ v: String) -> some View {
        HStack {
            Text(l)
            Spacer()
            Text(v).bold().foregroundStyle(Color.burgundy)
        }
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
