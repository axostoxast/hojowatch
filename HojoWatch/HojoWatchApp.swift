import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@main
struct HojoWatchApp: App {
    @State private var store = ProStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .modelContainer(for: WatchedSubsidy.self)
        // 事業の情報に合う新しい補助金をバックグラウンドで調べて通知する
        .backgroundTask(.appRefresh(NewMatchChecker.taskID)) {
            await NewMatchChecker.run()
        }
    }
}

enum NotifySettings {
    static let key = "notifyOffsets"
    static let defaultRaw = DeadlineNotifier.defaultOffsets.map(String.init).joined(separator: ",")

    /// 通知のタイミングは誰でも選べる（OS標準の通知を課金対象にしない）
    static func parse(_ raw: String) -> [Int] {
        raw.split(separator: ",").compactMap { Int($0) }.filter(DeadlineNotifier.candidateOffsets.contains)
    }
}

struct RootView: View {
    @Environment(ProStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Query private var watched: [WatchedSubsidy]
    @AppStorage(NotifySettings.key) private var offsetsRaw = NotifySettings.defaultRaw

    /// ウォッチ・締切・通知設定・購入状態のどれかが変わったら通知を組み直す
    private var scheduleKey: String {
        let items = watched.map { w in
            "\(w.subsidyID)@\(w.endAt?.timeIntervalSince1970 ?? 0)#" + w.checklist.map { "\($0.id)\($0.done)\($0.daysBefore ?? -1)" }.joined()
        }.sorted()
        return items.joined(separator: ",") + "|\(offsetsRaw)"
    }

    @Environment(\.modelContext) private var context
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            ForYouView()
                .tabItem { Label("あなたへ", systemImage: "sparkles") }.tag(0)
            SearchView()
                .tabItem { Label("探す", systemImage: "magnifyingglass") }.tag(1)
            WatchListView()
                .tabItem { Label("ウォッチ", systemImage: "bell") }.tag(2)
                .badge(watched.count)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }.tag(3)
        }
        #if DEBUG
        .task { seedDemoIfRequested() }
        #endif
        .task(id: scheduleKey) {
            let items = watched.compactMap { w in w.endAt.map { (id: w.subsidyID, title: w.title, endAt: $0) } }
            let offsets = NotifySettings.parse(offsetsRaw)
            let deadlinePlans = DeadlineNotifier.plans(for: items, offsets: offsets)
            await DeadlineNotifier.reschedule(deadlinePlans)
            // 申請準備の期限の通知（締切の通知を優先し、残りの枠で）
            let inputs = watched.compactMap { w in w.endAt.map { TaskNotifier.Input(id: w.subsidyID, title: w.title, endAt: $0, tasks: w.checklist) } }
            await TaskNotifier.reschedule(TaskNotifier.plans(for: inputs, limit: DeadlineNotifier.maxPending - deadlinePlans.count))
            // ウィジェット用に締切を書き出す
            WidgetSnapshot.make(items.map { .init(id: $0.id, title: $0.title, endAt: $0.endAt) },
                                calendar: Deadline.calendar).save()
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refreshWatched() } }
            if phase == .background { NewMatchChecker.schedule() }
        }
    }

    #if DEBUG
    /// スクリーンショット用: -demoWatch でウォッチ中の補助金を入れ、ウォッチタブを開く
    private func seedDemoIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-autoSearch") { tab = 1 }
        if args.contains("-demoProfile") {
            BusinessProfile(prefecture: "東京都", industry: "", employees: "20名以下",
                            purposes: ["設備整備・IT導入をしたい", "販路拡大・海外展開をしたい", "新たな事業を行いたい"]).save()
        }
        guard args.contains("-demoWatch") else { return }
        if watched.isEmpty {
            let samples: [(String, String, Int, Int)] = [
                ("demo-1", "ものづくり・商業・サービス生産性向上促進補助金（第22次）", 24, 12_500_000),
                ("demo-2", "小規模事業者持続化補助金〈一般型・通常枠〉", 45, 500_000),
                ("demo-3", "東京都 中小企業設備投資支援事業", 9, 30_000_000),
            ]
            for (id, title, days, amount) in samples {
                let s = Subsidy(id: id, title: title, targetArea: "全国", maxLimit: amount,
                                endAt: Calendar.current.date(byAdding: .day, value: days, to: .now))
                let w = WatchedSubsidy(s)
                if id == "demo-1" {
                    for i in 0..<3 { w.checklist[i].done = true }
                    w.memo = "見積書は2社から取る。商工会に事業計画の相談を予約済み。"
                    let page = UIGraphicsImageRenderer(size: CGSize(width: 210, height: 297)).image { ctx in
                        UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 210, height: 297))
                    }
                    for name in ["見積書（A社 加工機）", "見積書（B社 加工機）", "決算書 2025年3月期"] {
                        _ = try? DocumentStore().savePDF(pages: [page], subsidyID: id, name: name)
                    }
                }
                if id == "demo-3" { for i in 0..<5 { w.checklist[i].done = true } }
                context.insert(w)
            }
        }
        tab = args.contains("-settings") ? 3 : 2
    }
    #endif

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
