import UIKit

/// Draws the 1024 px square now-playing artwork: car picture on the dark set + greeting.
/// This square is the part of the CarPlay screen we fully own.
enum ArtworkComposer {
    static let gold = UIColor(red: 0.83, green: 0.73, blue: 0.49, alpha: 1)

    static func compose(profile: CarProfile, line1: String, line2: String, side: CGFloat = 1024) -> UIImage {
        let size = CGSize(width: side, height: side)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor(red: 0.03, green: 0.03, blue: 0.04, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            if let url = SharedStore.carImageURL(for: profile), let car = UIImage(contentsOfFile: url.path) {
                // Fill height, anchor the car to the right.
                let scale = side / car.size.height
                let w = car.size.width * scale
                car.draw(in: CGRect(x: side - w + side * 0.18, y: 0, width: w, height: side))
            }
            // Left fade so the text stays readable.
            let colors = [UIColor(white: 0.02, alpha: 1).cgColor, UIColor(white: 0.02, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: side * 0.6, y: 0), options: [])
            }

            let serif = UIFont(name: "CormorantGaramond-Italic", size: side * 0.07) ?? UIFont.italicSystemFont(ofSize: side * 0.06)
            let big = UIFont.systemFont(ofSize: side * 0.13, weight: .ultraLight)
            (line1 as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.08),
                                     withAttributes: [.font: serif, .foregroundColor: UIColor(white: 0.92, alpha: 1)])
            (line2 as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.16),
                                     withAttributes: [.font: big, .foregroundColor: UIColor.white])
            let tag = UIFont.systemFont(ofSize: side * 0.026, weight: .medium)
            ("MY DRIVE" as NSString).draw(at: CGPoint(x: side * 0.07, y: side * 0.88),
                                          withAttributes: [.font: tag, .foregroundColor: gold, .kern: side * 0.006])
        }
    }
}
