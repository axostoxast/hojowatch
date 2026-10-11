import SwiftData
import SwiftUI

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchedSubsidy.endAt) private var watched: [WatchedSubsidy]

    var body: some View {
        NavigationStack {
            List {
                ForEach(watched) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Link(destination: item.portalURL) {
                            Text(item.title)
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                        }
                        .tint(.primary)
                        DeadlineBadge(endAt: item.endAt)
                        Text(Deadline.amountLabel(item.maxLimit))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { offsets in
                    offsets.map { watched[$0] }.forEach(context.delete)
                }
            }
            .overlay {
                if watched.isEmpty {
                    ContentUnavailableView(
                        "ウォッチ中の補助金はありません",
                        systemImage: "bell.slash",
                        description: Text("「探す」で気になる補助金のベルを押すと、締切前に通知します")
                    )
                }
            }
            .navigationTitle("ウォッチ")
        }
    }
}
