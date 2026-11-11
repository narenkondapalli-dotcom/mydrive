import SwiftUI
import UIKit

/// Hex colour helpers shared by the app, the widget and the artwork drawing.
enum HexColor {
    static func rgb(_ hex: String) -> (r: Double, g: Double, b: Double) {
        var v: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&v)
        return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
    }
}

extension Color {
    init(hex: String) {
        let c = HexColor.rgb(hex)
        self.init(red: c.r, green: c.g, blue: c.b)
    }
}

extension UIColor {
    convenience init(hex: String) {
        let c = HexColor.rgb(hex)
        self.init(red: c.r, green: c.g, blue: c.b, alpha: 1)
    }
}
