//
//  ItemSlotNode.swift
//  Loot Wars
//
//  One square holding one stack: the panel, the item, and the count badge.
//
//  Extracted when the chest panel arrived and turned out to need exactly what the
//  hotbar already drew. Two copies of this would have looked identical on the day
//  they were written and drifted apart by the second time either was touched -
//  and a chest whose slots do not look like your own slots is a chest nobody
//  believes they can move things into.
//
//  Every measurement is a fraction of the slot's side, so a big slot in a chest
//  panel and a small one in the hotbar are the same drawing at two sizes. At the
//  hotbar's 66pt these reproduce the numbers originally taken off the reference
//  art - a 10pt inset, an 11.5pt badge radius, a 3pt outline.
//

import SpriteKit

final class ItemSlotNode: SKNode {

    private let side: CGFloat
    private var selection: SKShapeNode!
    private let icon = SKSpriteNode()
    private let badge = SKNode()
    private let count = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// Local origin is the centre of the slot.
    init(side: CGFloat) {
        self.side = side
        super.init()

        let panel = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                             width: side, height: side),
                                cornerRadius: side * 0.182)
        panel.fillColor = RenderPalette.hotbarSlot
        panel.strokeColor = .clear
        addChild(panel)

        selection = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                             width: side, height: side),
                                cornerRadius: side * 0.182)
        selection.fillColor = .clear
        selection.strokeColor = RenderPalette.countBadge
        selection.lineWidth = side * 0.06
        selection.zPosition = 3
        selection.isHidden = true
        addChild(selection)

        icon.zPosition = 1
        icon.isHidden = true
        addChild(icon)

        let radius = side * 0.174
        let inset = side * 0.076

        badge.position = CGPoint(x: -side / 2 + inset, y: side / 2 - inset)
        badge.zPosition = 2
        badge.isHidden = true
        addChild(badge)

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = RenderPalette.countBadge
        circle.strokeColor = .black
        circle.lineWidth = side * 0.045
        badge.addChild(circle)

        count.fontSize = radius * 1.22
        count.fontColor = .white
        count.horizontalAlignmentMode = .center
        count.verticalAlignmentMode = .center
        count.zPosition = 1
        badge.addChild(count)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Squeezes over the length of a hold, so the press has somewhere to go while
    /// the finger is down.
    ///
    /// Not decoration. Four tenths of a second with no response at all reads as a
    /// tap that failed to register, and the player lifts off just before the thing
    /// they were waiting for would have happened.
    func beginHold(duration: TimeInterval) {
        removeAction(forKey: "hold")
        run(.scale(to: 0.84, duration: duration), withKey: "hold")
    }

    func endHold() {
        removeAction(forKey: "hold")
        run(.scale(to: 1, duration: 0.12))
    }

    /// Ringed while this slot is armed - a chest waiting for you to pick a tile.
    /// Without it, tapping a chest looks exactly like tapping nothing.
    func setSelected(_ selected: Bool) {
        selection.isHidden = !selected
    }

    /// - Parameter dimmed: the item is there but cannot be used right now. Drawn
    ///   faint rather than hidden, so you can still see what you are carrying.
    func show(_ stack: ItemStack?, dimmed: Bool = false) {
        guard let stack else {
            icon.isHidden = true
            badge.isHidden = true
            return
        }

        let texture = ItemArt.texture(for: stack.type)
        icon.texture = texture
        icon.size = ItemArt.size(of: texture, fittingInto: side - side * 0.152)
        icon.isHidden = false
        icon.alpha = dimmed ? 0.35 : 1.0

        // A badge on a single item is noise - it only earns its place once there
        // is more than one.
        badge.isHidden = stack.count <= 1
        count.text = "\(stack.count)"
    }
}
