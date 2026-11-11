import WidgetKit
import SwiftUI

/// CarPlay Dashboard / iPhone small widget: your car and what's next.
/// Reads App Group files written with completeUntilFirstUserAuthentication so it works while the phone is locked.
/// What it shows is decided by WidgetSnapshot (shared with the app, unit tested).
struct NextUpEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let carImage: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NextUpEntry {
        NextUpEntry(date: .now,
                    snapshot: WidgetSnapshot(carName: "Meridian", title: "Clinic 9:30", detail: "32 min", style: .carLarge,
                                             accentHex: Accent.fallbackHex, streak: 3, totalKm: 120, carImagePath: nil),
                    carImage: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(WidgetSnapshot.refreshDate(after: .now))))
    }
    private func entry() -> NextUpEntry {
        let snap = WidgetSnapshot.load()
        return NextUpEntry(date: .now, snapshot: snap, carImage: snap.carImagePath.flatMap { UIImage(contentsOfFile: $0) })
    }
}

struct MyDriveWidgetView: View {
    let entry: NextUpEntry

    private var accent: Color { Color(hex: entry.snapshot.accentHex) }

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.black }
            .widgetURL(URL(string: "mydrive://today"))
    }

    @ViewBuilder
    private var content: some View {
        let s = entry.snapshot
        switch s.style {
        case .carLarge:
            VStack(alignment: .leading, spacing: 4) {
                if let img = entry.carImage {
                    Image(uiImage: img).resizable().scaledToFill().frame(height: 54).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                nameLabel(s)
                Text(s.title).font(.headline).lineLimit(1)
                Text(s.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        case .minimal:
            VStack(alignment: .leading, spacing: 4) {
                nameLabel(s)
                Spacer()
                Text(s.title).font(.title3.weight(.semibold)).lineLimit(2)
                Text(s.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .stats:
            VStack(alignment: .leading, spacing: 4) {
                nameLabel(s)
                Spacer()
                Text("\(s.streak)").font(.system(size: 38, weight: .ultraLight)).foregroundStyle(accent)
                Text(s.streak == 1 ? "day streak" : "day streak").font(.caption2).foregroundStyle(.secondary)
                Text("\(s.totalKm) km driven").font(.caption).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func nameLabel(_ s: WidgetSnapshot) -> some View {
        Text(s.carName.uppercased()).font(.system(size: 10, weight: .semibold)).kerning(1.5).foregroundStyle(accent)
    }
}

@main
struct MyDriveWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyDriveNextUp", provider: Provider()) { MyDriveWidgetView(entry: $0) }
            .configurationDisplayName("My Drive")
            .description("Your car and what's next.")
            .supportedFamilies([.systemSmall])
            .containerBackgroundRemovable(true)
    }
}
