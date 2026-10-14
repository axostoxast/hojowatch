import EventKit
import EventKitUI
import SwiftUI

/// ウォッチ中の補助金の詳細：締切、カレンダーへの追加、申請準備のチェックリスト、メモ
struct WatchDetailView: View {
    @Bindable var item: WatchedSubsidy
    @State private var newItem = ""
    @State private var showCalendar = false
    @FocusState private var memoFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            Section {
                Text(item.title).font(.headline)
                DeadlineBadge(endAt: item.endAt)
                Text(Deadline.amountLabel(item.maxLimit)).foregroundStyle(.secondary)
                if let area = item.targetArea, !area.isEmpty {
                    LabeledContent("対象地域", value: area)
                }
                Link(destination: item.portalURL) {
                    Label("Jグランツで公募要領を見る", systemImage: "safari")
                }
                Button {
                    showCalendar = true
                } label: {
                    Label("締切をカレンダーに追加", systemImage: "calendar.badge.plus")
                }
                .disabled(item.endAt == nil)
            }

            Section {
                ForEach($item.checklist) { $c in
                    Button {
                        c.done.toggle()
                    } label: {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: c.done ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(c.done ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.title)
                                    .strikethrough(c.done)
                                    .foregroundStyle(c.done ? .secondary : .primary)
                                if let due = c.dueDate(endAt: item.endAt), !c.done {
                                    let overdue = Deadline.daysLeft(until: due) < 0
                                    Text("\(Deadline.dateLabel(due))までに" + (overdue ? "（期限切れ）" : ""))
                                        .font(.caption)
                                        .foregroundStyle(overdue ? .red : .secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { item.checklist.remove(atOffsets: $0) }
                .onMove { item.checklist.move(fromOffsets: $0, toOffset: $1) }
                HStack {
                    TextField("項目を追加", text: $newItem)
                        .onSubmit(addItem)
                    Button("追加", action: addItem)
                        .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                let p = item.checklistProgress
                Text("申請準備（\(p.done)/\(p.total)）")
            } footer: {
                Text("締切から逆算した目安の期限です。期限の日の朝9時に通知します。必要な準備は補助金ごとに違うので、公募要領を見ながら項目を追加・削除してください。")
            }

            DocumentsSection(subsidyID: item.subsidyID)
                .id("documents")

            Section("メモ") {
                TextEditor(text: $item.memo)
                    .frame(minHeight: 100)
                    .focused($memoFocused)
            }
        }
        .task {
            if Self.scrollToBottom {
                try? await Task.sleep(for: .seconds(0.8))
                proxy.scrollTo("documents", anchor: .top)
            }
        }
        }
        .navigationTitle("補助金の詳細")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .sheet(isPresented: $showCalendar) {
            CalendarEventSheet(title: "【締切】\(item.title)", deadline: item.endAt ?? .now, url: item.portalURL)
                .ignoresSafeArea()
        }
    }

    /// スクリーンショット用: -scrollBottom で書類の欄を表示する
    private static var scrollToBottom: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("-scrollBottom")
        #else
        false
        #endif
    }

    private func addItem() {
        let title = newItem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        item.checklist.append(ChecklistItem(title: title, daysBefore: 7))
        newItem = ""
    }
}

/// iOS標準の予定作成画面（カレンダーへのアクセス許可は不要）
struct CalendarEventSheet: UIViewControllerRepresentable {
    let title: String
    let deadline: Date
    let url: URL

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = title
        event.isAllDay = true
        event.startDate = Deadline.calendar.startOfDay(for: deadline)
        event.endDate = event.startDate
        event.url = url
        event.notes = "補助金ウォッチから追加。締切時刻・要件は公募要領で確認してください。\n\(url.absoluteString)"
        let vc = EKEventEditViewController()
        vc.eventStore = store
        vc.event = event
        vc.editViewDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ vc: EKEventEditViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            controller.dismiss(animated: true)
        }
    }
}
