//
//  screen_slapApp.swift
//  screen-slap
//
//  Created by Daniel Kuhlwein on 2026-03-07.
//

import SwiftUI

@main
struct screen_slapApp: App {

    private let appSettings = AppSettings.shared
    private let calendarService = CalendarService.shared
    private let updaterController = UpdaterController()
    @State private var meetingMonitor: MeetingMonitor?
    @State private var overlayManager = OverlayWindowManager()
    @State private var lastAlertID: String?
    @State private var menuBarLabel: String = "no events"

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(calendarService: calendarService, meetingMonitor: meetingMonitor)
        } label: {
            Text(menuBarLabel)
                .onAppear {
                    startMonitoringIfNeeded()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(updaterController: updaterController)
        }
    }

    // MARK: - Monitor Setup

    private func startMonitoringIfNeeded() {
        guard meetingMonitor == nil else { return }

        updaterController.startUpdater()

        let monitor = MeetingMonitor(calendarService: calendarService)
        meetingMonitor = monitor
        monitor.start()

        // Bridge monitor's activeAlert to overlay manager and update menu bar label.
        // The monitor's fast timer (1s) updates activeAlert; we poll here
        // to sync with the overlay window manager (AppKit, non-SwiftUI).
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak monitor] _ in
            guard let monitor else { return }
            syncOverlay(with: monitor)
            updateMenuBarLabel(with: monitor)
        }
    }

    private func syncOverlay(with monitor: MeetingMonitor) {
        let currentAlertID = monitor.activeAlert?.id

        // Only act on changes
        guard currentAlertID != lastAlertID else { return }
        lastAlertID = currentAlertID

        if let meeting = monitor.activeAlert {
            overlayManager.showOverlay(
                for: meeting,
                snoozeDurationLabel: appSettings.formattedSnoozeDuration,
                onJoin: { monitor.joinMeeting() },
                onDismiss: { monitor.dismiss() },
                onSnooze: { monitor.snooze() }
            )
        } else {
            if overlayManager.isShowing {
                overlayManager.hideOverlay()
            }
        }
    }

    // MARK: - Menu Bar Label

    private func updateMenuBarLabel(with monitor: MeetingMonitor) {
        let newLabel = computeMenuBarLabel(from: monitor)
        if menuBarLabel != newLabel {
            menuBarLabel = newLabel
        }
    }

    private func computeMenuBarLabel(from monitor: MeetingMonitor) -> String {
        guard let next = monitor.nextMeeting else {
            return "no events"
        }

        let maxLength = Constants.UI.menuBarTitleMaxLength
        var name = next.title
        if name.count > maxLength {
            name = String(name.prefix(maxLength - 1)) + "…"
        }

        let time = shortformTimeRemaining(next.startDate)
        return "\(name) · \(time)"
    }

    private func shortformTimeRemaining(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        let calendar = Calendar.current

        if interval <= 0 { return "now" }

        // Today: show hours/minutes
        if calendar.isDateInToday(date) {
            let totalMinutes = Int(interval) / 60
            if totalMinutes >= 60 {
                let hours = totalMinutes / 60
                let remainingMinutes = totalMinutes % 60
                if remainingMinutes >= 30 {
                    return "\(hours).5h"
                } else {
                    return "\(hours)h"
                }
            } else if totalMinutes > 0 {
                return "\(totalMinutes)m"
            } else {
                return "<1m"
            }
        }

        // Tomorrow
        if calendar.isDateInTomorrow(date) {
            return "tmrw"
        }

        // Further out: show short day name (Mon, Tue, etc.)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}
