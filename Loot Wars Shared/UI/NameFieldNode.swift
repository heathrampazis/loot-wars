//
//  NameFieldNode.swift
//  Loot Wars
//
//  The nickname box on the title screen, just above Play: a see-through white
//  box, frosted over the map behind it, with dark writing and a pencil on the right to
//  say it can be written in. Its edge turns blue while you type,
//  and the pencil makes way for the field's own clear button.
//
//  This node draws the box only. The words in it are a real system text field
//  that MenuScene lays over textRect, so typing, the cursor, selecting and
//  deleting all behave the way they do everywhere else on the phone.
//

import SpriteKit
import UIKit

final class NameFieldNode: SKNode {

    let size: CGSize

    private static let edge: CGFloat = 3
    private static let face = SKColor(white: 1, alpha: 0.7)
    private static let idleEdge = SKColor(white: 0, alpha: 0.3)

    private let slab: SKShapeNode
    private let pencil: SKShapeNode

    /// Typing into it right now: the edge goes blue.
    var isEditing = false {
        didSet {
            guard isEditing != oldValue else { return }
            slab.strokeColor = isEditing ? RenderPalette.menuInfo.edge : NameFieldNode.idleEdge
            pencil.isHidden = isEditing
        }
    }

    /// A name turned down: the edge flashes red and the box gives a short shake.
    func refuse() {
        removeAction(forKey: "refuse")
        slab.strokeColor = RenderPalette.menuDanger.face
        run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.04),
            .moveBy(x: 12, y: 0, duration: 0.07),
            .moveBy(x: -10, y: 0, duration: 0.06),
            .moveBy(x: 4, y: 0, duration: 0.05),
            .wait(forDuration: 1.2),
            .run { [weak self] in
                guard let self, !self.isEditing else { return }
                self.slab.strokeColor = NameFieldNode.idleEdge
            }
        ]), withKey: "refuse")
    }

    /// Where the text field goes, in this node's own space: from the left
    /// margin to just short of the right edge. The pencil sits in the gap on the
    /// right and is hidden while typing, when the clear button needs the room.
    var textRect: CGRect {
        let left = -size.width / 2 + pad
        let right = size.width / 2 - pad * 0.6
        return CGRect(x: left, y: -size.height / 2, width: right - left, height: size.height)
    }

    private var pad: CGFloat { (size.height * 0.4).rounded() }

    init(width: CGFloat, height: CGFloat) {
        size = CGSize(width: width, height: height)
        let corner = (height * 0.3).rounded()
        slab = MenuButtonNode.slab(width: width, height: height, edge: NameFieldNode.edge,
                                   corner: corner,
                                   tone: RenderPalette.MenuTone(face: NameFieldNode.face,
                                                                edge: NameFieldNode.idleEdge))
        pencil = NameFieldNode.makePencil(length: (height * 0.56).rounded())
        super.init()

        // No drop shadow: it would show through the see-through face as a smudge.
        addChild(slab)

        pencil.position = CGPoint(x: width / 2 - height * 0.52, y: 0)
        pencil.zPosition = 1
        addChild(pencil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func contains(localPoint point: CGPoint) -> Bool {
        abs(point.x) <= size.width / 2 && abs(point.y) <= size.height / 2
    }

    /// The usual edit pencil: a body with a pointed tip, and a short rounded
    /// cap at the other end with a small gap before it. Tilted with the tip to
    /// the bottom left, in one flat grey.
    private static func makePencil(length: CGFloat) -> SKShapeNode {
        let half = max(2, (length * 0.15).rounded())
        let tip = length * 0.28
        let cap = length * 0.2
        let gap = max(1.5, (length * 0.08).rounded())
        let start = -length / 2
        let bodyEnd = length / 2 - cap - gap

        let path = CGMutablePath()
        path.move(to: CGPoint(x: start, y: 0))
        path.addLine(to: CGPoint(x: start + tip, y: half))
        path.addLine(to: CGPoint(x: bodyEnd, y: half))
        path.addLine(to: CGPoint(x: bodyEnd, y: -half))
        path.addLine(to: CGPoint(x: start + tip, y: -half))
        path.closeSubpath()
        path.addRoundedRect(in: CGRect(x: length / 2 - cap, y: -half, width: cap, height: half * 2),
                            cornerWidth: min(cap, half * 2) * 0.4,
                            cornerHeight: min(cap, half * 2) * 0.4)

        let node = SKShapeNode(path: path)
        node.fillColor = SKColor(white: 0.42, alpha: 1)
        node.strokeColor = .clear
        node.zRotation = .pi / 4
        return node
    }
}
