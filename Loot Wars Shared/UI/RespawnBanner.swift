//
//  RespawnBanner.swift
//  Loot Wars
//
//  Shown only while the local player is dead.
//
//  Without it, dying is just your sprite vanishing with no explanation - the one
//  moment in the game where the player most needs telling what is happening.
//

import SpriteKit

final class RespawnBanner: SKNode {

    private let panel = SKShapeNode(path: CGPath(
        roundedRect: CGRect(x: -120, y: -34, width: 240, height: 68),
        cornerWidth: 16, cornerHeight: 16, transform: nil))

    private let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let countdown = SKLabelNode(fontNamed: "AvenirNext-Bold")

    override init() {
        super.init()
        zPosition = 1200
        isHidden = true

        panel.fillColor = RenderPalette.hudPanel
        panel.strokeColor = .clear
        addChild(panel)

        title.text = "RESPAWNING"
        title.fontSize = 15
        title.fontColor = .white
        title.alpha = 0.75
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 17)
        addChild(title)

        countdown.fontSize = 30
        countdown.fontColor = .white
        countdown.verticalAlignmentMode = .center
        countdown.position = CGPoint(x: 0, y: -13)
        addChild(countdown)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with world: World) {
        guard let player = world.localPlayer, let remaining = player.respawnTimer else {
            isHidden = true
            return
        }

        isHidden = false
        countdown.text = "\(max(1, Int(remaining.rounded(.up))))"
    }
}
