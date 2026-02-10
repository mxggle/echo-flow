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

            aiServicesTab
                .tabItem {
                    Label("AI Services", systemImage: "brain")
                }
        }
        .frame(width: 480, height: 400)
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

    // MARK: - AI Services Tab

    private var selectedProvider: TranscriptionProvider {
        TranscriptionProvider(rawValue: settings.transcriptionProvider) ?? .openAI
    }

    private var aiServicesTab: some View {
        Form {
            Section("Provider") {
                Picker("Service", selection: $settings.transcriptionProvider) {
                    ForEach(TranscriptionProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.transcriptionProvider) { newValue in
                    // Auto-set default model when switching providers
                    if let provider = TranscriptionProvider(rawValue: newValue) {
                        settings.transcriptionModel = provider.defaultModel
                    }
                }
            }

            Section("API Key") {
                SecureField("Enter \(selectedProvider.displayName) API key", text: apiKeyBinding)
                    .textFieldStyle(.roundedBorder)

                if apiKeyBinding.wrappedValue.isEmpty {
                    Label("Required for transcription", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else {
                    Label("Key saved", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section("Model") {
                Picker("Model", selection: $settings.transcriptionModel) {
                    ForEach(selectedProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
            }

            Section("Language") {
                HStack {
                    TextField("ISO 639-1 code", text: $settings.transcriptionLanguage)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("e.g. en, ja, zh, es, fr, de")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.top, 8)
    }

    /// Returns a binding to the API key for the currently selected provider
    private var apiKeyBinding: Binding<String> {
        switch selectedProvider {
        case .openAI: return $settings.openAIApiKey
        case .gemini: return $settings.geminiApiKey
        case .grok:   return $settings.grokApiKey
        }
    }
}
