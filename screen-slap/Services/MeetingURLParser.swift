//
//  MeetingURLParser.swift
//  screen-slap
//

import EventKit
import Foundation

/// Known meeting service providers
enum MeetingProvider: String, CaseIterable, Identifiable, Codable {
    case zoom = "Zoom"
    case googleMeet = "Google Meet"
    case teams = "Microsoft Teams"
    case webex = "Webex"
    case slack = "Slack"
    case goTo = "GoTo"
    case whereby = "Whereby"
    case skype = "Skype"
    case jitsi = "Jitsi"
    case facetime = "FaceTime"
    case discord = "Discord"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .zoom: "video.fill"
        case .googleMeet: "video.fill"
        case .teams: "video.fill"
        case .webex: "video.fill"
        case .slack: "message.fill"
        case .goTo: "video.fill"
        case .whereby: "video.fill"
        case .skype: "video.fill"
        case .jitsi: "video.fill"
        case .facetime: "video.fill"
        case .discord: "headphones"
        case .other: "link"
        }
    }
}

/// Extracts meeting/conferencing URLs from calendar events.
/// Checks event.url first, then scans notes, then location.
enum MeetingURLParser {

    // MARK: - Public API

    /// Extract the best meeting URL from an EKEvent.
    /// Priority: event.url > event.notes > event.location
    static func extractMeetingURL(from event: EKEvent) -> URL? {
        // 1. Check the dedicated URL field first
        if let url = event.url, isMeetingURL(url) {
            return url
        }

        // 2. Scan notes for meeting URLs
        if let notes = event.notes, let url = findMeetingURL(in: notes) {
            return url
        }

        // 3. Scan location for meeting URLs
        if let location = event.location, let url = findMeetingURL(in: location) {
            return url
        }

        return nil
    }

    /// Extract the best meeting URL from raw text (for testing without EKEvent).
    /// Only matches known conferencing services — no generic URL fallback.
    static func findMeetingURL(in text: String) -> URL? {
        for pattern in meetingPatterns {
            if let url = firstMatch(pattern: pattern, in: text) {
                return url
            }
        }

        return nil
    }

    /// Detect which meeting provider a URL belongs to
    static func provider(for url: URL) -> MeetingProvider {
        guard let host = url.host?.lowercased() else { return .other }

        if host.hasSuffix("zoom.us") || host.hasSuffix("zoomgov.com") { return .zoom }
        if host.hasSuffix("meet.google.com") { return .googleMeet }
        if host.hasSuffix("teams.microsoft.com") || host.hasSuffix("teams.live.com") { return .teams }
        if host.hasSuffix("webex.com") { return .webex }
        if host.hasSuffix("slack.com") { return .slack }
        if host.hasSuffix("gotomeeting.com") || host.hasSuffix("goto.com") { return .goTo }
        if host.hasSuffix("whereby.com") { return .whereby }
        if host.hasSuffix("join.skype.com") { return .skype }
        if host.hasSuffix("meet.jit.si") { return .jitsi }
        if host.hasSuffix("facetime.apple.com") { return .facetime }
        if host.hasSuffix("discord.gg") { return .discord }

        return .other
    }

    // MARK: - Meeting Service Patterns

    private static let meetingPatterns: [String] = [
        // Zoom
        #"https?://[\w.-]*zoom\.us/[jw]/\d+[^\s<>"\)]*"#,

        // Zoom Gov
        #"https?://[\w.-]*zoomgov\.com/[jw]/\d+[^\s<>"\)]*"#,

        // Google Meet
        #"https?://meet\.google\.com/[\w-]+"#,

        // Microsoft Teams
        #"https?://teams\.microsoft\.com/l/meetup-join/[^\s<>"\)]*"#,

        // Microsoft Teams (short link)
        #"https?://teams\.live\.com/meet/[^\s<>"\)]*"#,

        // Webex
        #"https?://[\w.-]*webex\.com/[\w.-]*/[jm][^\s<>"\)]*"#,

        // Slack Huddle
        #"https?://app\.slack\.com/huddle/[^\s<>"\)]*"#,

        // GoToMeeting
        #"https?://[\w.-]*gotomeeting\.com/join/[^\s<>"\)]*"#,

        // GoTo (newer branding)
        #"https?://[\w.-]*goto\.com/[^\s<>"\)]*"#,

        // Around
        #"https?://[\w.-]*around\.co/[^\s<>"\)]*"#,

        // Whereby
        #"https?://whereby\.com/[^\s<>"\)]*"#,

        // Loom (live meetings)
        #"https?://[\w.-]*loom\.com/meeting/[^\s<>"\)]*"#,

        // Discord
        #"https?://discord\.gg/[^\s<>"\)]*"#,

        // Skype
        #"https?://join\.skype\.com/[^\s<>"\)]*"#,

        // Jitsi
        #"https?://meet\.jit\.si/[^\s<>"\)]*"#,

        // Chime (Amazon)
        #"https?://chime\.aws/[^\s<>"\)]*"#,

        // RingCentral
        #"https?://[\w.-]*ringcentral\.com/[jw]/[^\s<>"\)]*"#,

        // BlueJeans
        #"https?://[\w.-]*bluejeans\.com/[^\s<>"\)]*"#,

        // FaceTime
        #"https?://facetime\.apple\.com/join[^\s<>"\)]*"#,

        // Tuple (pair programming)
        #"https?://[\w.-]*tuple\.app/[^\s<>"\)]*"#,
    ]

    // MARK: - Known Meeting Hosts

    private static let knownMeetingHosts: Set<String> = [
        "zoom.us", "zoomgov.com",
        "meet.google.com",
        "teams.microsoft.com", "teams.live.com",
        "webex.com",
        "gotomeeting.com", "goto.com",
        "slack.com",
        "around.co",
        "whereby.com",
        "loom.com",
        "discord.gg",
        "join.skype.com",
        "meet.jit.si",
        "chime.aws",
        "ringcentral.com",
        "bluejeans.com",
        "facetime.apple.com",
        "tuple.app",
    ]

    // MARK: - Helpers

    /// Check if a URL belongs to a known meeting service
    private static func isMeetingURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return knownMeetingHosts.contains(where: { host.hasSuffix($0) })
    }

    /// Find the first regex match in text and return it as a URL
    private static func firstMatch(pattern: String, in text: String) -> URL? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }

        guard let matchRange = Range(match.range, in: text) else {
            return nil
        }

        let urlString = String(text[matchRange])
        return URL(string: urlString)
    }
}
