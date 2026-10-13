import SwiftUI

struct SettingsView: View {
    @Environment(ProStore.self) private var store
    @AppStorage(NotifySettings.key) private var offsetsRaw = NotifySettings.defaultRaw
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(DeadlineNotifier.candidateOffsets, id: \.self) { offset in
                        Toggle(offsetLabel(offset), isOn: binding(for: offset))
                    }
                } header: {
                    Text("締切前の通知（朝9時）")
                }

                Section("プロ版") {
                    if store.isPro {
                        Label("購入済み", systemImage: "checkmark.seal.fill")
                    } else {
                        Button("プロ版について", systemImage: "star") { isShowingPaywall = true }
                        Text("無料版はウォッチ\(WatchPolicy.freeLimit)件まで")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("このアプリについて") {
                    AttributionText()
                    Link("Jグランツ（補助金の原典）", destination: URL(string: "https://www.jgrants-portal.go.jp/")!)
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $isShowingPaywall) { PaywallView() }
        }
    }

    private func offsetLabel(_ offset: Int) -> String {
        switch offset {
        case 0: "当日"
        case 1: "前日"
        default: "\(offset)日前"
        }
    }

    private func binding(for offset: Int) -> Binding<Bool> {
        Binding {
            NotifySettings.parse(offsetsRaw).contains(offset)
        } set: { isOn in
            var offsets = Set(NotifySettings.parse(offsetsRaw))
            if isOn { offsets.insert(offset) } else { offsets.remove(offset) }
            offsetsRaw = offsets.sorted(by: >).map(String.init).joined(separator: ",")
        }
    }
}
