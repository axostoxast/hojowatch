import Foundation
import UserNotifications

/// 締切までの日数や金額の表示（日本時間の暦日で数える）
enum Deadline {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }()

    static func daysLeft(until end: Date, now: Date = .now) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: end)).day ?? 0
    }

    static func dateLabel(_ end: Date) -> String {
        let parts = calendar.dateComponents([.month, .day], from: end)
        return "\(parts.month ?? 0)/\(parts.day ?? 0)"
    }

    static func label(for end: Date?, now: Date = .now) -> String {
        guard let end else { return "締切は公募要領を確認" }
        let date = dateLabel(end)
        switch daysLeft(until: end, now: now) {
        case ..<0: return "\(date) 締切済み"
        case 0: return "\(date) 本日締切"
        case let days: return "\(date)締切・あと\(days)日"
        }
    }

    static func amountLabel(_ yen: Int?) -> String {
        guard let yen, yen > 0 else { return "上限額は公募要領を確認" }
        if yen >= 100_000_000 {
            return "上限 \(trimmed(Double(yen) / 100_000_000))億円"
        }
        if yen >= 10_000 {
            return "上限 \(trimmed(Double(yen) / 10_000))万円"
        }
        return "上限 \(yen)円"
    }

    private static func trimmed(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).grouping(.automatic))
    }
}

/// 締切前のローカル通知。ウォッチ一覧が変わるたびに全件を組み直す
enum DeadlineNotifier {
    static let candidateOffsets = [30, 14, 7, 3, 1, 0]
    static let freeOffsets = [7, 3, 1]
    static let notifyHour = 9
    /// iOSが保持できる予約は64件まで。余裕を持たせる
    static let maxPending = 60
    private static let idPrefix = "deadline-"

    struct Plan: Equatable {
        let id: String
        let subsidyID: String
        let title: String
        let offset: Int
        let fireDate: Date
        let endAt: Date
    }

    /// 締切日の offset 日前の朝9時（日本時間）。過ぎたものは除き、近い順に上限件数まで
    static func plans(for watched: [(id: String, title: String, endAt: Date)], offsets: [Int], now: Date = .now) -> [Plan] {
        let cal = Deadline.calendar
        let all = watched.flatMap { item in
            offsets.compactMap { offset -> Plan? in
                guard let day = cal.date(byAdding: .day, value: -offset, to: cal.startOfDay(for: item.endAt)),
                      let fire = cal.date(bySettingHour: notifyHour, minute: 0, second: 0, of: day),
                      fire > now, fire < item.endAt else { return nil }
                return Plan(id: "\(idPrefix)\(item.id)-\(offset)", subsidyID: item.id, title: item.title,
                            offset: offset, fireDate: fire, endAt: item.endAt)
            }
        }
        return Array(all.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    static func body(for plan: Plan) -> String {
        plan.offset == 0
            ? "本日（\(Deadline.dateLabel(plan.endAt))）が申請締切です。"
            : "申請締切（\(Deadline.dateLabel(plan.endAt))）まであと\(plan.offset)日です。"
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    @MainActor
    static func reschedule(_ plans: [Plan]) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = body(for: plan)
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

enum WatchPolicy {
    static let freeLimit = 3

    static func canAdd(currentCount: Int, isPro: Bool) -> Bool {
        isPro || currentCount < freeLimit
    }
}
