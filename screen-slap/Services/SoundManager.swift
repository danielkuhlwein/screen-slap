//
//  SoundManager.swift
//  screen-slap
//

import AppKit
import os

/// Manages alert sound playback using macOS system sounds.
enum SoundManager {

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "screen-slap",
        category: "SoundManager"
    )

    // MARK: - System Sounds

    /// Available system alert sound names, sorted alphabetically.
    static var systemSounds: [String] {
        let soundsDir = "/System/Library/Sounds"
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: soundsDir) else { return [] }
        return files
            .filter { $0.hasSuffix(".aiff") }
            .map { $0.replacingOccurrences(of: ".aiff", with: "") }
            .sorted()
    }

    // MARK: - Playback

    /// Play the alert sound configured in settings (if sound is enabled).
    static func playAlertSound() {
        let settings = AppSettings.shared
        guard settings.playSound else { return }
        play(settings.soundName)
    }

    /// Play a specific sound by name (for previewing in settings).
    static func play(_ soundName: String) {
        guard let sound = NSSound(named: NSSound.Name(soundName)) else {
            logger.warning("Sound not found: \(soundName)")
            return
        }
        sound.stop() // Stop if already playing (rapid re-triggers)
        sound.play()
    }
}
