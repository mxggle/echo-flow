import Foundation
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published State
    @Published var tracks: [Track] = []
    @Published var selectedTrack: Track?
    @Published var sentences: [Sentence] = []
    @Published var errorMessage: String?
    @Published var transcriptionStatus: TranscriptionStatus = .idle
    @Published var currentSentenceID: Int?
    @Published var currentFolderURL: URL?

    let audioController = AudioController()
    let transcriptionService = TranscriptionService()

    // MARK: - Init

    init() {
        // Use direct callback instead of Combine to avoid @MainActor isolation issues.
        // This callback runs inside AudioController's timer Task { @MainActor in },
        // so it's guaranteed to be on the main actor.
        audioController.onTimeUpdate = { [weak self] time in
            guard let self else { return }
            
            // 1. Check if the current sentence is still valid
            if let currentID = self.currentSentenceID,
               currentID >= 0, currentID < self.sentences.count {
                let current = self.sentences[currentID]
                if time >= current.startTime && time < current.endTime {
                    return // Still in the same sentence
                }
                
                // 2. Check the immediately next sentence (common case during playback)
                let nextID = currentID + 1
                if nextID < self.sentences.count {
                    let next = self.sentences[nextID]
                    if time >= next.startTime && time < next.endTime {
                        self.currentSentenceID = nextID
                        return
                    }
                }
            }
            
            // 3. Fallback: Binary search for the correct sentence
            // specific optimization: if time turned back, or jumped, we need to find it
            // Binary search to find the sentence containing `time`
            
            var low = 0
            var high = self.sentences.count - 1
            var foundID: Int? = nil
            
            while low <= high {
                let mid = (low + high) / 2
                let sentence = self.sentences[mid]
                
                if time < sentence.startTime {
                    high = mid - 1
                } else if time >= sentence.endTime {
                    low = mid + 1
                } else {
                    // time is within [startTime, endTime)
                    foundID = sentence.id
                    break
                }
            }
            
            if self.currentSentenceID != foundID {
                self.currentSentenceID = foundID
            }
        }
    }

    // MARK: - Computed

    var currentSentence: Sentence? {
        sentences.first { $0.id == currentSentenceID }
    }

    // MARK: - Directory Loading

    func loadDirectory(url: URL) {
        tracks = []
        sentences = []
        selectedTrack = nil
        currentFolderURL = url

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            errorMessage = "Could not read directory."
            return
        }

        var foundTracks: [Track] = []
        while let fileURL = enumerator.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "mp3" else { continue }

            // Look for a matching .srt file
            let srtURL = fileURL.deletingPathExtension().appendingPathExtension("srt")
            let srtExists = fm.fileExists(atPath: srtURL.path)

            let track = Track(
                url: fileURL,
                name: fileURL.deletingPathExtension().lastPathComponent,
                srtURL: srtExists ? srtURL : nil
            )
            foundTracks.append(track)
        }

        // Sort alphabetically
        tracks = foundTracks.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if tracks.isEmpty {
            errorMessage = "No .mp3 files found in the selected folder."
        } else {
            errorMessage = nil
        }

        // Add to recent folders
        SettingsManager.shared.addRecentFolder(url)
    }

    // MARK: - Track Selection

    func selectTrack(_ track: Track) {
        selectedTrack = track
        audioController.loadAudio(url: track.url)
        transcriptionStatus = .idle

        // Parse SRT if available
        if let srtURL = track.srtURL,
           let content = try? String(contentsOf: srtURL, encoding: .utf8) {
            sentences = SRTParser.parse(content)
        } else {
            sentences = []
        }
    }

    func selectNextTrack() {
        guard let current = selectedTrack,
              let idx = tracks.firstIndex(where: { $0.id == current.id }),
              idx + 1 < tracks.count else { return }
        selectTrack(tracks[idx + 1])
    }

    func selectPreviousTrack() {
        guard let current = selectedTrack,
              let idx = tracks.firstIndex(where: { $0.id == current.id }),
              idx > 0 else { return }
        selectTrack(tracks[idx - 1])
    }

    // MARK: - AI Transcription

    func transcribeCurrentTrack() {
        guard let track = selectedTrack else { return }

        let settings = SettingsManager.shared
        let provider = settings.activeProvider
        let apiKey = settings.activeAPIKey
        let model = settings.transcriptionModel
        let language = settings.transcriptionLanguage

        guard !apiKey.isEmpty else {
            transcriptionStatus = .failed("API key not set. Go to Settings → AI Services.")
            return
        }

        transcriptionStatus = .transcribing

        Task {
            do {
                let result = try await transcriptionService.transcribe(
                    audioURL: track.url,
                    provider: provider,
                    apiKey: apiKey,
                    model: model,
                    language: language
                )

                // Normalize timestamps to match actual audio duration.
                // AI transcription APIs (Whisper, Gemini) often return timestamps
                // that are stretched relative to the real audio, especially with
                // compressed formats like MP3. Scale them proportionally.
                let actualDuration = self.audioController.duration
                self.sentences = Self.normalizeTimestamps(result, to: actualDuration)
                self.transcriptionStatus = .completed
            } catch {
                self.transcriptionStatus = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Folder Picker

    func openFolderPicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Select a folder containing your audio files"
        panel.prompt = "Open"

        if panel.runModal() == .OK, let url = panel.url {
            loadDirectory(url: url)
        }
    }

    // MARK: - State Persistence

    func saveState() {
        let settings = SettingsManager.shared

        settings.lastFolderPath = currentFolderURL?.path ?? ""
        settings.lastTrackPath = selectedTrack?.url.path ?? ""
        settings.lastSentenceIndex = currentSentenceID ?? -1
        settings.lastPlaybackTime = audioController.currentTime

        // Save transcript as JSON
        if !sentences.isEmpty {
            if let data = try? JSONEncoder().encode(sentences),
               let json = String(data: data, encoding: .utf8) {
                settings.savedTranscriptJSON = json
            }
        } else {
            settings.savedTranscriptJSON = ""
        }
    }

    func restoreState() {
        let settings = SettingsManager.shared

        // 1. Restore folder
        let folderPath = settings.lastFolderPath
        guard !folderPath.isEmpty else { return }
        let folderURL = URL(fileURLWithPath: folderPath)

        guard FileManager.default.fileExists(atPath: folderPath) else { return }
        loadDirectory(url: folderURL)

        // 2. Restore track
        let trackPath = settings.lastTrackPath
        if !trackPath.isEmpty,
           let track = tracks.first(where: { $0.url.path == trackPath }) {
            selectedTrack = track
            audioController.loadAudio(url: track.url)

            // 3. Restore transcript (prefer saved transcription over SRT file)
            let savedJSON = settings.savedTranscriptJSON
            if !savedJSON.isEmpty,
               let data = savedJSON.data(using: .utf8),
               let decoded = try? JSONDecoder().decode([Sentence].self, from: data),
               !decoded.isEmpty {
                sentences = decoded
                transcriptionStatus = .completed
            } else if let srtURL = track.srtURL,
                      let content = try? String(contentsOf: srtURL, encoding: .utf8) {
                sentences = SRTParser.parse(content)
            }

            // 4. Restore playback position
            let savedTime = settings.lastPlaybackTime
            if savedTime > 0 && savedTime < audioController.duration {
                audioController.seek(to: savedTime)
            }

            // 5. Restore sentence index
            let savedSentence = settings.lastSentenceIndex
            if savedSentence >= 0 && savedSentence < sentences.count {
                currentSentenceID = savedSentence
            }
        }
    }

    // MARK: - Transcript Export / Import

    func exportTranscript() {
        guard !sentences.isEmpty else { return }

        let srtContent = SRTParser.generate(sentences)
        let defaultName = selectedTrack?.name ?? "transcript"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "srt")!]
        panel.nameFieldStringValue = "\(defaultName).srt"
        panel.message = "Export transcript as SRT"
        panel.prompt = "Export"

        if panel.runModal() == .OK, let url = panel.url {
            try? srtContent.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func importTranscript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.init(filenameExtension: "srt")!]
        panel.message = "Import an SRT transcript file"
        panel.prompt = "Import"

        if panel.runModal() == .OK, let url = panel.url {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let parsed = SRTParser.parse(content)
                // Normalize imported transcript timestamps to actual audio duration
                let actualDuration = audioController.duration
                sentences = Self.normalizeTimestamps(parsed, to: actualDuration)
                if !sentences.isEmpty {
                    transcriptionStatus = .completed
                }
            }
        }
    }

    // MARK: - Timestamp Normalization

    /// Scale sentence timestamps proportionally to match the actual audio duration.
    /// This fixes the known issue where AI transcription APIs return timestamps
    /// that are systematically stretched compared to the real audio length.
    static func normalizeTimestamps(_ sentences: [Sentence], to actualDuration: TimeInterval) -> [Sentence] {
        guard !sentences.isEmpty, actualDuration > 0 else { return sentences }

        // Find the end time of the last sentence (the transcript's idea of total duration)
        let transcriptDuration = sentences.last!.endTime
        guard transcriptDuration > 0 else { return sentences }

        // Only scale if there's a meaningful difference (>2% off)
        let ratio = actualDuration / transcriptDuration
        guard abs(ratio - 1.0) > 0.02 else { return sentences }

        print("⏱ Normalizing timestamps: transcript=\(String(format: "%.1f", transcriptDuration))s → audio=\(String(format: "%.1f", actualDuration))s (scale: \(String(format: "%.3f", ratio)))")

        return sentences.map { sentence in
            Sentence(
                id: sentence.id,
                startTime: sentence.startTime * ratio,
                endTime: sentence.endTime * ratio,
                text: sentence.text
            )
        }
    }
}
