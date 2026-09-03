//
//  ImpactArt.swift
//  Loot Wars
//
//  The star that comes off somebody who has just been hit.
//
//  Four points rather than five, and drawn with curved sides rather than straight
//  ones: a five-pointed star is a sheriff's badge or a rating, a four-pointed one
//  with concave edges is the shape everything from comics to cartoons uses for an
//  impact, and it stays legible down at eight or ten points across where a rounder
//  shape would just be a dot.
//
//  Two tones baked into the one drawing - a white core inside a yellow body - so a
//  single texture reads as bright without needing a glow, which SpriteKit would
//  charge a separate blend pass for.
//

import SpriteKit
import UIKit

enum ImpactArt {

    static let star: SKTexture = {
        let side: CGFloat = 64
        let centre = CGPoint(x: side / 2, y: side / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { context in
            let cg = context.cgContext

            /// Four points, with the sides pulled IN towards the middle - that
            /// pinch is what makes it a spark rather than a diamond.
            func star(reach: CGFloat, waist: CGFloat) -> CGPath {
                let path = CGMutablePath()
                let points = [CGPoint(x: 0, y: -reach), CGPoint(x: reach, y: 0),
                              CGPoint(x: 0, y: reach), CGPoint(x: -reach, y: 0)]

                path.move(to: CGPoint(x: centre.x + points[0].x, y: centre.y + points[0].y))
                for index in 0..<4 {
                    let next = points[(index + 1) % 4]
                    path.addQuadCurve(
                        to: CGPoint(x: centre.x + next.x, y: centre.y + next.y),
                        control: CGPoint(x: centre.x + (points[index].x + next.x) * waist,
                                         y: centre.y + (points[index].y + next.y) * waist))
                }
                path.closeSubpath()
                return path
            }

            cg.setFillColor(SKColor(red: 1, green: 0.84, blue: 0.29, alpha: 1).cgColor)
            cg.addPath(star(reach: side * 0.46, waist: 0.12))
            cg.fillPath()

            cg.setFillColor(SKColor.white.cgColor)
            cg.addPath(star(reach: side * 0.26, waist: 0.10))
            cg.fillPath()
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()
}
