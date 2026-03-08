//
//  SettingsView.swift
//  screen-slap
//

import AppKit
import EventKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            CalendarSettingsTab()
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }

            LinkHandlerSettingsTab()
                .tabItem {
                    Label("Link Handlers", systemImage: "link")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - General Tab

private struct GeneralSettingsTab: View {

    private var settings = AppSettings.shared

    private let alertOptions: [(label: String, minutes: Int)] = [
        ("1 minute", 1),
        ("2 minutes", 2),
        ("3 minutes", 3),
        ("5 minutes", 5),
        ("10 minutes", 10),
        ("15 minutes", 15),
    ]

    private let snoozeOptions: [(label: String, seconds: Int)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
    ]

    private let lookforwardOptions: [(label: String, days: Int)] = [
        ("Today only", 1),
        ("Next 2 days", 2),
        ("Next 3 days", 3),
        ("Next 5 days", 5),
        ("Next 7 days", 7),
    ]

    var body: some View {
        Form {
            Section("Timing") {
                Picker("Alert before meeting", selection: Bindable(settings).alertMinutesBefore) {
                    ForEach(alertOptions, id: \.minutes) { option in
                        Text(option.label).tag(option.minutes)
                    }
                }

                Picker("Snooze duration", selection: Bindable(settings).snoozeDurationSeconds) {
                    ForEach(snoozeOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }

                Picker("Show events for", selection: Bindable(settings).lookforwardDays) {
                    ForEach(lookforwardOptions, id: \.days) { option in
                        Text(option.label).tag(option.days)
                    }
                }
            }

            Section("Sound") {
                Toggle("Play alert sound", isOn: Bindable(settings).playSound)

                if settings.playSound {
                    Picker("Alert sound", selection: Bindable(settings).soundName) {
                        ForEach(SoundManager.systemSounds, id: \.self) { sound in
                            Text(sound).tag(sound)
                        }
                    }
                    .onChange(of: settings.soundName) { _, newValue in
                        SoundManager.play(newValue)
                    }
                }
            }

            Section("Behavior") {
                Toggle("Auto-join meetings", isOn: Bindable(settings).autoJoinMeetings)
                Toggle("Launch at login", isOn: Bindable(settings).launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Calendars Tab

private struct CalendarSettingsTab: View {

    private var settings = AppSettings.shared
    @State private var calendarService = CalendarService.shared

    /// Whether "All calendars" mode is active (empty enabledCalendarIDs means all)
    private var allCalendarsEnabled: Bool {
        settings.enabledCalendarIDs.isEmpty
    }

    /// Whether every individual calendar is toggled on (in explicit mode)
    private var allIndividualEnabled: Bool {
        let allIDs = Set(calendarService.availableCalendars.map(\.calendarIdentifier))
        return allIDs.isSubset(of: settings.enabledCalendarIDs)
    }

    var body: some View {
        Form {
            if !calendarService.hasAccess {
                CalendarPermissionView(
                    authorizationStatus: calendarService.authorizationStatus,
                    onRequestAccess: {
                        _ = await calendarService.requestAccess()
                    }
                )
            } else {
                Section {
                    Toggle("Monitor all calendars", isOn: Binding(
                        get: { allCalendarsEnabled },
                        set: { newValue in
                            if newValue {
                                settings.enabledCalendarIDs = []
                            } else {
                                // Switch to explicit mode with all currently available
                                settings.enabledCalendarIDs = Set(
                                    calendarService.availableCalendars.map(\.calendarIdentifier)
                                )
                            }
                        }
                    ))
                }

                if !allCalendarsEnabled {
                    Section("Select calendars to monitor") {
                        Toggle(
                            allIndividualEnabled ? "Deselect All" : "Select All",
                            isOn: Binding(
                                get: { allIndividualEnabled },
                                set: { selectAll in
                                    if selectAll {
                                        settings.enabledCalendarIDs = Set(
                                            calendarService.availableCalendars.map(\.calendarIdentifier)
                                        )
                                    } else {
                                        settings.enabledCalendarIDs = []
                                        // Set to a single impossible ID so it stays in explicit mode
                                        // (empty = "all calendars" mode)
                                        settings.enabledCalendarIDs = ["__none__"]
                                    }
                                }
                            )
                        )
                        .font(.subheadline)

                        ForEach(calendarService.availableCalendars, id: \.calendarIdentifier) { calendar in
                            calendarRow(calendar)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func calendarRow(_ calendar: EKCalendar) -> some View {
        Toggle(isOn: Binding(
            get: {
                settings.enabledCalendarIDs.contains(calendar.calendarIdentifier)
            },
            set: { enabled in
                if enabled {
                    settings.enabledCalendarIDs.insert(calendar.calendarIdentifier)
                } else {
                    settings.enabledCalendarIDs.remove(calendar.calendarIdentifier)
                }
            }
        )) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(cgColor: calendar.cgColor))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 1) {
                    Text(calendar.title)
                        .font(.body)

                    Text(calendar.source.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Link Handler Tab

private struct LinkHandlerSettingsTab: View {

    private var settings = AppSettings.shared

    var body: some View {
        Form {
            Section {
                Text("Choose which app opens meeting links for each provider. \"Default\" uses your system's default browser.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Meeting Providers") {
                ForEach(MeetingProvider.allCases) { provider in
                    providerRow(provider)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func providerRow(_ provider: MeetingProvider) -> some View {
        HStack {
            Image(systemName: provider.iconName)
                .frame(width: 20)
                .foregroundStyle(.secondary)

            Text(provider.rawValue)

            Spacer()

            let appName = settings.appDisplayName(for: provider)

            if let appURL = settings.appURL(for: provider) {
                appIcon(for: appURL)
            }

            Text(appName)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            Button("Choose...") {
                chooseApp(for: provider)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            if settings.appURL(for: provider) != nil {
                Button {
                    settings.setApp(nil, for: provider)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
    }

    private func appIcon(for appURL: URL) -> some View {
        let icon = NSWorkspace.shared.icon(forFile: appURL.path)
        return Image(nsImage: icon)
            .resizable()
            .frame(width: 18, height: 18)
    }

    private func chooseApp(for provider: MeetingProvider) {
        let panel = NSOpenPanel()
        panel.title = "Choose app for \(provider.rawValue) links"
        panel.allowedContentTypes = [UTType.application]
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            settings.setApp(url, for: provider)
        }
    }
}

// MARK: - About Tab

private struct AboutTab: View {

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Screen Slap")
                .font(.title2.bold())

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("Version \(version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("Never be late to a meeting again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
