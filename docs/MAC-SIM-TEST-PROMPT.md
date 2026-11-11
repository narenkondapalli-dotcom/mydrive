# Run the CarPlay Simulator test with Claude Code on the MacBook

The CarPlay Simulator only exists on a Mac, so the Windows PC cannot run it. Claude Code on the MacBook can: it can build the app, drive the Simulator with computer use, read the logs and write the results.

## One-time setup on the Mac
1. Install Claude Code on the Mac (or open the Claude desktop app, Code tab) and sign in.
2. In Terminal: `cd ~/mydrive && git pull` (the clone you already made).
3. Start Claude Code in that folder: `cd ~/mydrive && claude`.
4. When it asks, allow computer use for **Simulator** and **Xcode** (and Terminal if asked). Nothing else.

## Paste this prompt into Claude Code on the Mac

> Read CLAUDE.md, docs/SPEC.md, docs/IOS-TESTING.md and docs/IOS-SIM-REPORT.md if it exists. Then test My Drive in the iOS Simulator with CarPlay, end to end, and write the results.
>
> 1. `cd ios && xcodegen`, then build the MyDrive scheme for an iPhone simulator with `xcodebuild -project MyDrive.xcodeproj -scheme MyDrive -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath ~/mydrive-derived build`. If that simulator name does not exist use `xcrun simctl list devices available` and pick an iPhone. Fix compile errors only if the CI is green on the same commit would have failed too; otherwise report them.
> 2. Boot the simulator, install and launch `com.biolynk.mydrive` with `xcrun simctl`. Start a log capture in a second terminal tab: `xcrun simctl spawn booted log stream --level debug --predicate 'subsystem == "com.biolynk.mydrive"' > ~/mydrive-sim.log`.
> 3. Use computer use on the Simulator window. Finish onboarding (Jeep, Meridian, Pearl White, name Mohit, nickname Meri). Screenshot every screen.
> 4. In the Simulator menu choose I/O, External Displays, CarPlay. Open My Drive in the CarPlay window. Check and screenshot: three tabs Today, Library, Drives; Today shows the welcome; the Now Playing screen shows the car artwork and greeting; the clip then the briefing play as ONE continuous item with no long gap; Library lists the three themes and each plays; Drives shows streak, distance, favourite route and usual stops after you add simulated drives in the phone app Debug screen (usual-stop button three times, streak button once); the car screen has no settings, no recording and never tells the driver to pick up the phone; backing out and reopening works; changing the active profile on the phone updates the car screen.
> 5. Run the Shortcut path by hand from the Shortcuts app (Play welcome, My Drive) and confirm the same continuous sequence.
> 6. Put the widget on the Simulator Home Screen in all three styles and, if available on this iOS, on the CarPlay Dashboard. Lock the device and check it still shows data.
> 7. Collect: the metrics and diagnostics files (`xcrun simctl get_app_container booted com.biolynk.mydrive groups` then copy `metrics.jsonl` and any `diagnostics.jsonl`), `~/mydrive-sim.log`, and all screenshots. Put everything in `~/mydrive-sim-results/`.
> 8. Write docs/CARPLAY-SIM-RESULTS.md: a table of every check with WORKS / BROKEN / PARTIAL and the evidence (screenshot name, log line), the measured gap between clip end and speech start, the voice the app chose, and anything you could not test. Be honest: say when something is judged only from a screenshot.
> 9. Do not push to GitHub. Show me the summary here.

## Then
Zip `~/mydrive-sim-results/` and `docs/CARPLAY-SIM-RESULTS.md` and send them to the PC session (AirDrop, Drive or `git add` on a branch). The PC session reads them and fixes what is broken, and CI checks each fix.
