import WidgetKit
import SwiftUI

/// CarPlay Dashboard / iPhone small widget: your car + what's next.
/// Reads App Group files written with completeUntilFirstUserAuthentication so it works while the phone is locked.
struct NextUpEntry: TimelineEntry {
    let date: Date
    let carName: String
    let title: String
    let detail: String
    let carImage: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NextUpEntry {
        NextUpEntry(date: .now, carName: "Meridian", title: "Clinic 9:30", detail: "32 min", carImage: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (NextUpEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NextUpEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
    private func entry() -> NextUpEntry {
        let p = SharedStore.loadProfile()
        let n = SharedStore.loadNextUp()
        let img = p.flatMap { SharedStore.carImageURL(for: $0) }.flatMap { UIImage(contentsOfFile: $0.path) }
        return NextUpEntry(date: .now, carName: p?.displayName ?? "My Drive",
                           title: n?.title ?? "Ready", detail: n?.detail ?? "Have a good drive", carImage: img)
    }
}

struct MyDriveWidgetView: View {
    let entry: NextUpEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let img = entry.carImage {
                Image(uiImage: img).resizable().scaledToFill().frame(height: 54).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            Text(entry.carName.uppercased()).font(.system(size: 10, weight: .semibold)).kerning(1.5)
                .foregroundStyle(Color(red: 0.83, green: 0.73, blue: 0.49))
            Text(entry.title).font(.headline).lineLimit(1)
            Text(entry.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .containerBackground(for: .widget) { Color.black }
        .widgetURL(URL(string: "mydrive://today"))
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
