//
//  MeetingMonitor.swift
//  screen-slap
//

import AppKit
import Foundation
import os

/// Central coordinator that monitors the calendar for approaching meetings
/// and manages the alert/dismiss/snooze state machine.
///
/// Uses two timers:
/// - **Slow timer** (every 60s): fetches events from EventKit and caches them
/// - **Fast timer** (every 1s): checks cached events against the alert window
@Observable
final class MeetingMonitor {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screen-slap",
        category: "MeetingMonitor"
    )

    // MARK: - Dependencies

    let calendarService: any CalendarServiceProtocol
    private let settings: AppSettings

    // MARK: - Published State

    /// The meeting currently being alerted (nil = no overlay)
    private(set) var activeAlert: MeetingEvent?

    /// Next upcoming meeting (for menu bar display)
    private(set) var nextMeeting: MeetingEvent?

    /// All upcoming meetings with meeting URLs (cached from last fetch)
    private(set) var upcomingMeetings: [MeetingEvent] = []

    /// Whether the monitor is actively running
    private(set) var isMonitoring: Bool = false

    // MARK: - Internal State

    /// Event IDs the user has explicitly dismissed this session
    private var dismissedEventIDs: Set<String> = []

    /// When the current snooze expires (nil = not snoozed)
    private var snoozedUntil: Date?

    /// The snoozed event ID (to re-alert after snooze expires)
    private var snoozedEventID: String?

    /// Slow timer: periodic calendar fetch
    private var fetchTimer: Timer?

    /// Fast timer: checks cached events against alert window
    private var alertCheckTimer: Timer?

    // MARK: - Init

    init(calendarService: any CalendarServiceProtocol, settings: AppSettings = .shared) {
        self.calendarService = calendarService
        self.settings = settings
    }

    // MARK: - Lifecycle

    /// Start monitoring for approaching meetings
    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Immediate calendar fetch
        fetchEventsFromCalendar()

        // Slow timer: re-fetch from EventKit every 60s
        fetchTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.TimerIntervals.calendarFetchInterval,
            repeats: true
        ) { [weak self] _ in
            self?.fetchEventsFromCalendar()
        }
        fetchTimer?.tolerance = Constants.TimerIntervals.calendarFetchTolerance

        // Fast timer: check cached events every 1s
        alertCheckTimer = Timer.scheduledTimer(
            withTimeInterval: Constants.TimerIntervals.alertCheckInterval,
            repeats: true
        ) { [weak self] _ in
            self?.checkForAlerts()
        }

        Self.logger.info("Meeting monitor started (fetch: \(Constants.TimerIntervals.calendarFetchInterval)s, alert check: \(Constants.TimerIntervals.alertCheckInterval)s)")
    }

    /// Stop monitoring
    func stop() {
        fetchTimer?.invalidate()
        fetchTimer = nil
        alertCheckTimer?.invalidate()
        alertCheckTimer = nil
        isMonitoring = false
        Self.logger.info("Meeting monitor stopped")
    }

    // MARK: - User Actions

    /// Dismiss the current alert — won't show again for this event
    func dismiss() {
        guard let meeting = activeAlert else { return }
        dismissedEventIDs.insert(meeting.id)
        activeAlert = nil
        Self.logger.info("Dismissed alert for: \(meeting.title)")
    }

    /// Snooze the current alert — will re-show after snooze duration
    func snooze() {
        guard let meeting = activeAlert else { return }
        snoozedUntil = Date().addingTimeInterval(settings.snoozeTimeInterval)
        snoozedEventID = meeting.id
        activeAlert = nil
        Self.logger.info("Snoozed alert for: \(meeting.title) until \(self.snoozedUntil!)")
    }

    /// Join the meeting — open URL with configured app, then dismiss
    func joinMeeting() {
        guard let meeting = activeAlert, let url = meeting.meetingURL else { return }
        Self.logger.info("Joining meeting: \(meeting.title) at \(url)")

        // Dismiss first so overlay closes before browser opens
        dismissedEventIDs.insert(meeting.id)
        activeAlert = nil

        // Open meeting URL with the configured app (or system default)
        Self.openMeetingURL(url)
    }

    /// Open a meeting URL using the provider-specific app configured in settings, or system default.
    static func openMeetingURL(_ url: URL) {
        let provider = MeetingURLParser.provider(for: url)
        let settings = AppSettings.shared

        guard let appURL = settings.appURL(for: provider) else {
            NSWorkspace.shared.open(url)
            return
        }

        // Check if the selected app is a Chrome PWA
        if let chromePWAAppID = Self.chromePWAAppID(for: appURL) {
            Self.openInChromePWA(url: url, appID: chromePWAAppID)
        } else {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    /// Detect if an app bundle is a Chrome PWA and extract its app ID.
    /// Chrome PWAs have `CrAppModeShortcutID` in their Info.plist.
    private static func chromePWAAppID(for appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: plistURL) else { return nil }

        // Check it's a Chrome PWA by verifying CrBundleIdentifier
        guard let crBundle = plist["CrBundleIdentifier"] as? String,
              crBundle.contains("com.google.Chrome") else { return nil }

        return plist["CrAppModeShortcutID"] as? String
    }

    /// Open a URL in a Chrome app-style window (minimal UI, no tabs/address bar).
    /// Chrome PWAs cannot deep-link to specific URLs from external apps, so we use
    /// Chrome's `--app=URL` flag which provides the same app-like experience.
    private static func openInChromePWA(url: URL, appID: String) {
        logger.info("Opening \(url) in Chrome app window (PWA app-id: \(appID))")

        // Find Chrome's path
        guard let chromeURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.google.Chrome"
        ) else {
            logger.warning("Chrome not found, falling back to default browser")
            NSWorkspace.shared.open(url)
            return
        }

        // Use --app=URL to open in a minimal Chrome window (no tabs, no address bar).
        // This gives the same visual experience as the PWA.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [
            "-na", chromeURL.path,
            "--args",
            "--app=\(url.absoluteString)",
        ]

        do {
            try process.run()
        } catch {
            logger.warning("Failed to open Chrome app window: \(error.localizedDescription), falling back to default")
            NSWorkspace.shared.open(url)
        }
    }

    /// Force-trigger the overlay for a specific meeting (for testing)
    func triggerTestAlert(for meeting: MeetingEvent) {
        Self.logger.info("Test alert triggered for: \(meeting.title)")
        activeAlert = meeting
    }

    // MARK: - Slow Path: Calendar Fetch (every 60s)

    func fetchEventsFromCalendar() {
        guard calendarService.hasAccess else { return }

        let calendarIDs = settings.enabledCalendarIDs.isEmpty ? nil : settings.enabledCalendarIDs

        upcomingMeetings = calendarService.fetchUpcomingEvents(
            within: settings.lookforwardMinutes,
            calendarIDs: calendarIDs,
            meetingURLOnly: true
        )

        nextMeeting = upcomingMeetings.first

        // Clean up stale dismissals
        cleanupDismissedEvents()
    }

    // MARK: - Fast Path: Alert Check (every 1s)

    func checkForAlerts() {
        // Check if snooze has expired
        checkSnoozeExpiry()

        // Auto-dismiss if the active alert's meeting was cancelled or is no longer upcoming
        if let active = activeAlert {
            let stillUpcoming = upcomingMeetings.contains { $0.id == active.id }
            if !stillUpcoming {
                Self.logger.info("Active alert meeting no longer upcoming (cancelled/removed), auto-dismissing: \(active.title)")
                activeAlert = nil
            }
        }

        // Auto-dismiss if meeting has been running for too long
        if let active = activeAlert {
            let timeSinceStart = -active.timeUntilStart
            if timeSinceStart > TimeInterval(Constants.UI.autoDismissAfterStartMinutes * 60) {
                Self.logger.info("Meeting started >\(Constants.UI.autoDismissAfterStartMinutes) min ago, auto-dismissing: \(active.title)")
                dismissedEventIDs.insert(active.id)
                activeAlert = nil
            }
        }

        // Find the first meeting that should trigger an alert
        let candidate = upcomingMeetings.first { meeting in
            // Must be within the alert window
            let timeUntilStart = meeting.startDate.timeIntervalSinceNow
            guard timeUntilStart <= settings.alertTimeInterval else { return false }

            // Not already dismissed
            guard !dismissedEventIDs.contains(meeting.id) else { return false }

            // Not currently snoozed
            if let snoozedID = snoozedEventID, let snoozedUntil, meeting.id == snoozedID {
                if Date() < snoozedUntil {
                    return false
                }
            }

            return true
        }

        // Update activeAlert
        if let candidate {
            if activeAlert?.id != candidate.id {
                activeAlert = candidate
                Self.logger.info("Alert triggered for: \(candidate.title) starting at \(candidate.formattedStartTime)")
            }
        }
    }

    // MARK: - Helpers

    private func cleanupDismissedEvents() {
        // Simple approach: clear all dismissals if we have more than 50
        if dismissedEventIDs.count > 50 {
            dismissedEventIDs.removeAll()
            Self.logger.debug("Cleared stale dismissed event IDs")
        }

        // Clear snooze if the snoozed event is no longer upcoming
        if let snoozedID = snoozedEventID {
            let stillRelevant = upcomingMeetings.contains { $0.id == snoozedID }
            if !stillRelevant && (snoozedUntil ?? .distantPast) < Date() {
                snoozedEventID = nil
                snoozedUntil = nil
            }
        }
    }

    private func checkSnoozeExpiry() {
        guard let snoozedUntil, Date() >= snoozedUntil else { return }

        Self.logger.info("Snooze expired for event \(self.snoozedEventID ?? "unknown")")
        self.snoozedEventID = nil
        self.snoozedUntil = nil
    }
}
