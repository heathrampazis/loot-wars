//
//  BaseCompassNode.swift
//  Loot Wars
//
//  An arrow on the edge of the screen pointing home.
//
//  The same marker the supply drops use - a dark badge with an arrow on the side
//  facing the place - with a house in it instead of a crate. It rides round the
//  edge of the screen as you move and goes away while your base is in view, so it
//  is there whenever you have lost track of the way back, and only then.
//
//  Knows nothing about the world's geometry: GameScene hands it your base as an
//  offset from the middle of the screen, in screen points, plus the rectangle the
//  marker may use - exactly as it does for the supply compass.
//

import SpriteKit

final class BaseCompassNode: SKNode {

    private static let radius: CGFloat = 19

    private let marker = SKNode()
    private let arrow: SKShapeNode

    override init() {
        let radius = BaseCompassNode.radius

        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius + 12, y: 0))
        path.addLine(to: CGPoint(x: radius + 1, y: 8))
        path.addLine(to: CGPoint(x: radius + 1, y: -8))
        path.closeSubpath()
        arrow = SKShapeNode(path: path)

        super.init()
        zPosition = 40

        // The same see-through black as the supply marker and the rest of the
        // interface.
        arrow.fillColor = SKColor(white: 0, alpha: 0.55)
        arrow.strokeColor = .clear
        marker.addChild(arrow)

        let disc = SKShapeNode(circleOfRadius: radius)
        disc.fillColor = SKColor(white: 0, alpha: 0.55)
        disc.strokeColor = .clear
        marker.addChild(disc)

        let house = SKShapeNode(path: BaseCompassNode.housePath(width: radius * 1.1))
        house.fillColor = .white
        house.strokeColor = .clear
        house.zPosition = 1
        marker.addChild(house)

        marker.isHidden = true
        addChild(marker)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameters:
    ///   - offset: where your base is, relative to the middle of the screen, in
    ///     points. Nil hides the marker.
    ///   - bounds: the part of the screen the marker may sit in, in the same space.
    ///     A base inside it is on screen and needs no marker.
    func update(offset: CGPoint?, bounds: CGRect) {
        guard let point = offset, !bounds.contains(point) else {
            marker.isHidden = true
            return
        }

        if marker.isHidden {
            // Arrives with a small pop, so it is noticed when you walk out of
            // sight of home.
            marker.isHidden = false
            marker.setScale(0.4)
            marker.run(.sequence([.scale(to: 1.1, duration: 0.12), .scale(to: 1, duration: 0.08)]))
        }

        // Along the line from the middle of the screen towards the base, to
        // wherever that line leaves the rectangle.
        let centre = CGPoint(x: bounds.midX, y: bounds.midY)
        let dx = point.x - centre.x
        let dy = point.y - centre.y
        let scale = min(dx == 0 ? .greatestFiniteMagnitude : bounds.width / 2 / abs(dx),
                        dy == 0 ? .greatestFiniteMagnitude : bounds.height / 2 / abs(dy))

        marker.position = CGPoint(x: centre.x + dx * scale, y: centre.y + dy * scale)
        arrow.zRotation = atan2(dy, dx)
    }

    /// A plain house: a roof and a body with a door cut out, centred.
    private static func housePath(width: CGFloat) -> CGPath {
        let half = width / 2
        let path = CGMutablePath()

        // Roof, overhanging the walls a little.
        path.move(to: CGPoint(x: 0, y: half * 0.95))
        path.addLine(to: CGPoint(x: half, y: half * 0.05))
        path.addLine(to: CGPoint(x: -half, y: half * 0.05))
        path.closeSubpath()

        // Walls, with the door as a gap left at the bottom middle.
        let wall = half * 0.72
        let door = half * 0.26
        let bottom = -half * 0.8
        let eaves = half * 0.05
        path.move(to: CGPoint(x: -wall, y: eaves))
        path.addLine(to: CGPoint(x: wall, y: eaves))
        path.addLine(to: CGPoint(x: wall, y: bottom))
        path.addLine(to: CGPoint(x: door, y: bottom))
        path.addLine(to: CGPoint(x: door, y: bottom + half * 0.55))
        path.addLine(to: CGPoint(x: -door, y: bottom + half * 0.55))
        path.addLine(to: CGPoint(x: -door, y: bottom))
        path.addLine(to: CGPoint(x: -wall, y: bottom))
        path.closeSubpath()

        return path
    }
}
