import Foundation
import Testing
@testable import HojoWatch

private func jst(_ text: String) -> Date {
    JGrantsDate.parse(text)!
}

struct DecodingTests {
    @Test func decodesListFormat() throws {
        let json = #"{"result":[{"id":"a1","title":"テスト補助金","target_area_search":"東京都","subsidy_max_limit":3000000,"acceptance_end_datetime":"2026-10-12T14:59:00.000Z"}]}"#
        let subsidy = try #require(try JGrantsClient.decode(Data(json.utf8)).first)
        #expect(subsidy.maxLimit == 3_000_000)
        #expect(subsidy.endAt == jst("2026-10-12T14:59:00Z"))
        #expect(subsidy.targetArea == "東京都")
    }

    @Test func decodesDetailFormat() throws {
        let json = #"{"result":[{"id":"a1","title":"テスト補助金","subsidy_max_limit":"150000000","acceptance_end_datetime":"2026-10-12T14:59Z"}]}"#
        let subsidy = try #require(try JGrantsClient.decode(Data(json.utf8)).first)
        #expect(subsidy.maxLimit == 150_000_000)
        #expect(subsidy.endAt == jst("2026-10-12T14:59:00Z"))
    }

    @Test func toleratesMissingOptionalFields() throws {
        let json = #"{"result":[{"id":"a1","title":"テスト","subsidy_max_limit":null}]}"#
        let subsidy = try #require(try JGrantsClient.decode(Data(json.utf8)).first)
        #expect(subsidy.maxLimit == nil)
        #expect(subsidy.endAt == nil)
    }

    @Test func sortsByNearestDeadlineWithUnknownLast() {
        let items = [
            Subsidy(id: "late", title: "", endAt: jst("2027-05-31T14:59:00Z")),
            Subsidy(id: "none", title: ""),
            Subsidy(id: "soon", title: "", endAt: jst("2026-10-12T14:59:00Z")),
        ]
        #expect(JGrantsClient.sortedByDeadline(items).map(\.id) == ["soon", "late", "none"])
    }

    @Test func rejectsShortKeyword() {
        #expect(throws: JGrantsClient.ClientError.keywordTooShort) {
            try JGrantsClient.searchQuery(keyword: " 補 ", area: nil)
        }
    }

    @Test func includesAreaOnlyWhenGiven() throws {
        #expect(try JGrantsClient.searchQuery(keyword: "設備", area: "東京都").contains { $0.name == "target_area_search" })
        #expect(try !JGrantsClient.searchQuery(keyword: "設備", area: nil).contains { $0.name == "target_area_search" })
    }
}

struct DeadlineTests {
    // 締切 2026-10-12 23:59 JST
    let end = jst("2026-10-12T14:59:00.000Z")

    @Test func countsCalendarDaysInJST() {
        #expect(Deadline.daysLeft(until: end, now: jst("2026-10-11T15:30:00Z")) == 0) // 10/12 0:30 JST
        #expect(Deadline.daysLeft(until: end, now: jst("2026-10-11T14:30:00Z")) == 1) // 10/11 23:30 JST
        #expect(Deadline.label(for: end, now: jst("2026-10-09T01:00:00Z")) == "10/12締切・あと3日")
        #expect(Deadline.label(for: end, now: jst("2026-10-13T01:00:00Z")) == "10/12 締切済み")
    }

    @Test func formatsAmounts() {
        #expect(Deadline.amountLabel(150_000_000) == "上限 1.5億円")
        #expect(Deadline.amountLabel(3_000_000) == "上限 300万円")
        #expect(Deadline.amountLabel(nil) == "上限額は公募要領を確認")
    }

    @Test func plansNotificationsAtNineAMAndSkipsPast() {
        let now = jst("2026-10-08T00:00:00Z") // 10/8 9:00 JST ちょうど
        let plans = DeadlineNotifier.plans(for: [(id: "a1", title: "テスト", endAt: end)], offsets: [7, 3, 1, 0], now: now)
        // 7日前(10/5)は過去なので除外。3日前・前日・当日の朝9時
        #expect(plans.map(\.offset) == [3, 1, 0])
        #expect(plans.first?.fireDate == jst("2026-10-09T00:00:00Z"))
        #expect(DeadlineNotifier.body(for: plans[0]) == "申請締切（10/12）まであと3日です。")
    }

    @Test func capsPendingNotifications() {
        let items = (0..<30).map { (id: "s\($0)", title: "t", endAt: jst("2027-03-01T14:59:00Z")) }
        let plans = DeadlineNotifier.plans(for: items, offsets: [7, 3, 1], now: jst("2026-10-01T00:00:00Z"))
        #expect(plans.count == DeadlineNotifier.maxPending)
    }
}

struct PolicyTests {
    @Test func freeUsersAreLimitedToThree() {
        #expect(WatchPolicy.canAdd(currentCount: 2, isPro: false))
        #expect(!WatchPolicy.canAdd(currentCount: 3, isPro: false))
        #expect(WatchPolicy.canAdd(currentCount: 50, isPro: true))
    }

    @Test func everyoneCanChooseNotificationOffsets() {
        #expect(NotifySettings.parse("30,0,99") == [30, 0])
        #expect(NotifySettings.parse(NotifySettings.defaultRaw) == [7, 3, 1])
    }
}

struct ResubmissionFeatureTests {
    @Test func widgetSnapshotDropsPastAndSortsByDeadline() {
        let now = jst("2026-10-13T10:00:00+09:00")
        let items: [WidgetSnapshot.Item] = [
            .init(id: "late", title: "B", endAt: jst("2026-11-01T17:00:00+09:00")),
            .init(id: "past", title: "X", endAt: jst("2026-10-12T17:00:00+09:00")),
            .init(id: "today", title: "A", endAt: jst("2026-10-13T08:00:00+09:00")),
        ]
        let s = WidgetSnapshot.make(items, now: now, calendar: Deadline.calendar)
        #expect(s.items.map(\.id) == ["today", "late"])
        let data = try! JSONEncoder().encode(s)
        #expect(try! JSONDecoder().decode(WidgetSnapshot.self, from: data) == s)
    }

    @Test func defaultChecklistIsFreshPerSubsidy() {
        let a = ChecklistItem.defaults, b = ChecklistItem.defaults
        #expect(a.count == 7)
        #expect(a.allSatisfy { !$0.done })
        #expect(a.map(\.title) == b.map(\.title))
    }
}
