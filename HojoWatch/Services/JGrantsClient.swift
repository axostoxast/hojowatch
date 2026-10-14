import Foundation

/// jGrants公開API（認証不要・1秒10回まで）。端末から直接呼ぶ
struct JGrantsClient: Sendable {
    static let base = URL(string: "https://api.jgrants-portal.go.jp/exp/v1/public/subsidies")!

    enum ClientError: LocalizedError, Equatable {
        case keywordTooShort
        case badStatus(Int)

        var errorDescription: String? {
            switch self {
            case .keywordTooShort: "キーワードは2文字以上で入力してください"
            case .badStatus(let code): "補助金情報を取得できませんでした（エラー\(code)）"
            }
        }
    }

    private struct Response: Decodable {
        let result: [Subsidy]
    }

    var session: URLSession = .shared

    /// 受付中の補助金を締切が近い順に返す。area が nil なら全地域
    func search(keyword: String, area: String?) async throws -> [Subsidy] {
        var components = URLComponents(url: Self.base, resolvingAgainstBaseURL: false)!
        components.queryItems = try Self.searchQuery(keyword: keyword, area: area)
        return Self.sortedByDeadline(try await fetch(components.url!))
    }

    /// 任意の条件で検索する（事業の情報による絞り込み用）
    func search(queryItems: [URLQueryItem]) async throws -> [Subsidy] {
        var components = URLComponents(url: Self.base, resolvingAgainstBaseURL: false)!
        components.queryItems = queryItems
        return Self.sortedByDeadline(try await fetch(components.url!))
    }

    /// APIのsort指定は締切順にならないことがあるため、手元で並べ直す（締切不明は末尾）
    static func sortedByDeadline(_ items: [Subsidy]) -> [Subsidy] {
        items.sorted { ($0.endAt ?? .distantFuture) < ($1.endAt ?? .distantFuture) }
    }

    func detail(id: String) async throws -> Subsidy? {
        try await fetch(Self.base.appending(path: "id/\(id)")).first
    }

    static func searchQuery(keyword: String, area: String?) throws -> [URLQueryItem] {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { throw ClientError.keywordTooShort }
        var items = [
            URLQueryItem(name: "keyword", value: trimmed),
            URLQueryItem(name: "sort", value: "acceptance_end_datetime"),
            URLQueryItem(name: "order", value: "ASC"),
            URLQueryItem(name: "acceptance", value: "1"),
        ]
        if let area { items.append(URLQueryItem(name: "target_area_search", value: area)) }
        return items
    }

    static func decode(_ data: Data) throws -> [Subsidy] {
        try JSONDecoder().decode(Response.self, from: data).result
    }

    private func fetch(_ url: URL) async throws -> [Subsidy] {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("HojoWatch-iOS/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.badStatus(http.statusCode)
        }
        return try Self.decode(data)
    }
}

enum Prefectures {
    static let all = [
        "北海道", "青森県", "岩手県", "宮城県", "秋田県", "山形県", "福島県",
        "茨城県", "栃木県", "群馬県", "埼玉県", "千葉県", "東京都", "神奈川県",
        "新潟県", "富山県", "石川県", "福井県", "山梨県", "長野県", "岐阜県", "静岡県", "愛知県",
        "三重県", "滋賀県", "京都府", "大阪府", "兵庫県", "奈良県", "和歌山県",
        "鳥取県", "島根県", "岡山県", "広島県", "山口県",
        "徳島県", "香川県", "愛媛県", "高知県",
        "福岡県", "佐賀県", "長崎県", "熊本県", "大分県", "宮崎県", "鹿児島県", "沖縄県",
    ]
}
