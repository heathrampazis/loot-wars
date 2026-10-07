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
    /// Everything that is drawn, inside the marker, so the alarm can shake it
    /// without disturbing where the marker sits on the edge.
    private let body = SKNode()
    private let arrow: SKShapeNode
    private let disc: SKShapeNode
    private var alarmed = false

    private static let calm = SKColor(white: 0, alpha: 0.55)
    /// The alarm red: the same red as the rest of the interface's warnings (the
    /// "blocked" pills and shakes), see-through like the calm marker so the map
    /// still shows behind it.
    private static let alarm = RenderPalette.placementBlocked.withAlphaComponent(0.72)

    override init() {
        let radius = BaseCompassNode.radius

        let path = CGMutablePath()
        path.move(to: CGPoint(x: radius + 12, y: 0))
        path.addLine(to: CGPoint(x: radius + 1, y: 8))
        path.addLine(to: CGPoint(x: radius + 1, y: -8))
        path.closeSubpath()
        arrow = SKShapeNode(path: path)
        disc = SKShapeNode(circleOfRadius: radius)

        super.init()
        // Over the buttons, hotbar and sticks (1000), which it runs along the
        // edge past and used to vanish behind. Under every panel - the timer and
        // leaderboard (1045), the quick buy and hints (1050), the shop and chest
        // (1100) - which are there to be read and should win.
        zPosition = 1040

        // The same see-through black as the supply marker and the rest of the
        // interface.
        arrow.fillColor = BaseCompassNode.calm
        arrow.strokeColor = .clear
        body.addChild(arrow)

        disc.fillColor = BaseCompassNode.calm
        disc.strokeColor = .clear
        body.addChild(disc)

        let house = SKShapeNode(path: BaseCompassNode.housePath(width: radius * 1.1))
        house.fillColor = .white
        house.strokeColor = .clear
        house.zPosition = 1
        body.addChild(house)

        marker.addChild(body)
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
    ///   - keepOut: controls and panels it must not sit on - see EdgeMarker.
    func update(offset: CGPoint?, bounds: CGRect, avoiding keepOut: [CGRect] = []) {
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

        marker.position = EdgeMarker.clear(
            CGPoint(x: centre.x + dx * scale, y: centre.y + dy * scale),
            of: keepOut, radius: BaseCompassNode.radius + 8, within: bounds)
        arrow.zRotation = atan2(dy, dx)
    }

    /// Your base is being raided: the marker turns red and shakes in short
    /// bursts, so it is noticed from the corner of an eye in the middle of
    /// something else. Calm again when the raid is over.
    func setAlarm(_ on: Bool) {
        guard on != alarmed else { return }
        alarmed = on

        arrow.fillColor = on ? BaseCompassNode.alarm : BaseCompassNode.calm
        disc.fillColor = on ? BaseCompassNode.alarm : BaseCompassNode.calm

        body.removeAction(forKey: "alarm")
        body.position = .zero
        body.setScale(1)
        guard on else { return }

        let jolt: CGFloat = 3.5
        let shake = SKAction.sequence([
            .group([.scale(to: 1.18, duration: 0.05), .moveBy(x: jolt, y: 0, duration: 0.05)]),
            .moveBy(x: -jolt * 2, y: 0, duration: 0.06),
            .moveBy(x: jolt * 2, y: 0, duration: 0.06),
            .moveBy(x: -jolt * 2, y: 0, duration: 0.06),
            .group([.scale(to: 1, duration: 0.1), .moveBy(x: jolt, y: 0, duration: 0.05)]),
            .wait(forDuration: 0.7)
        ])
        body.run(.repeatForever(shake), withKey: "alarm")
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
