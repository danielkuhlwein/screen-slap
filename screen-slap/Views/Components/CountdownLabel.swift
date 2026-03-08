//
//  CountdownLabel.swift
//  screen-slap
//

import SwiftUI

/// A live-updating countdown display that ticks every second.
struct CountdownLabel: View {

    let targetDate: Date
    var style: CountdownStyle = .overlay

    enum CountdownStyle {
        case overlay   // Large, for the full-screen overlay
        case compact   // Small, for menu bar
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = targetDate.timeIntervalSince(context.date)
            content(for: remaining)
        }
    }

    @ViewBuilder
    private func content(for remaining: TimeInterval) -> some View {
        switch style {
        case .overlay:
            overlayContent(for: remaining)
        case .compact:
            compactContent(for: remaining)
        }
    }

    // MARK: - Overlay Style

    @ViewBuilder
    private func overlayContent(for remaining: TimeInterval) -> some View {
        if remaining <= 0 {
            Text("Starting now")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        } else {
            VStack(spacing: 4) {
                Text("Starting in")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.7))

                Text(formatTime(remaining))
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(urgencyColor(for: remaining))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: Int(remaining))
            }
        }
    }

    // MARK: - Compact Style

    @ViewBuilder
    private func compactContent(for remaining: TimeInterval) -> some View {
        if remaining <= 0 {
            Text("Now")
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            Text(formatTimeCompact(remaining))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(urgencyColor(for: remaining))
        }
    }

    // MARK: - Formatting

    private func formatTime(_ remaining: TimeInterval) -> String {
        let totalSeconds = Int(remaining)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    private func formatTimeCompact(_ remaining: TimeInterval) -> String {
        let totalSeconds = Int(remaining)
        let minutes = totalSeconds / 60

        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours)h \(remainingMinutes)m"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "\(totalSeconds)s"
        }
    }

    // MARK: - Urgency

    private func urgencyColor(for remaining: TimeInterval) -> Color {
        if remaining <= 30 {
            return .red
        } else if remaining <= 60 {
            return .orange
        } else {
            return .white
        }
    }
}
