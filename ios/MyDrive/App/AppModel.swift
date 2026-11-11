import SwiftUI
import WidgetKit

/// Phone-side state: all profiles (car + driver), which one is active, and the drive log.
/// Every change is written to the App Group so the car screen, the Shortcut and the widget see it.
final class AppModel: ObservableObject {
    @Published private(set) var book: ProfileBook
    @Published private(set) var drives: [Drive]

    init() {
        book = SharedStore.loadBook()
        drives = DriveLogStore.load()
    }

    var active: CarProfile? { book.active }
    var accent: Color { Color(hex: active?.accentHex ?? Accent.fallbackHex) }

    func save(_ profile: CarProfile) {
        book.upsert(profile)
        persist()
    }

    func updateActive(_ change: (inout CarProfile) -> Void) {
        book.updateActive(change)
        persist()
    }

    func switchTo(_ id: String) {
        guard id != book.active?.id, book.switchTo(id) else { return }
        Metrics.shared.log(.profileSwitched, ["to": id])
        persist()
    }

    func removeActive() {
        guard book.profiles.count > 1, let id = book.active?.id else { return }
        book.remove(id)
        persist()
    }

    func addSimulatedDrive(_ kind: SimulatedDrive.Kind) {
        let existing = drives.filter { $0.endLabel == (kind == .usualStop ? "Clinic" : "Office") }.count
        drives = DriveLogStore.add(SimulatedDrive.make(kind: kind, index: existing, now: AppClock.now))
        WidgetCenter.shared.reloadAllTimelines()
    }

    func clearDrives() {
        DriveLogStore.clear()
        drives = []
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func persist() {
        try? SharedStore.saveBook(book)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
