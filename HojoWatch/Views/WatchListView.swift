import SwiftData
import SwiftUI

struct WatchListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchedSubsidy.endAt) private var watched: [WatchedSubsidy]
    @State private var path: [String] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                ForEach(watched) { item in
                    NavigationLink(value: item.subsidyID) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                                .multilineTextAlignment(.leading)
                            DeadlineBadge(endAt: item.endAt)
                            HStack {
                                Text(Deadline.amountLabel(item.maxLimit))
                                Spacer()
                                let p = item.checklistProgress
                                Label("準備 \(p.done)/\(p.total)", systemImage: "checklist")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
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
            .navigationDestination(for: String.self) { id in
                if let item = watched.first(where: { $0.subsidyID == id }) { WatchDetailView(item: item) }
            }
            #if DEBUG
            .task {
                if ProcessInfo.processInfo.arguments.contains("-openDetail"), let first = watched.first(where: { !$0.memo.isEmpty }) ?? watched.first {
                    try? await Task.sleep(for: .seconds(0.6))
                    path = [first.subsidyID]
                }
            }
            #endif
        }
    }
}
