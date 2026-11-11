# iOS testing guide (for the owner, on the MacBook)

CI (GitHub Actions, `.github/workflows/ios.yml`) builds the app and runs the unit tests on a simulator on every push. Everything below is what CI cannot do: run on a real iPhone, in a real car, and look at the CarPlay screen and the widget.

## 1. Build and run on your iPhone

1. `brew install xcodegen`
2. `cd ios && xcodegen` (creates `MyDrive.xcodeproj` from `project.yml`; re-run after adding files)
3. `open MyDrive.xcodeproj`
4. Select the **MyDrive** target, Signing & Capabilities: team **BIOLYNK TECHNOLOGIES PRIVATE LIMITED (WSLRC7P5X9)**, automatic signing. Do the same for **MyDriveWidget**. The App Group `group.com.biolynk.mydrive` must be enabled on both (Xcode registers it).
5. Plug in the iPhone, pick it as the run destination, press Run. First run: trust the developer certificate on the phone (Settings, General, VPN & Device Management).
6. Device builds carry no CarPlay entitlement until Apple approves it (requested 11 Nov 2026). The app, Shortcut, briefing, widget and loved-one recording all work without it. The CarPlay screen works on the Simulator only.

### What to expect
- First launch: 3-step onboarding (car, colour, name + nickname). Then Home with your car, greeting and a gold (or paint-coloured) **Test welcome** button.
- **Test welcome** plays the welcome clip for the current time of day (theme + morning/afternoon/evening/night), then any loved-one clip, then the pause you set, then the spoken briefing (your name and items). Afterwards your music resumes.
- **Your ritual and look**: greeting choice, briefing items, loved-one recording (microphone permission is asked only when you tap Record; max 15 s), sound theme (jarvis / warm / minimal), pause 0-5 s, voice on/off, widget style.
- **Add another car** creates a second profile; the switcher at the top of Home changes the active one. The active profile is what the car screen, Shortcut and widget use.
- **Debug and measurements**: fake connect, export `metrics.jsonl`, and buttons to add simulated drives. Tap the usual-stop button 3 times to make "Clinic" a usual stop (spoken in the briefing on the same weekday and within an hour of the same time). Tap the streak button for consecutive days.

## 2. Create the "CarPlay connects" Shortcut

In the app: Home, **Set up "CarPlay connects" shortcut**. It lists the steps and has an **Open Shortcuts** button (`shortcuts://`). Tick each step as you go; progress is saved in your profile.

The steps:
1. Shortcuts app, Automation tab, New Automation.
2. Choose **CarPlay**, trigger **Connects**, choose **Run Immediately**.
3. Add action: **My Drive, Play welcome**.
4. Save.

Then connect to the car (or the CarPlay simulator, see below). Expected: the welcome clip, your name, the briefing, then your music.

## 3. What the Simulator can and cannot test

| Item | Simulator | Real phone/car |
|------|-----------|----------------|
| Build, unit tests, phone UI | yes (also in CI) | yes |
| CarPlay screen (tabs Today / Library / Drives, now playing) | yes: I/O, External Displays, CarPlay | needs Apple's CarPlay entitlement |
| Sim-only CarPlay entitlement | yes (`MyDrive-Sim.entitlements`) | not allowed on device |
| Audio plays | yes (Mac speakers) | yes |
| Shortcut "When CarPlay connects" | no (automation triggers need a real CarPlay connection) | yes |
| Microphone recording | limited (uses Mac mic) | yes |
| Widget on the Home Screen | yes | yes |
| Widget on the CarPlay Dashboard | yes, see below | yes, iOS 26 or later |
| Ducking/handing back to Spotify or Apple Music | no | yes |

### CarPlay on the Simulator (task I2)
1. Run the **MyDrive** scheme on an iPhone simulator.
2. Simulator menu: **I/O, External Displays, CarPlay**. A CarPlay window opens.
3. Tap the My Drive icon. Expect three tabs: **Today**, **Library**, **Drives**. Tap Today, Welcome theme: the Now Playing screen appears and the clip plays.
4. In the app, Debug, add simulated drives, then reopen My Drive in CarPlay: the Drives tab shows streak, total distance, favourite route, usual stops and recent drives.
5. Record the result (works / does not) in the plan doc.

### Widget on the CarPlay Dashboard (task I6, manual Mac step)
1. In the simulator Home Screen: long-press, Add Widget, **My Drive**, small size. It should show your car and the next item, in the style you chose (car / minimal / stats). Change the style in Your ritual and look; the widget reloads.
2. Open the CarPlay window (steps above). On the CarPlay Dashboard, edit the widget area and add the My Drive widget (iOS 26 and later).
3. Lock the simulated phone (Device, Lock) and confirm the widget still shows data. It reads App Group files with file protection "until first unlock", so it must keep working.

The widget logic (what it shows, style, 15-minute refresh) is unit tested in CI (`WidgetSnapshotTests`), and CI also checks that the widget extension is embedded in the app. Only the visual check on the CarPlay Dashboard is manual.

## 4. Report back
Note in `docs/TASKS.md`: I2 result, whether the Shortcut fired in the car, whether the widget appeared on the Dashboard, any crash. `metrics.jsonl` (Debug, Export) has the timing of connect, welcome and briefing.
