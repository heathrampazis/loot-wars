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

    private static let padding: CGFloat = 8
    private static let rowSpacing: CGFloat = 6

    /// Measured from the rows it actually has, so switching the ammo bar off in
    /// GameConfig shortens the panel rather than leaving a hole where it was.
    static var size: CGSize {
        let bars = GameConfig.Blaster.usesAmmo ? 2 : 1
        let rows = bars + 1     // and the token counter

        return CGSize(width: padding * 2 + StatBarNode.totalWidth,
                      height: padding * 2
                            + StatBarNode.barHeight * CGFloat(bars)
                            + StatCounterNode.height
                            + rowSpacing * CGFloat(rows - 1))
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

        var rows: [(SKNode, CGFloat)] = [(health, StatBarNode.barHeight)]
        if GameConfig.Blaster.usesAmmo { rows.append((ammo, StatBarNode.barHeight)) }
        rows.append((tokens, StatCounterNode.height))

        for (row, height) in rows {
            row.position = CGPoint(x: HUDNode.padding, y: edge - height / 2)
            edge -= height + HUDNode.rowSpacing
        }

        for (row, _) in rows { addChild(row) }

        zPosition = 1000
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        guard let player = world.localPlayer else { return }

        health.setFraction(Double(player.health) / Double(player.maxHealth))
        if GameConfig.Blaster.usesAmmo {
            ammo.setFraction(Double(player.ammo) / Double(GameConfig.Blaster.magazineSize))
        }
        tokens.setValue(player.tokens)
    }
}
