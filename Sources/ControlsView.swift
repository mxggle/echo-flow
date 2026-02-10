import SwiftUI

struct ControlsView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @ObservedObject var audio: AudioController

    var body: some View {
        VStack(spacing: 10) {
            Divider()

            // Progress bar
            progressBar

            // Controls row
            HStack(spacing: 20) {
                // Time display
                timeDisplay

                Spacer()

                // Transport controls
                transportControls

                Spacer()

                // Right side controls
                rightControls
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(.bar)
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 4)
                    .cornerRadius(2)

                // Progress
                let progress = audio.duration > 0
                    ? CGFloat(audio.currentTime / audio.duration)
                    : 0
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: geo.size.width * progress, height: 4)
                    .cornerRadius(2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let ratio = max(0, min(1, value.location.x / geo.size.width))
                        audio.seek(to: audio.duration * Double(ratio))
                    }
            )
        }
        .frame(height: 4)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Time Display

    private var timeDisplay: some View {
        HStack(spacing: 4) {
            Text(formatTime(audio.currentTime))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text("/")
                .font(.caption)
                .foregroundStyle(.quaternary)
            Text(formatTime(audio.duration))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(width: 100, alignment: .leading)
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack(spacing: 16) {
            // Loop toggle
            Button {
                audio.toggleLoop()
            } label: {
                Image(systemName: audio.isLooping ? "repeat.1" : "repeat")
                    .font(.title3)
                    .foregroundStyle(audio.isLooping ? .blue : .secondary)
            }
            .buttonStyle(.borderless)
            .help(audio.isLooping ? "Loop: On" : "Loop: Off")

            // Play/Pause
            Button {
                audio.togglePlayPause()
            } label: {
                Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedTrack == nil)

            // Record toggle
            Button {
                audio.toggleRecording()
            } label: {
                Image(systemName: audio.isRecording ? "stop.circle.fill" : "mic.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(audio.isRecording ? .red : .secondary)
            }
            .buttonStyle(.borderless)
            .help(audio.isRecording ? "Stop Recording" : "Start Recording")
        }
    }

    // MARK: - Right Controls (Speed)

    private var rightControls: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(value: Binding(
                get: { audio.playbackRate },
                set: { audio.setSpeed($0) }
            ), in: 0.5...1.5, step: 0.1)
            .frame(width: 100)

            Text(String(format: "%.1fx", audio.playbackRate))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .trailing)
        }
        .frame(width: 180, alignment: .trailing)
    }

    // MARK: - Helpers

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
