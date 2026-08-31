//
//  ChestPanelNode.swift
//  Loot Wars
//
//  What is inside a chest: four slots on a panel, above your own hotbar.
//
//  Deliberately NOT a modal. There is no scrim and the map stays visible behind it,
//  because the world does not stop while you are rummaging - bots keep moving,
//  bullets keep flying, and somebody can walk into your base while your head is in
//  a box. Dimming the game would tell the player the opposite of the truth.
//
//  Proportions came off the reference mockup, measured against the hotbar in the
//  same image to establish its scale: a chest slot is about one and a half hotbar
//  slots. The mockup's own ratio was nearer twice, which does not survive a short
//  landscape screen - at that size the panel ran into the HUD above it and the
//  hotbar below on anything smaller than a Pro Max.
//

import SpriteKit

final class ChestPanelNode: SKNode {

    private static let slotSize: CGFloat = 104
    private static let gap: CGFloat = 24
    private static let padding: CGFloat = 18

    private static let backSize = CGSize(width: 104, height: 44)
    /// How far the back button floats above the panel's top edge.
    private static let backLift: CGFloat = 14

    static var size: CGSize {
        let count = CGFloat(Inventory.slotCount)
        return CGSize(width: count * slotSize + (count - 1) * gap + padding * 2,
                      height: slotSize + padding * 2)
    }

    private var slots: [ItemSlotNode] = []
    private let back = SKNode()
    private var lastContents: Inventory?

    /// Which chest is on screen. nil when the panel is closed.
    private(set) var openChest: ChestID?

    override init() {
        super.init()
        zPosition = 1100      // above the hotbar, which stays live underneath it
        isHidden = true

        let size = ChestPanelNode.size
        let panel = SKShapeNode(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                             width: size.width, height: size.height),
                                cornerRadius: 22)
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        for index in 0..<Inventory.slotCount {
            let slot = ItemSlotNode(side: ChestPanelNode.slotSize)
            slot.position = CGPoint(x: ChestPanelNode.centreX(of: index), y: 0)
            addChild(slot)
            slots.append(slot)
        }

        buildBackButton()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func centreX(of index: Int) -> CGFloat {
        let inner = size.width - padding * 2
        return -inner / 2 + slotSize / 2 + CGFloat(index) * (slotSize + gap)
    }

    private func buildBackButton() {
        let box = ChestPanelNode.backSize
        back.position = CGPoint(
            x: ChestPanelNode.size.width / 2 - box.width / 2,
            y: ChestPanelNode.size.height / 2 + ChestPanelNode.backLift + box.height / 2)

        let pill = SKShapeNode(rect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                            width: box.width, height: box.height),
                               cornerRadius: box.height / 2)
        pill.fillColor = RenderPalette.hudPanel
        pill.strokeColor = .clear
        back.addChild(pill)

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "BACK"
        label.fontSize = 18
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        back.addChild(label)

        addChild(back)
    }

    // MARK: - Opening and closing

    func open(_ chest: ChestID) {
        openChest = chest
        lastContents = nil        // force a redraw for the new chest
        isHidden = false
    }

    func close() {
        openChest = nil
        isHidden = true
    }

    /// Redraws, and reports whether the chest is still there to be looked at.
    ///
    /// The panel asks the world rather than remembering what it was shown, so a
    /// chest that stops existing - or that you are shoved away from - closes itself
    /// rather than leaving a picture of something you can no longer reach.
    @discardableResult
    func update(with world: World) -> Bool {
        guard let id = openChest,
              let chest = world.chests[id],
              let player = world.localPlayer,
              player.isAlive,
              ChestSystem.canReach(chest, from: player) else {
            if openChest != nil { close() }
            return false
        }

        guard chest.contents != lastContents else { return true }
        lastContents = chest.contents

        for (index, stack) in chest.contents.slots.enumerated() {
            slots[index].show(stack)
        }
        return true
    }

    // MARK: - Hit testing

    func slotIndex(atLocalPoint point: CGPoint) -> Int? {
        let half = ChestPanelNode.slotSize / 2
        guard abs(point.y) <= half + ChestPanelNode.padding else { return nil }

        for index in 0..<Inventory.slotCount {
            let centreX = ChestPanelNode.centreX(of: index)
            if abs(point.x - centreX) <= half + ChestPanelNode.gap / 2 { return index }
        }

        return nil
    }

    func isBackButton(atLocalPoint point: CGPoint) -> Bool {
        let box = ChestPanelNode.backSize
        let local = CGPoint(x: point.x - back.position.x, y: point.y - back.position.y)
        // Grown a little: it is a small target and a miss keeps you stuck in a menu.
        return abs(local.x) <= box.width / 2 + 12 && abs(local.y) <= box.height / 2 + 12
    }
}
