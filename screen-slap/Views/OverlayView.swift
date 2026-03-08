//
//  OverlayView.swift
//  screen-slap
//

import AppKit
import SwiftUI

/// The full-screen overlay that blocks the screen before a meeting.
/// Displayed via NSHostingView inside an NSWindow at .screenSaver level.
struct OverlayView: View {

    let meeting: MeetingEvent
    let snoozeDurationLabel: String
    let onJoin: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var appeared = false
    @State private var showAllAttendees = false

    var body: some View {
        ZStack {
            // Blurred + tinted background
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Color.black.opacity(0.15))

            // Content
            VStack(spacing: 24) {
                Spacer()

                // Calendar indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(meeting.calendarColor)
                        .frame(width: 10, height: 10)

                    Text(meeting.calendarTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                // Meeting title
                Text(meeting.title)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .padding(.horizontal, 40)

                // Time range subtitle
                Text(meeting.formattedTimeRange)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.5))

                // Location (if present)
                if let location = meeting.location, !location.isEmpty {
                    Label(location, systemImage: "location.fill")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }

                // Attendees
                if !meeting.attendees.isEmpty {
                    attendeesView
                }

                // Countdown
                CountdownLabel(targetDate: meeting.startDate, style: .overlay)
                    .padding(.vertical, 8)

                // Action buttons
                actionButtons
                    .padding(.top, 8)

                Spacer()

                // Keyboard hints
                keyboardHints
                    .padding(.bottom, 32)
            }
        }
        .ignoresSafeArea()
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.95)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                appeared = true
            }
        }
    }

    // MARK: - Attendees

    private var attendeesView: some View {
        let others = sortedAttendees
        let maxShown = 8
        let visibleAttendees = showAllAttendees ? others : Array(others.prefix(maxShown))
        let remaining = others.count - maxShown

        return VStack(spacing: 8) {
            HStack(spacing: -6) {
                ForEach(visibleAttendees) { attendee in
                    attendeeAvatar(attendee)
                }

                if remaining > 0 && !showAllAttendees {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showAllAttendees = true
                        }
                    } label: {
                        Text("+\(remaining)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.2), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // Names list
            let nameCount = showAllAttendees ? others.count : min(5, others.count)
            Text(attendeeNameSummary(others, maxNames: nameCount))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(showAllAttendees ? nil : 2)
                .multilineTextAlignment(.center)

            if showAllAttendees {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllAttendees = false
                    }
                } label: {
                    Text("Show less")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 60)
    }

    /// Attendees sorted: contacts first (alphabetical), then email-only (alphabetical), excluding current user
    private var sortedAttendees: [MeetingEvent.Attendee] {
        let others = meeting.attendees.filter { !$0.isCurrentUser }
        let withContact = others.filter { $0.hasContactMatch }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let withoutContact = others.filter { !$0.hasContactMatch }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return withContact + withoutContact
    }

    private func attendeeAvatar(_ attendee: MeetingEvent.Attendee) -> some View {
        Group {
            if let photoData = attendee.contactPhoto, let nsImage = NSImage(data: photoData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                // Initials fallback
                Text(initials(for: attendee))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.white.opacity(0.2))
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func initials(for attendee: MeetingEvent.Attendee) -> String {
        let name = attendee.name
        if name.contains("@") {
            // Email address — use first character
            return String(name.prefix(1)).uppercased()
        }
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }

    private func attendeeNameSummary(_ attendees: [MeetingEvent.Attendee], maxNames: Int = 5) -> String {
        let names = attendees.prefix(maxNames).map { $0.name }
        let remaining = attendees.count - maxNames

        if remaining > 0 {
            return names.joined(separator: ", ") + " +\(remaining) more"
        } else {
            return names.joined(separator: ", ")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Join button (prominent blue, only if URL exists)
            if meeting.meetingURL != nil {
                OverlayButton(
                    label: "Join Meeting",
                    icon: "video.fill",
                    color: .blue,
                    isPrimary: true,
                    action: onJoin
                )
                .keyboardShortcut(.return, modifiers: [])
            }

            // Snooze button
            OverlayButton(
                label: "Snooze \(snoozeDurationLabel)",
                icon: "clock.arrow.circlepath",
                color: .white.opacity(0.15),
                action: onSnooze
            )

            // Dismiss button
            OverlayButton(
                label: "Dismiss",
                icon: "xmark",
                color: .white.opacity(0.15),
                action: onDismiss
            )
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    // MARK: - Keyboard Hints

    private var keyboardHints: some View {
        HStack(spacing: 24) {
            if meeting.meetingURL != nil {
                keyHint(key: "Return", action: "Join")
            }
            keyHint(key: "Esc", action: "Dismiss")
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.3))
    }

    private func keyHint(key: String, action: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(action)
        }
    }
}

// MARK: - Overlay Button

private struct OverlayButton: View {

    let label: String
    let icon: String
    let color: Color
    var isPrimary: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(isPrimary ? .title3.weight(.semibold) : .body.weight(.medium))
                .foregroundStyle(.white)
                .padding(.horizontal, isPrimary ? 24 : 20)
                .padding(.vertical, isPrimary ? 12 : 10)
                .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .brightness(isHovered ? 0.15 : 0)
        .shadow(color: isHovered ? color.opacity(0.4) : .clear, radius: 8, y: 2)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
