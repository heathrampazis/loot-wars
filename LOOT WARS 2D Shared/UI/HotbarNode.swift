//
//  HotbarNode.swift
//  Loot Wars
//
//  Four slots along the bottom of the screen, mirroring Inventory.slotCount.
//
//  Like the HUD it only reads the world, and only redraws when the inventory
//  actually changes - which is why Inventory is Equatable.
//
//  Its origin is the centre of the bar, so it sits at the bottom of the screen with
//  no arithmetic against its own width.
//
//  Every measurement below came off the reference art, scaled by its tile size:
//  a slot is 1.64 tiles, the gap 0.39, an item 0.74 of a slot, and the badge 0.66.
//

import SpriteKit

final class HotbarNode: SKNode {

    private static let slotSize: CGFloat = 66
    private static let gap: CGFloat = 16
    /// How much smaller the item is drawn than its slot.
    private static let iconInset: CGFloat = 10

    /// Badge geometry. The stroke straddles the circle, so the radius plus half the
    /// outline is the outer edge - 13pt, matching the reference's 26pt across.
    private static let badgeRadius: CGFloat = 11.5
    private static let badgeOutline: CGFloat = 3
    /// How far the badge's centre sits inside the slot's top-left corner, so it
    /// overhangs slightly rather than floating free.
    private static let badgeInset: CGFloat = 5

    static var size: CGSize {
        let count = CGFloat(Inventory.slotCount)
        return CGSize(width: count * slotSize + (count - 1) * gap, height: slotSize)
    }

    private var icons: [SKSpriteNode] = []
    private var badges: [SKNode] = []
    private var counts: [SKLabelNode] = []
    private var lastInventory: Inventory?
    private var lastUsable: Bool?

    override init() {
        super.init()
        zPosition = 1000

        let total = HotbarNode.size.width

        for index in 0..<Inventory.slotCount {
            let centreX = -total / 2
                + HotbarNode.slotSize / 2
                + CGFloat(index) * (HotbarNode.slotSize + HotbarNode.gap)

            addChild(makeSlot(atX: centreX))

            let icon = SKSpriteNode()
            icon.position = CGPoint(x: centreX, y: 0)
            icon.zPosition = 1
            icon.isHidden = true
            addChild(icon)
            icons.append(icon)

            let (badge, label) = makeBadge(atX: centreX)
            addChild(badge)
            badges.append(badge)
            counts.append(label)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// No outline: the slots are quiet panels the items sit on, not framed boxes.
    private func makeSlot(atX centreX: CGFloat) -> SKShapeNode {
        let side = HotbarNode.slotSize
        let slot = SKShapeNode(rect: CGRect(x: centreX - side / 2,
                                            y: -side / 2,
                                            width: side,
                                            height: side),
                               cornerRadius: 12)
        slot.fillColor = RenderPalette.hotbarSlot
        slot.strokeColor = .clear
        return slot
    }

    private func makeBadge(atX centreX: CGFloat) -> (SKNode, SKLabelNode) {
        let badge = SKNode()
        badge.position = CGPoint(
            x: centreX - HotbarNode.slotSize / 2 + HotbarNode.badgeInset,
            y: HotbarNode.slotSize / 2 - HotbarNode.badgeInset
        )
        badge.zPosition = 2
        badge.isHidden = true

        let circle = SKShapeNode(circleOfRadius: HotbarNode.badgeRadius)
        circle.fillColor = RenderPalette.countBadge
        circle.strokeColor = .black
        circle.lineWidth = HotbarNode.badgeOutline
        badge.addChild(circle)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        badge.addChild(label)

        return (badge, label)
    }

    /// Which slot a touch landed on, or nil if it missed the bar entirely.
    ///
    /// The slots are treated as touching each other rather than separated by their
    /// gap: a thumb landing in the crack between two slots meant to hit one of them.
    func slotIndex(atLocalPoint point: CGPoint) -> Int? {
        let half = HotbarNode.slotSize / 2
        guard abs(point.y) <= half + 12 else { return nil }

        let total = HotbarNode.size.width

        for index in 0..<Inventory.slotCount {
            let centreX = -total / 2
                + HotbarNode.slotSize / 2
                + CGFloat(index) * (HotbarNode.slotSize + HotbarNode.gap)

            if abs(point.x - centreX) <= half + HotbarNode.gap / 2 { return index }
        }

        return nil
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        // Greyed out at full health, because that is when drinking is refused. The
        // rule itself lives in ConsumableSystem - this only shows it.
        let usable = player.isAlive && player.health < player.maxHealth

        guard player.inventory != lastInventory || usable != lastUsable else { return }
        lastInventory = player.inventory
        lastUsable = usable

        for (index, stack) in player.inventory.slots.enumerated() {
            let icon = icons[index]

            guard let stack else {
                icon.isHidden = true
                badges[index].isHidden = true
                continue
            }

            let texture = ItemArt.texture(for: stack.type)
            let art = texture.size()
            let height = HotbarNode.slotSize - HotbarNode.iconInset
            let width = art.height > 0 ? height * (art.width / art.height) : height

            icon.texture = texture
            icon.size = CGSize(width: width, height: height)
            icon.isHidden = false
            icon.alpha = usable ? 1.0 : 0.35

            // A badge on a single item is noise - it only earns its place once
            // there is more than one.
            badges[index].isHidden = stack.count <= 1
            counts[index].text = "\(stack.count)"
        }
    }
}
