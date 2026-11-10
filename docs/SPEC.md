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
