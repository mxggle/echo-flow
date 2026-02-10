# EchoFlow — Development Log

> Built on 2026-02-10

---

## Task Checklist

- [x] Step 1: Project Skeleton (`Package.swift`, folder structure, `Info.plist`, entry point)
- [x] Step 2: Data Model (`Models.swift` — Track, Sentence, SRTParser)
- [x] Step 3: Audio Controller (`AudioController.swift` — AVAudioPlayer/Recorder)
- [x] Step 4: ViewModel & State (`AppViewModel.swift`)
- [x] Step 5: UI Components (SidebarView, TranscriptView, ControlsView, MainView)
- [x] Verification: Build and test

---

## Project Structure

```
echo-flow/
├── Package.swift              # SPM config, macOS 13+
├── Info.plist                 # NSMicrophoneUsageDescription
├── prompt.md                  # Original spec
├── DEVLOG.md                  # This file
└── Sources/
    ├── EchoFlowApp.swift      # @main entry, mic permission request
    ├── Models.swift           # Track, Sentence, SRTParser
    ├── AudioController.swift  # AVAudioPlayer/Recorder, loop, rate
    ├── AppViewModel.swift     # Directory scanning, track selection, state
    ├── SidebarView.swift      # Track list + folder picker
    ├── TranscriptView.swift   # Auto-scroll sentences, click-to-seek
    ├── ControlsView.swift     # Play/Pause, Record, Loop, Speed slider
    └── MainView.swift         # NavigationSplitView layout
```

---

## Features Implemented

| Feature | Details |
|---|---|
| **Directory Playlist** | Recursively scans for `.mp3`, pairs with `.srt` |
| **SRT Parser** | Handles standard format with multiline text |
| **Transcript UI** | Auto-scroll, active highlight, click-to-seek |
| **Loop Mode** | Loops the current sentence's time range |
| **Speed Control** | Slider 0.5x–1.5x via `enableRate` |
| **Recording** | AAC recording to temp directory |
| **Mic Permission** | Requested on launch via `AVCaptureDevice` |

---

## Build & Run

```bash
swift build   # ✅ Compiles successfully
swift run     # Launch the app
```

---

## Issues Fixed During Build

1. **`onChange` API compatibility** — Used macOS 13-compatible `onChange(of:perform:)` instead of macOS 14-only `onChange(of:initial:_:)` variant.
2. **`foregroundStyle` type mismatch** — `.tertiary` produces `some ShapeStyle`, not `Color`. Replaced with `Color.gray` for type-safe ternary.

---

## Bug Fixes — 2026-02-10

### 1. Keyboard shortcuts not responding

**Root cause:** The Play/Pause button used `.keyboardShortcut(.space, modifiers: [])` inline in `ControlsView`, but `NavigationSplitView` gives focus to the sidebar `List`, so the shortcut was never triggered.

**Fix:** Added app-level menu commands via `.commands { CommandMenu("Playback") { ... } }` in `EchoFlowApp.swift`. Shortcuts now work regardless of focus:

| Shortcut | Action |
|---|---|
| Space | Play / Pause |
| ⌘L | Toggle Loop |
| ⌘R | Toggle Recording |

**Files changed:** `EchoFlowApp.swift`, `ControlsView.swift`

### 2. No feedback on recorded file location

**Root cause:** Recordings were saved to a temp directory at a fixed filename (`echoflow_recording.m4a`) with no UI feedback.

**Fix:**
- Recordings now save to `~/Documents/EchoFlow Recordings/` with timestamped filenames (e.g., `Recording_2026-02-10_19-20-51.m4a`).
- After stopping, a green banner appears showing the filename with a **"Reveal in Finder"** button and a dismiss (×) button.

**Files changed:** `AudioController.swift`, `MainView.swift`

### 3. Window not focusable (no keyboard input)

**Root cause:** SPM-launched SwiftUI apps default to a background activation policy, so the window appears but can't receive focus or keyboard events.

**Fix:** Added `NSApp.setActivationPolicy(.regular)` and `NSApp.activate(ignoringOtherApps: true)` in `onAppear` to promote the app to a regular foreground process.

**Files changed:** `EchoFlowApp.swift`

### 4. Settings View (⌘,)

**Feature:** Added a native macOS Settings window with three tabs:

| Tab | Settings |
|---|---|
| **Playback** | Skip forward/backward step (1–60s), fine skip step (0.5–10s), default playback speed, speed step (+/- increment) |
| **Transcript** | Auto-scroll to active sentence toggle |
| **Recording** | Output format (AAC/WAV), reveal recordings folder |

All values persist via `@AppStorage`. `AudioController` reads skip steps, speed step, and default speed from `SettingsManager` instead of hardcoded values. Menu labels dynamically show the configured skip seconds.

