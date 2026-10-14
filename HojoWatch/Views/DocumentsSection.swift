import QuickLook
import SwiftUI
import UniformTypeIdentifiers
import VisionKit

/// 補助金ごとの申請書類：カメラでスキャン、ファイルから取り込み、プレビュー
struct DocumentsSection: View {
    let subsidyID: String
    @State private var items: [DocumentStore.Item] = []
    @State private var showScanner = false
    @State private var showImporter = false
    @State private var preview: URL?
    @State private var errorMessage: String?
    @State private var renaming: DocumentStore.Item?
    @State private var newName = ""
    private let store = DocumentStore()

    var body: some View {
        Section {
            ForEach(items) { item in
                Button { preview = item.url } label: {
                    HStack {
                        Image(systemName: item.url.pathExtension.lowercased() == "pdf" ? "doc.richtext" : "doc")
                            .foregroundStyle(Color.accentColor)
                        VStack(alignment: .leading) {
                            Text(item.name).foregroundStyle(.primary)
                            Text(item.createdAt.formatted(date: .numeric, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .contextMenu {
                    Button("名前を変更", systemImage: "pencil") { newName = item.name; renaming = item }
                    ShareLink(item: item.url)
                }
            }
            .onDelete { offsets in
                for i in offsets { try? store.delete(items[i]) }
                reload()
            }
            if VNDocumentCameraViewController.isSupported {
                Button { showScanner = true } label: { Label("書類をスキャン", systemImage: "doc.viewfinder") }
            }
            Button { showImporter = true } label: { Label("ファイルから追加", systemImage: "folder.badge.plus") }
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        } header: {
            Text("申請書類（\(items.count)）")
        } footer: {
            Text("見積書・決算書・登記事項証明書などをまとめておけます。書類はこのiPhoneの中だけに保存されます。長押しで名前の変更や共有ができます。")
        }
        .onAppear(perform: reload)
        .quickLookPreview($preview, in: items.map(\.url))
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScanner { pages in
                showScanner = false
                guard !pages.isEmpty else { return }
                do {
                    try store.savePDF(pages: pages, subsidyID: subsidyID, name: "スキャン \(Date().formatted(date: .numeric, time: .omitted))")
                    reload()
                } catch { errorMessage = "保存できませんでした" }
            }
            .ignoresSafeArea()
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.pdf, .image, .spreadsheet, .presentation, .text, .data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for u in urls { _ = try? store.importFile(u, subsidyID: subsidyID) }
                reload()
            case .failure:
                errorMessage = "ファイルを読み込めませんでした"
            }
        }
        .alert("名前を変更", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("名前", text: $newName)
            Button("変更") {
                if let r = renaming { _ = try? store.rename(r, to: newName) }
                renaming = nil
                reload()
            }
            Button("キャンセル", role: .cancel) { renaming = nil }
        }
    }

    private func reload() {
        items = store.list(for: subsidyID)
        errorMessage = nil
    }
}

/// iOS標準の書類スキャナ（台形補正・影の除去つき）
struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: VNDocumentCameraViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: ([UIImage]) -> Void
        init(onFinish: @escaping ([UIImage]) -> Void) { self.onFinish = onFinish }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            onFinish((0..<scan.pageCount).map { scan.imageOfPage(at: $0) })
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) { onFinish([]) }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) { onFinish([]) }
    }
}
