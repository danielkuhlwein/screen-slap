//
//  MeetingEventTests.swift
//  screen-slapTests
//

import XCTest
@testable import screen_slap

final class MeetingEventTests: XCTestCase {

    // MARK: - ID Generation

    func testIDCombinesIdentifierAndStartDate() {
        let date = Date(timeIntervalSince1970: 1000)
        let event = MeetingEvent(
            id: "test-123",
            title: "Test",
            startDate: date,
            endDate: date.addingTimeInterval(3600)
        )
        XCTAssertEqual(event.id, "test-123_1000.0")
    }

    func testRecurringEventsGetUniqueIDs() {
        let date1 = Date(timeIntervalSince1970: 1000)
        let date2 = Date(timeIntervalSince1970: 2000)
        let event1 = MeetingEvent(
            id: "recurring",
            title: "Standup",
            startDate: date1,
            endDate: date1.addingTimeInterval(1800)
        )
        let event2 = MeetingEvent(
            id: "recurring",
            title: "Standup",
            startDate: date2,
            endDate: date2.addingTimeInterval(1800)
        )
        XCTAssertNotEqual(event1.id, event2.id)
    }

    // MARK: - Time Status

    func testHasStartedFutureEvent() {
        let future = Date().addingTimeInterval(3600)
        let event = MeetingEvent(title: "Future", startDate: future, endDate: future.addingTimeInterval(3600))
        XCTAssertFalse(event.hasStarted)
    }

    func testHasStartedPastEvent() {
        let past = Date().addingTimeInterval(-3600)
        let event = MeetingEvent(title: "Past", startDate: past, endDate: past.addingTimeInterval(7200))
        XCTAssertTrue(event.hasStarted)
    }

    func testHasEndedOngoingEvent() {
        let past = Date().addingTimeInterval(-1800)
        let future = Date().addingTimeInterval(1800)
        let event = MeetingEvent(title: "Ongoing", startDate: past, endDate: future)
        XCTAssertTrue(event.hasStarted)
        XCTAssertFalse(event.hasEnded)
    }

    func testHasEndedFinishedEvent() {
        let pastStart = Date().addingTimeInterval(-7200)
        let pastEnd = Date().addingTimeInterval(-3600)
        let event = MeetingEvent(title: "Done", startDate: pastStart, endDate: pastEnd)
        XCTAssertTrue(event.hasEnded)
    }

    // MARK: - Time Until Start

    func testTimeUntilStartFutureEvent() {
        let future = Date().addingTimeInterval(300) // 5 minutes
        let event = MeetingEvent(title: "Soon", startDate: future, endDate: future.addingTimeInterval(3600))
        XCTAssertGreaterThan(event.timeUntilStart, 0)
        XCTAssertEqual(event.timeUntilStart, 300, accuracy: 2)
    }

    func testTimeUntilStartPastEvent() {
        let past = Date().addingTimeInterval(-300) // 5 minutes ago
        let event = MeetingEvent(title: "Started", startDate: past, endDate: past.addingTimeInterval(3600))
        XCTAssertLessThan(event.timeUntilStart, 0)
    }

    // MARK: - Formatted Time Remaining

    func testFormattedTimeRemainingNow() {
        let past = Date().addingTimeInterval(-10)
        let event = MeetingEvent(title: "Now", startDate: past, endDate: past.addingTimeInterval(3600))
        XCTAssertEqual(event.formattedTimeRemaining, "Now")
    }

    func testFormattedTimeRemainingSeconds() {
        let future = Date().addingTimeInterval(45) // 45 seconds
        let event = MeetingEvent(title: "Soon", startDate: future, endDate: future.addingTimeInterval(3600))
        XCTAssertTrue(event.formattedTimeRemaining.hasSuffix("s"))
    }

    func testFormattedTimeRemainingMinutes() {
        let future = Date().addingTimeInterval(305) // ~5 minutes
        let event = MeetingEvent(title: "Soon", startDate: future, endDate: future.addingTimeInterval(3600))
        XCTAssertEqual(event.formattedTimeRemaining, "5 min")
    }

    func testFormattedTimeRemainingHoursFormat() {
        // Use >60 min to trigger the hours format path
        let future = Date().addingTimeInterval(7200) // ~2 hours
        let event = MeetingEvent(title: "Later", startDate: future, endDate: future.addingTimeInterval(3600))
        let result = event.formattedTimeRemaining
        // Verify it uses "Xh Ym" format (integer truncation may vary by ~1 min)
        XCTAssertTrue(result.contains("h"), "Expected hours format, got: \(result)")
        XCTAssertTrue(result.contains("m"), "Expected minutes component, got: \(result)")
    }

