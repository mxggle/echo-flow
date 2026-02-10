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

    // MARK: - AI Transcription

    /// Selected transcription provider
    @AppStorage("transcriptionProvider") var transcriptionProvider: String = "openAI"

    /// API keys for each provider
    @AppStorage("openAIApiKey") var openAIApiKey: String = ""
    @AppStorage("geminiApiKey") var geminiApiKey: String = ""
    @AppStorage("grokApiKey") var grokApiKey: String = ""

    /// Model to use for transcription
    @AppStorage("transcriptionModel") var transcriptionModel: String = "whisper-1"

    /// Language code (ISO 639-1) for transcription
    @AppStorage("transcriptionLanguage") var transcriptionLanguage: String = "en"

    /// Helper to get the active provider enum
    var activeProvider: TranscriptionProvider {
        TranscriptionProvider(rawValue: transcriptionProvider) ?? .openAI
    }

    /// Helper to get the API key for the active provider
    var activeAPIKey: String {
        switch activeProvider {
        case .openAI: return openAIApiKey
        case .gemini: return geminiApiKey
        case .grok:   return grokApiKey
        }
    }

    // MARK: - State Persistence

    /// Last opened folder path
    @AppStorage("lastFolderPath") var lastFolderPath: String = ""

    /// Last selected track file path
    @AppStorage("lastTrackPath") var lastTrackPath: String = ""

    /// Last highlighted sentence index
    @AppStorage("lastSentenceIndex") var lastSentenceIndex: Int = -1

    /// Last playback position in seconds
    @AppStorage("lastPlaybackTime") var lastPlaybackTime: Double = 0

    /// Saved transcript as JSON: [[startTime, endTime, "text"], ...]
    @AppStorage("savedTranscriptJSON") var savedTranscriptJSON: String = ""

    // MARK: - Recent Folders

    /// JSON array of recently opened folder paths
    @AppStorage("recentFoldersJSON") var recentFoldersJSON: String = "[]"

    /// Maximum number of recent folders to keep
    static let maxRecentFolders = 10

    /// Get recent folder URLs
    var recentFolders: [URL] {
        guard let data = recentFoldersJSON.data(using: .utf8),
              let paths = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    /// Add a folder to the recent list (most recent first, capped at 10)
    func addRecentFolder(_ url: URL) {
        var paths: [String] = []
        if let data = recentFoldersJSON.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            paths = decoded
        }

        let newPath = url.path
        paths.removeAll { $0 == newPath }
        paths.insert(newPath, at: 0)

        if paths.count > Self.maxRecentFolders {
            paths = Array(paths.prefix(Self.maxRecentFolders))
        }

        if let encoded = try? JSONEncoder().encode(paths),
           let json = String(data: encoded, encoding: .utf8) {
            recentFoldersJSON = json
        }
    }

    /// Group recent folders by their parent directory name
    var recentFolderGroups: [(parent: String, folders: [URL])] {
        let folders = recentFolders
        var groups: [String: [URL]] = [:]
        var order: [String] = []

        for folder in folders {
            let parent = folder.deletingLastPathComponent().lastPathComponent
            if groups[parent] == nil {
                order.append(parent)
            }
            groups[parent, default: []].append(folder)
        }

        return order.compactMap { key in
            guard let urls = groups[key] else { return nil }
            return (parent: key, folders: urls)
        }
    }

    private init() {}
}
