//
//  HotbarNode.swift
//  Loot Wars
//
//  Four slots along the bottom of the screen, mirroring Inventory.slotCount.
//
//  Like the HUD it only reads the world. It also only redraws when the inventory
//  actually changes, which is why Inventory is Equatable.
//
//  Its origin is the centre of the bar, so it sits at the bottom of the screen with
//  no arithmetic against its own width.
//

import SpriteKit

final class HotbarNode: SKNode {

    private static let slotSize: CGFloat = 54
    private static let gap: CGFloat = 8
    private static let outline: CGFloat = 4.5

    static var size: CGSize {
        let count = CGFloat(Inventory.slotCount)
        return CGSize(width: count * slotSize + (count - 1) * gap, height: slotSize)
    }

    private var icons: [SKSpriteNode] = []
    private var counts: [SKLabelNode] = []
    private var lastInventory: Inventory?

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

            let count = SKLabelNode(fontNamed: "AvenirNext-Bold")
            count.fontSize = 15
            count.fontColor = .white
            count.horizontalAlignmentMode = .right
            count.verticalAlignmentMode = .bottom
            count.position = CGPoint(x: centreX + HotbarNode.slotSize / 2 - 8,
                                     y: -HotbarNode.slotSize / 2 + 7)
            count.zPosition = 2
            count.isHidden = true
            addChild(count)
            counts.append(count)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeSlot(atX centreX: CGFloat) -> SKShapeNode {
        // Inset by half the stroke so the outline's outer edge lands on slotSize,
        // the same trick the HUD bars use.
        let inner = HotbarNode.slotSize - HotbarNode.outline
        let slot = SKShapeNode(rect: CGRect(x: centreX - inner / 2,
                                            y: -inner / 2,
                                            width: inner,
                                            height: inner),
                               cornerRadius: 10)
        slot.fillColor = RenderPalette.hudPanel
        slot.strokeColor = .black
        slot.lineWidth = HotbarNode.outline
        return slot
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }
        guard player.inventory != lastInventory else { return }
        lastInventory = player.inventory

        for (index, stack) in player.inventory.slots.enumerated() {
            let icon = icons[index]
            let count = counts[index]

            guard let stack else {
                icon.isHidden = true
                count.isHidden = true
                continue
            }

            let texture = ItemArt.texture(for: stack.type)
            let art = texture.size()
            let height = HotbarNode.slotSize - 14
            let width = art.height > 0 ? height * (art.width / art.height) : height

            icon.texture = texture
            icon.size = CGSize(width: width, height: height)
            icon.isHidden = false

            count.text = "\(stack.count)"
            count.isHidden = stack.count <= 1
        }
    }
}
