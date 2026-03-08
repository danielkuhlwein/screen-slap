//
//  MockCalendarService.swift
//  screen-slapTests
//

import EventKit
import Foundation
@testable import screen_slap

/// Mock calendar service for unit tests.
/// Provides controlled event data without hitting EventKit.
final class MockCalendarService: CalendarServiceProtocol {

    var authorizationStatus: EKAuthorizationStatus = .fullAccess
    var hasAccess: Bool = true
    var availableCalendars: [EKCalendar] = []

    /// Events to return from fetchUpcomingEvents
    var mockEvents: [MeetingEvent] = []

    /// Tracks how many times fetchUpcomingEvents was called
    var fetchCallCount: Int = 0

    func requestAccess() async -> Bool {
        return hasAccess
    }

    func fetchUpcomingEvents(
        within minutes: Int,
        calendarIDs: Set<String>?,
        meetingURLOnly: Bool
    ) -> [MeetingEvent] {
        fetchCallCount += 1
        return mockEvents
    }
}
