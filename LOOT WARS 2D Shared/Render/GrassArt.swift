//
//  GrassArt.swift
//  Loot Wars
//
//  The grass, drawn in code, in the map's own colours.
//
//  One shape: a soft, round-tipped tuft, left behind a footfall - a bit of ground
//  that has been stepped on and is settling back.
//
//  Built out of the two floor greens and the terrain green, which is what the map
//  itself is painted with, so it does not read as a sprite sitting ON the ground -
//  it reads as the ground doing something.
//
//  A second, spikier drawing rode at the actor's ankles for one commit and looked
//  wrong - too much like a costume and not enough like the map. The `spiky` branch
//  below is what drew it, kept because the shape was fine and only the placement
//  was the mistake; the version that used it is at cbcac97.
//

import SpriteKit
import UIKit

enum GrassArt {

    /// Three splayed blades with rounded tips. Left behind a footfall.
    static let tuft: SKTexture = make(size: CGSize(width: 48, height: 34), spiky: false,
                                      blades: [(-11, -9, 20, 4.5),
                                               (0, 1, 26, 5.0),
                                               (11, 10, 19, 4.5)])

    private static func make(size: CGSize,
                             spiky: Bool,
                             blades: [(dx: CGFloat, lean: CGFloat,
                                       height: CGFloat, width: CGFloat)]) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext

            for blade in blades {
                let root = CGPoint(x: size.width / 2 + blade.dx, y: size.height - 2)
                let tip = CGPoint(x: root.x + blade.lean, y: root.y - blade.height)

                if spiky {
                    // Drawn as a filled triangle rather than a stroked line, so it
                    // comes to an actual point. A round cap at this size reads as a
                    // blob of paint.
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: root.x - blade.width / 2, y: root.y))
                    path.addQuadCurve(to: tip,
                                      control: CGPoint(x: root.x - blade.width / 4,
                                                       y: root.y - blade.height * 0.55))
                    path.addQuadCurve(to: CGPoint(x: root.x + blade.width / 2, y: root.y),
                                      control: CGPoint(x: root.x + blade.width / 2,
                                                       y: root.y - blade.height * 0.45))
                    path.closeSubpath()

                    cg.setFillColor(RenderPalette.terrain.withAlphaComponent(0.85).cgColor)
                    cg.addPath(path)
                    cg.fillPath()

                    // A lighter core, inset, so a blade has a lit side like the
                    // floor tiles do.
                    cg.saveGState()
                    cg.translateBy(x: root.x, y: root.y)
                    cg.scaleBy(x: 0.5, y: 0.78)
                    cg.translateBy(x: -root.x, y: -root.y)
                    cg.setFillColor(RenderPalette.floorDark.withAlphaComponent(0.95).cgColor)
                    cg.addPath(path)
                    cg.fillPath()
                    cg.restoreGState()
                } else {
                    let path = CGMutablePath()
                    path.move(to: root)
                    path.addQuadCurve(to: tip,
                                      control: CGPoint(x: root.x + blade.lean * 0.2,
                                                       y: root.y - blade.height * 0.6))

                    cg.setLineCap(.round)
                    cg.setStrokeColor(RenderPalette.terrain.withAlphaComponent(0.75).cgColor)
                    cg.setLineWidth(blade.width)
                    cg.addPath(path)
                    cg.strokePath()

                    cg.setStrokeColor(RenderPalette.floorDark.withAlphaComponent(0.9).cgColor)
                    cg.setLineWidth(blade.width * 0.45)
                    cg.addPath(path)
                    cg.strokePath()
                }
            }
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }
}
