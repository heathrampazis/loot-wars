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

    /// The menu's two secondary buttons. Drawn here with the rest rather than
    /// exported, for the reason this file exists: a symbol made of arcs and
    /// rectangles is a dozen lines and never needs a retina export.
    static let info: SKTexture = makeInfo()
    static let gear: SKTexture = makeGear()

    /// A plain house, for the way back to the title screen.
    static let home: SKTexture = makeHome()

    /// A head and shoulders - the profile corner on the title screen.
    static let profile: SKTexture = makeProfile()

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

    /// A lowercase i in a ring.
    ///
    /// Built out of a dot and a bar rather than set as TEXT, which is the whole
    /// reason it is in here. A letter drawn by a font is a different weight, a
    /// different width and a different optical centre in every font the device
    /// might fall back to, and this has to sit inside a circle next to a gear and
    /// look like its sibling.
    private static func makeInfo() -> SKTexture {
        let side: CGFloat = 128
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setFill()

            let width = side * 0.13
            let x = (side - width) / 2

            // The dot, then the stem. The gap between them is a shade wider than
            // the dot is tall, which is what keeps an i reading as an i at the size
            // a button glyph is actually seen at.
            UIBezierPath(ovalIn: CGRect(x: x, y: side * 0.20,
                                        width: width, height: width)).fill()

            UIBezierPath(roundedRect: CGRect(x: x, y: side * 0.40,
                                             width: width, height: side * 0.40),
                         cornerRadius: width / 2).fill()
        }

        return SKTexture(image: image)
    }

    /// A gear: a ring with eight teeth and a hole.
    ///
    /// Teeth as rotated rectangles around the rim rather than as one traced
    /// outline, because the traced version is a page of trigonometry to get wrong
    /// and this is eight rectangles in a loop. At the size a button draws it the
    /// two are indistinguishable.
    /// A roof and a body with a door cut out of it, in one white shape.
    private static func makeHome() -> SKTexture {
        let side: CGFloat = 128
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setFill()

            // Roof. Images run top-down, so the peak is the smaller y.
            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: side * 0.5, y: side * 0.14))
            roof.addLine(to: CGPoint(x: side * 0.90, y: side * 0.50))
            roof.addLine(to: CGPoint(x: side * 0.10, y: side * 0.50))
            roof.close()
            roof.fill()

            // Body, with the door left out of it.
            let body = UIBezierPath()
            body.move(to: CGPoint(x: side * 0.22, y: side * 0.46))
            body.addLine(to: CGPoint(x: side * 0.78, y: side * 0.46))
            body.addLine(to: CGPoint(x: side * 0.78, y: side * 0.86))
            body.addLine(to: CGPoint(x: side * 0.59, y: side * 0.86))
            body.addLine(to: CGPoint(x: side * 0.59, y: side * 0.64))
            body.addLine(to: CGPoint(x: side * 0.41, y: side * 0.64))
            body.addLine(to: CGPoint(x: side * 0.41, y: side * 0.86))
            body.addLine(to: CGPoint(x: side * 0.22, y: side * 0.86))
            body.close()
            body.fill()
        }

        return SKTexture(image: image)
    }

    /// A round head over rounded shoulders, in one white shape.
    private static func makeProfile() -> SKTexture {
        let side: CGFloat = 128
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in
            SKColor.white.setFill()

            // Head. Images run top-down.
            UIBezierPath(ovalIn: CGRect(x: side * 0.33, y: side * 0.10,
                                        width: side * 0.34, height: side * 0.34)).fill()

            // Shoulders: a dome cut flat along the bottom.
            let body = UIBezierPath()
            body.move(to: CGPoint(x: side * 0.14, y: side * 0.88))
            body.addCurve(to: CGPoint(x: side * 0.86, y: side * 0.88),
                          controlPoint1: CGPoint(x: side * 0.14, y: side * 0.46),
                          controlPoint2: CGPoint(x: side * 0.86, y: side * 0.46))
            body.close()
            body.fill()
        }

        return SKTexture(image: image)
    }

    private static func makeGear() -> SKTexture {
        let side: CGFloat = 128
        let centre = CGPoint(x: side / 2, y: side / 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { context in
            SKColor.white.setFill()

            let toothWidth = side * 0.15
            let toothLength = side * 0.17

            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4

                context.cgContext.saveGState()
                context.cgContext.translateBy(x: centre.x, y: centre.y)
                context.cgContext.rotate(by: angle)

                UIBezierPath(roundedRect: CGRect(x: -toothWidth / 2,
                                                 y: -side * 0.40,
                                                 width: toothWidth,
                                                 height: toothLength),
                             cornerRadius: side * 0.025).fill()

                context.cgContext.restoreGState()
            }

            // The body, and then the hole punched out of it. Punched rather than
            // drawn in the background colour, because this sits on a button whose
            // fill is not known here.
            UIBezierPath(ovalIn: CGRect(x: centre.x - side * 0.30,
                                        y: centre.y - side * 0.30,
                                        width: side * 0.60,
                                        height: side * 0.60)).fill()

            context.cgContext.setBlendMode(.clear)
            UIBezierPath(ovalIn: CGRect(x: centre.x - side * 0.125,
                                        y: centre.y - side * 0.125,
                                        width: side * 0.25,
                                        height: side * 0.25)).fill()
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
