import SwiftUI
import AVFoundation

@main
struct EchoFlowApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(viewModel)
                .frame(minWidth: 800, minHeight: 500)
                .onAppear {
                    // SPM apps launch as background processes — promote to regular app
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                    requestMicrophonePermission()
                    installKeyboardMonitor()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1000, height: 650)
        .commands {
            // Menu items for discoverability (shortcuts handled by NSEvent monitor)
            CommandMenu("Playback") {
                Button(viewModel.audioController.isPlaying ? "Pause" : "Play") {
                    viewModel.audioController.togglePlayPause()
                }
                .keyboardShortcut(.space, modifiers: [])
                .disabled(viewModel.selectedTrack == nil)

                Button(viewModel.audioController.isLooping ? "Loop Off" : "Loop On") {
                    viewModel.audioController.toggleLoop()
                }
                .keyboardShortcut("l", modifiers: .command)

                Divider()

                Button("Skip Forward 5s") {
                    viewModel.audioController.skipForward()
                }
                .keyboardShortcut(.rightArrow, modifiers: [])

                Button("Skip Back 5s") {
                    viewModel.audioController.skipBackward()
                }
                .keyboardShortcut(.leftArrow, modifiers: [])

                Divider()

                Button("Speed Up") {
                    viewModel.audioController.speedUp()
                }
                .keyboardShortcut("+", modifiers: [])

                Button("Speed Down") {
                    viewModel.audioController.speedDown()
                }
                .keyboardShortcut("-", modifiers: [])

                Divider()

                Button("Next Track") {
                    viewModel.selectNextTrack()
                }
                .keyboardShortcut(.downArrow, modifiers: .command)

                Button("Previous Track") {
                    viewModel.selectPreviousTrack()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
            }

            CommandMenu("Recording") {
                Button(viewModel.audioController.isRecording ? "Stop Recording" : "Start Recording") {
                    viewModel.audioController.toggleRecording()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }

    // MARK: - App-level keyboard monitor (bypasses SwiftUI focus issues)

    private func installKeyboardMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Space → Play / Pause
            if event.keyCode == 49 && flags == [] {
                if viewModel.selectedTrack != nil {
                    viewModel.audioController.togglePlayPause()
                    return nil
                }
            }

            // ← → Skip back / forward
            if event.keyCode == 123 && flags == [] {           // ←
                viewModel.audioController.skipBackward()
                return nil
            }
            if event.keyCode == 124 && flags == [] {           // →
                viewModel.audioController.skipForward()
                return nil
            }

            // ⇧← ⇧→  Fine skip (1s)
            if event.keyCode == 123 && flags == .shift {       // ⇧←
                viewModel.audioController.skipBackward(1)
                return nil
            }
            if event.keyCode == 124 && flags == .shift {       // ⇧→
                viewModel.audioController.skipForward(1)
                return nil
            }

            // ↑ ↓ Volume
            if event.keyCode == 126 && flags == [] {           // ↑
                viewModel.audioController.setVolume(viewModel.audioController.volume + 0.1)
                return nil
            }
            if event.keyCode == 125 && flags == [] {           // ↓
                viewModel.audioController.setVolume(viewModel.audioController.volume - 0.1)
                return nil
            }

            // ⌘↑ ⌘↓ Track navigation
            if event.keyCode == 126 && flags == .command {     // ⌘↑
                viewModel.selectPreviousTrack()
                return nil
            }
            if event.keyCode == 125 && flags == .command {     // ⌘↓
                viewModel.selectNextTrack()
                return nil
            }

            // + / = Speed up,  - Speed down
            if let chars = event.charactersIgnoringModifiers {
                if (chars == "=" || chars == "+") && flags == [] {
                    viewModel.audioController.speedUp()
                    return nil
                }
                if chars == "-" && flags == [] {
                    viewModel.audioController.speedDown()
                    return nil
                }
            }

            // ⌘L → Toggle loop
            if event.charactersIgnoringModifiers == "l" && flags == .command {
                viewModel.audioController.toggleLoop()
                return nil
            }

            // ⌘R → Toggle recording
            if event.charactersIgnoringModifiers == "r" && flags == .command {
                viewModel.audioController.toggleRecording()
                return nil
            }

            // ⌘O → Open folder
            if event.charactersIgnoringModifiers == "o" && flags == .command {
                viewModel.openFolderPicker()
                return nil
            }

            return event  // pass through unhandled keys
        }
    }

    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                print("⚠️ Microphone access denied.")
            }
        }
    }
}
