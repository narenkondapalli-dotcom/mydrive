import UIKit

/// Draws the 1024 px square now-playing artwork: scene (time of day + season) behind the car picture, plus the greeting.
/// This square is the part of the CarPlay screen we fully own.
enum ArtworkComposer {
    static let gold = UIColor(hex: Accent.fallbackHex)

    static func compose(profile: CarProfile, line1: String, line2: String, side: CGFloat = 1024,
                        scene: ArtworkScene = .pick(), accentHex: String? = nil) -> UIImage {
        let size = CGSize(width: side, height: side)
        let accent = UIColor(hex: accentHex ?? profile.accentHex)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            let cg = ctx.cgContext
            // Scene: time-of-day gradient. The car picture is lightened over it so its dark studio backdrop shows the scene.
            let sky = [UIColor(hex: scene.topHex).cgColor, UIColor(hex: scene.bottomHex).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sky, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: side), options: [])
            }

            if let url = SharedStore.carImageURL(for: profile), let car = UIImage(contentsOfFile: url.path) {
                // Fill height, anchor the car to the right.
                let scale = side / car.size.height
                let w = car.size.width * scale
                car.draw(in: CGRect(x: side - w + side * 0.18, y: 0, width: w, height: side), blendMode: .lighten, alpha: 1)
            }
            // Season tint.
            UIColor(hex: scene.tintHex).withAlphaComponent(0.14).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            // Left fade so the text stays readable.
            let colors = [UIColor(white: 0.02, alpha: 1).cgColor, UIColor(white: 0.02, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(g, start: .zero, end: CGPoint(x: side * 0.6, y: 0), options: [])
            }

            let serif = UIFont(name: "CormorantGaramond-Italic", size: side * 0.07) ?? UIFont.italicSystemFont(ofSize: side * 0.06)
            let big = UIFont.systemFont(ofSize: side * 0.13, weight: .ultraLight)
            (line1 as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.08),
                                     withAttributes: [.font: serif, .foregroundColor: UIColor(white: 0.92, alpha: 1)])
            (line2 as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.16),
                                     withAttributes: [.font: big, .foregroundColor: UIColor.white])
            accent.setFill()
            cg.fill(CGRect(x: side * 0.07, y: side * 0.855, width: side * 0.08, height: max(2, side * 0.004)))
            let tag = UIFont.systemFont(ofSize: side * 0.026, weight: .medium)
            ("MY DRIVE" as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.88),
                                          withAttributes: [.font: tag, .foregroundColor: accent, .kern: side * 0.006])
        }
    }
}
