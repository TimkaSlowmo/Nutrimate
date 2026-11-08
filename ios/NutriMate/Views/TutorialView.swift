import SwiftUI

/// Туториал: Нутрик проводит по всем вкладкам. Показывается один раз после регистрации
/// (повторить — Profile → «Replay tutorial»). Шаг сам переключает вкладку и подсвечивает её в таб-баре.
struct TutorialStep {
    let tab: AppTab
    let title: String
    let text: String
    let mood: NutrikMood
}

enum Tutorial {
    static let steps: [TutorialStep] = [
        TutorialStep(tab: .home, title: "Home",
                     text: "Hi again! This is Home. I show what to eat first, your calories today and the money at risk.",
                     mood: .wave),
        TutorialStep(tab: .fridge, title: "Fridge",
                     text: "Your fridge! Every product has a freshness bar. Swipe right if you ate it, left to freeze, share or bin it.",
                     mood: .happy),
        TutorialStep(tab: .search, title: "Search",
                     text: "\(FoodDB.shared.foods.count) foods from the US and Kazakhstan. Tap ＋ to put one in the fridge, long-press to log what you ate.",
                     mood: .eating),
        TutorialStep(tab: .recipes, title: "Recipes",
                     text: "Recipes made from what you already have — food that expires soonest goes on top. Missing items go to the shopping list.",
                     mood: .happy),
        TutorialStep(tab: .profile, title: "Profile",
                     text: "Your weight, daily goal, Eco Impact and medals live here. I can also remind you at 9:00 what to eat first!",
                     mood: .wave),
        TutorialStep(tab: .home, title: "Ready!",
                     text: "That's all! Let's eat well and waste nothing together 🌱",
                     mood: .happy),
    ]
}

struct TutorialOverlay: View {
    @EnvironmentObject var store: AppStore
    @Binding var step: Int
    @Binding var tab: AppTab
    @State private var arrowUp = false

    private var current: TutorialStep { Tutorial.steps[min(step, Tutorial.steps.count - 1)] }
    private var isLast: Bool { step >= Tutorial.steps.count - 1 }

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture { next() }

                VStack(spacing: 6) {
                    card
                        .padding(.horizontal, 16)
                    if !isLast {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.cream)
                            .shadow(color: .black.opacity(0.3), radius: 4)
                            .offset(y: arrowUp ? -4 : 4)
                            .position(x: arrowX(g.size.width), y: 14)
                            .frame(height: 28)
                            .animation(.spring(response: 0.45, dampingFraction: 0.7), value: step)
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { arrowUp = true }
        }
    }

    /// Центр нужной вкладки: таб-бар имеет отступ 14 + 6 по бокам и 5 равных кнопок.
    private func arrowX(_ w: CGFloat) -> CGFloat {
        let inset: CGFloat = 20
        let item = (w - inset * 2) / CGFloat(AppTab.allCases.count)
        return inset + item * (CGFloat(current.tab.rawValue) + 0.5)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                NutrikView(mood: current.mood, size: 78)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                VStack(alignment: .leading, spacing: 4) {
                    Text(current.title).font(.title3.bold()).foregroundStyle(Color.burgundy)
                    Text(current.text).font(.callout).foregroundStyle(Color.burgundy.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .id("t\(step)")
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .leading)))
            }
            if current.tab == .profile && !store.data.notifications {
                Button("🔔 Turn on reminders") { store.setNotifications(true) }
                    .buttonStyle(SoftButtonStyle())
            }
            HStack {
                HStack(spacing: 5) {
                    ForEach(0..<Tutorial.steps.count, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? Color.burgundy : Color.burgundy.opacity(0.2))
                            .frame(width: i == step ? 18 : 7, height: 7)
                    }
                }
                Spacer()
                if !isLast {
                    Button("Skip") { finish() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.burgundy.opacity(0.6))
                        .padding(.trailing, 8)
                }
                Button(isLast ? "Let's go! 🌱" : "Next") { next() }
                    .font(.headline)
                    .foregroundStyle(Color.cream)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .top, endPoint: .bottom)))
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.cream.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
        .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: step)
    }

    private func next() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if isLast { finish(); return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            step += 1
            tab = Tutorial.steps[step].tab
        }
    }

    private func finish() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.7)) { tab = .home }
        step = 0
        store.finishTutorial()
    }
}
