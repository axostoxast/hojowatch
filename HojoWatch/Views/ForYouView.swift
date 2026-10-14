import SwiftData
import SwiftUI

/// 事業の情報に合いそうな受付中の補助金（新着に印を付ける）
struct ForYouView: View {
    @Environment(\.modelContext) private var context
    @Environment(ProStore.self) private var store
    @Query private var watched: [WatchedSubsidy]

    @State private var profile = ForYouView.initialProfile()
    @State private var matches: [Match] = []
    @State private var seen = SeenMatches.load()
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var editingProfile = false
    @State private var isShowingPaywall = false
    @State private var filter: String?

    /// スクリーンショット用: -demoProfile で事業の情報を入れた状態にする
    private static func initialProfile() -> BusinessProfile {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demoProfile") {
            return BusinessProfile(prefecture: "東京都", industry: "", employees: "20名以下",
                                   purposes: ["設備整備・IT導入をしたい", "販路拡大・海外展開をしたい", "新たな事業を行いたい"])
        }
        #endif
        return BusinessProfile.load()
    }

    private var watchedIDs: Set<String> { Set(watched.map(\.subsidyID)) }
    private var shown: [Match] { filter.map { f in matches.filter { $0.purposes.contains(f) } } ?? matches }

    var body: some View {
        NavigationStack {
            List {
                if !profile.isComplete {
                    Section { setupCard }
                } else {
                    Section {
                        profileSummary
                    }
                    if let errorMessage {
                        Section { Label(errorMessage, systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                    }
                    if profile.purposes.count > 1 {
                        Section {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    chip("すべて", selected: filter == nil) { filter = nil }
                                    ForEach(profile.purposes, id: \.self) { p in
                                        chip(BusinessProfile.shortPurpose(p), selected: filter == p) { filter = p }
                                    }
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                    Section {
                        if !isLoading && shown.isEmpty && errorMessage == nil {
                            Text("いま受付中で条件に合う補助金は見つかりませんでした。条件を広げるか、時間をおいて確認してください。新しく出たら通知します。")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(shown) { m in
                            MatchRow(match: m, isNew: !seen.contains(m.id), isWatched: watchedIDs.contains(m.id)) { toggleWatch(m.subsidy) }
                        }
                    } header: {
                        if !matches.isEmpty {
                            let newCount = matches.filter { !seen.contains($0.id) }.count
                            Text("\(shown.count)件（締切が近い順）" + (newCount > 0 ? "・新着\(newCount)件" : ""))
                        }
                    } footer: {
                        if !matches.isEmpty { AttributionText() }
                    }
                }
            }
            .overlay { if isLoading && matches.isEmpty { ProgressView("合いそうな補助金を探しています…") } }
            .refreshable { await load() }
            .navigationTitle("あなたへの補助金")
            .toolbar {
                if profile.isComplete {
                    Button("条件", systemImage: "slider.horizontal.3") { editingProfile = true }
                }
            }
            .sheet(isPresented: $editingProfile) {
                ProfileEditView(profile: profile) { new in
                    profile = new
                    new.save()
                    Task {
                        await load()
                        _ = await DeadlineNotifier.requestAuthorization()
                    }
                }
            }
            .sheet(isPresented: $isShowingPaywall) { PaywallView() }
            .task { if profile.isComplete && matches.isEmpty { await load() } }
            .onDisappear {
                // 一度表示したものは新着から外す
                if !matches.isEmpty {
                    SeenMatches.markSeen(matches.map(\.id))
                    seen = SeenMatches.load()
                }
            }
        }
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("事業の情報を登録すると、合いそうな補助金を自動で集めます", systemImage: "sparkles")
                .font(.headline)
            Text("地域・業種・従業員数・やりたいこと（設備投資、販路開拓など）から、受付中の補助金を探します。新しい補助金が出たら通知でお知らせします。情報はこのiPhoneの中だけに保存します。")
                .font(.callout)
                .foregroundStyle(.secondary)
            Button("事業の情報を登録する") { editingProfile = true }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 8)
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text([profile.prefecture, profile.industry, profile.employees].filter { !$0.isEmpty }.joined(separator: "・"))
                .font(.subheadline.weight(.semibold))
            Text(profile.purposes.map(BusinessProfile.shortPurpose).joined(separator: "、"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chip(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(selected ? Color.accentColor : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func load() async {
        guard profile.isComplete else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            matches = try await Matcher.find(for: profile)
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

struct MatchRow: View {
    let match: Match
    let isNew: Bool
    let isWatched: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isNew {
                        Text("NEW").font(.caption2.bold()).padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.red, in: Capsule()).foregroundStyle(.white)
                    }
                    Text(match.isLocal ? (match.subsidy.targetArea ?? "地域") : "全国")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Link(destination: match.subsidy.portalURL) {
                    Text(match.subsidy.title).font(.headline).multilineTextAlignment(.leading)
                }
                .tint(.primary)
                DeadlineBadge(endAt: match.subsidy.endAt)
                Text(Deadline.amountLabel(match.subsidy.maxLimit)).font(.caption).foregroundStyle(.secondary)
                Text(match.purposes.map(BusinessProfile.shortPurpose).joined(separator: "・"))
                    .font(.caption2).foregroundStyle(Color.accentColor)
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

/// 事業の情報の登録・変更
struct ProfileEditView: View {
    @State var profile: BusinessProfile
    let onSave: (BusinessProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("所在地") {
                    Picker("都道府県", selection: $profile.prefecture) {
                        Text("選択してください").tag("")
                        ForEach(Prefectures.all, id: \.self) { Text($0).tag($0) }
                    }
                }
                Section {
                    Picker("業種", selection: $profile.industry) {
                        Text("指定しない").tag("")
                        ForEach(BusinessProfile.industryOptions, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("従業員数", selection: $profile.employees) {
                        Text("指定しない").tag("")
                        ForEach(BusinessProfile.employeeOptions, id: \.self) { Text($0).tag($0) }
                    }
                } header: {
                    Text("事業の規模")
                } footer: {
                    Text("指定すると、対象外の補助金を除いて探します。")
                }
                Section {
                    ForEach(BusinessProfile.purposeOptions, id: \.self) { p in
                        Button {
                            if let i = profile.purposes.firstIndex(of: p) { profile.purposes.remove(at: i) }
                            else { profile.purposes.append(p) }
                        } label: {
                            HStack {
                                Text(p).foregroundStyle(.primary)
                                Spacer()
                                if profile.purposes.contains(p) { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                            }
                        }
                    }
                } header: {
                    Text("やりたいこと（複数選べます）")
                }
            }
            .navigationTitle("事業の情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { onSave(profile); dismiss() }.disabled(!profile.isComplete)
                }
            }
        }
    }
}
