# My Drive — rules for Claude Code

Premium CarPlay / Android Auto companion. Code name `mydrive` (final app name TBD — Yaana / Sanctum / Prayaan shortlisted). Owner: Biolynk Technologies.
Full plan: Prototype Plan doc https://claude.ai/artifact/RReNj5c25y7qkbatvHWT8U . Task list: `docs/TASKS.md`. Spec: `docs/SPEC.md`.

## Layout
- `ios/` — Swift, SwiftUI, XcodeGen (`ios/project.yml`). Build on the MacBook only. `brew install xcodegen && cd ios && xcodegen`, then open `MyDrive.xcodeproj`.
- `android/` — Kotlin, Compose, Media3. Build on the Windows PC (SDK at `%LOCALAPPDATA%\Android\Sdk`, JDK 17).
- `shared/` — car catalogue JSON, briefing copy, welcome sounds (used by both apps).
- `tools/carrender/` — car picture generator (Vertex AI, Nano Banana Pro). Never run without Mohit's OK on cost.

## IDs
- iOS bundle `com.biolynk.mydrive`, widget `com.biolynk.mydrive.widget`, App Group `group.com.biolynk.mydrive`. Team: BIOLYNK TECHNOLOGIES PRIVATE LIMITED (WSLRC7P5X9).
- Android applicationId `com.biolynk.mydrive`.

## Platform rules (do not break)
- CarPlay category = **audio** only (`com.apple.developer.carplay-audio`). Requested 11 Nov 2026, not yet approved.
  - Simulator-only entitlements `ios/Config/MyDrive-Sim.entitlements` via `CODE_SIGN_ENTITLEMENTS[sdk=iphonesimulator*]`. Device builds must NOT carry CarPlay keys until Apple approves.
  - Templates only (list, tab bar, now playing, grid, alert, action sheet; voice control + search from iOS 27). Max 4 tabs, depth 5.
  - Activate AVAudioSession only when about to play. Never at launch. No microphone/recording in CarPlay.
  - No settings/setup screens in CarPlay. Never tell the driver to pick up the phone.
  - Widget: `.systemSmall` only; App Group data with `completeUntilFirstUserAuthentication` (must work while the phone is locked).
- Android Auto: Media3 `MediaLibraryService` + `MediaSession`; `automotive_app_desc.xml` with `media`. Detect connection with `androidx.car.app.connection.CarConnection`. Test with Desktop Head Unit (DHU). Play internal testing for real cars.
- Welcome sound plays only when the user switched it on (iOS: their "CarPlay connects" Shortcut → `PlayWelcomeIntent`).

## Measurement (every build)
One JSON line per event (`ts, event, ms_since_connect, platform, build, extra`) to `metrics.jsonl` (App Group on iOS, filesDir on Android). Events: `connect_detected, app_launched, welcome_started, welcome_finished, briefing_started, briefing_finished, handoff_music, widget_rendered, onboarding_step, onboarding_done, error`. Debug screen exports the file.

## Working rules
- Small commits, conventional messages. Build + unit tests before each commit.
- iOS sources in `ios/MyDrive` were written without a compiler (by Cowork). Expect small compile errors; fix them, keep the design.
- No paid APIs/tools without Mohit's explicit OK. GCP AI project `biolynk-studio-2610` (founder@biolynktech.com only).
- End each session with a plain-English summary: done / assumptions / left. Tick `docs/TASKS.md`.
