import StoreKit
import UIKit

/// 使い込んでくれた人にだけ、App Storeの評価をお願いする。
/// 実際にダイアログを出すかどうかと回数の上限（1年に3回まで）はAppleが決める。
@MainActor
enum ReviewPrompt {
    private static let key = "reviewPrompt.successCount"

    /// 目的を果たした操作（半荘の記録、1セット解き終えたなど）のたびに呼ぶ。
    /// 回数が milestones のどれかに達したときだけお願いする。
    static func recordSuccess(milestones: Set<Int> = [5, 30, 100]) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") { return }
        #endif
        let n = UserDefaults.standard.integer(forKey: key) + 1
        UserDefaults.standard.set(n, forKey: key)
        guard milestones.contains(n) else { return }
        Task { @MainActor in
            // 画面の切り替えが落ち着いてから出す
            try? await Task.sleep(for: .seconds(1.2))
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
