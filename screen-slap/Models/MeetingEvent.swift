//
//  MeetingEvent.swift
//  screen-slap
//

import Contacts
import EventKit
import SwiftUI

/// A lightweight value type that captures all needed data from an EKEvent.
/// This avoids holding stale EKEvent references across timer cycles.
struct MeetingEvent: Identifiable, Equatable, Hashable {

    /// Unique ID per occurrence — combines eventIdentifier with startDate
    /// to differentiate recurring event instances.
    let id: String

    /// The raw EKEvent identifier (shared across recurring instances)
    let eventIdentifier: String

    let title: String
    let startDate: Date
    let endDate: Date
    let calendarTitle: String
    let calendarColor: Color
    let meetingURL: URL?
    let isAllDay: Bool
    let location: String?
    let attendees: [Attendee]

    /// A lightweight representation of a meeting attendee.
    struct Attendee: Identifiable, Equatable, Hashable {
        let id: String // email or name-based identifier
        let email: String?
        let name: String
        let isCurrentUser: Bool
        let status: Status
        /// Contact photo resolved from Contacts.framework (nil if not found)
        let contactPhoto: Data?
        /// Whether this attendee was matched to a local contact
        var hasContactMatch: Bool { contactPhoto != nil || resolvedFromContacts }
        let resolvedFromContacts: Bool

        enum Status: Equatable, Hashable {
            case accepted, declined, tentative, pending, unknown
        }
    }

    // MARK: - Init from EKEvent

    init(from event: EKEvent) {
        let identifier = event.eventIdentifier ?? UUID().uuidString
        self.eventIdentifier = identifier
        // Combine identifier + start date for a unique ID per recurring occurrence
        self.id = "\(identifier)_\(event.startDate.timeIntervalSince1970)"
        self.title = event.title ?? "Untitled Event"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.calendarTitle = event.calendar?.title ?? "Unknown Calendar"
        self.isAllDay = event.isAllDay
        self.location = event.location

        if let cgColor = event.calendar?.cgColor {
            self.calendarColor = Color(cgColor: cgColor)
        } else {
            self.calendarColor = .blue
        }

        self.meetingURL = MeetingURLParser.extractMeetingURL(from: event)

        // Extract email from EKParticipant URL (format: mailto:email@example.com)
        let rawAttendees: [(email: String?, name: String, isCurrentUser: Bool, status: Attendee.Status)] =
            (event.attendees ?? [])
            .filter { $0.participantType == .person }
            .map { participant in
                let email = Self.extractEmail(from: participant)
                let name = participant.name ?? email ?? participant.url.absoluteString
                let status: Attendee.Status = switch participant.participantStatus {
                case .accepted: .accepted
                case .declined: .declined
                case .tentative: .tentative
                case .pending: .pending
                default: .unknown
                }
                return (email: email, name: name, isCurrentUser: participant.isCurrentUser, status: status)
            }

        // Resolve contacts for attendees
        let resolved = ContactResolver.shared.resolve(rawAttendees.compactMap { $0.email })

        self.attendees = rawAttendees.map { raw in
            let contactInfo = raw.email.flatMap { resolved[$0.lowercased()] }
            let displayName: String
            if let contact = contactInfo {
                let first = contact.givenName
                let lastInitial = contact.familyName.first.map { String($0) } ?? ""
                displayName = lastInitial.isEmpty ? first : "\(first) \(lastInitial)"
            } else {
                displayName = raw.name
            }

            return Attendee(
                id: raw.email ?? raw.name,
                email: raw.email,
                name: displayName,
                isCurrentUser: raw.isCurrentUser,
                status: raw.status,
                contactPhoto: contactInfo?.thumbnailImageData,
                resolvedFromContacts: contactInfo != nil
            )
        }
    }

    /// Extract email address from EKParticipant's URL (mailto:xxx)
    private static func extractEmail(from participant: EKParticipant) -> String? {
        let urlString = participant.url.absoluteString
        if urlString.lowercased().hasPrefix("mailto:") {
            return String(urlString.dropFirst(7))
        }
        return nil
    }

    // MARK: - Convenience Init (for previews / testing)

    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date,
        endDate: Date,
        calendarTitle: String = "Calendar",
        calendarColor: Color = .blue,
        meetingURL: URL? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        attendees: [Attendee] = []
    ) {
        self.eventIdentifier = id
        self.id = "\(id)_\(startDate.timeIntervalSince1970)"
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.calendarTitle = calendarTitle
        self.calendarColor = calendarColor
        self.meetingURL = meetingURL
        self.isAllDay = isAllDay
        self.location = location
        self.attendees = attendees
    }

    // MARK: - Formatted Time Range

    /// Formatted time range (e.g., "2:30 – 3:00 PM" or "2:30 PM – 3:30 PM")
    var formattedTimeRange: String {
        let startFormatter = DateFormatter()
        let endFormatter = DateFormatter()
        endFormatter.timeStyle = .short
        endFormatter.dateStyle = .none

        let startCal = Calendar.current
        let startComponents = startCal.dateComponents([.hour, .minute], from: startDate)
        let endComponents = startCal.dateComponents([.hour, .minute], from: endDate)

        // If both are in the same AM/PM period, omit AM/PM from start time
        let startIsAM = (startComponents.hour ?? 0) < 12
        let endIsAM = (endComponents.hour ?? 0) < 12

        if startIsAM == endIsAM {
            startFormatter.dateFormat = "h:mm"
        } else {
            startFormatter.timeStyle = .short
            startFormatter.dateStyle = .none
        }

        return "\(startFormatter.string(from: startDate)) – \(endFormatter.string(from: endDate))"
    }

    // MARK: - Computed Properties

    /// Whether this meeting has already started
    var hasStarted: Bool {
        Date() >= startDate
    }

    /// Whether this meeting has ended
    var hasEnded: Bool {
        Date() >= endDate
    }

    /// Time interval until the meeting starts (negative if already started)
    var timeUntilStart: TimeInterval {
        startDate.timeIntervalSinceNow
    }

    /// Formatted start time (e.g., "2:30 PM")
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: startDate)
    }

    /// Formatted time remaining (e.g., "5 min", "1:30")
    var formattedTimeRemaining: String {
        let remaining = timeUntilStart
        if remaining <= 0 {
            return "Now"
        }

        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(seconds)s"
        }
    }

    // MARK: - Equatable

    static func == (lhs: MeetingEvent, rhs: MeetingEvent) -> Bool {
        lhs.id == rhs.id && lhs.startDate == rhs.startDate
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(startDate)
    }
}
