import SwiftUI
import UIKit

/// Нутрик-помощник: на каждое важное действие выбегает снизу слева (над таб-баром),
/// ест продукт / спотыкается и грустит / радуется, говорит реплику и убегает обратно.
/// Нажатие — убежать сразу. Отключается в Profile → Nutrik.
struct NutrikBuddy: View {
    @EnvironmentObject var store: AppStore
    @State private var current: NutrikReaction?
    @State private var x: CGFloat = -200
    @State private var mood: NutrikMood = .run
    @State private var fallen = false
    @State private var showBubble = false
    @State private var facingLeft = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if showBubble, let c = current {
                Text(c.text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.burgundy)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 240, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.paper.opacity(0.9), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                    .padding(.leading, 30)
                    .transition(.scale(scale: 0.6, anchor: .bottomLeading).combined(with: .opacity))
            }
            // Пока сценки нет — Нутрик не рисуется вовсе (раньше невидимый анимировался всегда)
            if current != nil {
                NutrikView(mood: mood, size: 74, food: current?.emoji, clumsy: false)
                    .scaleEffect(x: facingLeft ? -1 : 1, y: 1)
                    .rotationEffect(.degrees(fallen ? -82 : 0), anchor: .bottomLeading)
                    .offset(y: fallen ? 6 : 0)
                    .allowsHitTesting(false)
            } else {
                Color.clear.frame(width: 74, height: 85)
            }
        }
        .offset(x: x)
        .padding(.leading, 10)
        .padding(.bottom, 4)
        .opacity(current == nil ? 0 : 1)
        .contentShape(Rectangle())
        .onTapGesture { runAway() }
        .allowsHitTesting(current != nil)
        .onChange(of: store.reaction) {
            if let r = store.reaction { play(r) }
        }
        .accessibilityHidden(current == nil)
    }

    private func pause(_ s: Double) async -> Bool {
        try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000))
        return !Task.isCancelled
    }

    private func play(_ r: NutrikReaction) {
        task?.cancel()
        task = Task { @MainActor in
            // небольшая пауза — чтобы успел закрыться лист, из которого пришло действие
            guard await pause(0.3) else { return }
            current = r
            showBubble = false
            fallen = false
            facingLeft = false
            mood = .run
            x = -200
            withAnimation(.easeOut(duration: 0.7)) { x = 0 }
            guard await pause(0.7) else { return }

            switch r.kind {
            case .sad:
                // неуклюжий: спотыкается, падает, лежит со звёздочками, встаёт грустный
                mood = .fall
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { fallen = true }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.3)) { showBubble = true }
                guard await pause(1.3) else { return }
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { fallen = false }
                mood = .sad
                guard await pause(1.6) else { return }
            case .eat:
                mood = .eating
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showBubble = true }
                guard await pause(2.6) else { return }
            case .cheer:
                mood = .cheer
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showBubble = true }
                guard await pause(2.3) else { return }
            }
            await leave()
        }
    }

    @MainActor private func leave() async {
        withAnimation(.easeOut(duration: 0.2)) { showBubble = false }
        facingLeft = true
        mood = .run
        withAnimation(.easeIn(duration: 0.65)) { x = -200 }
        guard await pause(0.65) else { return }
        current = nil
        store.reaction = nil
    }

    private func runAway() {
        task?.cancel()
        task = Task { @MainActor in await leave() }
    }
}
