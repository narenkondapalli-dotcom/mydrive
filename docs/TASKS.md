# Tasks

## Cowork (done 11 Nov 2026)
- [x] Repo skeleton, CLAUDE.md, SPEC, TASKS
- [x] iOS core sources (onboarding, car profile store, audio engine, CarPlay scene, widget, intents, metrics, debug) — written without a compiler; Mac must build
- [x] Car catalogue sample + car render script (`tools/carrender/render.py`)

## Android (written + built by Cowork 11 Nov 2026 — needs device/DHU testing on the Mac)
- [x] A1 Gradle project (AGP 8.9.1, Kotlin 2.1.20, Compose, minSdk 29, target 36), wrapper, `assembleDebug` green
- [x] A2 `MediaLibraryService` + `MediaSession`, roots Today / Library / Drives; welcome sound + TTS briefing queue; releases focus so music resumes
- [x] A3 `automotive_app_desc.xml` + manifest — [ ] verify in Android Auto Desktop Head Unit
- [x] A4 `CarConnection` observer + `onPlaybackResumption` welcome (if enabled) — [ ] verify on a real car / DHU
- [x] A5 Compose onboarding (3 steps, manufacturer colours, real renders)
- [x] A6 Metrics JSONL + on-screen viewer — [ ] add export/share
- [x] A7 Unit tests (5 passing: catalogue, search, profile, metrics, briefing)

## Claude Code — MacBook (iOS)
- [ ] I1 `brew install xcodegen`, `cd ios && xcodegen`, simulator build green
- [ ] I2 Day-1 check: Simulator → I/O → External Displays → CarPlay shows My Drive with sim-only entitlement. Record result in the plan doc.
- [ ] I3 Fix compile errors in Cowork-written sources; add unit tests (CarProfileStore, Metrics, ArtworkComposer)
- [x] I4 Bundle welcome sounds + car images into the app (CI green: all 12 clips + bundled renders resolve; 39 tests, run 42971369722)
- [x] I5 Shortcut setup helper screen (CI green; Shortcuts app opening is manual on device)
- [x] I6 Widget builds, embeds, timeline logic unit-tested (CI green) — [ ] manual CarPlay Dashboard check on the Mac, steps in docs/IOS-TESTING.md

## Cowork — next
- [x] C1 5-car test: Pro vs 2.1 → 2.1 chosen (more accurate current faces, ~¼ cost)
- [ ] C2 Full car library — 323 renders running on PC (D:\Projects\mydrive-assets\cars\nb21), then `prepare_app_assets.py` → `shared/cars/`
- [ ] C3 Welcome theme sounds (3)

## Personalization P1–P6 (spec in SPEC.md) — iOS + Android
- [x] P2 greetings, briefing item toggles, loved-one recording (iOS; recording itself unverified on device)
- [x] P3 DriveLog + usual stops/streak/favourite route + Drives tab (iOS)
- [x] P4 ritual settings + multiple profiles (iOS)
- [x] P5 accent from paint + time-of-day/season artwork (iOS)
- [x] P6 widget/phone style options (iOS; Android Glance widget left)
