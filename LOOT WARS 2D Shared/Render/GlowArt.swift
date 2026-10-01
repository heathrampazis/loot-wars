//
//  GlowArt.swift
//  Loot Wars
//
//  A soft pool of light, drawn once and tinted wherever it is used.
//
//  One texture rather than one per rarity: it is painted white and coloured at the
//  point of use with a blend factor, so adding a seventh rarity costs a line in a
//  palette rather than another image. It also means the six of them are the same
//  shape to the pixel, which matters more than it sounds - a gold glow that was
//  fractionally larger than a grey one would read as brighter for the wrong reason.
//
//  Drawn as a radial gradient with a real falloff rather than as a circle with a
//  soft edge. Under a small sprite on grass, a hard-edged disc reads as a plate the
//  item is standing on; a gradient reads as light.
//

import SpriteKit
import UIKit

enum GlowArt {

    static let pool: SKTexture = {
        let side: CGFloat = 128
        let centre = CGPoint(x: side / 2, y: side / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { context in
            let space = CGColorSpaceCreateDeviceRGB()

            // Bright and flat through the middle, then away quickly. A linear ramp
            // from the centre looks like a spotlight; holding the core and dropping
            // the outside looks like something is lit from within.
            let stops: [CGFloat] = [0, 0.35, 0.7, 1]
            let colours = [
                SKColor(white: 1, alpha: 0.95).cgColor,
                SKColor(white: 1, alpha: 0.7).cgColor,
                SKColor(white: 1, alpha: 0.22).cgColor,
                SKColor(white: 1, alpha: 0).cgColor
            ]

            guard let gradient = CGGradient(colorsSpace: space,
                                            colors: colours as CFArray,
                                            locations: stops) else { return }

            context.cgContext.drawRadialGradient(
                gradient,
                startCenter: centre, startRadius: 0,
                endCenter: centre, endRadius: side / 2,
                options: [])
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()

    // A pillar of light rising from a loot item: bright at the foot and in the middle,
    // fading out towards the top and the sides. Painted white and tinted where it is used.
    static let beam: SKTexture = {
        let size = CGSize(width: 64, height: 256)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let space = CGColorSpaceCreateDeviceRGB()

            let across = [SKColor(white: 1, alpha: 0).cgColor,
                          SKColor(white: 1, alpha: 0.55).cgColor,
                          SKColor(white: 1, alpha: 1).cgColor,
                          SKColor(white: 1, alpha: 0.55).cgColor,
                          SKColor(white: 1, alpha: 0).cgColor]
            guard let sides = CGGradient(colorsSpace: space, colors: across as CFArray,
                                         locations: [0, 0.3, 0.5, 0.7, 1]) else { return }
            cg.drawLinearGradient(sides, start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: size.width, y: 0), options: [])

            // Images run top-down, so the foot of the beam is the bottom edge.
            cg.setBlendMode(.destinationIn)
            let up = [SKColor(white: 1, alpha: 0).cgColor,
                      SKColor(white: 1, alpha: 0.75).cgColor,
                      SKColor(white: 1, alpha: 1).cgColor]
            guard let fade = CGGradient(colorsSpace: space, colors: up as CFArray,
                                        locations: [0, 0.45, 1]) else { return }
            cg.drawLinearGradient(fade, start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: 0, y: size.height), options: [])
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()
}
