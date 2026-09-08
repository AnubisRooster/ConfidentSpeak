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
  `Feedback/FeedbackSettings.swift` (defaults to OpenRouter)
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
4. In the app's **Settings** tab, pick a provider and paste in its API key
   (stored via `BYOKLLMKit`'s `LLMKeychainStore`, never in `UserDefaults`).
   Without a key, drills still record/transcribe/score locally;
   `FeedbackEngine` is skipped rather than erroring
   (`FeedbackEngine.isConfigured()`).

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
(against a mock `LLMSending`, so no network call runs in tests). CI
(`.github/workflows/ios-tests.yml`) generates the Xcode project with
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
clip).

## Status

First pass at all the SwiftUI screens and wiring described in the original
scaffold, a Settings screen for provider/key/model with a live OpenRouter
model picker, and an app icon (`AppIcon.appiconset`, a 1024px microphone
mark). The pipeline (`Recorder` → `Transcriber` → `SpeechMetrics` →
`FeedbackEngine` → `PracticeSession`) should be exercised end-to-end on a
device/simulator before treating this as done.
