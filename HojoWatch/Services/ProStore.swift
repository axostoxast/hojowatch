import Foundation
import Observation
import StoreKit

/// 買い切り「プロ版」（ウォッチ無制限・通知タイミング設定を解放）の購入状態
@MainActor
@Observable
final class ProStore {
    static let productID = "com.sidebiz.hojowatch.pro"

    private(set) var product: Product?
    private(set) var isLoadingProduct = false
    private(set) var isPro = false
    private(set) var isPurchasing = false
    var errorMessage: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
                await self?.refreshEntitlements()
            }
        }
        Task { [weak self] in await self?.load() }
    }

    func load() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
            // 通信は成功しても商品が返らないことがある（未配信の国、反映待ちなど）
            errorMessage = product == nil ? "商品情報を取得できませんでした。時間をおいて再読み込みしてください" : nil
        } catch {
            errorMessage = "商品情報を取得できませんでした。通信状況を確認して再読み込みしてください"
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.productID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    func purchase() async {
        guard let product else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlements()
            case .success(.unverified):
                errorMessage = "購入を確認できませんでした"
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入に失敗しました"
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = "購入の復元に失敗しました"
        }
        await refreshEntitlements()
    }
}
