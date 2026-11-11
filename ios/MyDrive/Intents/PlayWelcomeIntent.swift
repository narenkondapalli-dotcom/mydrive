import AppIntents

/// Run by the user's Shortcuts automation "When CarPlay connects".
/// AudioPlaybackIntent lets iOS start audio from the background.
struct PlayWelcomeIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play welcome"
    static var description = IntentDescription("Plays your My Drive welcome theme and briefing.")

    @MainActor
    func perform() async throws -> some IntentResult {
        Metrics.shared.markConnect()
        Metrics.shared.log(.appLaunched, ["surface": "shortcut"])
        DriveAudioEngine.shared.playWelcomeSequence()
        return .result()
    }
}

struct MyDriveShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: PlayWelcomeIntent(),
                    phrases: ["Play welcome in \(.applicationName)", "Start my drive in \(.applicationName)"],
                    shortTitle: "Play welcome",
                    systemImageName: "car.fill")
    }
}
