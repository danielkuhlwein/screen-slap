//
//  MeetingMonitorTests.swift
//  screen-slapTests
//

import XCTest
@testable import screen_slap

final class MeetingMonitorTests: XCTestCase {

    var mock: MockCalendarService!
    var monitor: MeetingMonitor!
    private var savedAlertMinutes: Int!
    private var savedAlertForTentative: Bool!

    override func setUp() {
        super.setUp()
        mock = MockCalendarService()
        monitor = MeetingMonitor(calendarService: mock)

        // Ensure consistent settings for tests
        savedAlertMinutes = AppSettings.shared.alertMinutesBefore
        savedAlertForTentative = AppSettings.shared.alertForTentativeEvents
        AppSettings.shared.alertMinutesBefore = Constants.Defaults.alertMinutesBefore
        AppSettings.shared.alertForTentativeEvents = Constants.Defaults.alertForTentativeEvents
    }

    override func tearDown() {
        monitor.stop()
        monitor = nil
        mock = nil
        AppSettings.shared.alertMinutesBefore = savedAlertMinutes
        AppSettings.shared.alertForTentativeEvents = savedAlertForTentative
        super.tearDown()
    }

    // MARK: - Initial State

    func testInitialState() {
        XCTAssertNil(monitor.activeAlert)
        XCTAssertNil(monitor.nextMeeting)
        XCTAssertTrue(monitor.upcomingMeetings.isEmpty)
        XCTAssertFalse(monitor.isMonitoring)
    }

    // MARK: - Start / Stop

    func testStartSetsIsMonitoring() {
        monitor.start()
        XCTAssertTrue(monitor.isMonitoring)
    }

    func testStopClearsIsMonitoring() {
        monitor.start()
        monitor.stop()
        XCTAssertFalse(monitor.isMonitoring)
    }

    func testDoubleStartIsNoOp() {
        monitor.start()
        monitor.start() // Should not crash or duplicate timers
        XCTAssertTrue(monitor.isMonitoring)
    }

    // MARK: - Trigger Test Alert

