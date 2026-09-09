# ConfidentSpeak

A standalone iOS app for a 14-day speaking-confidence program: record a short
practice clip against each day's drill, get objective pace/filler/pause
metrics plus one specific piece of LLM feedback, and track progress across
the program. Built alongside [CompyPal](https://github.com/AnubisRooster/CompyPal)
and [therAIpist](https://github.com/AnubisRooster/therAIpist), depending on
[OnDeviceKit](https://github.com/AnubisRooster/OnDeviceKit) (ODK) for BYOK LLM
access.

## What's here

- `Models/ProgramContent.swift` — static 14-day lesson/drill content (no DB needed)
- `Models/PracticeSession.swift` — GRDB record for user progress per day
- `Database/AppDatabase.swift` — `DatabaseMigrator` setup, plus an async
  convenience API (`latestSessionsByDay`, `completedSessions`, `save`) that
  the view models call
- `Audio/Recorder.swift` — AVFoundation recording wrapper
- `Audio/Transcriber.swift` — on-device `SFSpeechRecognizer` wrapper
- `Analysis/SpeechMetrics.swift` — WPM / filler-word / pause calculation, no LLM
- `Feedback/FeedbackEngine.swift` — LLM feedback via OnDeviceKit's
  `BYOKLLMKit` (`LLMService`/`LLMSending`), provider/model resolved from
  `Feedback/FeedbackSettings.swift` (defaults to OpenRouter); routes to
  on-device inference when a local model is selected (`FeedbackSettings.localModelID`)
- `Features/Local/LocalModelService.swift` — curated on-device model catalog
  (Apple Intelligence + GGUF via `OnDeviceKit`'s `LocalLLMKit`/llama.cpp) with
  download/cancel/delete and `Documents/models/` storage
- `Features/Local/AppleFoundationEngine.swift` — Apple's `FoundationModels`
  framework (`SystemLanguageModel`/`LanguageModelSession`), iOS 26 + Apple
  Intelligence, with a compile-safe stub otherwise
- `Features/DayList`, `Features/DayDetail`, `Features/Recording`,
  `Features/Progress`, `Features/Settings` — the SwiftUI screens and view
  models wiring the pipeline together: record → transcribe → compute
  metrics → optional LLM feedback → save `PracticeSession`
- `App/ConfidentSpeakApp.swift`, `App/ContentView.swift` — app entry point and
  the three-tab (`Program` / `Progress` / `Settings`) root view

## Setup

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).
2. From `ios/`, run `xcodegen generate` to produce `ConfidentSpeak.xcodeproj`
   (also runs automatically as an Xcode pre-build step, and in CI).
3. Open `ios/ConfidentSpeak.xcodeproj` in Xcode 15+, set a development team
   for signing, and run on an iOS 17+ simulator or device.
4. In the app's **Settings** tab, either pick a cloud provider and paste in
   its API key (stored via `BYOKLLMKit`'s `LLMKeychainStore`, never in
   `UserDefaults`) — or flip on **Use on-device model** for fully offline
   coach feedback: download a GGUF model (or use Apple Intelligence on iOS 26)
   and every step runs on the device with no key and no network. Without a
   key (or an installed local model), drills still record/transcribe/score
   locally; `FeedbackEngine` is skipped rather than erroring
   (`FeedbackEngine.isConfigured()`).

### Fully on-device mode

- Toggle **On-Device → Use on-device model** in Settings.
- **Apple Intelligence**: zero setup on iOS 26 devices with Apple
  Intelligence enabled (no download).
- **GGUF models**: pick from the curated catalog (Llama 3.2 1B/3B, Llama 3.1
  8B, Phi-4 Mini, Gemma 3 1B/4B, Qwen 2.5 1.5B, Qwen 3 4B, SmolLM2 1.7B).
  One-time downloads (~0.8–4.9 GB) land in `Documents/models/` and run via
  OnDeviceKit's `LocalLLMKit` (LLM.swift over llama.cpp).
- Selecting on-device persists to `FeedbackSettings.localModelID`; the cloud
  provider/key/model settings are untouched and reappear when off-device mode
  is re-enabled.

`ios/Package.swift` also lets `swift build`/`swift test` resolve the same
sources and dependencies directly, mirroring the `CompyPal`/`Companion`
package layout — useful for editing outside Xcode, though the app itself
only really builds/runs through the Xcode project (SwiftUI + AVFoundation +
Speech need the iOS SDK).

## Testing

`ios/ConfidentSpeakTests` uses Swift Testing (`@Test`/`#expect`, matching
`CompyPal`'s `CompanionTests`), covering `SpeechMetrics`, `ProgramContent`,
the `AppDatabase` GRDB queries (against an in-memory `DatabaseQueue`),
`FeedbackSettings`'s `UserDefaults` round-trip, and `FeedbackEngine`
(against a mock `LLMSending`, so no network call runs in tests), plus the
on-device model catalog and local/cloud routing (`LocalModelCatalogTests`).
CI (`.github/workflows/ios-tests.yml`) generates the Xcode project with
XcodeGen and runs the suite on an iOS Simulator.

## Known gap to design around

CompyPal's fresh-install bug was a migration-ordering issue (a table with a
foreign key created before its dependency). This schema only has one table
right now, so it's not at risk yet — but if you add related tables (e.g. a
`user_settings` or `streak` table), order the migrations carefully and test
against a truly fresh install, not just an upgrade path.

## Promotion candidates for OnDeviceKit

`Recorder.swift` and `Transcriber.swift` are generic enough to move into ODK
once proven here — CompyPal/therAIpist could pick up short-clip voice input
later without re-implementing this (note this is a different shape than
ODK's existing `VoiceLoopKit`, which is built around a continuous
listen/speak conversation loop rather than a single record-then-transcribe
clip). Likewise `LocalModelService.swift` (curated catalog + GGUF download
manager) and `AppleFoundationEngine.swift` are app-agnostic and would slot
naturally into ODK's `LocalLLMKit`/a future `FoundationModelsKit`.

## Status

First pass at all the SwiftUI screens and wiring described in the original
scaffold, a Settings screen with a live OpenRouter model picker, an app icon
(`AppIcon.appiconset`, a 1024px microphone mark), and a fully on-device
coach-feedback path (Apple Intelligence on iOS 26 + downloadable GGUF models,
100% offline). The pipeline (`Recorder` → `Transcriber` → `SpeechMetrics` →
`FeedbackEngine` → `PracticeSession`) should be exercised end-to-end on a
device/simulator — including one downloaded GGUF model run — before treating
this as done.
