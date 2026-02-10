import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared

    var body: some View {
        TabView {
            playbackTab
                .tabItem {
                    Label("Playback", systemImage: "play.circle")
                }

            transcriptTab
                .tabItem {
                    Label("Transcript", systemImage: "text.alignleft")
                }

            recordingTab
                .tabItem {
                    Label("Recording", systemImage: "mic.circle")
                }
        }
        .frame(width: 420, height: 340)
    }

    // MARK: - Playback Tab

    private var playbackTab: some View {
        Form {
            Section("Skip Steps") {
                HStack {
                    Text("Skip Forward")
                    Spacer()
                    Stepper(
                        "\(Int(settings.skipForwardStep))s",
                        value: $settings.skipForwardStep,
                        in: 1...60,
                        step: 1
                    )
                    .frame(width: 100)
                }

                HStack {
                    Text("Skip Backward")
                    Spacer()
                    Stepper(
                        "\(Int(settings.skipBackwardStep))s",
                        value: $settings.skipBackwardStep,
                        in: 1...60,
                        step: 1
                    )
                    .frame(width: 100)
                }

                HStack {
                    Text("Fine Skip (⇧+Arrow)")
                    Spacer()
                    Stepper(
                        String(format: "%.1fs", settings.fineSkipStep),
                        value: $settings.fineSkipStep,
                        in: 0.5...10,
                        step: 0.5
                    )
                    .frame(width: 100)
                }
            }

            Section("Speed") {
                HStack {
                    Text("Default Speed")
                    Spacer()
                    Stepper(
                        String(format: "%.1fx", settings.defaultPlaybackSpeed),
                        value: $settings.defaultPlaybackSpeed,
                        in: 0.5...2.0,
                        step: 0.1
                    )
                    .frame(width: 100)
                }

                HStack {
                    Text("Speed Step (+/- keys)")
                    Spacer()
                    Stepper(
                        String(format: "%.1f", settings.speedStep),
                        value: $settings.speedStep,
                        in: 0.05...0.5,
                        step: 0.05
                    )
                    .frame(width: 100)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    // MARK: - Transcript Tab

    private var transcriptTab: some View {
        Form {
            Section("Scrolling") {
                Toggle("Auto-scroll to active sentence", isOn: $settings.autoScrollTranscript)
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    // MARK: - Recording Tab

    private var recordingTab: some View {
        Form {
            Section("Output") {
                Picker("Format", selection: $settings.recordingFormat) {
                    Text("AAC (.m4a)").tag("m4a")
                    Text("WAV (.wav)").tag("wav")
                }
                .pickerStyle(.segmented)
            }

            Section("Storage") {
                HStack {
                    Text("Recordings are saved to:")
                    Spacer()
                }
                HStack {
                    Text("~/Documents/EchoFlow Recordings/")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reveal in Finder") {
                        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            .appendingPathComponent("EchoFlow Recordings")
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }
}
