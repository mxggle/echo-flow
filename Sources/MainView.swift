import SwiftUI
import AppKit

struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 250, max: 350)
        } detail: {
            VStack(spacing: 0) {
                // Recording saved banner
                if let recordingURL = viewModel.audioController.lastRecordingURL {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Saved: \(recordingURL.lastPathComponent)")
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([recordingURL])
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        Button {
                            viewModel.audioController.lastRecordingURL = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                }

                // Track title bar
                if let track = viewModel.selectedTrack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.headline)
                            if track.srtURL != nil {
                                Text("\(viewModel.sentences.count) sentences")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.bar)

                    Divider()
                }

                // Transcript
                TranscriptView()

                // Controls
                ControlsView(audio: viewModel.audioController)
            }
        }
        .frame(minWidth: 800, minHeight: 500)
    }
}
