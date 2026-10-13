import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProStore.self) private var store

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("プロ版")
                    .font(.largeTitle.bold())
                VStack(alignment: .leading, spacing: 12) {
                    Label("ウォッチする補助金を無制限に（無料版は3件まで）", systemImage: "bell")
                    Label("一度の購入でずっと使える", systemImage: "checkmark.seal")
                    Text("通知・チェックリスト・カレンダー追加・ウィジェットは無料で使えます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let product = store.product {
                    Button {
                        Task { await store.purchase() }
                    } label: {
                        Text("\(product.displayPrice)で購入")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isPurchasing)
                } else if store.isLoadingProduct {
                    ProgressView("読み込み中…")
                        .frame(maxWidth: .infinity, minHeight: 50)
                } else {
                    Button {
                        Task { await store.load() }
                    } label: {
                        Label("再読み込み", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                Button("購入を復元") {
                    Task { await store.restore() }
                }
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
            .task {
                if store.product == nil { await store.load() }
            }
        }
    }
}
