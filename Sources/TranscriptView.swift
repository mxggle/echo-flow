import SwiftUI

struct TranscriptView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.selectedTrack == nil {
                emptyState
            } else if viewModel.sentences.isEmpty {
                noTranscriptState
            } else {
                transcriptList
            }
        }
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 56))
                .foregroundStyle(.quaternary)
            Text("Select a track to begin")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Choose a track from the sidebar,\nor open a folder to get started.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noTranscriptState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.badge.xmark")
                .font(.system(size: 48))
                .foregroundStyle(.orange.opacity(0.6))
            Text("No Transcript")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("No .srt file found for this track.\nYou can still play the audio.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Transcript List

    private var transcriptList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.sentences) { sentence in
                        let isActive = viewModel.currentSentence?.id == sentence.id
                        SentenceRow(sentence: sentence, isActive: isActive)
                            .id(sentence.id)
                            .onTapGesture {
                                viewModel.audioController.seek(to: sentence.startTime)
                                // Set loop range to this sentence
                                viewModel.audioController.setLoopRange(
                                    start: sentence.startTime,
                                    end: sentence.endTime
                                )
                                if !viewModel.audioController.isPlaying {
                                    viewModel.audioController.play()
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.currentSentence?.id) { newID in
                if let id = newID, SettingsManager.shared.autoScrollTranscript {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
}

// MARK: - Sentence Row

struct SentenceRow: View {
    let sentence: Sentence
    let isActive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Timestamp
            Text(formatTime(sentence.startTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(isActive ? .blue : .gray)
                .frame(width: 60, alignment: .trailing)

            // Text
            Text(sentence.text)
                .font(.body)
                .foregroundStyle(isActive ? .primary : .secondary)
                .fontWeight(isActive ? .medium : .regular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