**Files added:** `SettingsManager.swift`, `SettingsView.swift`
**Files changed:** `AudioController.swift`, `EchoFlowApp.swift`, `TranscriptView.swift`

### 5. Audio Sync & Interaction Fixes

**Root cause:**
- Linear search in `onTimeUpdate` was inefficient and sometimes missed updates, causing highlight lag.
- SRT files with non-sequential or duplicate IDs caused `ForEach` rendering issues.
- `onTapGesture` on `lazyVStack` rows was unreliable.

**Fix:**
- **Robust Indexing:** `SRTParser` now assigns sequential internal IDs (0, 1, 2...) regardless of file content.
- **Optimized Lookups:** Replaced linear search with a multi-stage check: 1) Current sentence? 2) Next sentence? 3) Binary search (fallback).
- **Better Interaction:** Wrapped `SentenceRow` in a `Button` with `.buttonStyle(.plain)` for reliable native click handling.

**Files changed:** `Models.swift`, `AppViewModel.swift`, `TranscriptView.swift`

### 6. Recent Playlists Tab (Folder-Grouped Sidebar) — 2026-02-10

**Feature:** Added a segmented "Tracks" / "Recent" tab picker in the sidebar. The "Recent" tab shows previously opened folders grouped by parent directory (similar to VLC/IINA). Tapping a folder loads its tracks and switches to the Tracks tab. Maximum 10 recent folders are stored.

**Files changed:** `SidebarView.swift`, `SettingsManager.swift`, `AppViewModel.swift`

### 7. App State Persistence — 2026-02-10

**Feature:** The app now saves its full session state on quit and restores it on relaunch:
- Last opened folder URL
- Last selected track
- Last sentence index + playback position
- Current transcript (as JSON, including AI-generated ones)

State is persisted via `@AppStorage` in `SettingsManager`. Restoration runs on app launch in `onAppear`. Saving fires on `NSApplication.willTerminateNotification`.

**Files changed:** `SettingsManager.swift`, `AppViewModel.swift`, `EchoFlowApp.swift`

### 8. Transcript Export & Import — 2026-02-10

**Feature:** Users can now export and import transcripts as standard `.srt` files.

| Action | Trigger |
|---|---|
| Export transcript | ⌘E or ↑ button in title bar |
| Import transcript | ⌘⇧I or ↓ button in title bar |

Export generates proper SRT format with `HH:MM:SS,mmm` timestamps. Import parses any standard SRT file and loads it into the current track.

**Files changed:** `Models.swift` (SRT generation + Sentence Codable), `AppViewModel.swift`, `MainView.swift`, `EchoFlowApp.swift`

### 9. Fix Progressive Audio-Transcript Sync Drift — 2026-02-10

**Bug:** Transcript highlighting drifted further and further from the actual audio position over time. Clicking a sentence also jumped to the wrong position.

**Root Cause:** AI transcription APIs (Whisper, Gemini) return timestamps that are systematically **stretched** compared to the actual audio duration when processing compressed formats like MP3. For example, a 60-second audio file might get timestamps ending at 65 seconds.

**Fix (two parts):**
1. **Timer fix:** Replaced `Timer.scheduledTimer` + `Task { @MainActor }` with `DispatchSourceTimer` on `.main` queue for synchronous time updates (eliminates async dispatch jitter).
2. **Timestamp normalization:** Added `normalizeTimestamps()` in `AppViewModel` that scales all AI-generated timestamps proportionally: `ratio = actualDuration / transcriptDuration`. Applied to both `transcribeCurrentTrack()` and `importTranscript()`. A 2% tolerance threshold skips scaling when timestamps are already accurate. A console log `⏱ Normalizing timestamps: ...` prints the scaling factor for debugging.

### 10. Audio Resampling for Transcription — 2026-02-10

**Bug:** AI timestamp drift was caused by sample rate mismatches (sending 44.1/48kHz audio to models expecting 16kHz). This caused linear time stretching.

**Fix:** Implemented a robust preprocessing step in `TranscriptionService`. Before uploading to OpenAI/Gemini/Grok, the audio is converted to **16kHz Mono AAC** using `AVAssetReader` + `AVAssetWriter`. This standardized input prevents the AI from misinterpreting the sample rate, eliminating the root cause of the drift.

**Files changed:** `TranscriptionService.swift`
### 11. Project Documentation — 2026-02-11

**Action:** Created a comprehensive `README.md` for the project.

**Content:** Includes app overview, feature list, build instructions, keyboard shortcuts, and technical implementation details regarding audio-transcript synchronization.

**Files changed:** `README.md`

