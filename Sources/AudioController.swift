import Foundation
import AVFoundation
import Combine

@MainActor
class AudioController: ObservableObject {
    // MARK: - Published State
    @Published var isPlaying: Bool = false
    @Published var isRecording: Bool = false
    @Published var isLooping: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    @Published var volume: Float = 1.0
    @Published var lastRecordingURL: URL? = nil

    /// Callback invoked on every timer tick with the current playback time
    var onTimeUpdate: ((TimeInterval) -> Void)?

    // MARK: - Private
    private var player: AVAudioPlayer?
    private var recorder: AVAudioRecorder?
    private var timer: DispatchSourceTimer?
    private var loopStart: TimeInterval = 0
    private var loopEnd: TimeInterval = 0

    private var recordingsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EchoFlow Recordings")
    }

    private func makeRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return recordingsDirectory.appendingPathComponent("Recording_\(timestamp).m4a")
    }

    // MARK: - Player Controls

    func loadAudio(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.enableRate = true
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            currentTime = 0
            playbackRate = Float(SettingsManager.shared.defaultPlaybackSpeed)
        } catch {
            print("❌ Failed to load audio: \(error.localizedDescription)")
        }
    }

    func play() {
        guard let player else { return }
        player.rate = playbackRate
        player.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopTimer()
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
        onTimeUpdate?(time)
    }

    func setSpeed(_ rate: Float) {
        let clamped = min(max(rate, 0.5), 1.5)
        playbackRate = clamped
        if isPlaying {
            player?.rate = clamped
        }
    }

    func skipForward(_ seconds: TimeInterval? = nil) {
        guard let player else { return }
        let step = seconds ?? SettingsManager.shared.skipForwardStep
        let target = min(player.currentTime + step, duration)
        seek(to: target)
    }

    func skipBackward(_ seconds: TimeInterval? = nil) {
        guard let player else { return }
        let step = seconds ?? SettingsManager.shared.skipBackwardStep
        let target = max(player.currentTime - step, 0)
        seek(to: target)
    }

    func setVolume(_ vol: Float) {
        let clamped = min(max(vol, 0), 1)
        volume = clamped
        player?.volume = clamped
    }

    func speedUp() {
        setSpeed(playbackRate + Float(SettingsManager.shared.speedStep))
    }

    func speedDown() {
        setSpeed(playbackRate - Float(SettingsManager.shared.speedStep))
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        stopTimer()
        currentTime = 0
        duration = 0
    }

    // MARK: - Loop Mode

    func setLoopRange(start: TimeInterval, end: TimeInterval) {
        loopStart = start
        loopEnd = end
    }

    func toggleLoop() {
        isLooping.toggle()
    }

    // MARK: - Recorder Controls

    func startRecording() {
        // Ensure recordings directory exists
        let fm = FileManager.default
        if !fm.fileExists(atPath: recordingsDirectory.path) {
            try? fm.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        }

        let url = makeRecordingURL()
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            isRecording = true
        } catch {
            print("❌ Failed to start recording: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        let url = recorder?.url
        recorder?.stop()
        recorder = nil
        isRecording = false
        lastRecordingURL = url
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        let source = DispatchSource.makeTimerSource(queue: .main)
        source.schedule(deadline: .now(), repeating: .milliseconds(50))
        source.setEventHandler { [weak self] in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
            self.onTimeUpdate?(player.currentTime)

            // Handle looping
            if self.isLooping && self.loopEnd > self.loopStart {
                if player.currentTime >= self.loopEnd {
                    player.currentTime = self.loopStart
                }
            }

            // Handle end of track
            if !player.isPlaying && self.isPlaying {
                self.isPlaying = false
                self.stopTimer()
            }
        }
        source.resume()
        timer = source
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
}
