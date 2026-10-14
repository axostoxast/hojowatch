import BackgroundTasks
import Foundation
import UserNotifications

/// アプリを開いていなくても、事業の情報に合う新しい補助金が出たら通知する（バックグラウンド更新）
enum NewMatchChecker {
    static let taskID = "com.sidebiz.hojowatch.refresh"
    private static let notifiedKey = "notifiedMatchIDs"

    /// 次回の更新を予約する（実行のタイミングはiOSが決める）
    static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: taskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    /// 新着を調べて通知する。通知した件数を返す
    @discardableResult
    static func run(defaults: UserDefaults = .standard) async -> Int {
        schedule()
        let profile = BusinessProfile.load(defaults)
        guard profile.isComplete, let matches = try? await Matcher.find(for: profile) else { return 0 }
        let known = SeenMatches.load(defaults).union(defaults.stringArray(forKey: notifiedKey) ?? [])
        let fresh = matches.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return 0 }
        defaults.set(Array(known.union(fresh.map(\.id))), forKey: notifiedKey)

        let content = UNMutableNotificationContent()
        content.title = "合いそうな補助金が\(fresh.count)件見つかりました"
        content.body = fresh.prefix(2).map(\.subsidy.title).joined(separator: "、") + (fresh.count > 2 ? " ほか" : "")
        content.sound = .default
        content.userInfo = ["tab": "forYou"]
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "newmatch-\(Int(Date().timeIntervalSince1970))", content: content, trigger: nil))
        return fresh.count
    }
}
