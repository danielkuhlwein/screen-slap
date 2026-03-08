//
//  CalendarServiceProtocol.swift
//  screen-slap
//

import EventKit
import Foundation

/// Protocol for calendar access, enabling mock injection in tests.
protocol CalendarServiceProtocol {
    /// Current authorization status for calendar access
    var authorizationStatus: EKAuthorizationStatus { get }

    /// Whether the user has granted full access to calendars
    var hasAccess: Bool { get }

    /// All available calendars for event display
    var availableCalendars: [EKCalendar] { get }

    /// Request full access to the user's calendars.
    /// Returns true if access was granted.
    func requestAccess() async -> Bool

    /// Fetch upcoming events within the given time window.
    /// - Parameters:
    ///   - minutes: How many minutes ahead to look
    ///   - calendarIDs: Optional set of calendar IDs to filter by. Nil or empty means all calendars.
    ///   - meetingURLOnly: If true, only return events that have a detected meeting URL.
    /// - Returns: Array of MeetingEvent sorted by start date
    func fetchUpcomingEvents(within minutes: Int, calendarIDs: Set<String>?, meetingURLOnly: Bool) -> [MeetingEvent]
}
