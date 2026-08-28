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
               height: padding * 2 + StatBarNode.barHeight * 2 + rowSpacing)
    }

    private let health = StatBarNode(iconNamed: "HealthIcon",
                                     fillColour: RenderPalette.healthBar)
    private let ammo = StatBarNode(iconNamed: "BulletIcon",
                                   fillColour: RenderPalette.ammoBar)

    override init() {
        super.init()

        let size = HUDNode.size
        let panel = SKShapeNode(path: CGPath(
            roundedRect: CGRect(x: 0, y: -size.height, width: size.width, height: size.height),
            cornerWidth: 14, cornerHeight: 14, transform: nil))
        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        let firstRowCentre = -HUDNode.padding - StatBarNode.barHeight / 2
        health.position = CGPoint(x: HUDNode.padding, y: firstRowCentre)
        ammo.position = CGPoint(x: HUDNode.padding,
                                y: firstRowCentre - StatBarNode.barHeight - HUDNode.rowSpacing)

        addChild(health)
        addChild(ammo)

        zPosition = 1000
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        health.setFraction(Double(player.health) / Double(GameConfig.Player.maxHealth))
        ammo.setFraction(Double(player.ammo) / Double(GameConfig.Blaster.magazineSize))
    }
}
