# EchoFlow 🌊

**EchoFlow** is a native macOS application designed for high-performance audio playback, recording, and AI-powered transcription. It features a seamless, synchronized interface for studying, transcribing, and reviewing audio content with integrated AI services.

![EchoFlow Header](https://raw.githubusercontent.com/placeholder-media/banner.png)

## ✨ Features

- 🎧 **High-Performance Audio**: Native playback and recording with granular control.
- 🧠 **AI Transcription**: Integrated support for **OpenAI Whisper**, **Google Gemini**, and **xAI Grok**.
- ⏱️ **Zero-Drift Sync**: Advanced 16kHz audio resampling and `DispatchSourceTimer` logic ensuring the transcript stays perfectly synced with the audio.
- 📂 **Smart Sidebar**: View tracks in the current folder or browse recent playlists grouped by parent directory.
- 💾 **State Persistence**: Remembers your exact position (folder, track, sentence, and playback time) so you can pick up where you left off.
- 📥 **Import/Export**: Full support for SRT files. Import existing transcripts or export AI-generated ones.
- ⌨️ **Power-User Shortcuts**: Fully navigable via keyboard for efficient workflows.

## 🚀 Getting Started

### Prerequisites
- macOS 13.0 or later
- Swift 5.9+

### Installation & Build
```bash
# Clone the repository
git clone https://github.com/yourusername/echo-flow.git
cd echo-flow

# Build the project
swift build

# Run the app
swift run
```

### Configuration
1. Launch EchoFlow.
2. Open **Settings** (⌘,) -> **AI Services**.
3. Enter your API keys for OpenAI, Gemini, or Grok.
4. Select your preferred model and language.

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Space` | Play / Pause |
| `⌘R` | Start / Stop Recording |
| `⌘L` | Toggle Loop Mode |
| `→` / `←` | Skip Forward / Backward |
| `⌘E` | Export Transcript as SRT |
| `⌘⇧I` | Import SRT File |
| `⌘[` / `⌘]` | Previous / Next Track |

## 🛠️ Technical Details

### Audio-Transcript Sync
EchoFlow solves the common "AI drift" problem by preprocessing all audio to **16kHz Mono** before transcription. This eliminates sample-rate mismatches that cause AI models to return "stretched" timestamps. The UI uses a synchronous `DispatchSourceTimer` on the main queue to read the audio playhead with millisecond precision.

### Security & Privacy
- **API Keys**: Stored securely using standard macOS persistence.
- **Microphone**: Permission is requested only for recording features.
- **Local First**: Audio files and recent history are accessed directly from your filesystem.

---

Built with ❤️ using **SwiftUI** and **AVFoundation**.
