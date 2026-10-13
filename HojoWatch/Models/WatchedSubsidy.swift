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

    /// 多くの補助金で共通する準備（補助金ごとに編集できる）
    static let defaults: [ChecklistItem] = [
        "公募要領を読む",
        "対象者・対象経費の要件を確認する",
        "GビズIDプライムを取得する（電子申請に必要）",
        "見積書をそろえる",
        "事業計画書を作る",
        "決算書・登記事項証明書などの書類をそろえる",
        "Jグランツで申請する",
    ].map { ChecklistItem(title: $0) }
}

extension WatchedSubsidy {
    var checklistProgress: (done: Int, total: Int) {
        (checklist.filter(\.done).count, checklist.count)
    }
}