    func testFormattedTimeRemainingOverOneHour() {
        let future = Date().addingTimeInterval(3660) // ~61 minutes
        let event = MeetingEvent(title: "Later", startDate: future, endDate: future.addingTimeInterval(3600))
        let result = event.formattedTimeRemaining
        XCTAssertTrue(result.hasPrefix("1h"), "Expected 1h prefix, got: \(result)")
    }

    // MARK: - Equatable

    func testEqualityBySameID() {
        let date = Date()
        let event1 = MeetingEvent(id: "test", title: "Meeting A", startDate: date, endDate: date.addingTimeInterval(3600))
        let event2 = MeetingEvent(id: "test", title: "Meeting B", startDate: date, endDate: date.addingTimeInterval(3600))
        XCTAssertEqual(event1, event2)
    }

    func testInequalityByDifferentID() {
        let date = Date()
        let event1 = MeetingEvent(id: "test1", title: "Meeting", startDate: date, endDate: date.addingTimeInterval(3600))
        let event2 = MeetingEvent(id: "test2", title: "Meeting", startDate: date, endDate: date.addingTimeInterval(3600))
        XCTAssertNotEqual(event1, event2)
    }

    // MARK: - Hashable

    func testHashableConsistency() {
        let date = Date()
        let event1 = MeetingEvent(id: "hash-test", title: "Meeting", startDate: date, endDate: date.addingTimeInterval(3600))
        let event2 = MeetingEvent(id: "hash-test", title: "Different Name", startDate: date, endDate: date.addingTimeInterval(3600))
        XCTAssertEqual(event1.hashValue, event2.hashValue)
    }

    func testSetDeduplication() {
        let date = Date()
        let event1 = MeetingEvent(id: "dup", title: "Meeting", startDate: date, endDate: date.addingTimeInterval(3600))
        let event2 = MeetingEvent(id: "dup", title: "Meeting", startDate: date, endDate: date.addingTimeInterval(3600))
        let set: Set<MeetingEvent> = [event1, event2]
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Meeting URL

    func testMeetingURLStorage() {
        let url = URL(string: "https://zoom.us/j/123")!
        let event = MeetingEvent(
            title: "Call",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            meetingURL: url
        )
        XCTAssertEqual(event.meetingURL, url)
    }

    func testMeetingURLNilByDefault() {
        let event = MeetingEvent(
            title: "No Link",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600)
        )
        XCTAssertNil(event.meetingURL)
    }

    // MARK: - Convenience Init Defaults

    func testConvenienceInitDefaults() {
        let event = MeetingEvent(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600)
        )
        XCTAssertEqual(event.calendarTitle, "Calendar")
        XCTAssertFalse(event.isAllDay)
        XCTAssertNil(event.location)
        XCTAssertNil(event.meetingURL)
        XCTAssertTrue(event.attendees.isEmpty)
    }

    func testConvenienceInitWithAllParameters() {
        let url = URL(string: "https://zoom.us/j/123")!
        let attendee = MeetingEvent.Attendee(
            id: "test@example.com",
            email: "test@example.com",
            name: "Test User",
            isCurrentUser: false,
            status: .accepted,
            contactPhoto: nil,
            resolvedFromContacts: false
        )
        let event = MeetingEvent(
            id: "custom-id",
            title: "Full Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            calendarTitle: "Work",
            meetingURL: url,
            isAllDay: false,
            location: "Room 42",
            attendees: [attendee]
        )
        XCTAssertEqual(event.title, "Full Meeting")
        XCTAssertEqual(event.calendarTitle, "Work")
        XCTAssertEqual(event.meetingURL, url)
        XCTAssertEqual(event.location, "Room 42")
        XCTAssertEqual(event.attendees.count, 1)
        XCTAssertEqual(event.attendees.first?.name, "Test User")
    }

    // MARK: - Attendee

    func testAttendeeHasContactMatch() {
        let attendee = MeetingEvent.Attendee(
            id: "a",
            email: "a@b.com",
            name: "Alice",
            isCurrentUser: false,
            status: .accepted,
            contactPhoto: Data([0x00]),
            resolvedFromContacts: true
        )
        XCTAssertTrue(attendee.hasContactMatch)
    }

    func testAttendeeNoContactMatch() {
        let attendee = MeetingEvent.Attendee(
            id: "b",
            email: "b@c.com",
            name: "Bob",
            isCurrentUser: false,
            status: .pending,
            contactPhoto: nil,
            resolvedFromContacts: false
        )
        XCTAssertFalse(attendee.hasContactMatch)
    }

    func testAttendeeStatusValues() {
        // Verify all status cases can be created
        let statuses: [MeetingEvent.Attendee.Status] = [
            .accepted, .declined, .tentative, .pending, .unknown,
        ]
        XCTAssertEqual(statuses.count, 5)
    }
}
