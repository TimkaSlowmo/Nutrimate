import SwiftUI
import UserNotifications

/// Таймер шага в режиме готовки.
struct CookTimer: Equatable {
    let step: Int
    let seconds: Int
    var end: Date
}

/// Режим готовки «Готовим с Нутриком»: подготовка → шаги крупно по одному (свайп или «Далее») → финиш.
/// Таймеры берутся из текста шага («cook 8–10 minutes» → 8 мин), работают и с выключенным экраном
/// (локальное уведомление), экран во время готовки не гаснет. У каждого шага — продукты, которые в нём нужны.
struct CookModeView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    var onCooked: () -> Void = {}

    @State private var page: Int
    @State private var timers: [String: CookTimer] = [:]
    @State private var rung: Set<String> = []
    @State private var now = Date()
    @State private var portions = 1
    @State private var alert: String? = nil
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init(recipe: Recipe, startPage: Int = 0, onCooked: @escaping () -> Void = {}) {
        self.recipe = recipe
        self.onCooked = onCooked
        _page = State(initialValue: max(0, min(startPage, recipe.steps.count + 1)))
    }

    private var steps: [String] { recipe.localizedSteps }
    private var lastPage: Int { steps.count + 1 }   // 0 — подготовка, 1…N — шаги, N+1 — готово

    var body: some View {
        VStack(spacing: 0) {
            header
            if let running = otherRunningTimer {
                runningPill(running)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            TabView(selection: $page) {
                prepPage.tag(0)
                ForEach(0..<steps.count, id: \.self) { i in
                    stepPage(i).tag(i + 1)
                }
                finishPage.tag(lastPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.25), value: page)

            NutrikSays(text: nutrikLine, mood: page == lastPage ? .cheer : (alert != nil ? .wave : .happy), size: 58)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            if page < lastPage { controls }
        }
        .background(LiveBackground())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: otherRunningTimer?.step)
        .onReceive(tick) { d in
            now = d
            for (k, t) in timers where t.end <= d && !rung.contains(k) {
                rung.insert(k)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                alert = L("⏰ Step {0}: time's up! Check it 👀", t.step + 1)
            }
        }
        .onChange(of: page) { alert = nil }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            if UIShot.enabled, UIShot.args.contains("-cookTimer"), page >= 1, page <= recipe.steps.count,
               let secs = Recipe.durations(in: recipe.steps[page - 1]).first {
                start(page - 1, secs, elapsed: min(secs - 30, 187))
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            let ids = timers.keys.map { "nutrimate.cook.\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Шапка и кнопки

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(Color.burgundy)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Color.glassFill))
                }
                .accessibilityLabel(L("Close"))
                Spacer()
                VStack(spacing: 1) {
                    Text("\(recipe.emoji) \(N(recipe.name))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.burgundy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(pageTitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            HStack(spacing: 4) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i <= page ? Color.brand : Color.brand.opacity(0.15))
                        .frame(height: 5)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: page)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var pageTitle: String {
        if page == 0 { return L("Get ready") }
        if page == lastPage { return L("Done!") }
        return L("Step {0} of {1}", page, steps.count)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if page > 0 {
                Button { go(page - 1) } label: {
                    Label(L("Back"), systemImage: "chevron.left").frame(maxWidth: .infinity)
                }
                .buttonStyle(SoftButtonStyle())
                .frame(maxWidth: 130)
            }
            Button { go(page + 1) } label: {
                Text(page == 0 ? L("Let's cook ▶︎") : page == steps.count ? L("Finish 🎉") : L("Next"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func go(_ p: Int) {
        UISelectionFeedbackGenerator().selectionChanged()
        withAnimation(.easeInOut(duration: 0.25)) { page = max(0, min(lastPage, p)) }
    }

    private var nutrikLine: String {
        if let alert { return alert }
        if page == 0 {
            let miss = recipe.missing(store.pantryNames).count
            return miss == 0 ? L("You have everything! Let's cook together — swipe or tap Next 🐾")
                             : L("Let's cook together! Something is missing — maybe swap it or skip it 🐾")
        }
        if page == lastPage { return L("Yum! Tell me how many portions you ate — I'll log them 🍽️") }
        let i = page - 1
        if !Recipe.durations(in: recipe.steps[i]).isEmpty { return L("Start the timer — I'll call you, even if the screen is off ⏰") }
        let tips = [LK("Take your time — cooking is not a race 🐾"), LK("Smells good already! 😋"),
                    LK("Tip: clean as you go — less mess at the end 🧽"), LK("Taste it — a pinch of salt fixes a lot 🧂"),
                    LK("You're doing great, chef! 👩‍🍳")]
        return L(tips[i % tips.count])
    }

    // MARK: - Страницы

    private var prepPage: some View {
        let have = store.pantryNames
        let missing = recipe.missing(have)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 6) {
                    Text(recipe.emoji).font(.system(size: 64))
                    Text(N(recipe.name)).font(.title2.bold()).foregroundStyle(Color.burgundy).multilineTextAlignment(.center)
                    Text(L("⏱ {0} · {1} · {2} kcal each", recipe.localTime, Lp(recipe.servings, "serving|servings"), recipe.kcal))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 10) {
                    SectionTitle(text: L("Get everything ready"))
                    ForEach(recipe.ingredients, id: \.name) { i in
                        HStack(spacing: 10) {
                            Text(store.db.byName[i.name]?.emoji ?? "•").font(.title3)
                            Text(N(i.name)).font(.body)
                            Spacer()
                            Text(L("{0} g", i.g)).foregroundStyle(.secondary)
                            Image(systemName: have.contains(i.name) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(have.contains(i.name) ? Color.freshGreen : Color.burgundy.opacity(0.35))
                        }
                    }
                    Text(L("Also: {0}", recipe.localStaples)).font(.caption).foregroundStyle(.secondary)
                    if !missing.isEmpty {
                        Button { store.addShopping(missing) } label: {
                            Label(L("Add {0} missing to shopping list", missing.count), systemImage: "cart.badge.plus")
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
                .glassCard()
                let timed = recipe.steps.indices.filter { !Recipe.durations(in: recipe.steps[$0]).isEmpty }.count
                if timed > 0 {
                    Label(L("{0} steps have a timer — I'll ring when it's time", timed), systemImage: "timer")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.burgundy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 16, padding: 12)
                }
            }
            .padding(16)
        }
    }

    private func stepPage(_ i: Int) -> some View {
        let used = recipe.ingredients(forStep: i)
        let durations = Recipe.durations(in: recipe.steps[i])
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("\(i + 1)")
                    .font(.title.bold())
                    .foregroundStyle(Color.cream)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.brand))
                Text(steps[i])
                    .font(.title2.weight(.medium))
                    .foregroundStyle(Color.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !used.isEmpty {
                    StepChips(items: used.map { ing in
                        "\(store.db.byName[ing.name]?.emoji ?? "•") \(N(ing.name)) · " + L("{0} g", ing.g)
                    })
                }
                ForEach(durations, id: \.self) { secs in
                    timerCard(step: i, secs: secs)
                }
            }
            .padding(20)
        }
    }

    private var finishPage: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("🎉").font(.system(size: 72))
                Text(L("{0} is ready!", N(recipe.name)))
                    .font(.title2.bold())
                    .foregroundStyle(Color.burgundy)
                    .multilineTextAlignment(.center)
                VStack(spacing: 12) {
                    Stepper(L("Portions eaten: {0} · {1} kcal", portions, recipe.kcal * portions),
                            value: $portions, in: 1...max(1, recipe.servings))
                    Button {
                        store.cook(recipe, portions: portions)
                        dismiss()
                        onCooked()
                    } label: {
                        Text(L("I cooked it! 👩‍🍳")).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text(L("Ingredients from your fridge are used up — the ones expiring first."))
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if recipe.servings > portions {
                        Text(L("Leftovers? Put them in the fridge — Nutrik will remind you 🥡"))
                            .font(.caption).foregroundStyle(Color.freshGreen).multilineTextAlignment(.center)
                    }
                }
                .glassCard()
                Button { go(lastPage - 1) } label: {
                    Label(L("Back"), systemImage: "chevron.left")
                }
                .buttonStyle(SoftButtonStyle())
            }
            .padding(20)
        }
    }

    // MARK: - Таймеры

    private func key(_ step: Int, _ secs: Int) -> String { "\(step)-\(secs)" }

    @ViewBuilder
    private func timerCard(step: Int, secs: Int) -> some View {
        let k = key(step, secs)
        if let t = timers[k] {
            let left = max(0, Int(ceil(t.end.timeIntervalSince(now))))
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(Color.brand.opacity(0.15), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: CGFloat(left) / CGFloat(max(1, t.seconds)))
                        .stroke(left == 0 ? Color.freshGreen : Color.brand, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: left)
                    Image(systemName: left == 0 ? "checkmark" : "timer")
                        .font(.headline)
                        .foregroundStyle(left == 0 ? Color.freshGreen : Color.burgundy)
                }
                .frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 2) {
                    Text(left == 0 ? L("Time's up!") : Self.clock(left))
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(left == 0 ? Color.freshGreen : Color.burgundy)
                    Text(L("Timer · {0}", Self.duration(secs))).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    if left > 0 {
                        Button(L("+1 min")) { extend(k, by: 60) }
                            .font(.caption.weight(.bold))
                            .buttonStyle(.bordered)
                            .tint(Color.burgundy)
                    }
                    Button { stop(k) } label: { Image(systemName: "xmark") }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.bordered)
                        .tint(Color.burgundy)
                        .accessibilityLabel(L("Cancel"))
                }
            }
            .glassCard(radius: 20, padding: 14)
        } else {
            Button { start(step, secs) } label: {
                Label(L("Start timer · {0}", Self.duration(secs)), systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SoftButtonStyle())
        }
    }

    /// Таймер, запущенный на другом шаге — плашка сверху, по нажатию — к его шагу.
    private var otherRunningTimer: CookTimer? {
        timers.values
            .filter { $0.step + 1 != page }
            .min { $0.end < $1.end }
    }

    private func runningPill(_ t: CookTimer) -> some View {
        let left = max(0, Int(ceil(t.end.timeIntervalSince(now))))
        return Button { go(t.step + 1) } label: {
            HStack(spacing: 8) {
                Image(systemName: left == 0 ? "bell.fill" : "timer")
                Text(L("Step {0}", t.step + 1)).font(.subheadline.weight(.semibold))
                Spacer()
                Text(left == 0 ? L("Time's up!") : Self.clock(left)).font(.subheadline.weight(.bold).monospacedDigit())
            }
            .foregroundStyle(Color.cream)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(left == 0 ? Color.freshGreen : Color.brand))
        }
        .buttonStyle(.plain)
    }

    private func start(_ step: Int, _ secs: Int, elapsed: Int = 0) {
        let k = key(step, secs)
        timers[k] = CookTimer(step: step, seconds: secs, end: Date().addingTimeInterval(TimeInterval(secs - elapsed)))
        rung.remove(k)
        alert = nil
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        schedule(k, step: step, after: secs - elapsed)
    }

    private func extend(_ k: String, by s: Int) {
        guard var t = timers[k] else { return }
        t.end = max(t.end, Date()).addingTimeInterval(TimeInterval(s))
        timers[k] = t
        schedule(k, step: t.step, after: Int(t.end.timeIntervalSinceNow))
    }

    private func stop(_ k: String) {
        timers[k] = nil
        rung.remove(k)
        alert = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["nutrimate.cook.\(k)"])
    }

    /// Локальное уведомление — сработает и при выключенном экране.
    private func schedule(_ k: String, step: Int, after secs: Int) {
        guard !UIShot.enabled, secs > 0 else { return }
        let title = L("⏰ Time's up — step {0}", step + 1)
        let body = "\(recipe.emoji) \(N(recipe.name)) · " + L("Nutrik says: check it!")
        Reminders.requestPermission { granted in
            guard granted else { return }
            let c = UNMutableNotificationContent()
            c.title = title
            c.body = body
            c.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(secs), repeats: false)
            UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "nutrimate.cook.\(k)", content: c, trigger: trigger))
        }
    }

    static func clock(_ s: Int) -> String {
        s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60) : String(format: "%02d:%02d", s / 60, s % 60)
    }

    static func duration(_ s: Int) -> String {
        if s < 60 { return L("{0} s", s) }
        let h = s / 3600, m = s / 60 % 60
        if h == 0 { return L("{0} min", m) }
        return m == 0 ? L("{0} h", h) : L("{0} h {1} min", h, m)
    }
}

