//
//  AppSettings.swift
//  screen-slap
//

import Foundation
import ServiceManagement

@Observable
final class AppSettings {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Settings Properties

    /// How many minutes before a meeting to show the overlay
    var alertMinutesBefore: Int {
        didSet { defaults.set(alertMinutesBefore, forKey: Constants.UserDefaultsKeys.alertMinutesBefore) }
    }

    /// How long a snooze lasts (in seconds)
    var snoozeDurationSeconds: Int {
        didSet { defaults.set(snoozeDurationSeconds, forKey: Constants.UserDefaultsKeys.snoozeDurationSeconds) }
    }

    /// Whether to automatically open the meeting URL when the overlay appears
    var autoJoinMeetings: Bool {
        didSet { defaults.set(autoJoinMeetings, forKey: Constants.UserDefaultsKeys.autoJoinMeetings) }
    }

    /// IDs of calendars to monitor. Empty means all calendars.
    var enabledCalendarIDs: Set<String> {
        didSet {
            defaults.set(Array(enabledCalendarIDs), forKey: Constants.UserDefaultsKeys.enabledCalendarIDs)
        }
    }

    /// Whether to play a sound when the overlay appears
    var playSound: Bool {
        didSet { defaults.set(playSound, forKey: Constants.UserDefaultsKeys.playSound) }
    }

    /// Name of the alert sound to play (system sound name or "None")
    var soundName: String {
        didSet { defaults.set(soundName, forKey: Constants.UserDefaultsKeys.soundName) }
    }

    /// How many days ahead to fetch and display events
    var lookforwardDays: Int {
        didSet { defaults.set(lookforwardDays, forKey: Constants.UserDefaultsKeys.lookforwardDays) }
    }

    /// Whether to launch at login via SMAppService
    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Revert on failure
                launchAtLogin = oldValue
            }
        }
    }

    /// Per-provider app overrides. Key = MeetingProvider.rawValue, Value = app bundle path.
    /// Missing key or empty string = use system default.
    var linkHandlerApps: [String: String] {
        didSet {
            defaults.set(linkHandlerApps, forKey: Constants.UserDefaultsKeys.linkHandlerApps)
        }
    }

    // MARK: - Link Handler Helpers

    /// Get the configured app URL for a meeting provider (nil = system default)
    func appURL(for provider: MeetingProvider) -> URL? {
        guard let path = linkHandlerApps[provider.rawValue], !path.isEmpty else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// Set the app for a provider (nil = reset to default)
    func setApp(_ appURL: URL?, for provider: MeetingProvider) {
        if let appURL {
            linkHandlerApps[provider.rawValue] = appURL.path
        } else {
            linkHandlerApps.removeValue(forKey: provider.rawValue)
        }
    }

    /// Get the display name of the configured app for a provider
    func appDisplayName(for provider: MeetingProvider) -> String {
        guard let url = appURL(for: provider) else { return "Default" }
        return url.deletingPathExtension().lastPathComponent
    }

    // MARK: - Computed Properties

    /// The alert time as a TimeInterval (for calculations)
    var alertTimeInterval: TimeInterval {
        TimeInterval(alertMinutesBefore * 60)
    }

    /// The snooze duration as a TimeInterval
    var snoozeTimeInterval: TimeInterval {
        TimeInterval(snoozeDurationSeconds)
    }

    /// Lookforward window in minutes (for calendar fetch calls)
    var lookforwardMinutes: Int {
        lookforwardDays * 24 * 60
    }

    /// Formatted snooze duration for display
    var formattedSnoozeDuration: String {
        if snoozeDurationSeconds < 60 {
            return "\(snoozeDurationSeconds)s"
        } else {
            let minutes = snoozeDurationSeconds / 60
            return "\(minutes) min"
        }
    }

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard

        // Register defaults so first read always returns a sensible value
        defaults.register(defaults: [
            Constants.UserDefaultsKeys.alertMinutesBefore: Constants.Defaults.alertMinutesBefore,
            Constants.UserDefaultsKeys.snoozeDurationSeconds: Constants.Defaults.snoozeDurationSeconds,
            Constants.UserDefaultsKeys.autoJoinMeetings: Constants.Defaults.autoJoinMeetings,
            Constants.UserDefaultsKeys.playSound: Constants.Defaults.playSound,
            Constants.UserDefaultsKeys.soundName: Constants.Defaults.soundName,
            Constants.UserDefaultsKeys.lookforwardDays: Constants.Defaults.lookforwardDays,
        ])

        self.alertMinutesBefore = defaults.integer(forKey: Constants.UserDefaultsKeys.alertMinutesBefore)
        self.snoozeDurationSeconds = defaults.integer(forKey: Constants.UserDefaultsKeys.snoozeDurationSeconds)
        self.autoJoinMeetings = defaults.bool(forKey: Constants.UserDefaultsKeys.autoJoinMeetings)
        self.playSound = defaults.bool(forKey: Constants.UserDefaultsKeys.playSound)
        self.soundName = defaults.string(forKey: Constants.UserDefaultsKeys.soundName) ?? Constants.Defaults.soundName
        self.lookforwardDays = defaults.integer(forKey: Constants.UserDefaultsKeys.lookforwardDays)
        self.linkHandlerApps = (defaults.dictionary(forKey: Constants.UserDefaultsKeys.linkHandlerApps) as? [String: String]) ?? [:]
        self.launchAtLogin = SMAppService.mainApp.status == .enabled

        if let savedIDs = defaults.stringArray(forKey: Constants.UserDefaultsKeys.enabledCalendarIDs) {
            self.enabledCalendarIDs = Set(savedIDs)
        } else {
            self.enabledCalendarIDs = []
        }
    }
}
