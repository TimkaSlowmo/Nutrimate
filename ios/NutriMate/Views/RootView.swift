import SwiftUI

enum AppTab: Int, CaseIterable, Identifiable {
    case home, fridge, search, recipes, profile
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .home: return "Home"
        case .fridge: return "Fridge"
        case .search: return "Search"
        case .recipes: return "Recipes"
        case .profile: return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .fridge: return "refrigerator.fill"
        case .search: return "magnifyingglass"
        case .recipes: return "fork.knife"
        case .profile: return "person.crop.circle.fill"
        }
    }
}

struct RootView: View {
    @EnvironmentObject var store: AppStore
    @State private var tab: AppTab = UIShot.enabled ? UIShot.tab : .home
    @State private var shotSheet: ShotSheet? = UIShot.sheet.map { ShotSheet(id: $0) }
    @State private var tutorialStep = 0

    var body: some View {
        ZStack {
            if store.data.profile.registered {
                mainTabs.transition(.opacity.combined(with: .scale(scale: 1.03)))
            } else {
                OnboardingView().transition(.opacity)
            }
        }
        .overlay(alignment: .top) {
            if let t = store.toast {
                Text(t)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.burgundy)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.top, 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { store.toast = nil } }
            }
        }
        .sheet(item: $shotSheet) { s in
            switch s.id {
            case "body": BodyView()
            case "chat": ChatView()
            case "eco": EcoImpactView()
            case "shopping": ShoppingView()
            default: DiaryView()
            }
        }
        .sheet(item: $store.newMedal) { m in
            MedalUnlockedView(medal: m)
                .presentationDetents([.medium])
                .presentationBackground(.regularMaterial)
        }
    }

    private var mainTabs: some View {
        Group {
            switch tab {
            case .home: HomeView(tab: $tab)
            case .fridge: FridgeView(tab: $tab)
            case .search: SearchView()
            case .recipes: RecipesView()
            case .profile: ProfileView()
            }
        }
        .id(tab)
        .transition(.opacity)
        .overlay(alignment: .bottomLeading) {
            if store.data.profile.tutorialDone && store.data.nutrikBuddy {
                NutrikBuddy()
            }
        }
        .overlay {
            if !store.data.profile.tutorialDone {
                TutorialOverlay(step: $tutorialStep, tab: $tab)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(selection: $tab)
                .padding(.horizontal, 14)
                .padding(.bottom, 2)
        }
    }
}

/// Лист, который открывается сразу при запуске в режиме скриншотов (`-sheet body`).
struct ShotSheet: Identifiable { let id: String }

extension Medal: Equatable {
    static func == (a: Medal, b: Medal) -> Bool { a.id == b.id }
}

struct MedalUnlockedView: View {
    let medal: Medal
    @Environment(\.dismiss) private var dismiss
    @State private var pop = false

    var body: some View {
        VStack(spacing: 14) {
            Text("New medal!").font(.title2.bold()).foregroundStyle(Color.burgundy)
            Text(medal.emoji)
                .font(.system(size: 84))
                .scaleEffect(pop ? 1 : 0.3)
                .rotationEffect(.degrees(pop ? 0 : -25))
            Text(medal.title).font(.title3.bold())
            Text(medal.desc).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button("Yay! 🎉") { dismiss() }.buttonStyle(PrimaryButtonStyle()).padding(.top, 6)
        }
        .padding(24)
        .onAppear { withAnimation(.spring(response: 0.5, dampingFraction: 0.45)) { pop = true } }
    }
}

/// Стеклянная нижняя панель с «желейной» капсулой выбранной вкладки.
struct GlassTabBar: View {
    @Binding var selection: AppTab
    @Namespace private var ns
    @State private var squishX: CGFloat = 1
    @State private var bounce: AppTab?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { t in
                Button { tap(t) } label: {
                    VStack(spacing: 3) {
                        Image(systemName: t.icon)
                            .font(.system(size: 19, weight: .semibold))
                            .scaleEffect(bounce == t ? 1.25 : 1)
                        Text(t.title).font(.system(size: 10, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selection == t ? Color.cream : Color.burgundy.opacity(0.75))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background {
                        if selection == t {
                            Capsule()
                                .fill(LinearGradient(colors: [.burgundyLight, .burgundy], startPoint: .top, endPoint: .bottom))
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.28), lineWidth: 1))
                                .overlay(alignment: .top) {
                                    Capsule().fill(Color.white.opacity(0.22)).frame(height: 8).padding(.horizontal, 10).padding(.top, 3)
                                }
                                .shadow(color: Color.burgundy.opacity(0.35), radius: 8, y: 4)
                                .scaleEffect(x: squishX, y: 2 - squishX)
                                .matchedGeometryEffect(id: "pill", in: ns)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(t.title)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial, in: Capsule())
        .background(Capsule().fill(Color.cream.opacity(0.35)))
        .overlay(
            Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.95), .white.opacity(0.15)], startPoint: .top, endPoint: .bottom), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }

    private func tap(_ t: AppTab) {
        guard t != selection else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.68)) { selection = t }
        squishX = 1.22
        bounce = t
        withAnimation(.spring(response: 0.5, dampingFraction: 0.32).delay(0.06)) {
            squishX = 1
            bounce = nil
        }
    }
}
