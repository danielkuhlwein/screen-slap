//
//  AppSettingsTests.swift
//  screen-slapTests
//

import XCTest
@testable import screen_slap

final class AppSettingsTests: XCTestCase {

    let settings = AppSettings.shared

    // MARK: - Alert Time Interval

    func testAlertTimeInterval() {
        let original = settings.alertMinutesBefore
        defer { settings.alertMinutesBefore = original }

        settings.alertMinutesBefore = 5
        XCTAssertEqual(settings.alertTimeInterval, 300)
    }

    func testAlertTimeIntervalOneMinute() {
        let original = settings.alertMinutesBefore
        defer { settings.alertMinutesBefore = original }

        settings.alertMinutesBefore = 1
        XCTAssertEqual(settings.alertTimeInterval, 60)
    }

    // MARK: - Snooze Time Interval

    func testSnoozeTimeInterval() {
        let original = settings.snoozeDurationSeconds
        defer { settings.snoozeDurationSeconds = original }

        settings.snoozeDurationSeconds = 120
        XCTAssertEqual(settings.snoozeTimeInterval, 120)
    }

    // MARK: - Lookforward Minutes

    func testLookforwardMinutes() {
        let original = settings.lookforwardDays
        defer { settings.lookforwardDays = original }

        settings.lookforwardDays = 7
        XCTAssertEqual(settings.lookforwardMinutes, 7 * 24 * 60) // 10080
    }

    func testLookforwardMinutesOneDay() {
        let original = settings.lookforwardDays
        defer { settings.lookforwardDays = original }

        settings.lookforwardDays = 1
        XCTAssertEqual(settings.lookforwardMinutes, 1440)
    }

    // MARK: - Formatted Snooze Duration

    func testFormattedSnoozeDurationSeconds() {
        let original = settings.snoozeDurationSeconds
        defer { settings.snoozeDurationSeconds = original }

        settings.snoozeDurationSeconds = 30
        XCTAssertEqual(settings.formattedSnoozeDuration, "30s")
    }

    func testFormattedSnoozeDurationOneMinute() {
        let original = settings.snoozeDurationSeconds
        defer { settings.snoozeDurationSeconds = original }

        settings.snoozeDurationSeconds = 60
        XCTAssertEqual(settings.formattedSnoozeDuration, "1 min")
    }

    func testFormattedSnoozeDurationMultipleMinutes() {
        let original = settings.snoozeDurationSeconds
        defer { settings.snoozeDurationSeconds = original }

        settings.snoozeDurationSeconds = 300
        XCTAssertEqual(settings.formattedSnoozeDuration, "5 min")
    }

    // MARK: - Link Handler Apps

    func testAppURLDefaultIsNil() {
        let original = settings.linkHandlerApps
        defer { settings.linkHandlerApps = original }

        settings.linkHandlerApps = [:]
        XCTAssertNil(settings.appURL(for: .zoom))
    }

    func testAppDisplayNameDefault() {
        let original = settings.linkHandlerApps
        defer { settings.linkHandlerApps = original }

        settings.linkHandlerApps = [:]
        XCTAssertEqual(settings.appDisplayName(for: .zoom), "Default")
    }

    func testSetAndGetApp() {
        let original = settings.linkHandlerApps
        defer { settings.linkHandlerApps = original }

        let testURL = URL(fileURLWithPath: "/Applications/Safari.app")
        settings.setApp(testURL, for: .zoom)
        XCTAssertEqual(settings.appURL(for: .zoom)?.path, testURL.path)
        XCTAssertEqual(settings.appDisplayName(for: .zoom), "Safari")
    }

    func testClearApp() {
        let original = settings.linkHandlerApps
        defer { settings.linkHandlerApps = original }

        let testURL = URL(fileURLWithPath: "/Applications/Safari.app")
        settings.setApp(testURL, for: .zoom)
        settings.setApp(nil, for: .zoom)
        XCTAssertNil(settings.appURL(for: .zoom))
        XCTAssertEqual(settings.appDisplayName(for: .zoom), "Default")
    }

    func testMultipleProviderApps() {
        let original = settings.linkHandlerApps
        defer { settings.linkHandlerApps = original }

        let safari = URL(fileURLWithPath: "/Applications/Safari.app")
        let chrome = URL(fileURLWithPath: "/Applications/Google Chrome.app")

        settings.setApp(safari, for: .zoom)
        settings.setApp(chrome, for: .googleMeet)

        XCTAssertEqual(settings.appDisplayName(for: .zoom), "Safari")
        XCTAssertEqual(settings.appDisplayName(for: .googleMeet), "Google Chrome")
        XCTAssertEqual(settings.appDisplayName(for: .teams), "Default")
    }

    // MARK: - Constants

    func testDefaultValues() {
        XCTAssertEqual(Constants.Defaults.alertMinutesBefore, 1)
        XCTAssertEqual(Constants.Defaults.snoozeDurationSeconds, 60)
        XCTAssertEqual(Constants.Defaults.autoJoinMeetings, false)
        XCTAssertEqual(Constants.Defaults.playSound, true)
        XCTAssertEqual(Constants.Defaults.soundName, "Glass")
        XCTAssertEqual(Constants.Defaults.lookforwardDays, 5)
    }

    func testUIConstants() {
        XCTAssertEqual(Constants.UI.maxUpcomingMeetings, 15)
        XCTAssertEqual(Constants.UI.menuBarTitleMaxLength, 14)
        XCTAssertEqual(Constants.UI.autoDismissAfterStartMinutes, 5)
    }

    func testTimerIntervals() {
        XCTAssertEqual(Constants.TimerIntervals.calendarFetchInterval, 60)
        XCTAssertEqual(Constants.TimerIntervals.alertCheckInterval, 1)
        XCTAssertEqual(Constants.TimerIntervals.calendarFetchTolerance, 5)
    }
}
