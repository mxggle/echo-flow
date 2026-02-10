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

            switch viewModel.transcriptionStatus {
            case .transcribing:
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.bottom, 8)
                Text("Transcribing…")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("This may take a moment depending on the file size.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)

            case .failed(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red.opacity(0.7))
                Text("Transcription Failed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                HStack(spacing: 12) {
                    Button("Retry") {
                        viewModel.transcribeCurrentTrack()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)

                    Button("Settings") {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                    .controlSize(.regular)
                }

            default:
                Image(systemName: "text.badge.xmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange.opacity(0.6))
                Text("No Transcript")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("No .srt file found for this track.\nYou can still play the audio, or use AI to generate a transcript.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.transcribeCurrentTrack()
                } label: {
                    Label("Transcribe with AI", systemImage: "brain")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)

                Text("Using \(SettingsManager.shared.activeProvider.displayName)")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }

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
                        let isActive = viewModel.currentSentenceID == sentence.id
                        Button {
                            viewModel.audioController.seek(to: sentence.startTime)
                            if !viewModel.audioController.isPlaying {
                                viewModel.audioController.play()
                            }
                        } label: {
                            SentenceRow(sentence: sentence, isActive: isActive)
                        }
                        .buttonStyle(.plain)
                        .id(sentence.id)
                        .contextMenu {
                            Button {
                                viewModel.audioController.seek(to: sentence.startTime)
                                viewModel.audioController.setLoopRange(
                                    start: sentence.startTime,
                                    end: sentence.endTime
                                )
                                if !viewModel.audioController.isLooping {
                                    viewModel.audioController.toggleLoop()
                                }
                                if !viewModel.audioController.isPlaying {
                                    viewModel.audioController.play()
                                }
                            } label: {
                                Label("Loop This Sentence", systemImage: "repeat")
                            }

                            Divider()

                            Button {
                                // TODO: Implement AI explanation feature
                                print("Explain sentence: \(sentence.text)")
                            } label: {
                                Label("Explain Sentence", systemImage: "brain.head.profile")
                            }

                            Divider()

                            Button {
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(sentence.text, forType: .string)
                            } label: {
                                Label("Copy Text", systemImage: "doc.on.doc")
                            }

                            Button {
                                let timeStr = formatTime(sentence.startTime)
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString("[\(timeStr)] \(sentence.text)", forType: .string)
                            } label: {
                                Label("Copy with Timestamp", systemImage: "clock")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.currentSentenceID) { newID in
                if let id = newID, SettingsManager.shared.autoScrollTranscript {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Sentence Row

struct SentenceRow: View {
    let sentence: Sentence
    let isActive: Bool
    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Play indicator / Timestamp
            ZStack {
                Text(formatTime(sentence.startTime))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(isActive ? .blue : .gray)
                    .opacity(isHovered && !isActive ? 0 : 1)

                Image(systemName: "play.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                    .opacity(isHovered && !isActive ? 1 : 0)
            }
            .frame(width: 60, alignment: .trailing)

            // Text
            Text(sentence.text)
                .font(.body)
                .foregroundStyle(isActive ? .primary : (isHovered ? .primary : .secondary))
                .fontWeight(isActive ? .medium : .regular)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isActive ? Color.blue.opacity(0.1) : (isHovered ? Color.primary.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isActive ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
