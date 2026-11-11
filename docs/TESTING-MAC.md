# Testing on the MacBook (step by step)

Use **Claude Code inside the Claude desktop app** (Code tab) — no terminal needed for Claude itself.

## 0. One-time setup (≈ 1–2 h, mostly downloads)
1. Install **Xcode** (App Store) → open once, accept licence, install iOS simulators.
   Settings → Accounts → add the Apple ID that is on the Biolynk developer team.
2. Install **Android Studio** (https://developer.android.com/studio) → SDK Manager: Android 16 (API 36),
   Build-Tools 36, Android Auto **Desktop Head Unit** (SDK Tools tab → "Android Auto Desktop Head Unit Emulator").
3. Claude desktop app → sign in → **Code** tab → choose folder → pick the cloned `mydrive` folder.
4. Get the code: in the Code tab ask Claude: *"clone narenkondapalli-dotcom/mydrive into ~/Projects"*
   (or GitHub Desktop → Clone). Car pictures are already inside (`shared/cars`).

## 1. iPhone app (ask Claude Code to do these)
- `brew install xcodegen && cd ios && xcodegen` → open `MyDrive.xcodeproj`.
- Build for an iPhone simulator; fix any compile errors (sources were written without a compiler).
- Run → onboarding: pick Jeep Meridian → Pearl White → Looks right.
- **Day-1 check:** Simulator menu → I/O → External Displays → CarPlay. Does "My Drive" appear? Record yes/no in the plan doc.
- Tap Today → Welcome theme → Now Playing shows the car artwork; listen to the briefing.
- Add the widget on the simulator home screen.
- Debug screen → Export metrics.jsonl → share to Cowork for review.

## 2. Android app
- Open `android/` in Android Studio → Run on an emulator (API 34+).
- Onboarding → Home → **Test welcome**: chime, then spoken briefing, then silence (music would resume).
- Android Auto: start DHU (`$ANDROID_HOME/extras/google/auto/desktop-head-unit`), connect a real Android phone
  with Android Auto developer mode + "Unknown sources" on → My Drive appears in the media apps → browse Today → play.
- Copy the measurements shown on the Home screen into the test sheet.

## 3. What "pass" means for v0
| Check | Pass |
|---|---|
| Onboarding finishes | < 60 s, right picture for model + colour |
| Welcome starts after tap/connect | < 2 s (`welcome_started.ms_since_connect`) |
| Briefing starts after welcome | < 1 s gap |
| Music resumes after briefing | yes |
| CarPlay window shows the app (iOS sim) | yes / no (record) |
