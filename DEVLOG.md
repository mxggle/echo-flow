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
