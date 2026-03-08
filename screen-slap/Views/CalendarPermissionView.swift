//
//  CalendarPermissionView.swift
//  screen-slap
//

import EventKit
import SwiftUI

/// Shown when calendar access is not yet granted or has been denied.
struct CalendarPermissionView: View {

    let authorizationStatus: EKAuthorizationStatus
    let onRequestAccess: () async -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(iconColor)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actionButton
        }
        .padding()
    }

    // MARK: - Computed

    private var icon: String {
        switch authorizationStatus {
        case .denied, .restricted:
            "calendar.badge.exclamationmark"
        default:
            "calendar.badge.plus"
        }
    }

    private var iconColor: Color {
        switch authorizationStatus {
        case .denied, .restricted:
            .red
        default:
            .blue
        }
    }

    private var title: String {
        switch authorizationStatus {
        case .denied:
            "Calendar Access Denied"
        case .restricted:
            "Calendar Access Restricted"
        default:
            "Calendar Access Needed"
        }
    }

    private var message: String {
        switch authorizationStatus {
        case .denied:
            "Screen Slap needs calendar access to alert you before meetings. Please enable it in System Settings → Privacy & Security → Calendars."
        case .restricted:
            "Calendar access is restricted on this device. Please check your device management settings."
        default:
            "Screen Slap needs access to your calendars to know when your meetings are."
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch authorizationStatus {
        case .notDetermined:
            Button("Grant Access") {
                Task {
                    await onRequestAccess()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .denied:
            Button("Open System Settings") {
                openCalendarPrivacySettings()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        default:
            EmptyView()
        }
    }

    // MARK: - Actions

    private func openCalendarPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
