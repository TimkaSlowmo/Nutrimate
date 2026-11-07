import SwiftUI

/// Знакомство с Нутриком и регистрация (данные хранятся только на телефоне).
struct OnboardingView: View {
    @EnvironmentObject var store: AppStore
    @State private var step = 0
    @State private var name = ""
    @State private var email = ""
    @State private var isMan = true
    @State private var age = 20
    @State private var weight = 70.0
    @State private var height = 175.0
    @State private var demo = true

    private var line: String {
        switch step {
        case 0: return "Hi! I'm Nutrik 🐾 I help people stop wasting food. Nice to meet you!"
        case 1: return "What should I call you?"
        default: return "A few numbers so I can count your daily calories 📏"
        }
    }

    var body: some View {
        ZStack {
            LiveBackground()
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 30)
                    Text("NutriMate").font(.system(size: 40, weight: .bold, design: .serif)).foregroundStyle(Color.burgundy)
                    Text("Eat well · waste less · save the planet")
                        .font(.subheadline).foregroundStyle(Color.burgundy.opacity(0.7))
                    NutrikView(mood: step == 0 ? .wave : .happy, size: 150)
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
                        if step == 1 { account }
                        if step == 2 { params }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))

                    Button(step == 2 ? "Start saving food 🌱" : "Next") { next() }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(step == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(step == 1 && name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                    if step > 0 {
                        Button("Back") { withAnimation(.spring) { step -= 1 } }
                            .foregroundStyle(Color.burgundy)
                    }
                    Text("Your data stays on this iPhone.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: step)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var account: some View {
        VStack(spacing: 12) {
            field("Your name", text: $name, icon: "person.fill")
                .textContentType(.givenName)
            field("Email (optional)", text: $email, icon: "envelope.fill")
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .glassCard()
    }

    private var params: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Sex", selection: $isMan) {
                Text("Male").tag(true)
                Text("Female").tag(false)
            }
            .pickerStyle(.segmented)
            Stepper("Age: \(age)", value: $age, in: 10...100)
            VStack(alignment: .leading) {
                Text("Weight: \(weight, specifier: "%.0f") kg")
                Slider(value: $weight, in: 35...180, step: 1)
            }
            VStack(alignment: .leading) {
                Text("Height: \(height, specifier: "%.0f") cm")
                Slider(value: $height, in: 120...220, step: 1)
            }
            Toggle("Fill my fridge with demo products", isOn: $demo)
        }
        .foregroundStyle(Color.burgundy)
        .glassCard()
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
        if step < 2 {
            withAnimation(.spring) { step += 1 }
        } else {
            store.register(name: name.trimmingCharacters(in: .whitespaces), email: email, isMan: isMan,
                           age: age, weight: weight, height: height, demo: demo)
        }
    }
}
