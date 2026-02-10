import Foundation
import SwiftUI

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Published State
    @Published var tracks: [Track] = []
    @Published var selectedTrack: Track?
    @Published var sentences: [Sentence] = []
    @Published var errorMessage: String?

    let audioController = AudioController()

    // MARK: - Computed

    var currentSentence: Sentence? {
        let time = audioController.currentTime
        return sentences.first { time >= $0.startTime && time < $0.endTime }
    }

    // MARK: - Directory Loading

    func loadDirectory(url: URL) {
        tracks = []
        sentences = []
        selectedTrack = nil

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
    }

    // MARK: - Track Selection

    func selectTrack(_ track: Track) {
        selectedTrack = track
        audioController.loadAudio(url: track.url)

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
}
