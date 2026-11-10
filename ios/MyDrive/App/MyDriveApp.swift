import SwiftUI

@main
struct MyDriveApp: App {
    @State private var profile = SharedStore.loadProfile()

    init() { Metrics.shared.log(.appLaunched, ["surface": "phone"]) }

    var body: some Scene {
        WindowGroup {
            Group {
                if let profile {
                    HomeView(profile: profile, onReset: { self.profile = nil })
                } else {
                    CarOnboardingView { saved in self.profile = saved }
                }
            }
            .preferredColorScheme(.dark)
            .tint(Theme.gold)
        }
    }
}

enum Theme {
    static let gold = Color(red: 0.83, green: 0.73, blue: 0.49)
    static let bg = Color(red: 0.03, green: 0.035, blue: 0.045)
    static func serif(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Medium", size: size, relativeTo: .largeTitle) }
}

struct HomeView: View {
    let profile: CarProfile
    var onReset: () -> Void
    @StateObject private var audio = DriveAudioEngine.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    CarHero(profile: profile)
                    Text("Welcome back,").font(Theme.serif(28)).italic().foregroundStyle(.secondary)
                    Text(profile.ownerName.isEmpty ? "Driver" : profile.ownerName).font(.system(size: 54, weight: .ultraLight))
                    Button {
                        Metrics.shared.markConnect()
                        audio.playWelcomeSequence(briefing: BriefingBuilder.build())
                    } label: {
                        Label(audio.stage == .idle ? "Test welcome" : "Playing \(audio.stage.rawValue)…", systemImage: "play.fill")
                            .frame(maxWidth: .infinity).padding()
                            .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.black)
                    }
                    NavigationLink("Set up “CarPlay connects” shortcut") { ShortcutHelpView() }
                    NavigationLink("Debug & measurements") { DebugView() }
                    Button("Change car", role: .destructive, action: onReset)
                }.padding(22)
            }
            .background(Theme.bg.ignoresSafeArea())
        }
    }
}

struct CarHero: View {
    let profile: CarProfile
    var body: some View {
        Group {
            if let url = SharedStore.carImageURL(for: profile), let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let img = UIImage(named: "car-placeholder") {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "car.side.fill").resizable().scaledToFit().padding(40).foregroundStyle(.secondary)
            }
        }
        .frame(height: 200).frame(maxWidth: .infinity).clipped()
        .background(Color.black).clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

struct ShortcutHelpView: View {
    var body: some View {
        List {
            Text("1. Open the Shortcuts app → Automation → New Automation.")
            Text("2. Choose CarPlay → Connects → Run Immediately.")
            Text("3. Add action: My Drive → Play welcome.")
            Text("4. Done. Next time you connect, your car welcomes you.")
        }
        .navigationTitle("One-time setup")
    }
}
