import SwiftUI

enum SidebarTab: String, CaseIterable {
    case tracks = "Tracks"
    case recent = "Recent"
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var sidebarTab: SidebarTab = .tracks

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with tab picker
            VStack(spacing: 10) {
                HStack {
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.secondary)
                    Text("Library")
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

                Picker("", selection: $sidebarTab) {
                    ForEach(SidebarTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Tab content
            switch sidebarTab {
            case .tracks:
                tracksTab
            case .recent:
                recentTab
            }
        }
    }

    // MARK: - Tracks Tab

    private var tracksTab: some View {
        Group {
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

    // MARK: - Recent Folders Tab

    private var recentTab: some View {
        Group {
            let groups = SettingsManager.shared.recentFolderGroups
            if groups.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No recent folders")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open a folder to see it here.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(groups, id: \.parent) { group in
                        Section {
                            ForEach(group.folders, id: \.path) { folderURL in
                                Button {
                                    viewModel.loadDirectory(url: folderURL)
                                    sidebarTab = .tracks
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.blue)
                                            .frame(width: 20)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folderURL.lastPathComponent)
                                                .font(.body)
                                                .lineLimit(1)
                                            Text(trackCountLabel(for: folderURL))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Label(group.parent, systemImage: "folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    // MARK: - Helpers

    /// Count .mp3 files in a folder (lightweight check)
    private func trackCountLabel(for url: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return "Unavailable"
        }
        let mp3Count = contents.filter { $0.pathExtension.lowercased() == "mp3" }.count
        return mp3Count == 1 ? "1 track" : "\(mp3Count) tracks"
    }
}
