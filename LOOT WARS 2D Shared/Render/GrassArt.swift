// Footstep grass tufts, drawn in code in the colours of each biome's ground.

import SpriteKit
import UIKit

enum GrassArt {
    // Blades are (dx, lean, height, width) in texture points.
    private static let blades: [(dx: CGFloat, lean: CGFloat, height: CGFloat, width: CGFloat)] = [
        (-11, -9, 20, 4.5),
        (0, 1, 26, 5.0),
        (11, 10, 19, 4.5)
    ]

    private static var cache: [Biome: SKTexture] = [:]

    // Three splayed blades left behind a footfall, in the colours of the ground underfoot.
    static func tuft(for biome: Biome) -> SKTexture {
        if let cached = cache[biome] { return cached }
        let tones = RenderPalette.tones(for: biome)
        let made = make(size: CGSize(width: 48, height: 34),
                        outer: tones.tuftOuter, inner: tones.tuftInner)
        cache[biome] = made
        return made
    }

    private static func make(size: CGSize, outer: SKColor, inner: SKColor) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext

            for blade in GrassArt.blades {
                let root = CGPoint(x: size.width / 2 + blade.dx, y: size.height - 2)
                let tip = CGPoint(x: root.x + blade.lean, y: root.y - blade.height)

                let path = CGMutablePath()
                path.move(to: root)
                path.addQuadCurve(to: tip,
                                  control: CGPoint(x: root.x + blade.lean * 0.2,
                                                   y: root.y - blade.height * 0.6))

                cg.setLineCap(.round)
                cg.setStrokeColor(outer.withAlphaComponent(0.75).cgColor)
                cg.setLineWidth(blade.width)
                cg.addPath(path)
                cg.strokePath()

                cg.setStrokeColor(inner.withAlphaComponent(0.9).cgColor)
                cg.setLineWidth(blade.width * 0.45)
                cg.addPath(path)
                cg.strokePath()
            }
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }
}
