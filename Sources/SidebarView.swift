import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "music.note.list")
                    .foregroundStyle(.secondary)
                Text("Tracks")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.openFolderPicker()
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.title3)
                }
                .buttonStyle(.borderless)
                .help("Open folder")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if viewModel.tracks.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No tracks loaded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Open Folder") {
                        viewModel.openFolderPicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(viewModel.tracks, selection: Binding<Track?>(
                    get: { viewModel.selectedTrack },
                    set: { track in
                        if let track { viewModel.selectTrack(track) }
                    }
                )) { track in
                    HStack(spacing: 8) {
                        Image(systemName: track.id == viewModel.selectedTrack?.id
                              ? "speaker.wave.2.fill" : "music.note")
                            .foregroundStyle(track.id == viewModel.selectedTrack?.id
                                             ? .blue : .secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name)
                                .font(.body)
                                .lineLimit(1)
                            if track.srtURL != nil {
                                Label("Transcript", systemImage: "text.alignleft")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            } else {
                                Label("No transcript", systemImage: "exclamationmark.triangle")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(track)
                }
                .listStyle(.sidebar)
            }
        }
    }
}
