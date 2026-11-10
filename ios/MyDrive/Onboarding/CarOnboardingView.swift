import SwiftUI

/// Locked design (11 Nov 2026): 1) which car  2) which colour  3) meet your car.
struct CarOnboardingView: View {
    var onDone: (CarProfile) -> Void

    @State private var step = 0
    @State private var query = ""
    @State private var model: CarCatalog.Model?
    @State private var colour = CarCatalog.colours[0]
    @State private var roof = "Black"
    @State private var wheels = "Black"
    @State private var nickname = ""
    @State private var ownerName = ""
    private let catalog = CarCatalog.load()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("STEP \(step + 1) OF 3").font(.caption).kerning(3).foregroundStyle(Theme.gold)
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
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            List(catalog.search(query)) { m in
                Button { model = m } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(m.make) \(m.model)")
                            Text(m.note).font(.caption).foregroundStyle(.secondary)
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

    // MARK: Step 2
    private var whichColour: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What colour is it?").font(Theme.serif(32)).padding(.top, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(CarCatalog.colours, id: \.name) { c in
                    VStack(spacing: 6) {
                        Circle().fill(c.color).frame(width: 46, height: 46)
                            .overlay(Circle().stroke(colour.name == c.name ? Theme.gold : .clear, lineWidth: 2).padding(-4))
                        Text(c.name).font(.caption).foregroundStyle(colour.name == c.name ? Theme.gold : .secondary)
                    }
                    .onTapGesture { colour = c }
                }
            }
            Picker("Roof", selection: $roof) { Text("Body colour").tag("Body"); Text("Black").tag("Black") }
                .pickerStyle(.segmented)
            Picker("Wheels", selection: $wheels) { Text("Silver").tag("Silver"); Text("Black").tag("Black") }
                .pickerStyle(.segmented)
        }
    }

    // MARK: Step 3
    private var meetCar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Meet your \(model?.model ?? "car")").font(Theme.serif(32)).padding(.top, 8)
            if let img = CarCatalog.renderImage(model: model, colour: colour.name) {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 200).clipped()
            }
            Text("\(colour.name) · \(roof == "Black" ? "black roof" : "body-colour roof") · \(model?.note ?? "")")
                .font(.footnote).foregroundStyle(.secondary)
            TextField("Your name (for the greeting)", text: $ownerName)
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            TextField("Call it", text: $nickname, prompt: Text(model?.model ?? "Nickname"))
                .padding(12).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
            Button("Not quite right? Adjust") { step = 1 }.font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func next() {
        if step < 2 { step += 1; return }
        guard let model else { return }
        var profile = CarProfile(make: model.make, model: model.model, colour: colour.name, roof: roof, wheels: wheels,
                                 nickname: nickname, renderId: nil, ownerName: ownerName)
        if let img = CarCatalog.renderImage(model: model, colour: colour.name), let data = img.jpegData(compressionQuality: 0.9) {
            let id = "car-render.jpg"
            try? SharedStore.write(data, to: SharedStore.containerURL.appendingPathComponent(id))
            profile.renderId = id
        }
        try? SharedStore.saveProfile(profile)
        Metrics.shared.log(.onboardingDone, ["model": "\(model.make) \(model.model)", "colour": colour.name])
        onDone(profile)
    }
}

/// Car list + colours. Source of truth: shared/car-catalog.json (bundled as a resource).
struct CarCatalog {
    struct Model: Codable, Identifiable, Equatable {
        var id: String { make + "/" + model }
        let make: String, model: String, note: String, slug: String
    }
    struct Swatch { let name: String; let color: Color }
    private struct File: Codable { let models: [Model] }

    let models: [Model]

    static let colours: [Swatch] = [
        .init(name: "White", color: Color(white: 0.95)), .init(name: "Black", color: Color(white: 0.08)),
        .init(name: "Grey", color: Color(white: 0.43)), .init(name: "Silver", color: Color(white: 0.77)),
        .init(name: "Blue", color: Color(red: 0.12, green: 0.23, blue: 0.4)), .init(name: "Red", color: Color(red: 0.49, green: 0.09, blue: 0.13)),
        .init(name: "Green", color: Color(red: 0.18, green: 0.29, blue: 0.23)), .init(name: "Bronze", color: Color(red: 0.48, green: 0.35, blue: 0.23)),
    ]

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

    /// Bundled render named `<slug>-<colour>.jpg` (e.g. jeep-meridian-white.jpg). Library generated by tools/carrender.
    static func renderImage(model: Model?, colour: String) -> UIImage? {
        guard let model else { return nil }
        return UIImage(named: "\(model.slug)-\(colour.lowercased())") ?? UIImage(named: "car-placeholder")
    }
}
