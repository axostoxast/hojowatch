import SwiftData
import SwiftUI

@main
struct HojoWatchApp: App {
    @State private var store = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: WatchedSubsidy.self)
    }
}

enum NotifySettings {
    static let key = "notifyOffsets"
    static let defaultRaw = DeadlineNotifier.freeOffsets.map(String.init).joined(separator: ",")

    static func parse(_ raw: String) -> [Int] {
        raw.split(separator: ",").compactMap { Int($0) }.filter(DeadlineNotifier.candidateOffsets.contains)
    }

    /// 無料版は既定のタイミング固定。プロ版は設定値を使う
    static func effective(raw: String, isPro: Bool) -> [Int] {
        isPro ? parse(raw) : DeadlineNotifier.freeOffsets
    }
}

struct RootView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Query private var watched: [WatchedSubsidy]
    @AppStorage(NotifySettings.key) private var offsetsRaw = NotifySettings.defaultRaw

    /// ウォッチ・締切・通知設定・購入状態のどれかが変わったら通知を組み直す
    private var scheduleKey: String {
        let items = watched.map { "\($0.subsidyID)@\($0.endAt?.timeIntervalSince1970 ?? 0)" }.sorted()
        return items.joined(separator: ",") + "|\(offsetsRaw)|\(store.isPro)"
    }

    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("探す", systemImage: "magnifyingglass") }
            WatchListView()
                .tabItem { Label("ウォッチ", systemImage: "bell") }
                .badge(watched.count)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .task(id: scheduleKey) {
            let items = watched.compactMap { w in w.endAt.map { (id: w.subsidyID, title: w.title, endAt: $0) } }
            let offsets = NotifySettings.effective(raw: offsetsRaw, isPro: store.isPro)
            await DeadlineNotifier.reschedule(DeadlineNotifier.plans(for: items, offsets: offsets))
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshWatched() } }
        }
    }

    /// 締切の延長・変更をjGrantsから取り直す（1秒10回の上限に余裕を持たせる）
    private func refreshWatched() async {
        let client = JGrantsClient()
        for item in watched {
            if let latest = try? await client.detail(id: item.subsidyID) {
                item.update(from: latest)
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
    }
}
