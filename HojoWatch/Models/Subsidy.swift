import Foundation

/// jGrantsの補助金1件。一覧APIと詳細APIで型や日時の書式が違うため、どちらも受け付ける
struct Subsidy: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let targetArea: String?
    let maxLimit: Int?
    let endAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title
        case targetArea = "target_area_search"
        case maxLimit = "subsidy_max_limit"
        case endAt = "acceptance_end_datetime"
    }

    init(id: String, title: String, targetArea: String? = nil, maxLimit: Int? = nil, endAt: Date? = nil) {
        self.id = id
        self.title = title
        self.targetArea = targetArea
        self.maxLimit = maxLimit
        self.endAt = endAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        targetArea = try c.decodeIfPresent(String.self, forKey: .targetArea)
        // 一覧は数値、詳細は文字列で返る
        if let number = try? c.decodeIfPresent(Int.self, forKey: .maxLimit) {
            maxLimit = number
        } else {
            maxLimit = (try? c.decodeIfPresent(String.self, forKey: .maxLimit)).flatMap { Int($0) }
        }
        endAt = (try c.decodeIfPresent(String.self, forKey: .endAt)).flatMap(JGrantsDate.parse)
    }

    var portalURL: URL {
        URL(string: "https://www.jgrants-portal.go.jp/subsidy/\(id)")!
    }
}

enum JGrantsDate {
    /// "2026-10-12T14:59:00.000Z"（一覧）と "2026-10-12T14:59Z"（詳細）の両方を読む
    static func parse(_ raw: String) -> Date? {
        var text = raw
        if text.range(of: #"T\d{2}:\d{2}Z$"#, options: .regularExpression) != nil {
            text.insert(contentsOf: ":00", at: text.index(text.endIndex, offsetBy: -1))
        }
        return (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(text, strategy: Date.ISO8601FormatStyle()))
    }
}
