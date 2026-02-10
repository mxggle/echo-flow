# Role
You are an expert Senior macOS Engineer specializing in Swift, SwiftUI, and AVFoundation. You are tasked with building a "No-Xcode" macOS desktop application called "EchoFlow."

# Project Goal
Build a Minimum Viable Product (MVP) for a language learning "Shadowing" app. 
The app is **Content-Centric**: It treats a folder of audio files as a playlist and syncs them with `.srt` subtitle files. 

# Tech Stack & Constraints
1. **Language:** Swift 5.9+
2. **UI Framework:** SwiftUI (macOS target).
3. **Audio Framework:** AVFoundation (AVAudioPlayer & AVAudioRecorder).
4. **Build System:** Swift Package Manager (SPM) only. Do NOT create an `.xcodeproj` or `.xcworkspace`.
5. **Architecture:** MVVM (Model-View-ViewModel).
6. **Editor Context:** I am using VS Code. Ensure all file paths and build instructions (`swift run`) work from the terminal.

# Core Features (MVP)
1. **Directory-Based Playlist:**
   - User selects a root folder.
   - App recursively finds all `.mp3` files.
   - App pairs them with matching `.srt` files (e.g., `Lesson1.mp3` + `Lesson1.srt`).
2. **Transcript-First UI:**
   - Display the `.srt` content as a scrollable list of sentences.
   - **Active State:** The currently playing sentence must be highlighted.
   - **Click-to-Seek:** Clicking a sentence jumps audio to that timestamp.
3. **Shadowing Engine:**
   - Play audio while simultaneously recording microphone input.
   - "Loop Mode": A toggle to infinitely loop the current active sentence.
   - Playback Speed: Slider (0.5x to 1.5x) using `enableRate`.

# Step-by-Step Implementation Plan
Execute this project in the following order. Do not skip steps.

## Step 1: Project Skeleton
- Initialize a generic executable package: `swift package init --type executable`.
- Update `Package.swift` to target `.macOS(.v13)`.
- Create a valid `Info.plist` file in the root directory ensuring `NSMicrophoneUsageDescription` is present (CRITICAL).
- Create the entry point `EchoFlowApp.swift`.

## Step 2: The Data Model
Create a `Models.swift` file:
- `Track`: Represents an audio file (URL, name, isPlayed).
- `Sentence`: Represents a parsed subtitle line (id, startTime, endTime, text).
- `SRTParser`: A utility class to parse a raw `.srt` string into an array of `Sentence` objects.

## Step 3: The Audio Controller
Create `AudioController.swift` (ObservableObject):
- Manage `AVAudioPlayer` for the backing track.
- Manage `AVAudioRecorder` for user voice.
- Implement `func play(at time: TimeInterval)`.
- Implement `func toggleLoop()`.
- Implement `func setSpeed(_ rate: Float)`.

## Step 4: The ViewModel & State
Create `AppViewModel.swift`:
- `loadDirectory(url: URL)`: Scans for files.
- `selectTrack(_ track: Track)`: Loads audio and parses the `.srt`.
- `currentSentence`: Computed property based on current audio time.

## Step 5: The UI Components
- **SidebarView**: Uses `List` to show tracks.
- **TranscriptView**: Uses `ScrollViewReader` to auto-scroll to the active sentence.
- **ControlsView**: Play/Pause, Record, Speed Slider.
- **MainView**: Uses `NavigationSplitView` to hold it all together.

# Specific Code Requirements
1. **SRT Parsing:** Use a simple Regex or string split approach. Assume standard SRT format (Index -> Time -> Text -> Empty Line).
2. **Permissions:** Ensure the app requests microphone permission on first launch using `AVCaptureDevice.requestAccess`.
3. **Concurrency:** Use `Task` and `MainActor` for UI updates.
4. **Error Handling:** If no `.srt` file is found for an `.mp3`, show a "No Transcript" placeholder but still allow audio playback.

# Output Requirement
Start by generating the **Folder Structure** and the **Package.swift** content. Then, wait for my confirmation before generating the source code for the Models and Logic.