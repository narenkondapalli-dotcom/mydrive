# My Drive — v0 prototype spec

## Phone app
1. **Onboarding (3 screens, design locked 11 Nov 2026)** — see `docs/design/onboarding-your-car.jpg`
   - Step 1: search make + model (`shared/car-catalog.json`); "Can't find it?" → free text or photo.
   - Step 2: body colour (8 swatches) + roof + wheels.
   - Step 3: car render for that model+colour, nickname field, "Looks right" / "Adjust".
   - Fallback: photo of own car → on-device background removal (iOS Vision `VNGenerateForegroundInstanceMaskRequest`; Android ML Kit Subject Segmentation) → composited on the dark set.
   - Save `CarProfile {make, model, colour, roof, wheels, nickname, renderId}`.
2. **Welcome settings**: name, theme (3 built-in sounds), voice on/off, briefing items (weather, first calendar event, traffic ETA).
3. **iOS: Shortcut setup helper** — guided steps for "When CarPlay connects → Play welcome (My Drive)". Track completion.
4. **Debug screen** — metrics viewer + export, fake-connect button.

## Car screen
- Audio app, 3 tabs: **Today** (welcome + today's briefing), **Library** (themes, past briefings), **Drives** (recent drives).
- Now-playing artwork = car render + greeting baked into a 1024 px square, drawn on device.
- iOS 27 extras when available: list thumbnails with badge/progress, details header, CPPlaybackConfiguration, Voice Control template as "Preparing your briefing…" status.

## Widget (iOS)
- `.systemSmall`: car render, nickname, next item ("Clinic 9:30 · 32 min"). Removable background. Tap opens the app in CarPlay.

## Android
- `MediaLibraryService` with the same 3 roots; `CarConnection` observer → welcome on connect (if enabled).
- Compose phone UI mirroring iOS onboarding.

## Look
Black/graphite, gold `#D4B97E`, serif display (Cormorant Garamond) on artwork only; system fonts elsewhere.

## Personalization (added 11 Nov 2026) — both platforms
The car screen layout is fixed by Apple/Google templates, so personal = content. Same behaviour on iOS and Android.

P1. **Their car**: render in their paint/roof/wheels + nickname on now-playing artwork and widget, every connect (exists).
P2. **Their voice and words**
   - Time-of-day greeting by name: morning (05–11), afternoon (12–16), evening (17–20), night (21–04). Copy lives in `shared/briefing/greetings.json`.
   - Briefing items the user switches on/off: weather, first calendar event, traffic ETA, usual stop, streak. Persisted in the profile.
   - **Loved-one line**: record a short clip (max 15 s) on the PHONE only (never in car UI), label it ("Papa"), play it after the chime when enabled. Stored locally. Mic permission asked only on tapping Record.
P3. **Their routine**
   - `DriveLog` of drives {id, startTs, endTs, distanceKm, startLabel, endLabel}. Local only. Debug screen can add a simulated drive; an opt-in toggle is reserved for real capture later (no location permission requested in this build).
   - Derived: usual stops (end label seen ≥3 times, with typical weekday+hour), streak (consecutive days with a drive), total distance, favourite route (most frequent start→end).
   - Briefing line: "Clinic at 9:30 — 32 min" when a usual stop matches the current weekday/hour window (ETA minutes from last average duration). Drives tab lists recent drives + the stats.
P4. **Their ritual**: per-car "ritual" = welcome sound (3 themes), delay before briefing (0–5 s), voice on/off. Multiple profiles (car+driver): switch in phone app; active one used in car.
P5. **Look follows the car**: accent colour derived from paint (map colour name → hex, fallback gold #D4B97E); artwork scene by time of day (dawn/day/dusk/night gradient) and season (northern-India: summer/monsoon/winter) behind the car.
P6. **Phone + widget**: style options — widget style (car-large / minimal / stats) and phone accent follows P5. Android has a matching app widget (Glance) if time allows, otherwise noted as left.

Tests: unit tests for greeting picker, usual-stop/streak/favourite-route maths, accent mapping, scene picker, profile switching, ritual settings. Metrics events unchanged plus `profile_switched`, `loved_one_played`.
