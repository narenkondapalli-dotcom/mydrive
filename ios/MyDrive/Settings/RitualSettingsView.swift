import SwiftUI

/// Phone-only settings: greeting, briefing items, loved-one recording, ritual, widget style. Nothing here appears in CarPlay.
struct RitualSettingsView: View {
    @ObservedObject var model: AppModel
    @StateObject private var recorder = LovedOneRecorder()

    private var profile: CarProfile? { model.active }

    var body: some View {
        if let profile {
            Form {
                greetingSection(profile)
                briefingSection(profile)
                lovedOneSection(profile)
                ritualSection(profile)
                widgetSection(profile)
            }
            .navigationTitle("Your ritual")
        }
    }

    // MARK: Greeting

    private func greetingSection(_ p: CarProfile) -> some View {
        let hour = Calendar.current.component(.hour, from: Date())
        let lines = (GreetingBook.load() ?? .fallback).lines(forHour: hour)
        return Section("Greeting") {
            Picker("Greeting", selection: Binding(get: { p.greetingIndex }, set: { v in model.updateActive { $0.greetingIndex = v } })) {
                Text("Rotate automatically").tag(Int?.none)
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    Text(GreetingBook.fill(line, name: p.ownerName)).tag(Int?.some(i))
                }
            }
            .pickerStyle(.inline)
        }
    }

    // MARK: Briefing items

    private func briefingSection(_ p: CarProfile) -> some View {
        Section {
            ForEach(BriefingItem.allCases, id: \.self) { item in
                Toggle(item.title, isOn: Binding(
                    get: { p.briefingItems.contains(item) },
                    set: { on in model.updateActive { if on { $0.briefingItems.insert(item) } else { $0.briefingItems.remove(item) } } }))
            }
        } header: {
            Text("Briefing")
        } footer: {
            Text("Weather and traffic switch on once their data connections arrive.")
        }
    }

    // MARK: Loved one

    private func lovedOneSection(_ p: CarProfile) -> some View {
        Section {
            TextField("Who is it for? (for example Papa)", text: Binding(
                get: { p.lovedOne.label }, set: { v in model.updateActive { $0.lovedOne.label = v } }))
            if recorder.state == .recording {
                Button { recorder.stop() } label: {
                    Label(String(format: "Stop (%.0f of %.0f s)", recorder.elapsed, LovedOne.maxSeconds), systemImage: "stop.circle.fill")
                }
            } else {
                Button { record(p) } label: { Label(p.lovedOne.fileName == nil ? "Record" : "Record again", systemImage: "mic.fill") }
            }
            if recorder.state == .denied {
                Text("Microphone access is off. Allow it in Settings, then tap Record again.").font(.footnote).foregroundStyle(.secondary)
            }
            if recorder.state == .failed {
                Text("Recording did not work. Try again.").font(.footnote).foregroundStyle(.secondary)
            }
            if let url = LovedOneStore.url(for: p), FileManager.default.fileExists(atPath: url.path) {
                Button { recorder.preview(url: url) } label: { Label("Play clip", systemImage: "play.fill") }
                Toggle("Play after the chime", isOn: Binding(
                    get: { p.lovedOne.enabled }, set: { v in model.updateActive { $0.lovedOne.enabled = v } }))
                Button("Delete clip", role: .destructive) {
                    try? FileManager.default.removeItem(at: url)
                    model.updateActive { $0.lovedOne.fileName = nil; $0.lovedOne.enabled = false }
                }
            }
        } header: {
            Text("A voice you love")
        } footer: {
            Text("Up to 15 seconds, recorded here on your phone and kept only on it. Plays after the welcome chime.")
        }
    }

    private func record(_ p: CarProfile) {
        recorder.start(fileName: "loved-one-\(p.id).m4a") { file in
            model.updateActive { $0.lovedOne.fileName = file; $0.lovedOne.enabled = true }
        }
    }

    // MARK: Ritual

    private func ritualSection(_ p: CarProfile) -> some View {
        Section("Welcome ritual") {
            Picker("Sound", selection: Binding(get: { p.ritual.theme }, set: { v in model.updateActive { $0.ritual.theme = v } })) {
                ForEach(SoundTheme.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            Stepper("Pause before briefing: \(p.ritual.delaySeconds) s",
                    value: Binding(get: { p.ritual.delaySeconds }, set: { v in model.updateActive { $0.ritual.setDelay(v) } }),
                    in: Ritual.delayRange)
            Toggle("Spoken briefing", isOn: Binding(get: { p.ritual.voiceOn }, set: { v in model.updateActive { $0.ritual.voiceOn = v } }))
        }
    }

    // MARK: Widget

    private func widgetSection(_ p: CarProfile) -> some View {
        Section {
            Picker("Widget style", selection: Binding(get: { p.widgetStyle }, set: { v in model.updateActive { $0.widgetStyle = v } })) {
                ForEach(WidgetStyle.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Widget")
        } footer: {
            Text("The accent colour of this app follows your car's paint.")
        }
    }
}