/// Чипы продуктов шага (переносятся на новую строку; FlowLayout — из SearchView).
struct StepChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { t in
                Text(t)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.burgundy)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.glassFill))
                    .overlay(Capsule().strokeBorder(Color.paper.opacity(0.8), lineWidth: 1))
            }
        }
    }
}

extension Recipe {
    /// Таймеры из английского текста шага: «cook 8–10 minutes» → 8 мин, «1 hour» → 60 мин, «30 seconds» → 30 с.
    /// (Переведённые шаги идут в том же порядке, поэтому время берётся из английского — надёжнее.)
    static func durations(in step: String) -> [Int] {
        let pattern = #"(\d+(?:[.,]\d+)?)(?:\s*(?:–|-|to)\s*\d+(?:[.,]\d+)?)?\s*(seconds?|secs?|minutes?|mins?|hours?|hrs?|h)\b"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let ns = step as NSString
        var out: [Int] = []
        for m in re.matches(in: step, range: NSRange(location: 0, length: ns.length)) {
            let num = Double(ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")) ?? 0
            let unit = ns.substring(with: m.range(at: 2)).lowercased()
            let secs = Int(unit.hasPrefix("s") ? num : unit.hasPrefix("h") ? num * 3600 : num * 60)
            if secs >= 10 && secs <= 6 * 3600 && !out.contains(secs) { out.append(secs) }
        }
        return Array(out.prefix(3))
    }

    /// Ингредиенты, которые упоминаются в шаге (по английскому тексту: «the eggs» → Eggs, «diced chicken» → Chicken Breast).
    func ingredients(forStep i: Int) -> [Ing] {
        guard steps.indices.contains(i) else { return [] }
        let words = steps[i].lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init)
        let stop: Set<String> = ["fresh", "green", "white", "black", "red", "yellow", "sauce", "powder", "dried", "whole", "sweet",
                                 "baby", "leaves", "seeds", "juice", "with", "plain", "greek", "light", "dark", "frozen", "canned",
                                 "ground", "smoked", "sliced", "stale", "cooked", "boiled", "raw", "mixed", "small", "large"]
        return ingredients.filter { ing in
            ing.name.lowercased().split(whereSeparator: { !$0.isLetter }).contains { part in
                var w = String(part)
                if stop.contains(w) { return false }
                if w.hasSuffix("oes") && w.count > 5 { w = String(w.dropLast(2)) }
                else if w.hasSuffix("s") && w.count > 3 { w = String(w.dropLast()) }
                guard w.count >= 3 else { return false }
                let stem = String(w.prefix(6))
                return words.contains { $0.hasPrefix(stem) }
            }
        }
    }
}
