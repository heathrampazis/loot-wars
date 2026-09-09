//
//  ChestRenderer.swift
//  Loot Wars
//
//  Chests standing in bases. Placed during a match rather than at generation, so
//  unlike the arcades this syncs each frame instead of being built once.
//

import SpriteKit

final class ChestRenderer {

    let node = SKNode()

    private var nodesByChest: [ChestID: SKSpriteNode] = [:]
    private lazy var texture: SKTexture = {
        let texture = SKTexture(imageNamed: "Chest")
        texture.usesMipmaps = true
        return texture
    }()

    /// Which chest is currently wearing the "you can touch this" rim.
    ///
    /// Held so the rim is faded on a CHANGE rather than restarted every frame -
    /// an action begun sixty times a second never gets past its first frame, which
    /// is how you end up with an outline permanently half visible. The same
    /// mistake, and the same fix, as LootboxRenderer.
    private var lit: ChestID?

    private static let rimName = "reach"

    func sync(with world: World) {
        for (id, chest) in world.chests where nodesByChest[id] == nil {
            make(chest)
        }

        for (id, sprite) in Array(nodesByChest) where world.chests[id] == nil {
            nodesByChest[id] = nil
            if lit == id { lit = nil }
            smash(sprite)
        }

        // The chest within arm's reach wears a rim, exactly as a crate does.
        //
        // Both kinds, yours and anybody else's, because the rim answers "can you
        // touch this" and the answer is yes to both - what touching it DOES is the
        // corner button's business, and it already shows a different glyph for
        // taking your things out and for breaking somebody else's open.
        //
        // Asked with the same question the tap and the button use, so the outline
        // can never light up on something the simulation would then refuse.
        let reachable = world.localPlayer.flatMap { player in
            player.isAlive ? world.reachableChest(for: player)?.id : nil
        }

        guard reachable != lit else { return }

        if let lit { setRim(on: nodesByChest[lit], showing: false) }
        lit = reachable
        if let reachable { setRim(on: nodesByChest[reachable], showing: true) }
    }

    private func setRim(on sprite: SKSpriteNode?, showing: Bool) {
        guard let rim = sprite?.childNode(withName: ChestRenderer.rimName) else { return }

        rim.removeAllActions()
        rim.run(.fadeAlpha(to: showing ? 0.85 : 0, duration: showing ? 0.12 : 0.18))
    }

    /// The lid knocked open, for a chest you are looking into.
    ///
    /// Opening your own chest is the one interaction in the game that changes
    /// nothing about the world - it only changes what this screen is showing - so
    /// there is no state for a renderer to notice and this has to be told. Which
    /// makes it the exception worth naming: everything else in here is a diff.
    ///
    /// A knock rather than a bounce. The chest is a heavy thing standing on the
    /// ground and it should read as being opened rather than as being picked up.
    func nudge(_ id: ChestID) {
        guard let sprite = nodesByChest[id] else { return }

        sprite.removeAction(forKey: "nudge")
        sprite.run(.sequence([
            .group([.scaleX(to: 1.10, y: 0.90, duration: 0.06),
                    .rotate(toAngle: 0.05, duration: 0.06)]),
            .group([.scaleX(to: 0.96, y: 1.06, duration: 0.09),
                    .rotate(toAngle: -0.03, duration: 0.09)]),
            .group([.scaleX(to: 1, y: 1, duration: 0.12),
                    .rotate(toAngle: 0, duration: 0.12)])
        ]), withKey: "nudge")
    }

    /// Smashed, for a chest somebody has just stripped.
    ///
    /// A raided chest is not opened, it is BROKEN - see ChestSystem.crack - and it
    /// stops existing in the same frame. So this is the whole of what a player sees
    /// happen to it, and a fade would say the chest was switched off rather than
    /// taken apart. It shakes hard first, twice, and only then comes apart.
    private func smash(_ sprite: SKSpriteNode) {
        sprite.childNode(withName: ChestRenderer.rimName)?.removeFromParent()

        sprite.run(.sequence([
            .group([.rotate(toAngle: 0.11, duration: 0.04),
                    .scaleX(to: 1.14, y: 0.88, duration: 0.04)]),
            .rotate(toAngle: -0.13, duration: 0.05),
            .group([.rotate(toAngle: 0.06, duration: 0.05),
                    .scale(to: 1.28, duration: 0.05),
                    .fadeAlpha(to: 0.9, duration: 0.05)]),
            .group([.scale(to: 0.2, duration: 0.18),
                    .rotate(byAngle: -0.6, duration: 0.18),
                    .moveBy(x: 0, y: 6, duration: 0.18),
                    .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    private func make(_ chest: Chest) {
        // As wide as the box it stands on, and as tall as the art says - measured,
        // so the exported canvas's transparent margin does not shrink the chest
        // inside its own footprint.
        //
        // Not stretched to the box, which is what it was for one commit. The box is
        // shorter than the picture on purpose now (see GameConfig.Chest.size), so
        // covering it squashed the chest by a sixth. Instead the chest STANDS on the
        // box - its base on the box's base - and the lid overhangs the top, which is
        // both what a chest looks like and what keeps the gap behind it walkable.
        let fit = ArtFit.spanning("Chest", width: GameConfig.Chest.size.x)

        let sprite = SKSpriteNode(texture: texture, size: fit.size)

        let standing = GridGeometry.point(for: chest.position)
        let footing = standing.y - GridGeometry.length(ofTiles: GameConfig.Chest.size.y / 2)

        sprite.position = CGPoint(x: standing.x - fit.content.midX,
                                  y: footing - fit.content.minY)
        sprite.zPosition = 3    // with the crates: above trees, below walls and actors

        // A short landing, so a chest you just put down reads as having arrived
        // rather than having always been there.
        sprite.setScale(0.4)
        sprite.run(.scale(to: 1, duration: 0.18))

        // The rim that says it can be touched. Built with every chest and left
        // invisible, because a node that already exists can be faded in on the
        // frame it is wanted; one that has to be created first arrives late.
        //
        // Drawn round the PICTURE rather than round the sprite. The sprite is
        // bigger than the chest - the artwork carries an eighth of its height as
        // transparent air, which is what ArtFit measures - so a rim on the sprite's
        // own bounds would float clear of the chest on every side.
        let rim = SKShapeNode(rect: fit.content.insetBy(dx: -3, dy: -3), cornerRadius: 6)
        rim.name = ChestRenderer.rimName
        rim.strokeColor = .white
        rim.lineWidth = 2
        rim.fillColor = .clear
        rim.alpha = 0
        rim.zPosition = 2
        sprite.addChild(rim)

        node.addChild(sprite)
        nodesByChest[chest.id] = sprite
    }
}
