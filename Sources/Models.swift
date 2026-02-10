import Foundation

// MARK: - Track

struct Track: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    let srtURL: URL?
    var isPlayed: Bool = false

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Sentence

struct Sentence: Identifiable, Codable {
    let id: Int
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

// MARK: - SRTParser

struct SRTParser {
    /// Parse a raw SRT string into an array of Sentence objects.
    static func parse(_ raw: String) -> [Sentence] {
        var sentences: [Sentence] = []

        // Normalize line endings
        let content = raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Split into blocks separated by blank lines
        let blocks = content.components(separatedBy: "\n\n")

        var currentIndex = 0
        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")

            // Each SRT block must have at least 3 lines: index, timing, and text
            guard lines.count >= 3 else { continue }

            // Line 1: Index (Ignored, we use our own sequential index)
            // guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

            // Line 2: Timing  "00:01:23,456 --> 00:01:25,789"
            let timeLine = lines[1]
            let timeParts = timeLine.components(separatedBy: " --> ")
            guard timeParts.count == 2,
                  let start = parseTimestamp(timeParts[0].trimmingCharacters(in: .whitespaces)),
                  let end = parseTimestamp(timeParts[1].trimmingCharacters(in: .whitespaces))
            else { continue }

            // Lines 3+: Text (join multiline subtitles)
            let text = lines[2...].joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else { continue }

            sentences.append(Sentence(id: currentIndex, startTime: start, endTime: end, text: text))
            currentIndex += 1
        }

        return sentences
    }

    /// Parse "HH:MM:SS,mmm" into TimeInterval (seconds)
    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        // Support both comma and period as decimal separator
        let normalized = str.replacingOccurrences(of: ",", with: ".")
        let parts = normalized.components(separatedBy: ":")
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2])
        else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }

    /// Generate an SRT string from an array of Sentence objects.
    static func generate(_ sentences: [Sentence]) -> String {
        var lines: [String] = []
        for (i, sentence) in sentences.enumerated() {
            lines.append("\(i + 1)")
            lines.append("\(formatTimestamp(sentence.startTime)) --> \(formatTimestamp(sentence.endTime))")
            lines.append(sentence.text)
            lines.append("") // blank line separator
        }
        return lines.joined(separator: "\n")
    }

    /// Format TimeInterval as "HH:MM:SS,mmm"
    private static func formatTimestamp(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let millis = Int((time - Double(totalSeconds)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, millis)
    }
}

// MARK: - AI Transcription

enum TranscriptionProvider: String, CaseIterable, Identifiable {
    case openAI = "openAI"
    case gemini = "gemini"
    case grok   = "grok"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI (Whisper)"
        case .gemini: return "Google Gemini"
        case .grok:   return "xAI Grok"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: return "whisper-1"
        case .gemini: return "gemini-2.0-flash"
        case .grok:   return "whisper-large-v3"
        }
    }

    var availableModels: [String] {
        switch self {
        case .openAI: return ["whisper-1"]
        case .gemini: return ["gemini-2.0-flash", "gemini-2.5-pro"]
        case .grok:   return ["whisper-large-v3"]
        }
    }
}

enum TranscriptionStatus: Equatable {
    case idle
    case transcribing
    case completed
    case failed(String)

    static func == (lhs: TranscriptionStatus, rhs: TranscriptionStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.transcribing, .transcribing), (.completed, .completed):
            return true
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}
