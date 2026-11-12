import Foundation

/// Онлайн-Нутрик: бесплатный ИИ через наш Cloudflare Worker (POST /chat).
/// Любая проблема (нет адреса/сети, ошибка, лимит) → nil, и чат молча отвечает офлайн (NutrikBrain).
enum NutrikAI {
    static var isConfigured: Bool { URL(string: NutrikServer.url)?.host != nil }

    /// Сервер сказал «лимит на сегодня» — не дёргаем сеть до завтра (до перезапуска приложения).
    @MainActor private static var pausedDay: String?

    private struct Payload: Encodable {
        struct Msg: Encodable { let role: String; let content: String }
        struct FridgeItem: Encodable { let name: String; let daysLeft: Int; let qty: Int }
        struct RecipeInfo: Encodable { let name: String; let kcal: Int; let time: String; let ingredients: [String]; let missing: [String] }
        struct Context: Encodable {
            let name: String
            let fridge: [FridgeItem]
            let kcalToday: Int
            let kcalGoal: Int
            let dislikes: [String]
            let recipes: [RecipeInfo]
        }
        let deviceId: String
        let messages: [Msg]
        let context: Context
    }
    private struct Answer: Decodable { let reply: String }

    private static func dayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    /// Ответ ИИ на последнее сообщение пользователя (история уже содержит его в `store.data.chat`).
    @MainActor
    static func ask(store: AppStore) async -> NutrikReply? {
        guard store.data.smartNutrik, !UIShot.enabled, isConfigured,
              let base = URL(string: NutrikServer.url) else { return nil }
        if pausedDay == dayKey() { return nil }

        let d = store.data
        let history = d.chat.suffix(10).map {
            Payload.Msg(role: $0.fromUser ? "user" : "assistant", content: String($0.text.prefix(600)))
        }
        guard history.last?.role == "user" else { return nil }
        let have = store.pantryNames
        let recipes = store.rankedRecipes().prefix(8).map { r in
            Payload.RecipeInfo(name: r.name, kcal: r.kcal, time: r.time,
                               ingredients: r.ingredients.map { "\($0.name) \($0.g) g" },
                               missing: r.missing(have))
        }
        let payload = Payload(
            deviceId: d.deviceId,
            messages: Array(history),
            context: .init(name: d.profile.name,
                           fridge: store.sortedPantry.prefix(40).map { .init(name: $0.name, daysLeft: $0.daysLeft, qty: $0.qty) },
                           kcalToday: store.eatenToday, kcalGoal: store.targetCalories,
                           dislikes: d.dislikes, recipes: Array(recipes)))

        var req = URLRequest(url: base.appendingPathComponent("chat"), timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("ios/\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")", forHTTPHeaderField: "X-NutriMate-Client")
        guard let body = try? JSONEncoder().encode(payload) else { return nil }
        req.httpBody = body

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 429 { pausedDay = dayKey(); return nil }
            guard code == 200, let a = try? JSONDecoder().decode(Answer.self, from: data) else { return nil }
            let text = a.reply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            // ИИ не умеет менять данные: если он «отчитался», что что-то добавил/записал/выбросил, —
            // это неправда, отвечаем честно офлайн-Нутриком (он либо сделает действие, либо скажет, что не понял).
            if claimsAction(text) { return nil }
            return NutrikReply(text: text, mood: mood(for: text), recipe: recipeMentioned(in: text, store: store))
        } catch {
            return nil
        }
    }

    /// Рецепт из базы, названный в ответе ИИ (самое длинное совпадение), — для кнопки «Open recipe».
    @MainActor
    static func recipeMentioned(in text: String, store: AppStore) -> String? {
        let t = text.lowercased()
        return store.db.recipes
            .filter { $0.name.count >= 5 && t.contains($0.name.lowercased()) }
            .max { $0.name.count < $1.name.count }?.name
    }

    static func claimsAction(_ text: String) -> Bool {
        let t = text.lowercased()
        let patterns = [
            #"\bi('ve| have)? (just )?(added|put|logged|removed|deleted|froze|frozen|moved|marked|updated|saved)\b"#,
            #"\b(added|logged|moved|put) (it|them|\d+|two|three|some|your|the)\b.*\b(fridge|freezer|pantry|list|diary|log)\b"#,
            #"\b(has|have) been (added|logged|removed|frozen)\b"#,
            #"(добавил|добавила|добавлено|записал|записала|положил|положила|выбросил|удалил|заморозил|отметил)"#,
            #"(қостым|қосылды|жаздым|салдым|тастадым|мұздаттым)"#,
        ]
        return patterns.contains { t.range(of: $0, options: .regularExpression) != nil }
    }

    private static func mood(for text: String) -> NutrikMood {
        let t = text.lowercased()
        if ["🎉", "great", "yay", "awesome", "well done", "супер", "молодец"].contains(where: t.contains) { return .cheer }
        if ["cook", "recipe", "eat", "🍳", "🥗", "готов", "рецепт"].contains(where: t.contains) { return .eating }
        if ["sorry", "😿", "unfortunately", "к сожалению"].contains(where: t.contains) { return .sad }
        return .happy
    }
}
