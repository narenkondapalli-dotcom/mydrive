import SwiftUI

/// Locked design (11 Nov 2026): 1) which car  2) which colour  3) meet your car.
struct CarOnboardingView: View {
    var onCancel: (() -> Void)?
    var onDone: (CarProfile) -> Void

    @State private var step = 0
    @State private var query = ""
    @State private var model: CarCatalog.Model?
    @State private var colour: CarCatalog.Colour?
    @State private var nickname = ""
    @State private var ownerName = ""
    private let catalog = CarCatalog.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("STEP \(step + 1) OF 3").font(.caption).kerning(3).foregroundStyle(Theme.gold)
                Spacer()
                if let onCancel { Button("Cancel", action: onCancel).font(.footnote) }
            }
            Group {
                switch step {
                case 0: whichCar
                case 1: whichColour
                default: meetCar
                }
            }
            Spacer()
            Button(step == 2 ? "Looks right" : "Next", action: next)
                .font(.headline).frame(maxWidth: .infinity).padding()
                .background(Theme.gold, in: RoundedRectangle(cornerRadius: 16)).foregroundStyle(.black)
                .disabled(step == 0 && model == nil)
                .accessibilityIdentifier("onboarding-next")
        }
        .padding(22)
        .background(Theme.bg.ignoresSafeArea())
        .onChange(of: step) { _, s in Metrics.shared.log(.onboardingStep, ["step": "\(s + 1)"]) }
    }

    // MARK: Step 1
    private var whichCar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Which car do you drive?").font(Theme.serif(32)).padding(.top, 8)
            TextField("Search make or model", text: $query)
                .accessibilityIdentifier("car-search")
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            List(catalog.search(query)) { m in
                Button { model = m; colour = m.colours.first } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(m.make) \(m.model)")
                            Text("\(m.note) · \(m.colours.count) colours").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model == m { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.gold) }
                    }
                }
                .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
        }
    }

    // MARK: Step 2 — the manufacturer's own colour list for this model
    private var whichColour: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What colour is it?").font(Theme.serif(32)).padding(.top, 8)
            Text("\(model?.make ?? "") \(model?.model ?? "") · official colours").font(.footnote).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    ForEach(model?.colours ?? []) { c in
                        VStack(spacing: 6) {
                            ZStack(alignment: .top) {
                                Circle().fill(Color(hex: c.hex))
                                if c.roof != "body" {
                                    Rectangle().fill(Color(white: 0.07)).frame(height: 13)
                                }
                            }
                            .frame(width: 46, height: 46).clipShape(Circle())
                            .overlay(Circle().stroke(colour == c ? Theme.gold : .clear, lineWidth: 2).padding(-4))
                            Text(c.name).font(.caption2).multilineTextAlignment(.center).lineLimit(2)
                                .foregroundStyle(colour == c ? Theme.gold : .secondary)
                        }
                        .onTapGesture { colour = c }
                    }
                }
            }
            Text(colour?.label ?? "").font(.footnote).foregroundStyle(Theme.gold)
        }
    }

    // MARK: Step 3
    private var meetCar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Meet your \(model?.model ?? "car")").font(Theme.serif(32)).padding(.top, 8)
            if let img = CarCatalog.renderImage(model: model, colour: colour) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 200).clipped()
            }
            Text("\(colour?.label ?? "") · \(model?.note ?? "")")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("Your name (for the greeting)", text: $ownerName)
                .accessibilityIdentifier("owner-name")
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            TextField("Call it", text: $nickname, prompt: Text(model?.model ?? "Nickname"))
                .accessibilityIdentifier("nickname")
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            Button("Not quite right? Adjust") { step = 1 }.font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("adjust")
        }
    }

    private func next() {
        if step < 2 { step += 1; return }
        guard let model, let colour else { return }
        var profile = CarProfile(make: model.make, model: model.model, colour: colour.name, roof: colour.roof, wheels: "",
                                 nickname: nickname, renderId: nil, ownerName: ownerName)
        if let img = CarCatalog.renderImage(model: model, colour: colour), let data = img.jpegData(compressionQuality: 0.9) {
            let id = "car-render-\(profile.id).jpg"
            try? SharedStore.write(data, to: SharedStore.containerURL.appendingPathComponent(id))
            profile.renderId = id
        }
        try? SharedStore.saveProfile(profile)
        Metrics.shared.log(.onboardingDone, ["model": "\(model.make) \(model.model)", "colour": colour.id])
        onDone(profile)
    }
}

/// Car list + manufacturer colours. Source of truth: shared/car-catalog.json (bundled as a resource).
struct CarCatalog {
    struct Colour: Codable, Identifiable, Hashable {
        let id: String, name: String, hex: String, roof: String, label: String
    }
    struct Model: Codable, Identifiable, Equatable {
        var id: String { slug }
        let make: String, model: String, note: String, slug: String
        let colours: [Colour]
    }
    private struct File: Codable { let models: [Model] }

    let models: [Model]

    static func load() -> CarCatalog {
        guard let url = Bundle.main.url(forResource: "car-catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(File.self, from: data) else { return CarCatalog(models: []) }
        return CarCatalog(models: file.models)
    }

    func search(_ q: String) -> [Model] {
        let q = q.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return Array(models.prefix(12)) }
        return models.filter { "\($0.make) \($0.model)".lowercased().contains(q) }
    }

    /// Render `cars/<slug>--<colourId>.jpg` from the bundled library (generated by tools/carrender).
    static func renderImage(model: Model?, colour: Colour?) -> UIImage? {
        if let model, let colour,
           let url = Bundle.main.url(forResource: "\(model.slug)--\(colour.id)", withExtension: "jpg", subdirectory: "cars"),
           let img = UIImage(contentsOfFile: url.path) { return img }
        return UIImage(named: "car-placeholder")
    }
}
