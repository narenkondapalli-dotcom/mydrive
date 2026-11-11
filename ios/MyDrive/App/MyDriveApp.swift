import SwiftUI

@main
struct MyDriveApp: App {
    @StateObject private var model = AppModel()
    @State private var addingCar = false

    init() { Metrics.shared.log(.appLaunched, ["surface": "phone"]) }

    var body: some Scene {
        WindowGroup {
            Group {
                if model.active == nil || addingCar {
                    CarOnboardingView(onCancel: model.active == nil ? nil : { addingCar = false }) { saved in
                        model.save(saved)
                        addingCar = false
                    }
                } else {
                    HomeView(model: model, onAddCar: { addingCar = true })
                }
            }
            .preferredColorScheme(.dark)
            .tint(model.accent)
        }
    }
}

enum Theme {
    static let gold = Color(hex: Accent.fallbackHex)
    static let bg = Color(red: 0.03, green: 0.035, blue: 0.045)
    static func serif(_ size: CGFloat) -> Font { .custom("CormorantGaramond-Medium", size: size, relativeTo: .largeTitle) }
}

struct HomeView: View {
    @ObservedObject var model: AppModel
    var onAddCar: () -> Void
    @StateObject private var audio = DriveAudioEngine.shared

    var body: some View {
        if let profile = model.active {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        profileSwitcher(active: profile)
                        CarHero(profile: profile)
                        Text(greeting(for: profile)).font(Theme.serif(28)).italic().foregroundStyle(.secondary)
                        Text(profile.ownerName.isEmpty ? "Driver" : profile.ownerName).font(.system(size: 54, weight: .ultraLight))
                        Button {
                            Metrics.shared.markConnect()
                            audio.playWelcomeSequence()
                        } label: {
                            Label(audio.stage == .idle ? "Test welcome" : "Playing \(audio.stage.rawValue)…", systemImage: "play.fill")
                                .frame(maxWidth: .infinity).padding()
                                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.black)
                        }
                        NavigationLink("Your ritual and look") { RitualSettingsView(model: model) }
                        NavigationLink("Set up “CarPlay connects” shortcut") { ShortcutHelpView(model: model) }
                        NavigationLink("Debug & measurements") { DebugView(model: model) }
                        Button("Add another car", action: onAddCar)
                        if model.book.profiles.count > 1 {
                            Button("Remove this car", role: .destructive) { model.removeActive() }
                        }
                    }.padding(22)
                }
                .background(Theme.bg.ignoresSafeArea())
            }
        }
    }

    private func greeting(for profile: CarProfile) -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        let book = GreetingBook.load() ?? .fallback
        let line = book.pick(hour: hour, name: "", index: profile.greetingIndex,
                             seed: Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0)
        return line.components(separatedBy: ".").first ?? line
    }

    /// Profile switcher (several cars / drivers). The active one is used in the car and on the widget.
    @ViewBuilder
    private func profileSwitcher(active: CarProfile) -> some View {
        if model.book.profiles.count > 1 {
            Menu {
                ForEach(model.book.profiles, id: \.id) { p in
                    Button {
                        model.switchTo(p.id)
                    } label: {
                        Label("\(p.displayName) · \(p.ownerName.isEmpty ? "Driver" : p.ownerName)",
                              systemImage: p.id == active.id ? "checkmark" : "car")
                    }
                }
            } label: {
                Label("\(active.displayName) · switch", systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
            }
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
