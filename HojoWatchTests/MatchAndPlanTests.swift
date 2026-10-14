import Foundation
import Testing
import UIKit
@testable import HojoWatch

struct MatchAndPlanTests {
    private let profile = BusinessProfile(prefecture: "東京都", industry: "製造業", employees: "20名以下",
                                          purposes: ["設備整備・IT導入をしたい", "販路拡大・海外展開をしたい"])

    @Test func queriesCoverPurposesAndAreas() {
        let qs = Matcher.queries(for: profile)
        #expect(qs.count == 4)   // 目的2つ × 都道府県・全国
        #expect(Set(qs.map(\.area)) == ["東京都", "全国"])
        let names = Set(qs[0].items.map(\.name))
        #expect(names.isSuperset(of: ["keyword", "use_purpose", "target_area_search", "industry", "target_number_of_employees", "acceptance"]))
    }

    @Test func mergeDedupesAndDropsExpired() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let a = Subsidy(id: "a", title: "A", endAt: now.addingTimeInterval(86400 * 10))
        let b = Subsidy(id: "b", title: "B", endAt: now.addingTimeInterval(86400 * 3))
        let old = Subsidy(id: "x", title: "X", endAt: now.addingTimeInterval(-86400))
        let merged = Matcher.merge([("設備", "全国", [a, old]), ("販路", "東京都", [a, b])], now: now)
        #expect(merged.map(\.id) == ["b", "a"])
        let ma = merged.first { $0.id == "a" }!
        #expect(ma.purposes == ["設備", "販路"])
        #expect(ma.isLocal)
        #expect(SeenMatches.newIDs(in: merged, seen: ["a"]) == ["b"])
    }

    @Test func profileRoundTrip() {
        let d = UserDefaults(suiteName: "t.\(UUID())")!
        #expect(!BusinessProfile.load(d).isComplete)
        profile.save(d)
        #expect(BusinessProfile.load(d) == profile)
    }

    @Test func checklistDueDatesCountBackFromDeadline() {
        let end = Deadline.calendar.date(from: DateComponents(year: 2026, month: 12, day: 25, hour: 17))!
        let items = ChecklistItem.defaults
        let gbiz = items.first { $0.title.contains("GビズID") }!
        let due = gbiz.dueDate(endAt: end)!
        #expect(Deadline.daysLeft(until: end, now: due) == 21)
        #expect(ChecklistItem(title: "自由").dueDate(endAt: end) == nil)
    }

    @Test func taskPlansSkipDoneAndPastAndRespectLimit() {
        let now = Deadline.calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 12))!
        let end = Deadline.calendar.date(from: DateComponents(year: 2026, month: 12, day: 25, hour: 17))!
        var tasks = ChecklistItem.defaults
        tasks[3].done = true   // 見積書（14日前）は済み
        let plans = TaskNotifier.plans(for: [.init(id: "s", title: "S", endAt: end, tasks: tasks)], limit: 10, now: now)
        // 28・25日前は過去、見積書は完了 → 21,10,7,2日前の4件
        #expect(plans.count == 4)
        #expect(plans.map(\.task).contains { $0.contains("GビズID") })
        #expect(TaskNotifier.plans(for: [.init(id: "s", title: "S", endAt: end, tasks: tasks)], limit: 2, now: now).count == 2)
        #expect(TaskNotifier.plans(for: [.init(id: "s", title: "S", endAt: end, tasks: tasks)], limit: -3, now: now).isEmpty)
    }

    @Test func documentStoreSaveListRenameDelete() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "docs-\(UUID())")
        let store = DocumentStore(root: root)
        let page = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 140)).image { ctx in
            UIColor.white.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 140))
        }
        try store.savePDF(pages: [page, page], subsidyID: "s1", name: "見積書")
        try store.savePDF(pages: [page], subsidyID: "s1", name: "見積書")
        var items = store.list(for: "s1")
        #expect(Set(items.map(\.name)) == ["見積書", "見積書 2"])
        let renamed = try store.rename(items[0], to: "決算書/2025")
        #expect(renamed.lastPathComponent == "決算書-2025.pdf")
        items = store.list(for: "s1")
        try store.delete(items[0])
        #expect(store.list(for: "s1").count == 1)
        store.deleteAll(for: "s1")
        #expect(store.list(for: "s1").isEmpty)
    }
}
