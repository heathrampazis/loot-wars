//
//  HUDNode.swift
//  Loot Wars
//
//  The panel in the top-left corner.
//
//  It reads the world and never writes to it, exactly like the renderers. The bars
//  are driven by real simulation values, so health will start moving the moment
//  damage exists - nothing here needs revisiting for that.
//
//  Its origin is its own top-left corner, so positioning it is just "inset from the
//  corner of the screen" rather than arithmetic with its size.
//

import SpriteKit

final class HUDNode: SKNode {

    private static let padding: CGFloat = 12
    private static let rowSpacing: CGFloat = 8

    static var size: CGSize {
        CGSize(width: padding * 2 + StatBarNode.totalWidth,
               height: padding * 2 + StatBarNode.barHeight * 2
                     + StatCounterNode.height + rowSpacing * 2)
    }

    private let health = StatBarNode(iconNamed: "HealthIcon",
                                     fillColour: RenderPalette.healthBar)
    private let ammo = StatBarNode(iconNamed: "BulletIcon",
                                   fillColour: RenderPalette.ammoBar)
    private let tokens = StatCounterNode(iconNamed: "Token")

    override init() {
        super.init()

        let size = HUDNode.size
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -size.height, width: size.width, height: size.height),
            cornerWidth: 14, cornerHeight: 14, transform: nil))
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        // Rows stacked by walking DOWN the panel, each one placed against the
        // bottom of the last. Deriving every row from the first is how the token
        // counter first came out three points inside the ammo bar.
        var edge = -HUDNode.padding

        for (row, height) in [(health, StatBarNode.barHeight),
                              (ammo, StatBarNode.barHeight),
                              (tokens, StatCounterNode.height)] as [(SKNode, CGFloat)] {
            row.position = CGPoint(x: HUDNode.padding, y: edge - height / 2)
            edge -= height + HUDNode.rowSpacing
        }

        addChild(health)
        addChild(ammo)
        addChild(tokens)

        zPosition = 1000
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        health.setFraction(Double(player.health) / Double(player.maxHealth))
        ammo.setFraction(Double(player.ammo) / Double(GameConfig.Blaster.magazineSize))
        tokens.setValue(player.tokens)
    }
}
