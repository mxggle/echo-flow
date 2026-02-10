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

struct Sentence: Identifiable {
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

        for block in blocks {
            let lines = block.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n")

            // Each SRT block must have at least 3 lines: index, timing, and text
            guard lines.count >= 3 else { continue }

            // Line 1: Index
            guard let index = Int(lines[0].trimmingCharacters(in: .whitespaces)) else { continue }

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

            sentences.append(Sentence(id: index, startTime: start, endTime: end, text: text))
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
}
