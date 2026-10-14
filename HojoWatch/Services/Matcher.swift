import Foundation

/// 事業の情報に合いそうな受付中の補助金
struct Match: Identifiable, Hashable, Sendable {
    var subsidy: Subsidy
    /// どの目的の検索で見つかったか
    var purposes: [String]
    /// 都道府県の補助金か（false は全国）
    var isLocal: Bool
    var id: String { subsidy.id }
}

/// 事業の情報から jGrants を検索し、重複をまとめて締切順に並べる
enum Matcher {
    /// 目的ごとに「都道府県」と「全国」の2回検索する（1秒10回の上限に余裕を持たせる）
    static func queries(for p: BusinessProfile) -> [(purpose: String, area: String, items: [URLQueryItem])] {
        p.purposes.flatMap { purpose in
            [p.prefecture, "全国"].filter { !$0.isEmpty }.map { area in
                var items = [
                    URLQueryItem(name: "keyword", value: "事業"),
                    URLQueryItem(name: "sort", value: "acceptance_end_datetime"),
                    URLQueryItem(name: "order", value: "ASC"),
                    URLQueryItem(name: "acceptance", value: "1"),
                    URLQueryItem(name: "use_purpose", value: purpose),
                    URLQueryItem(name: "target_area_search", value: area),
                ]
                if !p.industry.isEmpty { items.append(URLQueryItem(name: "industry", value: p.industry)) }
                if !p.employees.isEmpty { items.append(URLQueryItem(name: "target_number_of_employees", value: p.employees)) }
                return (purpose, area, items)
            }
        }
    }

    static func merge(_ results: [(purpose: String, area: String, subsidies: [Subsidy])], now: Date = .now) -> [Match] {
        var byID: [String: Match] = [:]
        var order: [String] = []
        for r in results {
            for s in r.subsidies {
                // 締切を過ぎたものは除く
                if let end = s.endAt, end < now { continue }
                if var m = byID[s.id] {
                    if !m.purposes.contains(r.purpose) { m.purposes.append(r.purpose) }
                    m.isLocal = m.isLocal || r.area != "全国"
                    byID[s.id] = m
                } else {
                    byID[s.id] = Match(subsidy: s, purposes: [r.purpose], isLocal: r.area != "全国")
                    order.append(s.id)
                }
            }
        }
        return order.compactMap { byID[$0] }
            .sorted { ($0.subsidy.endAt ?? .distantFuture) < ($1.subsidy.endAt ?? .distantFuture) }
    }

    static func find(for profile: BusinessProfile, client: JGrantsClient = JGrantsClient()) async throws -> [Match] {
        var results: [(purpose: String, area: String, subsidies: [Subsidy])] = []
        var lastError: Error?
        for q in queries(for: profile) {
            do {
                results.append((q.purpose, q.area, try await client.search(queryItems: q.items)))
            } catch {
                lastError = error
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        if results.isEmpty, let lastError { throw lastError }
        return merge(results)
    }
}

/// まだ見ていない新着の判定（見た補助金のIDを端末に残す）
enum SeenMatches {
    static let key = "seenMatchIDs"

    static func load(_ defaults: UserDefaults = .standard) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    static func markSeen(_ ids: [String], _ defaults: UserDefaults = .standard) {
        // 古いIDがたまり続けないよう、最新の一覧で置き換える
        defaults.set(ids, forKey: key)
    }

    static func newIDs(in matches: [Match], seen: Set<String>) -> [String] {
        matches.map(\.id).filter { !seen.contains($0) }
    }
}
