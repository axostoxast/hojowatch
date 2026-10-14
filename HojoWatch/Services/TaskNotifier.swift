import Foundation
import UserNotifications

/// 申請準備の期限の朝9時に知らせる（未完了の項目だけ）
enum TaskNotifier {
    private static let idPrefix = "task-"

    struct Plan: Equatable {
        let id: String
        let subsidyID: String
        let subsidyTitle: String
        let task: String
        let fireDate: Date
        let endAt: Date
    }

    struct Input {
        let id: String
        let title: String
        let endAt: Date
        let tasks: [ChecklistItem]
    }

    static func plans(for watched: [Input], limit: Int, now: Date = .now) -> [Plan] {
        let cal = Deadline.calendar
        let all = watched.flatMap { w in
            w.tasks.filter { !$0.done }.compactMap { t -> Plan? in
                guard let due = t.dueDate(endAt: w.endAt),
                      let fire = cal.date(bySettingHour: DeadlineNotifier.notifyHour, minute: 0, second: 0, of: due),
                      fire > now else { return nil }
                return Plan(id: "\(idPrefix)\(w.id)-\(t.id.uuidString)", subsidyID: w.id, subsidyTitle: w.title,
                            task: t.title, fireDate: fire, endAt: w.endAt)
            }
        }
        return Array(all.sorted { $0.fireDate < $1.fireDate }.prefix(max(0, limit)))
    }

    @MainActor
    static func reschedule(_ plans: [Plan]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = "今日までの準備：\(plan.task)"
            content.body = "\(plan.subsidyTitle)（締切 \(Deadline.dateLabel(plan.endAt))）"
            content.sound = .default
            content.userInfo = ["subsidyID": plan.subsidyID]
            let parts = Deadline.calendar.dateComponents(in: Deadline.calendar.timeZone, from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(timeZone: parts.timeZone, year: parts.year, month: parts.month,
                                             day: parts.day, hour: parts.hour, minute: parts.minute),
                repeats: false)
            try? await center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }
}
