import Foundation
import UIKit

/// 補助金ごとの申請書類（スキャンしたPDFや取り込んだファイル）。端末のアプリ内フォルダに保存する
struct DocumentStore {
    var root: URL = URL.documentsDirectory.appending(path: "documents", directoryHint: .isDirectory)

    struct Item: Identifiable, Hashable {
        let url: URL
        let createdAt: Date
        var id: URL { url }
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    func folder(for subsidyID: String) -> URL {
        root.appending(path: subsidyID, directoryHint: .isDirectory)
    }

    func list(for subsidyID: String) -> [Item] {
        let dir = folder(for: subsidyID)
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return urls.map { u in
            Item(url: u, createdAt: (try? u.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// 同じ名前があれば「名前 2」のように番号を付ける
    func uniqueURL(for subsidyID: String, name: String, ext: String) throws -> URL {
        let dir = folder(for: subsidyID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = Self.safe(name)
        var url = dir.appending(path: "\(base).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = dir.appending(path: "\(base) \(n).\(ext)")
            n += 1
        }
        return url
    }

    /// スキャンした画像を1つのPDFにまとめて保存する
    @discardableResult
    func savePDF(pages: [UIImage], subsidyID: String, name: String) throws -> URL {
        let url = try uniqueURL(for: subsidyID, name: name, ext: "pdf")
        // A4（72dpi基準）に合わせて縦横比を保って配置する
        let a4 = CGRect(x: 0, y: 0, width: 595, height: 842)
        try UIGraphicsPDFRenderer(bounds: a4).writePDF(to: url) { ctx in
            for page in pages {
                ctx.beginPage()
                let scale = min(a4.width / page.size.width, a4.height / page.size.height)
                let size = CGSize(width: page.size.width * scale, height: page.size.height * scale)
                page.draw(in: CGRect(x: (a4.width - size.width) / 2, y: (a4.height - size.height) / 2,
                                     width: size.width, height: size.height))
            }
        }
        return url
    }

    /// ファイルアプリなどから選んだファイルをコピーする
    @discardableResult
    func importFile(_ source: URL, subsidyID: String) throws -> URL {
        let accessing = source.startAccessingSecurityScopedResource()
        defer { if accessing { source.stopAccessingSecurityScopedResource() } }
        let url = try uniqueURL(for: subsidyID, name: source.deletingPathExtension().lastPathComponent,
                                ext: source.pathExtension.isEmpty ? "dat" : source.pathExtension)
        try FileManager.default.copyItem(at: source, to: url)
        return url
    }

    func rename(_ item: Item, to name: String) throws -> URL {
        let dir = item.url.deletingLastPathComponent()
        let ext = item.url.pathExtension
        var url = dir.appending(path: "\(Self.safe(name)).\(ext)")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path), url != item.url {
            url = dir.appending(path: "\(Self.safe(name)) \(n).\(ext)")
            n += 1
        }
        if url != item.url { try FileManager.default.moveItem(at: item.url, to: url) }
        return url
    }

    func delete(_ item: Item) throws {
        try FileManager.default.removeItem(at: item.url)
    }

    /// ウォッチを外したときに書類も消す
    func deleteAll(for subsidyID: String) {
        try? FileManager.default.removeItem(at: folder(for: subsidyID))
    }

    static func safe(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>")).joined(separator: "-")
        return trimmed.isEmpty ? "書類" : String(trimmed.prefix(60))
    }
}
