//
//  Glyphs.swift
//  Loot Wars
//
//  Simple UI symbols drawn in code, so there are no art assets to manage yet.
//  Each one is built once and reused.
//

import SpriteKit
import UIKit

enum Glyphs {

    static let crosshair: SKTexture = makeCrosshair()

    private static func makeCrosshair() -> SKTexture {
        let side: CGFloat = 128
        let centre = CGPoint(x: side / 2, y: side / 2)
        let lineWidth: CGFloat = 9

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setStroke()
            SKColor.white.setFill()

            let ring = UIBezierPath(arcCenter: centre,
                                    radius: 38,
                                    startAngle: 0,
                                    endAngle: .pi * 2,
                                    clockwise: true)
            ring.lineWidth = lineWidth
            ring.stroke()

            // Four ticks reaching out through the ring.
            for (dx, dy) in [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)] {
                let tick = UIBezierPath()
                tick.move(to: CGPoint(x: centre.x + CGFloat(dx) * 24,
                                      y: centre.y + CGFloat(dy) * 24))
                tick.addLine(to: CGPoint(x: centre.x + CGFloat(dx) * 56,
                                         y: centre.y + CGFloat(dy) * 56))
                tick.lineWidth = lineWidth
                tick.lineCapStyle = .round
                tick.stroke()
            }

            UIBezierPath(arcCenter: centre,
                         radius: 7,
                         startAngle: 0,
                         endAngle: .pi * 2,
                         clockwise: true).fill()
        }

        return SKTexture(image: image)
    }
}
