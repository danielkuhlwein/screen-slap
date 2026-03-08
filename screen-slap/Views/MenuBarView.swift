//
//  MenuBarView.swift
//  screen-slap
//

import SwiftUI

struct MenuBarView: View {

    var calendarService: CalendarService
    var meetingMonitor: MeetingMonitor?

    /// Read directly from the monitor's cached meetings — no duplicate fetching.
    private var upcomingMeetings: [MeetingEvent] {
        meetingMonitor?.upcomingMeetings ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Permission warning or meeting list
            if !calendarService.hasAccess {
                CalendarPermissionView(
                    authorizationStatus: calendarService.authorizationStatus,
                    onRequestAccess: {
                        _ = await calendarService.requestAccess()
                        meetingMonitor?.fetchEventsFromCalendar()
                    }
                )
                .padding(12)
            } else if upcomingMeetings.isEmpty {
                Text("No upcoming meetings")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                meetingsList
            }

            Divider()

            footerSection
        }
        .frame(width: 320)
    }

    // MARK: - Meetings List

    private var meetingsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group meetings by day
            let grouped = groupedByDay(upcomingMeetings.prefix(Constants.UI.maxUpcomingMeetings))

            ForEach(Array(grouped.enumerated()), id: \.offset) { index, group in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 2)
                }

                // Day header
                Text(group.label)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .padding(.horizontal, 12)
                    .padding(.top, index == 0 ? 6 : 4)
                    .padding(.bottom, 4)

                ForEach(group.meetings) { meeting in
                    MeetingRow(meeting: meeting, meetingMonitor: meetingMonitor)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            SettingsLink {
                Label("Settings…", systemImage: "gear")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .onHover { _ in }  // Workaround: force hit-testing
            .simultaneousGesture(TapGesture().onEnded {
                NSApp.activate(ignoringOtherApps: true)
            })

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Day Grouping

    private struct DayGroup {
        let label: String
        let meetings: [MeetingEvent]
    }

    private func groupedByDay(_ meetings: some Collection<MeetingEvent>) -> [DayGroup] {
        let calendar = Calendar.current
        var groups: [DayGroup] = []
        var currentMeetings: [MeetingEvent] = []
        var currentDay: Int?

        for meeting in meetings {
            let day = calendar.ordinality(of: .day, in: .era, for: meeting.startDate)
            if day != currentDay {
                if !currentMeetings.isEmpty {
                    let label = dayLabel(for: currentMeetings[0].startDate)
                    groups.append(DayGroup(label: label, meetings: currentMeetings))
                }
                currentMeetings = [meeting]
                currentDay = day
            } else {
                currentMeetings.append(meeting)
            }
        }

        if !currentMeetings.isEmpty {
            let label = dayLabel(for: currentMeetings[0].startDate)
            groups.append(DayGroup(label: label, meetings: currentMeetings))
        }

        return groups
    }

    private func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }

}

// MARK: - Meeting Row

private struct MeetingRow: View {

    let meeting: MeetingEvent
    var meetingMonitor: MeetingMonitor?
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Calendar color dot
            Circle()
                .fill(meeting.calendarColor)
                .frame(width: 8, height: 8)

            // Title and time range
            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.body)
                    .foregroundStyle(isHovered ? .white : .primary)
                    .lineLimit(1)

                Text(meeting.formattedTimeRange)
                    .font(.subheadline)
                    .foregroundStyle(isHovered ? Color.white.opacity(0.8) : .secondary)
            }

            Spacer()

            // Time remaining badge
            Text(meeting.formattedTimeRemaining)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(isHovered ? .white : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered ? Color.white.opacity(0.2) : Color.primary.opacity(0.06))
                )

            // Join button (opens meeting link directly)
            if let url = meeting.meetingURL {
                Button {
                    MeetingMonitor.openMeetingURL(url)
                } label: {
                    Image(systemName: "video.fill")
                        .font(.subheadline)
                        .foregroundStyle(isHovered ? .white : .secondary)
                }
                .buttonStyle(.borderless)
                .help("Join meeting")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            meetingMonitor?.triggerTestAlert(for: meeting)
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
