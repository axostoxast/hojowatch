import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @Query private var watched: [WatchedSubsidy]

    @AppStorage("lastKeyword") private var keyword = "補助"
    @AppStorage("lastArea") private var area = ""
    @State private var results: [Subsidy] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hasSearched = false
    @State private var isShowingPaywall = false

    private var watchedIDs: Set<String> { Set(watched.map(\.subsidyID)) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("キーワード（例: 設備、IT導入、創業）", text: $keyword)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    Picker("地域", selection: $area) {
                        Text("すべての地域").tag("")
                        ForEach(Prefectures.all, id: \.self) { Text($0).tag($0) }
                    }
                    Button {
                        Task { await search() }
                    } label: {
                        Label("受付中の補助金を検索", systemImage: "magnifyingglass")
                    }
                    .disabled(isLoading)
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                if hasSearched && !isLoading && errorMessage == nil {
                    Section {
                        if results.isEmpty {
                            Text("条件に合う受付中の補助金はありませんでした")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(results) { subsidy in
                            SubsidyRow(subsidy: subsidy, isWatched: watchedIDs.contains(subsidy.id)) {
                                toggleWatch(subsidy)
                            }
                        }
                    } header: {
                        Text("\(results.count)件（締切が近い順）")
                    } footer: {
                        AttributionText()
                    }
                }
            }
            .overlay {
                if isLoading { ProgressView("検索中…") }
            }
            .navigationTitle("補助金を探す")
            .sheet(isPresented: $isShowingPaywall) { PaywallView() }
            #if DEBUG
            // スクリーンショット・動作確認用: 起動時に検索を実行する
            .task {
                if ProcessInfo.processInfo.arguments.contains("-autoSearch"), !hasSearched { await search() }
            }
            #endif
        }
    }

    private func search() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false; hasSearched = true }
        do {
            results = try await JGrantsClient().search(keyword: keyword, area: area.isEmpty ? nil : area)
        } catch let error as JGrantsClient.ClientError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "補助金情報を取得できませんでした。通信状況を確認してください"
        }
    }

    private func toggleWatch(_ subsidy: Subsidy) {
        if let existing = watched.first(where: { $0.subsidyID == subsidy.id }) {
            context.delete(existing)
            return
        }
        guard WatchPolicy.canAdd(currentCount: watched.count, isPro: store.isPro) else {
            isShowingPaywall = true
            return
        }
        context.insert(WatchedSubsidy(subsidy))
        Task { _ = await DeadlineNotifier.requestAuthorization() }
    }
}

struct SubsidyRow: View {
    let subsidy: Subsidy
    let isWatched: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Link(destination: subsidy.portalURL) {
                    Text(subsidy.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                }
                .tint(.primary)
                DeadlineBadge(endAt: subsidy.endAt)
                Text(Deadline.amountLabel(subsidy.maxLimit))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let area = subsidy.targetArea {
                    Text(area)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(isWatched ? "ウォッチを外す" : "ウォッチする",
                   systemImage: isWatched ? "bell.fill" : "bell", action: onToggle)
                .labelStyle(.iconOnly)
                .font(.title3)
                .buttonStyle(.borderless)
                .sensoryFeedback(.selection, trigger: isWatched)
        }
        .padding(.vertical, 2)
    }
}

struct DeadlineBadge: View {
    let endAt: Date?

    var body: some View {
        let days = endAt.map { Deadline.daysLeft(until: $0) }
        Text(Deadline.label(for: endAt))
            .font(.caption.bold())
            .foregroundStyle(days.map { $0 <= 3 } == true ? .red : .accentColor)
    }
}

struct AttributionText: View {
    var body: some View {
        Text("出典：Jグランツ。このアプリは、政府公式の補助金申請システムjGrantsのWeb-API機能を利用して取得した情報をもとに、補助金ウォッチ（個人開発・非公式）が表示しています。内容は日本国政府及び自治体によって保証されたものではありません。申請要件・締切は必ず公募要領で確認してください。")
            .font(.caption2)
    }
}
