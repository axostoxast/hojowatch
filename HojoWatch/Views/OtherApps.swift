import SwiftUI

/// 同じ開発者のほかのアプリ（タップでApp Storeを開く）
struct OtherAppsSection: View {
    struct Item: Identifiable {
        let id: String
        let name: String
        let detail: String
        let symbol: String
    }

    static let mahjong: [Item] = [
        Item(id: "6450893374", name: "麻雀点数表示", detail: "点棒いらず。卓の真ん中に置く点数表示", symbol: "rectangle.grid.2x2"),
        Item(id: "6822218449", name: "麻雀成績表", detail: "ウマ・オカ込みの精算と通算成績", symbol: "list.number"),
        Item(id: "6822173418", name: "麻雀点数計算ドリル", detail: "符と翻から点数を答える練習問題", symbol: "graduationcap"),
        Item(id: "6822353532", name: "麻雀待ち判定", detail: "待ち牌と役・符・点数がわかる", symbol: "questionmark.square"),
        Item(id: "6822556543", name: "麻雀何切る問題", detail: "向聴数と受け入れ枚数で牌効率を練習", symbol: "hand.point.up"),
    ]
    static let business: [Item] = [
        Item(id: "6821510788", name: "補助金ウォッチ", detail: "補助金の締切を通知。申請準備も逆算", symbol: "bell.badge"),
        Item(id: "6820345195", name: "棚卸カウンター", detail: "バーコードで在庫を数える棚卸アプリ", symbol: "barcode.viewfinder"),
        Item(id: "6822750481", name: "証明写真・履歴書・職務経歴書", detail: "背景を消した写真をそのまま履歴書に", symbol: "person.crop.square"),
    ]

    let items: [Item]
    /// このアプリ自身のApp Store ID（一覧から外す）
    let current: String

    var body: some View {
        Section("ほかのアプリ") {
            ForEach(items.filter { $0.id != current }) { item in
                Link(destination: URL(string: "https://apps.apple.com/jp/app/id\(item.id)")!) {
                    HStack(spacing: 12) {
                        Image(systemName: item.symbol).frame(width: 24).foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name).foregroundStyle(.primary)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.forward.app").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
