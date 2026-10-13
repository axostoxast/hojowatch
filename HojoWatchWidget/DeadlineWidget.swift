import SwiftUI
import WidgetKit

struct DeadlineEntry: TimelineEntry {
    let date: Date
    let items: [WidgetSnapshot.Item]
}

struct DeadlineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeadlineEntry {
        DeadlineEntry(date: .now, items: [
            .init(id: "1", title: "ものづくり補助金", endAt: .now.addingTimeInterval(86400 * 5)),
            .init(id: "2", title: "IT導入補助金", endAt: .now.addingTimeInterval(86400 * 12)),
        ])
    }

    func getSnapshot(in context: Context, completion: @escaping (DeadlineEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeadlineEntry>) -> Void) {
        // 残り日数は日付で変わるので、毎日0時に更新する
        let now = Date.now
        let midnight = Deadline.calendar.date(byAdding: .day, value: 1, to: Deadline.calendar.startOfDay(for: now))!
        completion(Timeline(entries: [entry(at: now), entry(at: midnight)], policy: .after(midnight)))
    }

    private func entry(at date: Date) -> DeadlineEntry {
        let s = WidgetSnapshot.make(WidgetSnapshot.load().items, now: date, calendar: Deadline.calendar)
        return DeadlineEntry(date: date, items: s.items)
    }
}

struct DeadlineWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DeadlineEntry

    var body: some View {
        Group {
            if entry.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Label("補助金ウォッチ", systemImage: "bell").font(.caption.weight(.semibold))
                    Text("ウォッチ中の補助金はありません").font(.caption).foregroundStyle(.secondary)
                }
            } else {
                switch family {
                case .accessoryRectangular:
                    if let first = entry.items.first { row(first, compact: true) }
                case .systemSmall:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("次の締切", systemImage: "bell.fill").font(.caption2.weight(.semibold)).foregroundStyle(.orange)
                        if let first = entry.items.first {
                            Text(daysText(first)).font(.title.weight(.bold)).foregroundStyle(color(first))
                            Text(first.title).font(.caption).lineLimit(3)
                        }
                        Spacer(minLength: 0)
                    }
                default:
                    VStack(alignment: .leading, spacing: 6) {
                        Label("締切が近い補助金", systemImage: "bell.fill").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                        ForEach(entry.items.prefix(3), id: \.id) { row($0, compact: false) }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private func row(_ item: WidgetSnapshot.Item, compact: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(daysText(item))
                .font((compact ? Font.headline : .subheadline).weight(.bold).monospacedDigit())
                .foregroundStyle(compact ? .primary : color(item))
                .frame(minWidth: 44, alignment: .leading)
            Text(item.title).font(.caption).lineLimit(compact ? 2 : 1)
        }
    }

    private func daysText(_ item: WidgetSnapshot.Item) -> String {
        let d = Deadline.daysLeft(until: item.endAt, now: entry.date)
        return d == 0 ? "今日" : "あと\(d)日"
    }

    private func color(_ item: WidgetSnapshot.Item) -> Color {
        Deadline.daysLeft(until: item.endAt, now: entry.date) <= 3 ? .red : .primary
    }
}

@main
struct DeadlineWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetSnapshot.widgetKind, provider: DeadlineProvider()) { entry in
            DeadlineWidgetView(entry: entry)
        }
        .configurationDisplayName("補助金の締切")
        .description("ウォッチ中の補助金を、締切が近い順に表示します。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}
