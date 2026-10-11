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
