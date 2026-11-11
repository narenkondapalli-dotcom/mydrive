import SwiftUI

/// Guided steps for "When CarPlay connects → Play welcome (My Drive)". Phone only. Completion is saved in the profile.
struct ShortcutHelpView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openURL) private var openURL

    private var setup: ShortcutSetup { ShortcutSetup(completed: model.active?.shortcutSteps ?? []) }

    var body: some View {
        List {
            Section {
                ForEach(Array(ShortcutSetup.steps.enumerated()), id: \.offset) { index, text in
                    Button { toggle(index) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: setup.completed.contains(index) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(Color.accentColor)
                            Text("\(index + 1). \(text)").foregroundStyle(.primary).multilineTextAlignment(.leading)
                        }
                    }
                    .accessibilityIdentifier("shortcut-step-\(index)")
                    .accessibilityValue(setup.completed.contains(index) ? "done" : "todo")
                }
            } footer: {
                Text(setup.isComplete ? "All set. Your car will welcome you when it connects."
                                      : "Tick each step as you finish it.")
            }
            Section {
                Button { openURL(ShortcutSetup.shortcutsURL) } label: {
                    Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                }
                .accessibilityIdentifier("open-shortcuts")
            }
        }
        .navigationTitle("One-time setup")
    }

    private func toggle(_ index: Int) {
        var s = setup
        let ticked = s.toggle(index)
        model.updateActive { $0.shortcutSteps = s.completed }
        if ticked { Metrics.shared.log(.onboardingStep, ["flow": "shortcut", "step": "\(index + 1)"]) }
        if ticked && s.isComplete { Metrics.shared.log(.onboardingDone, ["flow": "shortcut"]) }
    }
}