    func testTriggerTestAlert() {
        let meeting = makeMeeting(title: "Test Meeting")
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)
        XCTAssertEqual(monitor.activeAlert?.title, "Test Meeting")
    }

    func testTriggerTestAlertReplacesPrevious() {
        let meeting1 = makeMeeting(title: "First")
        let meeting2 = makeMeeting(title: "Second")
        monitor.triggerTestAlert(for: meeting1)
        monitor.triggerTestAlert(for: meeting2)
        XCTAssertEqual(monitor.activeAlert?.title, "Second")
    }

    // MARK: - Dismiss

    func testDismissClearsActiveAlert() {
        let meeting = makeMeeting(title: "Dismissable")
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)

        monitor.dismiss()
        XCTAssertNil(monitor.activeAlert)
    }

    func testDismissWithNoAlertIsNoOp() {
        monitor.dismiss() // Should not crash
        XCTAssertNil(monitor.activeAlert)
    }

    func testDismissedEventNotReAlerted() {
        let meeting = makeMeeting(title: "Once Only", minutesFromNow: 0.5)
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.triggerTestAlert(for: meeting)
        monitor.dismiss()

        // Check alerts again — dismissed event should not re-trigger
        monitor.checkForAlerts()
        XCTAssertNil(monitor.activeAlert)
    }

    // MARK: - Snooze

    func testSnoozeClearsActiveAlert() {
        let meeting = makeMeeting(title: "Snoozable")
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)

        monitor.snooze()
        XCTAssertNil(monitor.activeAlert)
    }

    func testSnoozeWithNoAlertIsNoOp() {
        monitor.snooze() // Should not crash
        XCTAssertNil(monitor.activeAlert)
    }

    // MARK: - Join Meeting

    func testJoinMeetingClearsAlert() {
        let meeting = makeMeeting(
            title: "Joinable",
            meetingURL: URL(string: "https://zoom.us/j/123")
        )
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)

        monitor.joinMeeting()
        XCTAssertNil(monitor.activeAlert)
    }

    func testJoinMeetingWithoutURLKeepsAlert() {
        let meeting = makeMeeting(title: "No URL")
        monitor.triggerTestAlert(for: meeting)

        monitor.joinMeeting()
        // joinMeeting bails early when no URL — alert stays
        XCTAssertNotNil(monitor.activeAlert)
    }

    // MARK: - Calendar Fetch

    func testFetchPopulatesUpcomingMeetings() {
        let m1 = makeMeeting(title: "Meeting 1", minutesFromNow: 30)
        let m2 = makeMeeting(title: "Meeting 2", minutesFromNow: 60)
        mock.mockEvents = [m1, m2]

        monitor.fetchEventsFromCalendar()

        XCTAssertEqual(monitor.upcomingMeetings.count, 2)
        XCTAssertEqual(monitor.nextMeeting?.title, "Meeting 1")
    }

    func testFetchWithNoAccessReturnsEmpty() {
        mock.hasAccess = false
        mock.mockEvents = [makeMeeting(title: "Hidden")]

        monitor.fetchEventsFromCalendar()

        XCTAssertTrue(monitor.upcomingMeetings.isEmpty)
        XCTAssertNil(monitor.nextMeeting)
    }

    func testFetchSetsNextMeetingToFirst() {
        let early = makeMeeting(title: "Early", minutesFromNow: 10)
        let later = makeMeeting(title: "Later", minutesFromNow: 60)
        mock.mockEvents = [early, later]

        monitor.fetchEventsFromCalendar()

        XCTAssertEqual(monitor.nextMeeting?.title, "Early")
    }

    func testFetchTracksCallCount() {
        mock.mockEvents = []

        monitor.fetchEventsFromCalendar()
        monitor.fetchEventsFromCalendar()
        monitor.fetchEventsFromCalendar()

        XCTAssertEqual(mock.fetchCallCount, 3)
    }

    // MARK: - Alert Logic

    func testAlertTriggeredWithinWindow() {
        // Meeting starting in 30 seconds — within default 1-minute alert window
        let meeting = makeMeeting(
            title: "Imminent",
            minutesFromNow: 0.5,
            meetingURL: URL(string: "https://zoom.us/j/123")
        )
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNotNil(monitor.activeAlert)
        XCTAssertEqual(monitor.activeAlert?.title, "Imminent")
    }

    func testAlertNotTriggeredOutsideWindow() {
        // Meeting starting in 10 minutes — outside default 1-minute alert window
        let meeting = makeMeeting(
            title: "Later",
            minutesFromNow: 10,
            meetingURL: URL(string: "https://zoom.us/j/123")
        )
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNil(monitor.activeAlert)
    }

    func testAlertNotTriggeredForDismissedEvent() {
        let meeting = makeMeeting(title: "Dismissed", minutesFromNow: 0.5)
        mock.mockEvents = [meeting]

        // Trigger and dismiss
        monitor.fetchEventsFromCalendar()
        monitor.triggerTestAlert(for: meeting)
        monitor.dismiss()

        // Should not re-trigger
        monitor.checkForAlerts()
        XCTAssertNil(monitor.activeAlert)
    }

    // MARK: - Auto-Dismiss

    func testAutoDismissCancelledMeeting() {
        let meeting = makeMeeting(title: "Will Be Cancelled", minutesFromNow: 0.5)
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)

        // Simulate meeting being cancelled (removed from upcoming)
        mock.mockEvents = []
        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNil(monitor.activeAlert)
    }

    func testAutoDismissStaleAlert() {
        // Meeting started 6 minutes ago — past the 5-minute auto-dismiss threshold
        let meeting = makeMeeting(title: "Stale Meeting", minutesFromNow: -6)
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.triggerTestAlert(for: meeting)
        XCTAssertNotNil(monitor.activeAlert)

        monitor.checkForAlerts()

        XCTAssertNil(monitor.activeAlert)
    }

    func testNoAutoDismissWithinThreshold() {
        // Meeting started 2 minutes ago — within the 5-minute threshold
        let meeting = makeMeeting(title: "Recent", minutesFromNow: -2)
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.triggerTestAlert(for: meeting)

        monitor.checkForAlerts()

        // Should still be active (within 5-minute window)
        XCTAssertNotNil(monitor.activeAlert)
    }

    // MARK: - Tentative Event Alerts

    func testTentativeEventAlertsWhenEnabled() {
        AppSettings.shared.alertForTentativeEvents = true

        let meeting = makeMeeting(
            title: "Maybe Meeting",
            minutesFromNow: 0.5,
            meetingURL: URL(string: "https://zoom.us/j/123"),
            currentUserStatus: .tentative
        )
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNotNil(monitor.activeAlert)
        XCTAssertEqual(monitor.activeAlert?.title, "Maybe Meeting")
    }

    func testTentativeEventSuppressedWhenDisabled() {
        AppSettings.shared.alertForTentativeEvents = false

        let meeting = makeMeeting(
            title: "Maybe Meeting",
            minutesFromNow: 0.5,
            meetingURL: URL(string: "https://zoom.us/j/123"),
            currentUserStatus: .tentative
        )
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNil(monitor.activeAlert)
    }

    func testAcceptedEventAlertsRegardlessOfTentativeSetting() {
        AppSettings.shared.alertForTentativeEvents = false

        let meeting = makeMeeting(
            title: "Accepted Meeting",
            minutesFromNow: 0.5,
            meetingURL: URL(string: "https://zoom.us/j/123"),
            currentUserStatus: .accepted
        )
        mock.mockEvents = [meeting]

        monitor.fetchEventsFromCalendar()
        monitor.checkForAlerts()

        XCTAssertNotNil(monitor.activeAlert)
        XCTAssertEqual(monitor.activeAlert?.title, "Accepted Meeting")
    }

    // MARK: - Helpers

    private func makeMeeting(
        title: String,
        minutesFromNow: Double = 5,
        meetingURL: URL? = nil,
        currentUserStatus: MeetingEvent.Attendee.Status? = nil
    ) -> MeetingEvent {
        let start = Date().addingTimeInterval(minutesFromNow * 60)

        var attendees: [MeetingEvent.Attendee] = []
        if let status = currentUserStatus {
            attendees = [
                MeetingEvent.Attendee(
                    id: "me@test.com",
                    email: "me@test.com",
                    name: "Me",
                    isCurrentUser: true,
                    status: status,
                    contactPhoto: nil,
                    resolvedFromContacts: false
                )
            ]
        }

        return MeetingEvent(
            title: title,
            startDate: start,
            endDate: start.addingTimeInterval(3600),
            meetingURL: meetingURL,
            attendees: attendees
        )
    }
}
