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

    /// How much bigger a picked-out slot sits than its neighbours, and how far a
    /// held one is squeezed. Both are scales on the whole slot rather than badges
    /// added to it, so they compose: a selected slot being held squeezes from its
    /// larger size and springs back to it.
    private static let selectedScale: CGFloat = 1.14
    private static let heldScale: CGFloat = 0.8

    private let side: CGFloat
    private var selected = false

    /// The slot's own plate, recoloured to the rarity of whatever is in it.
    private let panel: SKShapeNode

    private let icon = SKSpriteNode()
    private let badge = SKNode()
    private let count = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// Local origin is the centre of the slot.
    init(side: CGFloat) {
        self.side = side

        // Built before super.init, because it is a constant stored property and
        // Swift wants every one of those settled before the superclass runs. It is
        // only decorated and parented afterwards, where self exists.
        panel = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                         width: side, height: side),
                            cornerRadius: side * 0.182)
        super.init()

        panel.fillColor = RenderPalette.hotbarSlot
        panel.strokeColor = .clear
        panel.lineWidth = side * 0.045
        addChild(panel)

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

    /// Where the slot rests: bigger while it is the one picked out.
    private var restingScale: CGFloat {
        selected ? ItemSlotNode.selectedScale : 1
    }

    /// Squeezes over the length of a hold, so the press has somewhere to go while
    /// the finger is down.
    ///
    /// Not decoration. Four tenths of a second with no response at all reads as a
    /// tap that failed to register, and the player lifts off just before the thing
    /// they were waiting for would have happened.
    func beginHold(duration: TimeInterval) {
        removeAction(forKey: "scale")
        run(.scale(to: restingScale * ItemSlotNode.heldScale, duration: duration),
            withKey: "hold")
    }

    func endHold() {
        removeAction(forKey: "hold")
        settle()
    }

    /// The picked-out slot simply sits larger than the others.
    ///
    /// It used to wear a ring. Growing it says the same thing without adding a
    /// second colour to a bar that is already carrying item art and count badges -
    /// and it reads at a glance on a screen held at arm's length, which an outline
    /// four points wide does not.
    func setSelected(_ selected: Bool) {
        guard selected != self.selected else { return }
        self.selected = selected
        removeAction(forKey: "hold")
        settle()
    }

    private func settle() {
        removeAction(forKey: "scale")
        run(.scale(to: restingScale, duration: 0.12), withKey: "scale")
    }

    /// - Parameter dimmed: the item is there but cannot be used right now. Drawn
    ///   faint rather than hidden, so you can still see what you are carrying.
    func show(_ stack: ItemStack?, dimmed: Bool = false) {
        guard let stack else {
            icon.isHidden = true
            badge.isHidden = true

            // An empty slot is a hole in the bar, not an item of no value.
            panel.fillColor = RenderPalette.hotbarSlot
            panel.strokeColor = .clear
            return
        }

        // The rarity, said twice over: a wash of the colour through the plate and
        // the same colour round the edge. Twice because one alone fails somewhere -
        // a fill this faint is hard to judge against grass showing through the
        // slot, and an outline alone is four points of colour on a screen held at
        // arm's length. Together they read at a glance, which is the entire job.
        let colour = RenderPalette.colour(of: stack.type.rarity)
        panel.fillColor = colour.withAlphaComponent(dimmed ? 0.16 : 0.30)
        panel.strokeColor = colour.withAlphaComponent(dimmed ? 0.35 : 0.85)

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
