import SwiftUI

/// Знакомство с Нутриком и регистрация (данные хранятся только на телефоне).
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    /// 0 язык · 1 знакомство · 2 имя · 3 параметры · 4 активность и цель
    @State private var step = min(4, max(0, Int(UIShot.value("-obStep") ?? "") ?? 0))
    @State private var name = ""
    @State private var email = ""
    @State private var isMan = true
    @State private var age = 20
    @State private var weight = 70.0
    @State private var height = 175.0
    @State private var demo = true
    @State private var activity = 1
    @State private var goal = 0
    @State private var goalTouched = false

    private let lastStep = 4

    /// Временный профиль для живого расчёта цели калорий.
    private var preview: Profile {
        var p = Profile()
        p.isMan = isMan; p.age = age; p.weight = weight; p.height = height
        p.activity = activity; p.goal = goal
        return p
    }

    private var line: String {
        switch step {
        case 0: return store.data.language.hello
        case 1: return L("Hi! I'm Nutrik 🐾 I help people stop wasting food. Nice to meet you!")
        case 2: return L("What should I call you?")
        case 3: return L("A few numbers so I can count your daily calories 📏")
        default:
            switch preview.bmiCategory {
            case .under: return L("How active are you? You're a bit light — I'd suggest \"Gain\" 🍝")
            case .over, .obese: return L("How active are you? A gentle \"Lose\" goal works best — no strict diets! 🥗")
            case .normal: return L("How active are you, and what's your goal? 🎯")
            }
        }
    }

    var body: some View {
        ZStack {
            LiveBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 30)
                    Text("NutriMate").font(.system(size: 40, weight: .bold, design: .serif)).foregroundStyle(Color.burgundy)
                    Text(L("Eat well · waste less · save the planet"))
                        .font(.subheadline).foregroundStyle(Color.burgundy.opacity(0.7))
                    NutrikView(mood: step <= 1 ? .wave : .happy, size: 150)
                    Text(line)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.burgundy)
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .id(line)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))

                    Group {
                        if step == 0 { languagePicker }
                        if step == 2 { account }
                        if step == 3 { params }
                        if step == 4 { activityGoal }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                    Button(step == lastStep ? L("Start saving food 🌱") : L("Next")) { next() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(step == 2 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(step == 2 && name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    if step > 0 {
                        Button(L("Back")) { withAnimation(.spring) { step -= 1 } }
                            .foregroundStyle(Color.burgundy)
                    }
                    Text(L("Your data stays on this iPhone."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    /// Шаг 0: выбор языка — крупные карточки, смена сразу (Нутрик здоровается на выбранном языке).
    private var languagePicker: some View {
        VStack(spacing: 10) {
            ForEach(AppLang.allCases) { lang in
                let on = store.data.language == lang
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { store.data.language = lang }
                } label: {
                    HStack(spacing: 14) {
                        Text(lang.flag).font(.system(size: 34))
                        Text(lang.native).font(.title3.weight(.semibold))
                        Spacer()
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.title2)
                            .foregroundStyle(on ? Color.burgundy : Color.burgundy.opacity(0.3))
                    }
                    .foregroundStyle(Color.burgundy)
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(on ? Color.burgundy.opacity(0.10) : Color.paper.opacity(0.7),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(on ? Color.burgundy.opacity(0.55) : Color.paper.opacity(0.9), lineWidth: on ? 1.5 : 1))
                    .scaleEffect(on ? 1.02 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var account: some View {
        VStack(spacing: 12) {
            field(L("Your name"), text: $name, icon: "person.fill")
                .textContentType(.givenName)
            field(L("Email (optional)"), text: $email, icon: "envelope.fill")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .glassCard()
    }

    private var params: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker(L("Sex"), selection: $isMan) {
                Text(L("Male")).tag(true)
                Text(L("Female")).tag(false)
            }
            .pickerStyle(.segmented)
            Stepper(L("Age: {0}", age), value: $age, in: 10...100)
            VStack(alignment: .leading) {
                Text(L("Weight: {0} kg", Int(weight)))
                Slider(value: $weight, in: 35...180, step: 1)
            }
            VStack(alignment: .leading) {
                Text(L("Height: {0} cm", Int(height)))
                Slider(value: $height, in: 120...220, step: 1)
            }
            Toggle(L("Fill my fridge with demo products"), isOn: $demo)
        }
        .foregroundStyle(Color.burgundy)
        .glassCard()
    }

    private var activityGoal: some View {
        let p = preview
        let underweight = p.bmiCategory == .under
        return VStack(alignment: .leading, spacing: 14) {
            Text(L("Activity")).font(.headline)
            VStack(spacing: 8) {
                ForEach(0..<Profile.activityTitles.count, id: \.self) { i in
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        withAnimation(.spring(response: 0.35)) { activity = i }
                    } label: {
                        HStack {
                            Text(L(Profile.activityTitles[i])).font(.subheadline)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 6)
                            Image(systemName: activity == i ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(activity == i ? Color.burgundy : Color.burgundy.opacity(0.3))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(activity == i ? Color.burgundy.opacity(0.10) : Color.sand.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(activity == i ? Color.burgundy.opacity(0.5) : .clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(L("Goal")).font(.headline)
            Picker(L("Goal"), selection: Binding(get: { goal }, set: { goal = $0; goalTouched = true })) {
                Text(L("📉 Lose")).tag(-1)
                Text(L("⚖️ Keep")).tag(0)
                Text(L("📈 Gain")).tag(1)
            }
            .pickerStyle(.segmented)
            if underweight && goal < 0 {
                Text(L("Your weight is already below the healthy range, so I'll plan for keeping it instead 💛"))
                    .font(.caption).foregroundStyle(Color.warnOrange)
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Your daily goal")).font(.caption.bold()).foregroundStyle(Color.burgundy.opacity(0.7))
                    Text(L("{0} kcal", effectiveTarget))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                        .animation(.spring, value: effectiveTarget)
                }
                Spacer()
                Text(L("BMI {0}", String(format: "%.1f", p.bmi)))
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(p.bmiCategory.color.opacity(0.18), in: Capsule())
            }
            Text(L("Base metabolism {0} × activity, {1}. You can change it later in Profile.", p.bmr,
                   goal < 0 && !underweight ? L("−400 to lose gently") : goal > 0 ? L("+300 to gain") : L("to keep your weight")))
                .font(.caption).foregroundStyle(.secondary)
        }
        .foregroundStyle(Color.burgundy)
        .glassCard()
        .onAppear {
            guard !goalTouched else { return }
            switch p.bmiCategory {
            case .under: goal = 1
            case .over, .obese: goal = -1
            case .normal: goal = 0
            }
        }
    }

    /// Недовесу не даём выбрать похудение.
    private var finalGoal: Int { preview.bmiCategory == .under && goal < 0 ? 0 : goal }
    private var effectiveTarget: Int {
        var p = preview
        p.goal = finalGoal
        return p.targetCalories
    }

    private func field(_ title: String, text: Binding<String>, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(Color.burgundy)
            TextField(title, text: text)
        }
        .padding(14)
        .background(Color.sand.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if step < lastStep {
            withAnimation(.spring) { step += 1 }
        } else {
            store.register(name: name.trimmingCharacters(in: .whitespaces), email: email, isMan: isMan,
                           age: age, weight: weight, height: height, activity: activity, goal: finalGoal, demo: demo)
        }
    }
}
