import Foundation

/// アプリからウィジェットへ渡す、ウォッチ中の補助金の締切（App Groupに保存）
struct WidgetSnapshot: Codable, Equatable {
    struct Item: Codable, Equatable {
        var id: String
        var title: String
        var endAt: Date
    }

    var items: [Item]

    static let appGroup = "group.com.sidebiz.hojowatch"
    static let fileName = "widget-snapshot.json"
    static let widgetKind = "DeadlineWidget"

    static var url: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.appendingPathComponent(fileName)
    }

    /// 締切が過ぎていないものを近い順に
    static func make(_ items: [Item], now: Date = .now, calendar: Calendar) -> WidgetSnapshot {
        let today = calendar.startOfDay(for: now)
        return WidgetSnapshot(items: items.filter { calendar.startOfDay(for: $0.endAt) >= today }.sorted { $0.endAt < $1.endAt })
    }

    static func load() -> WidgetSnapshot {
        guard let url, let data = try? Data(contentsOf: url),
              let s = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot(items: []) }
        return s
    }

    func save() {
        guard let url = Self.url, let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
