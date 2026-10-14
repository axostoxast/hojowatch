import Foundation

/// 利用者の事業の情報。合いそうな補助金を探す条件に使う（端末内だけに保存）
struct BusinessProfile: Codable, Equatable, Sendable {
    var prefecture: String = ""
    var industry: String = ""
    var employees: String = ""
    var purposes: [String] = []

    var isComplete: Bool { !prefecture.isEmpty && !purposes.isEmpty }

    static let storageKey = "businessProfile"

    static func load(_ defaults: UserDefaults = .standard) -> BusinessProfile {
        guard let data = defaults.data(forKey: storageKey),
              let p = try? JSONDecoder().decode(BusinessProfile.self, from: data) else { return BusinessProfile() }
        return p
    }

    func save(_ defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.storageKey) }
    }

    /// jGrantsの「利用目的」の値
    static let purposeOptions = [
        "設備整備・IT導入をしたい",
        "販路拡大・海外展開をしたい",
        "新たな事業を行いたい",
        "人材育成を行いたい",
        "雇用・職場環境を改善したい",
        "研究開発・実証事業を行いたい",
        "事業を引き継ぎたい",
        "資金繰りを改善したい",
        "エコ・SDGs活動支援がほしい",
        "安全・防災対策支援がほしい",
        "イベント・事業運営支援がほしい",
        "まちづくり・地域振興支援がほしい",
    ]

    /// jGrantsの「業種」の値（日本標準産業分類の大分類）
    static let industryOptions = [
        "農業、林業", "漁業", "鉱業、採石業、砂利採取業", "建設業", "製造業",
        "電気・ガス・熱供給・水道業", "情報通信業", "運輸業、郵便業", "卸売業、小売業",
        "金融業、保険業", "不動産業、物品賃貸業", "学術研究、専門・技術サービス業",
        "宿泊業、飲食サービス業", "生活関連サービス業、娯楽業", "教育、学習支援業",
        "医療、福祉", "複合サービス事業", "サービス業（他に分類されないもの）",
    ]

    /// jGrantsの「従業員数」の値
    static let employeeOptions = ["5名以下", "20名以下", "50名以下", "100名以下", "300名以下", "900名以下", "901名以上"]

    /// 画面に出す短い言い方
    static func shortPurpose(_ p: String) -> String {
        p.replacingOccurrences(of: "をしたい", with: "")
            .replacingOccurrences(of: "を行いたい", with: "")
            .replacingOccurrences(of: "を改善したい", with: "の改善")
            .replacingOccurrences(of: "を引き継ぎたい", with: "の承継")
            .replacingOccurrences(of: "支援がほしい", with: "")
    }
}
