//
//  SupplyCompassNode.swift
//  Loot Wars
//
//  Arrows on the edge of the screen pointing at supply drops you cannot see.
//
//  One marker per drop: a gold badge with the crate in it, an arrow on the side
//  facing the drop, and the countdown underneath - or OPEN once it can be taken.
//  It rides round the edge of the screen as you move, and goes away the moment
//  the drop itself comes into view, where the crate's own badge takes over.
//
//  Knows nothing about the world's geometry: GameScene hands it each drop as an
//  offset from the middle of the screen, in screen points, plus the rectangle the
//  markers may use. Everything here is layout and look.
//

import SpriteKit
import UIKit

final class SupplyCompassNode: SKNode {

    struct Target {
        let id: LootboxID
        /// Where the drop is, relative to the middle of the screen, in points.
        let offset: CGPoint
        /// Whole seconds until it opens, or nil once it can be opened.
        let secondsLeft: Int?
    }

    private final class Marker {
        let root = SKNode()
        let arrow: SKShapeNode
        let label = SKLabelNode()
        var text = ""
        var open = false

        init(radius: CGFloat) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: radius + 13, y: 0))
            path.addLine(to: CGPoint(x: radius + 1, y: 9))
            path.addLine(to: CGPoint(x: radius + 1, y: -9))
            path.closeSubpath()
            arrow = SKShapeNode(path: path)
        }
    }

    private var markers: [LootboxID: Marker] = [:]

    private static let radius: CGFloat = 21

    private lazy var crate: SKTexture = SKTexture(imageNamed: "LootboxGold")

    override init() {
        super.init()
        zPosition = 40
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameter bounds: the part of the screen the markers may sit in, in the
    ///   same space as the offsets. A drop inside it is on screen and needs no
    ///   marker.
    func update(targets: [Target], bounds: CGRect) {
        let wanted = Set(targets.map(\.id))
        for (id, marker) in markers where !wanted.contains(id) {
            marker.root.removeFromParent()
            markers[id] = nil
        }

        for target in targets {
            let marker = markers[target.id] ?? make(target.id)
            let point = target.offset

            // On screen: the crate is right there, wearing its own countdown.
            guard !bounds.contains(point) else {
                marker.root.isHidden = true
                continue
            }
            marker.root.isHidden = false

            // Along the line from the middle of the screen towards the drop, to
            // wherever that line leaves the rectangle.
            let centre = CGPoint(x: bounds.midX, y: bounds.midY)
            let dx = point.x - centre.x
            let dy = point.y - centre.y
            let halfW = bounds.width / 2
            let halfH = bounds.height / 2
            let scale = min(dx == 0 ? .greatestFiniteMagnitude : halfW / abs(dx),
                            dy == 0 ? .greatestFiniteMagnitude : halfH / abs(dy))

            marker.root.position = CGPoint(x: centre.x + dx * scale, y: centre.y + dy * scale)
            marker.arrow.zRotation = atan2(dy, dx)

            setText(on: marker, secondsLeft: target.secondsLeft)
        }
    }

    private func setText(on marker: Marker, secondsLeft: Int?) {
        let text = secondsLeft.map { "\($0)" } ?? "OPEN"
        guard text != marker.text else { return }
        marker.text = text

        marker.label.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .heavy),
            .foregroundColor: SKColor.white,
            .strokeColor: SKColor.black,
            .strokeWidth: -4.0
        ])

        let open = secondsLeft == nil
        guard open != marker.open else { return }
        marker.open = open

        if open {
            marker.root.run(.repeatForever(.sequence([
                .scale(to: 1.14, duration: 0.35),
                .scale(to: 1, duration: 0.35)
            ])), withKey: "pulse")
        } else {
            marker.root.removeAction(forKey: "pulse")
            marker.root.setScale(1)
        }
    }

    private func make(_ id: LootboxID) -> Marker {
        let radius = SupplyCompassNode.radius
        let marker = Marker(radius: radius)

        // The same see-through black as the hotbar and the other controls, arrow
        // included, so the marker sits with the rest of the interface. The gold
        // crate inside is what says "supply drop".
        marker.arrow.fillColor = SKColor(white: 0, alpha: 0.55)
        marker.arrow.strokeColor = .clear
        marker.root.addChild(marker.arrow)

        let disc = SKShapeNode(circleOfRadius: radius)
        disc.fillColor = SKColor(white: 0, alpha: 0.55)
        disc.strokeColor = .clear
        marker.root.addChild(disc)

        let art = crate.size()
        let width = radius * 1.35
        let icon = SKSpriteNode(texture: crate,
                                size: CGSize(width: width,
                                             height: art.width > 0 ? width * art.height / art.width : width))
        icon.zPosition = 1
        marker.root.addChild(icon)

        marker.label.verticalAlignmentMode = .top
        marker.label.horizontalAlignmentMode = .center
        marker.label.position = CGPoint(x: 0, y: -radius - 3)
        marker.label.zPosition = 2
        marker.root.addChild(marker.label)

        // Arrives with a pop, so a new drop off to one side is noticed.
        marker.root.setScale(0.2)
        marker.root.run(.sequence([.scale(to: 1.2, duration: 0.14), .scale(to: 1, duration: 0.1)]))

        addChild(marker.root)
        markers[id] = marker
        return marker
    }
}
