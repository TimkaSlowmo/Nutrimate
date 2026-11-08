import Foundation
import UserNotifications

/// Локальные уведомления «съешь сегодня» — без сервера, всё планируется на самом iPhone.
/// Одно уведомление в день (в 9:00) на ближайшие 30 дней: что истекает сегодня и завтра.
enum Reminders {
    private static let prefix = "nutrimate.day."

    static func requestPermission(_ done: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { done(granted) }
        }
    }

    static func clear() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    static func reschedule(_ data: AppData) {
        guard data.notifications else { return }
        let items = data.pantry
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let old = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: old)

            let cal = Calendar.current
            let today = cal.startOfDay(for: Date())
            let now = Date()
            for offset in 0..<30 {
                guard let day = cal.date(byAdding: .day, value: offset, to: today),
                      let fire = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day),
                      fire > now else { continue }
                let todayItems = items.filter { cal.isDate($0.expiry, inSameDayAs: day) && $0.storage != .freezer }
                let tomorrow = cal.date(byAdding: .day, value: 1, to: day) ?? day
                let tomorrowItems = items.filter { cal.isDate($0.expiry, inSameDayAs: tomorrow) && $0.storage != .freezer }
                guard !todayItems.isEmpty || !tomorrowItems.isEmpty else { continue }

                let content = UNMutableNotificationContent()
                if !todayItems.isEmpty {
                    content.title = "Eat today: \(list(todayItems))"
                    content.body = tomorrowItems.isEmpty
                        ? "Nutrik found a recipe for it — open NutriMate and rescue your food 🦸"
                        : "Tomorrow: \(list(tomorrowItems)). Open NutriMate for a recipe idea 🍲"
                } else {
                    content.title = "Expires tomorrow: \(list(tomorrowItems))"
                    content.body = "Plan it for dinner or freeze it tonight ❄️ — Nutrik"
                }
                content.sound = .default
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: prefix + "\(offset)", content: content, trigger: trigger))
            }
        }
    }

    private static func list(_ items: [PantryItem]) -> String {
        var names: [String] = []
        for i in items where !names.contains("\(i.emoji) \(i.name)") { names.append("\(i.emoji) \(i.name)") }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return names.prefix(2).joined(separator: ", ") + " +\(names.count - 2)"
    }
}
