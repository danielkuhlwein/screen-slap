//
//  Constants.swift
//  screen-slap
//

import Foundation

enum Constants {

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let alertMinutesBefore = "alertMinutesBefore"
        static let snoozeDurationSeconds = "snoozeDurationSeconds"
        static let autoJoinMeetings = "autoJoinMeetings"
        static let enabledCalendarIDs = "enabledCalendarIDs"
        static let playSound = "playSound"
        static let linkHandlerApps = "linkHandlerApps"
        static let soundName = "soundName"
        static let lookforwardDays = "lookforwardDays"
        static let alertForTentativeEvents = "alertForTentativeEvents"
    }

    // MARK: - Default Values

    enum Defaults {
        static let alertMinutesBefore: Int = 1
        static let snoozeDurationSeconds: Int = 60
        static let autoJoinMeetings: Bool = false
        static let playSound: Bool = true
        static let soundName: String = "Glass"
        static let lookforwardDays: Int = 5
        static let alertForTentativeEvents: Bool = true
    }

    // MARK: - Timer Intervals

    enum TimerIntervals {
        /// How often to re-fetch events from the calendar (seconds).
        /// This is the "slow" poll — hits EventKit.
        static let calendarFetchInterval: TimeInterval = 60

        /// How often to check if a cached meeting is within the alert window (seconds).
        /// This is the "fast" poll — just compares dates in memory.
        static let alertCheckInterval: TimeInterval = 1

        /// Tolerance on the calendar fetch timer for power efficiency (seconds)
        static let calendarFetchTolerance: TimeInterval = 5
    }

    // MARK: - UI

    enum UI {
        /// Maximum number of upcoming meetings to show in the menu bar dropdown
        static let maxUpcomingMeetings: Int = 15

        /// Maximum characters for the event title in the menu bar
        static let menuBarTitleMaxLength: Int = 14

        /// Minutes after meeting start to auto-dismiss the overlay
        static let autoDismissAfterStartMinutes: Int = 5
    }
}
