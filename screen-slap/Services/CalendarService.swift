//
//  CalendarService.swift
//  screen-slap
//

import EventKit
import Foundation
import os

/// Wraps EKEventStore to provide calendar access, permission handling, and event fetching.
/// Owns a single EKEventStore instance for the app's lifetime.
@Observable
final class CalendarService: CalendarServiceProtocol {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screen-slap",
        category: "CalendarService"
    )

    static let shared = CalendarService()

    // MARK: - Properties

    private let eventStore = EKEventStore()

    /// Current calendar authorization status
    private(set) var authorizationStatus: EKAuthorizationStatus

    /// All available event calendars
    private(set) var availableCalendars: [EKCalendar] = []

    /// Whether the user has granted full access
    var hasAccess: Bool {
        authorizationStatus == .fullAccess
    }

    // MARK: - Init

    init() {
        self.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        if hasAccess {
            refreshCalendars()
        }
        setupNotifications()
    }

    // MARK: - Permission Handling

    /// Request full access to the user's calendars.
    func requestAccess() async -> Bool {
        do {
            let granted = try await eventStore.requestFullAccessToEvents()
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            if granted {
                refreshCalendars()
            }
            Self.logger.info("Calendar access request result: \(granted)")
            return granted
        } catch {
            Self.logger.error("Failed to request calendar access: \(error.localizedDescription)")
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return false
        }
    }

    // MARK: - Event Fetching

    /// Fetch upcoming events within the given time window.
    func fetchUpcomingEvents(within minutes: Int, calendarIDs: Set<String>?, meetingURLOnly: Bool = true) -> [MeetingEvent] {
        guard hasAccess else {
            Self.logger.debug("No calendar access, returning empty events")
            return []
        }

        let now = Date()
        let endDate = now.addingTimeInterval(TimeInterval(minutes * 60))

        // Determine which calendars to query
        let calendars: [EKCalendar]?
        if let ids = calendarIDs, !ids.isEmpty {
            calendars = availableCalendars.filter { ids.contains($0.calendarIdentifier) }
        } else {
            calendars = nil // nil means all calendars
        }

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: calendars
        )

        let ekEvents = eventStore.events(matching: predicate)

        let meetings = ekEvents
            .filter { event in
                // Filter out all-day events
                guard !event.isAllDay else { return false }

                // Filter out cancelled events
                guard event.status != .canceled else { return false }

                // Filter out declined events
                if let attendee = event.attendees?.first(where: { $0.isCurrentUser }) {
                    if attendee.participantStatus == .declined {
                        return false
                    }
                }

                return true
            }
            .map { MeetingEvent(from: $0) }
            .filter { meeting in
                // If meetingURLOnly is set, only include events with a detected meeting URL
                if meetingURLOnly {
                    return meeting.meetingURL != nil
                }
                return true
            }
            .sorted { $0.startDate < $1.startDate }

        Self.logger.debug("Fetched \(meetings.count) upcoming events (meetingURLOnly: \(meetingURLOnly)) within \(minutes) minutes")
        return meetings
    }

    // MARK: - Private

    /// Refresh the list of available calendars
    private func refreshCalendars() {
        availableCalendars = eventStore.calendars(for: .event)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        Self.logger.debug("Refreshed calendars: \(self.availableCalendars.count) available")
    }

    /// Listen for calendar store changes
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { [weak self] _ in
            // EKEventStoreChangedNotification fires on a background thread
            DispatchQueue.main.async {
                self?.handleStoreChanged()
            }
        }
    }

    /// Handle calendar store changes (events added/removed/modified, calendars changed)
    private func handleStoreChanged() {
        // Re-check authorization in case user revoked access
        let newStatus = EKEventStore.authorizationStatus(for: .event)
        if newStatus != authorizationStatus {
            Self.logger.info("Authorization status changed: \(String(describing: newStatus))")
            authorizationStatus = newStatus
        }

        if hasAccess {
            refreshCalendars()
        }
    }
}
