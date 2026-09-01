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

    /// The action button borrows the lootbox art when there is one in reach.
    static let lootbox: SKTexture = SKTexture(imageNamed: "LootboxRed")

    static let chest: SKTexture = SKTexture(imageNamed: "Chest")

    static let shoppingBag: SKTexture = makeShoppingBag()

    static let clock: SKTexture = makeClock()

    /// The shop's bag, traced off the reference: a body that flares outwards
    /// towards the bottom, and a handle looping up out of the top edge.
    ///
    /// Proportions are fractions of the tile rather than round numbers, because
    /// they were measured off the drawing - the top edge sits at 0.31 of the way
    /// down, the bottom at 0.79, and the stroke is 0.047 of the width.
    private static func makeShoppingBag() -> SKTexture {
        let side: CGFloat = 128
        let stroke = side * 0.047

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setStroke()

            let topY = side * 0.313
            let bottomY = side * 0.785

            // Wider at the bottom than the top, which is what stops it reading as
            // a plain box.
            let body = UIBezierPath()
            body.move(to: CGPoint(x: side * 0.274, y: topY))
            body.addLine(to: CGPoint(x: side * 0.220, y: bottomY))
            body.addLine(to: CGPoint(x: side * 0.767, y: bottomY))
            body.addLine(to: CGPoint(x: side * 0.731, y: topY))
            body.close()
            body.lineWidth = stroke
            body.lineJoinStyle = .round
            body.stroke()

            // The handle: two stubs reaching down INSIDE the bag, joined over the
            // top by a half circle.
            let handleY = side * 0.297
            let left = side * 0.375
            let right = side * 0.594
            let stubBottom = side * 0.403

            let handle = UIBezierPath()
            handle.move(to: CGPoint(x: left, y: stubBottom))
            handle.addLine(to: CGPoint(x: left, y: handleY))
            handle.addArc(withCenter: CGPoint(x: (left + right) / 2, y: handleY),
                          radius: (right - left) / 2,
                          startAngle: .pi, endAngle: 0, clockwise: true)
            handle.addLine(to: CGPoint(x: right, y: stubBottom))
            handle.lineWidth = stroke
            handle.lineCapStyle = .round
            handle.stroke()
        }

        return SKTexture(image: image)
    }

    /// A clock face for the match timer. A ring and two hands, which is all that
    /// survives being drawn at eighteen points across.
    private static func makeClock() -> SKTexture {
        let side: CGFloat = 128
        let centre = CGPoint(x: side / 2, y: side / 2)
        let stroke = side * 0.075

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setStroke()

            let ring = UIBezierPath(arcCenter: centre, radius: side * 0.36,
                                    startAngle: 0, endAngle: .pi * 2, clockwise: true)
            ring.lineWidth = stroke
            ring.stroke()

            // Pointing at twelve and four - far enough apart to read as two hands
            // rather than one thick one.
            for (dx, dy, length) in [(0.0, -1.0, 0.23), (0.62, 0.42, 0.17)] {
                let hand = UIBezierPath()
                hand.move(to: centre)
                hand.addLine(to: CGPoint(x: centre.x + CGFloat(dx) * side * CGFloat(length),
                                         y: centre.y + CGFloat(dy) * side * CGFloat(length)))
                hand.lineWidth = stroke
                hand.lineCapStyle = .round
                hand.stroke()
            }
        }

        return SKTexture(image: image)
    }

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
