import SwiftUI

/// Чат с Нутриком: офлайн-«AI» (NutrikBrain), история сохраняется, ответы с кнопкой рецепта.
struct ChatView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    @State private var typing = false
    @State private var mood: NutrikMood = .wave
    @FocusState private var focused: Bool

    private var greeting: ChatMessage {
        ChatMessage(text: L("Hi, {0}! I'm Nutrik 🐾 Ask me what to cook, what expires soon, how to store food — or tell me what you don't like.", store.data.profile.name), fromUser: false)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            bubble(greeting)
                            ForEach(store.data.chat) { m in
                                bubble(m)
                                    .id(m.id)
                                    .transition(.asymmetric(insertion: .scale(scale: 0.8, anchor: m.fromUser ? .bottomTrailing : .bottomLeading).combined(with: .opacity), removal: .opacity))
                            }
                            if typing {
                                HStack { TypingDots(); Spacer() }.id("typing").transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onAppear { scrollDown(proxy, animated: false) }
                    .onChange(of: store.data.chat.count) { scrollDown(proxy) }
                    .onChange(of: typing) { scrollDown(proxy) }
                }
                suggestionsRow
                inputBar
            }
            .background(LiveBackground())
            .navigationTitle(L("Chat with Nutrik"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }.fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button(role: .destructive) {
                            withAnimation { store.data.chat.removeAll() }
                        } label: { Label(L("Clear chat"), systemImage: "trash") }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .navigationDestination(for: Recipe.self) { r in RecipeDetail(recipe: r) }
        }
        .tint(Color.burgundy)
    }

    private var aiOn: Bool { store.data.smartNutrik && NutrikAI.isConfigured }
    private var statusLine: String { aiOn ? L("Smart AI · online ✨") : L("Your zero-waste buddy · works offline") }

    private var header: some View {
        HStack(spacing: 12) {
            NutrikView(mood: typing ? .talk : mood, size: 58)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Nutrik")).font(.headline).foregroundStyle(Color.burgundy)
                Text(typing ? L("typing…") : statusLine)
                    .font(.caption).foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.paper.opacity(0.7)).frame(height: 1) }
    }

    @ViewBuilder private func bubble(_ m: ChatMessage) -> some View {
        HStack(alignment: .bottom) {
            if m.fromUser { Spacer(minLength: 50) }
            VStack(alignment: .leading, spacing: 8) {
                Text(m.text)
                    .font(.callout)
                    .foregroundStyle(m.fromUser ? Color.cream : Color.burgundy)
                    .fixedSize(horizontal: false, vertical: true)
                if m.ai == true {
                    Text(L("✨ AI · can be wrong"))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.burgundy.opacity(0.45))
                }
                if let name = m.recipe, let r = store.db.recipes.first(where: { $0.name == name }) {
                    NavigationLink(value: r) {
                        Label(L("Open recipe"), systemImage: "book.fill")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Capsule().fill(Color.burgundy.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.burgundy)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(m.fromUser
                          ? AnyShapeStyle(LinearGradient(colors: [.brandLight, .brand], startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(Color.paper.opacity(0.82)))
            }
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(m.fromUser ? Color.white.opacity(0.25) : Color.paper.opacity(0.9), lineWidth: 1))
            .textSelection(.enabled)
            if !m.fromUser { Spacer(minLength: 50) }
        }
    }

    private var suggestionsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(NutrikBrain.suggestions, id: \.self) { s in
                    Button { send(L(s)) } label: { Chip(text: L(s)) }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .disabled(typing)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(L("Ask Nutrik…"), text: $input, axis: .vertical)
                .lineLimit(1...4)
                .focused($focused)
                .submitLabel(.send)
                .onSubmit { send(input) }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.paper.opacity(0.9), lineWidth: 1))
            Button { send(input) } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.cream)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(LinearGradient(colors: [.brandLight, .brand], startPoint: .top, endPoint: .bottom)))
                    .shadow(color: Color.brand.opacity(0.3), radius: 6, y: 3)
            }
            .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || typing)
            .opacity(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !typing else { return }
        input = ""
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            store.data.chat.append(ChatMessage(text: text, fromUser: true))
            typing = true
        }
        let started = Date()
        Task { @MainActor in
            // Команды (покупки, «не люблю») — локально; остальное — онлайн-ИИ, при любой проблеме — офлайн-Нутрик.
            var r: NutrikReply? = nil
            var fromAI = false
            if !NutrikBrain.isLocalCommand(text), let ai = await NutrikAI.ask(store: store) {
                r = ai; fromAI = true
            }
            let minDelay = 0.55 + Double.random(in: 0...0.4)
            let wait = minDelay - Date().timeIntervalSince(started)
            if wait > 0 { try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) }
            let reply = r ?? NutrikBrain.reply(to: text, store: store)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                typing = false
                mood = reply.mood == .talk ? .happy : reply.mood
                store.data.chat.append(ChatMessage(text: reply.text, fromUser: false, recipe: reply.recipe, ai: fromAI ? true : nil))
                if store.data.chat.count > 80 { store.data.chat.removeFirst(store.data.chat.count - 80) }
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            store.checkMedals()
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = typing ? AnyHashable("typing") : store.data.chat.last.map { AnyHashable($0.id) }
        guard let target else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if animated { withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .bottom) } }
            else { proxy.scrollTo(target, anchor: .bottom) }
        }
    }
}

/// Три прыгающие точки «Нутрик печатает».
struct TypingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.burgundy.opacity(0.7))
                        .frame(width: 8, height: 8)
                        .offset(y: -4 * max(0, sin(t * 7 - Double(i) * 0.8)))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.paper.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.paper.opacity(0.9), lineWidth: 1))
        }
    }
}
