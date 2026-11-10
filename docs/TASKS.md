# Tasks

## Cowork (done 11 Nov 2026)
- [x] Repo skeleton, CLAUDE.md, SPEC, TASKS
- [x] iOS core sources (onboarding, car profile store, audio engine, CarPlay scene, widget, intents, metrics, debug) — written without a compiler; Mac must build
- [x] Car catalogue sample + car render script (`tools/carrender/render.py`)

## Claude Code — Windows PC (Android)
- [ ] A1 Gradle project in `android/` (AGP + Kotlin + Compose, minSdk 29, target 36), wrapper committed, `assembleDebug` green
- [ ] A2 `MediaLibraryService` + `MediaSession`, roots Today / Library / Drives; plays bundled welcome sound + TTS briefing
- [ ] A3 `automotive_app_desc.xml`, manifest entries; app visible in Android Auto DHU
- [ ] A4 `CarConnection` observer → `connect_detected` metric + welcome (if enabled)
- [ ] A5 Compose onboarding (3 steps) + DataStore CarProfile, reading `shared/car-catalog.json`
- [ ] A6 Metrics JSONL + debug screen + export
- [ ] A7 Unit tests (CarProfile, metrics, catalogue parsing)

## Claude Code — MacBook (iOS)
- [ ] I1 `brew install xcodegen`, `cd ios && xcodegen`, simulator build green
- [ ] I2 Day-1 check: Simulator → I/O → External Displays → CarPlay shows My Drive with sim-only entitlement. Record result in the plan doc.
- [ ] I3 Fix compile errors in Cowork-written sources; add unit tests (CarProfileStore, Metrics, ArtworkComposer)
- [ ] I4 Bundle welcome sounds + car images into the app
- [ ] I5 Shortcut setup helper screen
- [ ] I6 Widget on simulator CarPlay Dashboard

## Cowork — next
- [ ] C1 5-car test: Nano Banana Pro vs 2.1 on GCP credits
- [ ] C2 Full car library (top 40 India models × 7 colours)
- [ ] C3 Welcome theme sounds (3)
