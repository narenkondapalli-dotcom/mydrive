# Android testing — phone, emulator and the Android Auto Desktop Head Unit (DHU)

Windows paths. Everything below uses **D:** for caches; do not let Gradle or AVDs write to C:.

## 0. What was verified and what was not (11 Nov 2026)

| Item | Status |
|------|--------|
| `gradlew.bat assembleDebug testDebugUnitTest` | green, 24 unit tests |
| Install + launch on an API 36 Pixel emulator (Google APIs x86_64) | verified |
| Onboarding Jeep Meridian → Pearl White → name → profile saved | verified (screens + `onboarding_*` metrics) |
| "Test welcome": theme clip → pause → spoken briefing | verified from `metrics.jsonl` (connect_detected, welcome_started, welcome_finished, briefing_started, briefing_finished, handoff_music) |
| Loved-one line: mic permission asked only on tapping Record, clip saved, `loved_one_played` | verified on emulator |
| Drives: seed a week → streak / km / favourite route / usual stop shown, usual-stop line spoken in the briefing | verified on emulator |
| Android Auto DHU against the app | **not verified.** The emulator's Android Auto is only a stub, and no Android phone was attached to this PC. Follow section 3 on your phone. |
| Real car | **not verified** |

## 1. Build and install on your phone (USB)

1. Phone: Settings → About phone → tap **Build number** 7 times → back → System → **Developer options** → turn on **USB debugging**.
2. Plug the phone in. On the phone accept "Allow USB debugging" (tick "Always allow").
3. PowerShell:

```powershell
$env:JAVA_HOME      = "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
$env:GRADLE_USER_HOME = "D:\DevCache\gradle"
$env:ANDROID_HOME   = "$env:LOCALAPPDATA\Android\Sdk"
$env:Path          += ";$env:ANDROID_HOME\platform-tools"
adb devices                       # your phone must show as "device", not "unauthorized"
cd D:\Projects\mydrive\android
.\gradlew.bat assembleDebug testDebugUnitTest
adb install -r app\build\outputs\apk\debug\app-debug.apk
adb shell am start -n com.biolynk.mydrive/.ui.MainActivity
```

4. In the app: pick a car, a colour, type your name, **Looks right**. Press **Test welcome**. You should hear the welcome clip for the current time of day, a short pause, then the spoken briefing. The phone needs a text-to-speech engine (Google Speech Services is installed on most phones).
5. Read the measurements:

```powershell
adb shell "run-as com.biolynk.mydrive cat files/metrics.jsonl"
```

Expect `connect_detected` (via `phone_test`), `welcome_started`, `welcome_finished`, `briefing_started`, `briefing_finished`, `handoff_music`.

## 2. Optional: emulator on D:

```powershell
$env:ANDROID_AVD_HOME = "D:\DevCache\android-avd"
$env:ANDROID_HOME     = "$env:LOCALAPPDATA\Android\Sdk"
# one-time (needs system image android-36 google_apis x86_64, already installed here):
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\avdmanager.bat" create avd -n MyDrive_Pixel -k "system-images;android-36;google_apis;x86_64" -d pixel
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd MyDrive_Pixel -no-snapshot -no-audio
```

`avdmanager` may print "Could not load devices" warnings for other images; the AVD is still created. Then `adb install -r ...` as above.

## 3. Android Auto on your phone with the DHU

### 3a. One-time setup on the PC

```powershell
& "$env:ANDROID_HOME\cmdline-tools\latest\bin\sdkmanager.bat" "extras;google;auto"
```

This installs `%ANDROID_HOME%\extras\google\auto\desktop-head-unit.exe` (DHU 2.0). If sdkmanager reports it is already installed, nothing to do.

### 3b. One-time setup on the phone

1. Install / update **Android Auto** from Google Play (phone must be on Android 11+ and Android Auto 13+ for a modern DHU).
2. Open Android Auto settings: Settings → Connected devices → Connection preferences → **Android Auto**.
3. Scroll to the bottom, tap **Version** (or "Version and permission info") **10 times** until the "developer mode" toast appears. Confirm.
4. Top-right **⋮** → **Developer settings**. Turn on **Unknown sources** (needed because My Drive is a sideloaded debug build, not from Play).
5. Still in the ⋮ menu choose **Start head unit server**. A notification "Head unit server started" appears.

### 3c. Each test session

```powershell
adb devices
adb forward tcp:5277 tcp:5277
cd "$env:ANDROID_HOME\extras\google\auto"
.\desktop-head-unit.exe
```

A window with the car screen opens (800x480). Other layouts: `.\desktop-head-unit.exe -c config\default_1080p.ini`.

If it says it cannot connect: make sure "Start head unit server" is on (step 3b.5), the phone is unlocked, and the `adb forward` was run after the phone was plugged in.

### 3d. What to check in the DHU

1. In the car launcher open the **My Drive** media app (if missing: step 3b.4, then force-stop Android Auto and restart the head unit server).
2. Root shows three tabs: **Today**, **Library**, **Drives**.
3. Today → **Welcome back, <name>**: the clip plays, then the briefing, then audio focus is released (music app resumes).
4. Library lists the three welcome themes (Jarvis, Warm, Minimal); tapping one plays that theme.
5. Drives: before the test, on the phone press **Seed a week** (Drives section). The Drives tab then lists streak, total distance, favourite route, usual stops and recent drives; the briefing also speaks the usual-stop line when it matches the current weekday and hour.
6. Now-playing artwork shows the car with the greeting, tinted by time of day and the paint accent.
7. Metrics after the DHU run (phone plugged in):

```powershell
adb shell "run-as com.biolynk.mydrive cat files/metrics.jsonl"
```

Look for `connect_detected` with `via` = `android_auto_play` or `resumption`, then the welcome/briefing events. `ms_since_connect` is the number the prototype exists to measure.

### 3e. Troubleshooting

- Live log: `adb logcat -s ExoPlayerImpl TextToSpeech AndroidRuntime:E MediaSessionService`
- App is a media app only if the manifest meta-data resolves: `adb shell dumpsys package com.biolynk.mydrive | Select-String "car.application"`
- No spoken briefing: install/enable Google Speech Services (Settings → System → Languages → Text-to-speech output).
- Loved-one clip: it is recorded on the phone (Loved-one line → Record; the microphone permission dialog only appears when you press Record). Max 15 seconds.

## 4. Real car (later)

Upload an AAB to Play **internal testing**, add yourself as a tester, install from Play on the phone, plug into the car. Android Auto in a real car only lists apps that are installed from Play (or with Unknown sources on in developer mode).
