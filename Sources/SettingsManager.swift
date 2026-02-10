import Foundation
import SwiftUI

/// Singleton that persists user preferences via @AppStorage.
@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    // MARK: - Playback

    /// Seconds to skip when pressing → (default 5s)
    @AppStorage("skipForwardStep") var skipForwardStep: Double = 5.0

    /// Seconds to skip when pressing ← (default 5s)
    @AppStorage("skipBackwardStep") var skipBackwardStep: Double = 5.0

    /// Seconds for fine skip via ⇧→ / ⇧← (default 1s)
    @AppStorage("fineSkipStep") var fineSkipStep: Double = 1.0

    /// Playback speed applied when loading a new track (default 1.0x)
    @AppStorage("defaultPlaybackSpeed") var defaultPlaybackSpeed: Double = 1.0

    /// Increment for +/- speed keyboard shortcuts (default 0.1)
    @AppStorage("speedStep") var speedStep: Double = 0.1

    // MARK: - Transcript

    /// Auto-scroll transcript to the active sentence
    @AppStorage("autoScrollTranscript") var autoScrollTranscript: Bool = true

    // MARK: - Recording

    /// Recording output format: "m4a" or "wav"
    @AppStorage("recordingFormat") var recordingFormat: String = "m4a"

    private init() {}
}
