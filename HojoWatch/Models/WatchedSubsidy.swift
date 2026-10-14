import Foundation
import SwiftData

@Model
final class WatchedSubsidy {
    @Attribute(.unique) var subsidyID: String
    var title: String
    var targetArea: String?
    var maxLimit: Int?
    var endAt: Date?
    var addedAt: Date
    /// 申請準備のチェックリスト（補助金ごと）
    var checklist: [ChecklistItem] = ChecklistItem.defaults
    var memo: String = ""

    init(_ subsidy: Subsidy, now: Date = .now) {
        subsidyID = subsidy.id
        title = subsidy.title
        targetArea = subsidy.targetArea
        maxLimit = subsidy.maxLimit
        endAt = subsidy.endAt
        addedAt = now
    }

    /// 締切の延長などをjGrantsの最新情報で反映する
    func update(from subsidy: Subsidy) {
        title = subsidy.title
        targetArea = subsidy.targetArea ?? targetArea
        maxLimit = subsidy.maxLimit ?? maxLimit
        if let newEnd = subsidy.endAt { endAt = newEnd }
    }

    var portalURL: URL {
        URL(string: "https://www.jgrants-portal.go.jp/subsidy/\(subsidyID)")!
    }
}

/// 申請準備のチェック項目
struct ChecklistItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var done = false
    /// 締切の何日前までに済ませるか（逆算スケジュール）。nil は期限なし
    var daysBefore: Int?

    /// 期限の日（締切日から逆算。日本時間の暦日）
    func dueDate(endAt: Date?) -> Date? {
        guard let endAt, let daysBefore else { return nil }
        let cal = Deadline.calendar
        return cal.date(byAdding: .day, value: -daysBefore, to: cal.startOfDay(for: endAt))
    }

    /// 多くの補助金で共通する準備と、締切から逆算した目安（補助金ごとに編集できる）。
    /// GビズIDプライムは発行に2〜3週間かかることがあるため早めに置く。
    static let defaults: [ChecklistItem] = [
        ("公募要領を読む", 28),
        ("対象者・対象経費の要件を確認する", 25),
        ("GビズIDプライムを取得する（電子申請に必要）", 21),
        ("見積書をそろえる", 14),
        ("事業計画書を作る", 10),
        ("決算書・登記事項証明書などの書類をそろえる", 7),
        ("Jグランツで申請する", 2),
    ].map { ChecklistItem(title: $0.0, daysBefore: $0.1) }
}

extension WatchedSubsidy {
    var checklistProgress: (done: Int, total: Int) {
        (checklist.filter(\.done).count, checklist.count)
    }

    /// 次にやること（未完了で期限が一番近いもの）
    var nextTask: ChecklistItem? {
        checklist.filter { !$0.done }.min { ($0.dueDate(endAt: endAt) ?? .distantFuture) < ($1.dueDate(endAt: endAt) ?? .distantFuture) }
    }
}
