import SwiftUI

// MARK: - Недельные задания (v32): карточка на Главной и лист с подробностями

/// Кольцо «выполнено N из 3».
struct ChallengeRing: View {
    let done: Int
    let total: Int
    var size: CGFloat = 46
    var body: some View {
        ZStack {
            Circle().stroke(Color.burgundy.opacity(0.12), lineWidth: size * 0.12)
            Circle()
                .trim(from: 0, to: CGFloat(done) / CGFloat(max(1, total)))
                .stroke(LinearGradient(colors: [.brandLight, .brand], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(done == total ? "🏆" : "\(done)/\(total)")
                .font(.system(size: size * (done == total ? 0.42 : 0.3), weight: .bold, design: .rounded))
                .foregroundStyle(Color.burgundy)
        }
        .frame(width: size, height: size)
    }
}

/// Строка задания: эмодзи, название, полоска прогресса, галочка.
struct ChallengeRow: View {
    let c: Challenge
    var showHint = false
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(c.emoji).font(.system(size: 22))
                .frame(width: 40, height: 40)
                .background(Circle().fill(c.done ? Color.freshGreen.opacity(0.18) : Color.paper.opacity(0.7)))
            VStack(alignment: .leading, spacing: 5) {
                Text(c.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.burgundy)
                    .strikethrough(c.done, color: Color.burgundy.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if c.done {
                        Label(L("Done · +{0} XP", Challenges.xpPerQuest), systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.bold)).foregroundStyle(Color.freshGreen)
                    } else if c.missed {
                        Text(L("Not this week — next week you've got it 💪"))
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ProgressBar(value: c.fraction).frame(maxWidth: 140)
                        Text("\(c.progress)/\(c.target)")
                            .font(.caption.weight(.bold).monospacedDigit()).foregroundStyle(Color.burgundy.opacity(0.75))
                    }
                }
                if showHint && !c.done {
                    Text(c.hint).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Карточка на Главной.
struct ChallengesCard: View {
    let w: Challenges
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ChallengeRing(done: w.doneCount, total: w.items.count, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Challenges of the week")).font(.headline).foregroundStyle(Color.burgundy)
                    Text(w.allDone ? L("All done — you're a champion! 🏆") : L("{0} left · +{1} XP each", Lp(w.daysLeft, "day|days"), Challenges.xpPerQuest))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.subheadline.bold()).foregroundStyle(Color.burgundy.opacity(0.5))
            }
            ForEach(w.items) { c in ChallengeRow(c: c) }
        }
        .glassCard(radius: 20, padding: 14)
    }
}

/// Лист с заданиями недели: прогресс, подсказки, награды и итоги за всё время.
struct ChallengesView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let w = store.challenges
        let hist = Challenges.history(store.data.questsDone)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    NutrikSays(text: headline(w), mood: w.allDone ? .happy : .wave, size: 76)

                    HStack(spacing: 14) {
                        ChallengeRing(done: w.doneCount, total: w.items.count, size: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(weekRange(w)).font(.caption.weight(.semibold)).foregroundStyle(Color.burgundy.opacity(0.65))
                            Text(L("{0} of {1} done", w.doneCount, w.items.count)).font(.title3.bold()).foregroundStyle(Color.burgundy)
                            Text(L("New challenges every Monday · {0} left", Lp(w.daysLeft, "day|days")))
                                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .glassCard(radius: 20, padding: 14)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(w.items) { c in
                            ChallengeRow(c: c, showHint: true)
                            if c != w.items.last { Divider().opacity(0.5) }
                        }
                    }
                    .glassCard(radius: 20, padding: 14)

                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("Rewards")).font(.headline).foregroundStyle(Color.burgundy)
                        reward("🎯", L("Each challenge: +{0} XP", Challenges.xpPerQuest))
                        reward("🏆", L("All 3 in a week: +{0} XP bonus and the “Weekly Champion” medal", Challenges.xpBonusAll))
                        reward("🌍", L("Every rescued product also counts for your Eco Impact"))
                    }
                    .glassCard(radius: 20, padding: 14)

                    HStack(spacing: 10) {
                        StatTile(value: "\(hist.quests)", label: L("challenges done"), emoji: "🎯")
                        StatTile(value: "\(hist.weeks)", label: L("champion weeks"), emoji: "🏆")
                        StatTile(value: "\(Challenges.xp(store.data.questsDone))", label: L("XP earned"), emoji: "⭐")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(LiveBackground())
            .navigationTitle(L("Weekly challenges"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("Done")) { dismiss() } } }
        }
    }

    private func headline(_ w: Challenges) -> String {
        if w.allDone { return L("You did all 3 this week! I'm so proud of you 🥹") }
        if w.doneCount > 0 { return L("{0} down, {1} to go — let's save some food together!", w.doneCount, w.items.count - w.doneCount) }
        return L("Three little missions for this week. Every one keeps food out of the bin!")
    }

    private func weekRange(_ w: Challenges) -> String {
        let end = Challenges.calendar.date(byAdding: .day, value: 6, to: w.weekStart) ?? w.weekStart
        let f = Date.FormatStyle.dateTime.day().month(.abbreviated).locale(AppLang.current.locale)
        return "\(w.weekStart.formatted(f)) – \(end.formatted(f))"
    }

    private func reward(_ e: String, _ t: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(e)
            Text(t).font(.subheadline).foregroundStyle(Color.primary.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
        }
    }
}
