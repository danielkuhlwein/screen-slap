//
//  OverlayWindowManager.swift
//  screen-slap
//

import AppKit
import os
import SwiftUI

/// Borderless NSWindow subclass that can become key (receive keyboard input).
/// Borderless windows return false for canBecomeKey by default.
private class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Manages full-screen NSWindow overlays at .screenSaver level across all monitors.
/// This is the AppKit bridge — SwiftUI cannot create windows at this level.
@Observable
final class OverlayWindowManager {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screen-slap",
        category: "OverlayWindowManager"
    )

    // MARK: - State

    /// Whether the overlay is currently visible
    private(set) var isShowing: Bool = false

    /// Active overlay windows (one per screen)
    private var overlayWindows: [NSWindow] = []

    /// The current meeting being displayed
    private var currentMeeting: MeetingEvent?

    /// Callbacks for overlay actions
    private var onJoin: (() -> Void)?
    private var onDismiss: (() -> Void)?
    private var onSnooze: (() -> Void)?

    /// Screen change observer
    private var screenObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public API

    /// Show the overlay across all screens for the given meeting.
    func showOverlay(
        for meeting: MeetingEvent,
        snoozeDurationLabel: String,
        onJoin: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        onSnooze: @escaping () -> Void
    ) {
        // If already showing for the same meeting, just update
        if isShowing && currentMeeting?.id == meeting.id {
            return
        }

        // Tear down any existing overlay
        hideOverlayImmediate()

        self.currentMeeting = meeting
        self.onJoin = onJoin
        self.onDismiss = onDismiss
        self.onSnooze = onSnooze

        // Create one window per screen
        for screen in NSScreen.screens {
            let window = createOverlayWindow(
                for: screen,
                meeting: meeting,
                snoozeDurationLabel: snoozeDurationLabel
            )
            overlayWindows.append(window)
            window.orderFrontRegardless()
        }

        // Force the app to activate so keyboard shortcuts work immediately
        NSApp.activate(ignoringOtherApps: true)

        // Make the first window key for keyboard input
        overlayWindows.first?.makeKeyAndOrderFront(nil)

        isShowing = true

        // Play alert sound
        SoundManager.playAlertSound()

        Self.logger.info("Overlay shown on \(NSScreen.screens.count) screen(s) for: \(meeting.title)")
    }

    /// Hide the overlay with a fade animation.
    func hideOverlay() {
        guard isShowing else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            for window in overlayWindows {
                window.animator().alphaValue = 0
            }
        }, completionHandler: { [weak self] in
            self?.hideOverlayImmediate()
        })
    }

    // MARK: - Window Creation

    private func createOverlayWindow(
        for screen: NSScreen,
        meeting: MeetingEvent,
        snoozeDurationLabel: String
    ) -> NSWindow {
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )

        // Window level: above everything including fullscreen apps
        window.level = .screenSaver

        // Appear on all Spaces, including fullscreen app Spaces
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]

        // Transparent window hosting SwiftUI
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false

        // Accept mouse events
        window.acceptsMouseMovedEvents = true

        // Don't show in mission control or app switcher
        window.isExcludedFromWindowsMenu = true

        // Set up SwiftUI content
        let overlayView = OverlayView(
            meeting: meeting,
            snoozeDurationLabel: snoozeDurationLabel,
            onJoin: { [weak self] in self?.onJoin?() },
            onDismiss: { [weak self] in self?.onDismiss?() },
            onSnooze: { [weak self] in self?.onSnooze?() }
        )

        window.contentView = NSHostingView(rootView: overlayView)

        // Start fully transparent for fade-in (SwiftUI handles the visual fade)
        window.alphaValue = 1

        // Make the window key so it receives keyboard events
        window.makeKey()

        return window
    }

    // MARK: - Private

    /// Immediately remove all overlay windows without animation.
    private func hideOverlayImmediate() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        currentMeeting = nil
        isShowing = false

        Self.logger.debug("Overlay hidden")
    }

    /// Watch for screen configuration changes (monitor plug/unplug)
    private func setupScreenChangeObserver() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleScreenChange()
        }
    }

    /// Rebuild overlay windows when screens change
    private func handleScreenChange() {
        guard isShowing, let meeting = currentMeeting else { return }

        Self.logger.info("Screen configuration changed, rebuilding overlays")

        let snoozeDurationLabel = AppSettings.shared.formattedSnoozeDuration

        // Tear down and recreate
        let savedOnJoin = onJoin
        let savedOnDismiss = onDismiss
        let savedOnSnooze = onSnooze

        hideOverlayImmediate()

        if let onJoin = savedOnJoin, let onDismiss = savedOnDismiss, let onSnooze = savedOnSnooze {
            showOverlay(
                for: meeting,
                snoozeDurationLabel: snoozeDurationLabel,
                onJoin: onJoin,
                onDismiss: onDismiss,
                onSnooze: onSnooze
            )
        }
    }
}
