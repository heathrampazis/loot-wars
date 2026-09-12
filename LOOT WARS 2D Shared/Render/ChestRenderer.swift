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

    /// The bar shown while a chest is being broken open, and how full it was drawn.
    private var cracks: [ChestID: SKShapeNode] = [:]
    private var drawnCrack: [ChestID: Double] = [:]

    /// Which band of the crack each chest's shudder is currently drawn at.
    ///
    /// Held so the shake is restarted four times over two seconds rather than sixty
    /// times a second. The progress itself moves every frame, and an SKAction that
    /// is replaced every frame never gets anywhere - see the note in
    /// EffectsRenderer about values rewritten each tick. Bands are how this file
    /// animates something continuous.
    private var crackStep: [ChestID: Int] = [:]

    /// How many bands the two seconds are cut into, and how much bigger the chest
    /// gets at each one. Four steps of seven per cent, so a chest a moment from
    /// coming open is standing a fifth larger than it did and buzzing twice as fast.
    private static let crackSteps = 4
    private static let crackGrowth: CGFloat = 0.07

    /// Narrower than the chest, so it reads as a thing happening TO the chest
    /// rather than as a label sitting beside it.
    private static let crackBarInTiles: Double = 0.8

    func sync(with world: World) {
        for (id, chest) in world.chests where nodesByChest[id] == nil {
            make(chest)
        }

        for (id, sprite) in Array(nodesByChest) where world.chests[id] == nil {
            nodesByChest[id] = nil
            if lit == id { lit = nil }
            cracks[id]?.parent?.removeFromParent()
            cracks[id] = nil
            drawnCrack[id] = nil
            crackStep[id] = nil
            smash(sprite)
        }

        for (id, sprite) in nodesByChest {
            setCracking(world.crackShare(of: id), of: id, on: sprite)
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

    /// A chest with somebody working on it.
    ///
    /// Two things at once, and they are saying different halves of it. The bar is
    /// how far through they are; the shudder is that it is happening at all, which
    /// has to be readable from across a base by the person sprinting home. Both
    /// come off the world's own state rather than from an event, because a crack
    /// starting, being interrupted and resuming are all just that number moving -
    /// an interrupt is the bar dropping to nothing, which says it better than any
    /// announcement would.
    private func setCracking(_ share: Double?, of id: ChestID, on sprite: SKSpriteNode) {
        guard drawnCrack[id] != share else { return }
        let was = drawnCrack[id]
        drawnCrack[id] = share

        guard let share else {
            cracks[id]?.parent?.isHidden = true
            sprite.removeAction(forKey: "cracking")
            sprite.run(.group([.rotate(toAngle: 0, duration: 0.12),
                               .scaleX(to: 1, y: 1, duration: 0.12)]))
            cracks[id] = nil
            crackStep[id] = nil
            return
        }

        let full = GridGeometry.length(ofTiles: ChestRenderer.crackBarInTiles)
        let fill = cracks[id] ?? makeCrackBar(for: id, on: sprite, full: full)
        fill.parent?.isHidden = false
        fill.path = BarArt.path(full: full,
                                filled: max(BarArt.height, full * CGFloat(share)))

        // Starting, starting again after somebody put a shot into them, or simply
        // further through than it was.
        let step = min(ChestRenderer.crackSteps - 1,
                       max(0, Int(share * Double(ChestRenderer.crackSteps))))
        let restarted = was == nil || share < (was ?? 0)

        guard restarted || crackStep[id] != step else { return }
        crackStep[id] = step
        shudder(sprite, step: step)
    }

    /// The chest swelling and buzzing harder the closer it is to coming open.
    ///
    /// It used to shake at one fixed amplitude for the whole two seconds, which
    /// said "this is happening" and nothing else - the bar carried all of the
    /// progress and the chest carried none of it. Now the thing itself is the
    /// countdown: it grows, and it rattles faster, and by the last band it is
    /// visibly straining against itself. Then it comes apart, and smash below picks
    /// up from exactly where this left it rather than starting over at full size.
    ///
    /// Four discrete bands rather than a smooth ramp, because an SKAction replaced
    /// every frame never plays. Four is enough to read as continuous and few enough
    /// that each one lands as a distinct lurch.
    private func shudder(_ sprite: SKSpriteNode, step: Int) {
        let reach = CGFloat(step)
        let grow = 1 + ChestRenderer.crackGrowth * reach
        let tilt = 0.045 + 0.022 * reach
        let beat = TimeInterval(0.05 - 0.008 * Double(step))

        sprite.removeAction(forKey: "cracking")
        sprite.run(.repeatForever(.sequence([
            .group([.rotate(toAngle: tilt, duration: beat),
                    .scaleX(to: grow * 1.03, y: grow * 0.97, duration: beat)]),
            .group([.rotate(toAngle: -tilt, duration: beat),
                    .scaleX(to: grow * 0.98, y: grow * 1.02, duration: beat)])
        ])), withKey: "cracking")
    }

    private func makeCrackBar(for id: ChestID, on sprite: SKSpriteNode, full: CGFloat) -> SKShapeNode {
        // In the raider's red rather than a team colour: this is not information
        // about whose chest it is - the base around it already said that - it is a
        // countdown to losing it.
        let (bar, fill) = BarArt.make(full: full, colour: RenderPalette.placementBlocked)

        // In the scene rather than on the sprite, which is shaking.
        bar.position = CGPoint(x: sprite.position.x,
                               y: sprite.position.y + GridGeometry.length(ofTiles: 0.75))
        bar.zPosition = sprite.zPosition + 0.5

        node.addChild(bar)
        cracks[id] = fill
        return fill
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
    /// taken apart.
    ///
    /// It BURSTS now rather than shaking twice and shrinking. shudder above has
    /// spent two seconds swelling the chest and buzzing it harder, so the old
    /// opening frame - a squash to 1.14 - was actually smaller than where the
    /// shudder had already got to, and the smash began by deflating. Now it carries
    /// straight on: a hard wrench, a bigger one the other way, a swell past
    /// anything the shudder reached, and then it is gone in a fifth of a second.
    ///
    /// The collapse at the end is what sells it as bursting rather than as
    /// exploding outward. Nothing here is thrown clear - the contents are already
    /// scattered on the grass by ChestSystem and they are the debris.
    private func smash(_ sprite: SKSpriteNode) {
        // Whatever was shaking it has had its answer.
        sprite.removeAction(forKey: "cracking")
        sprite.childNode(withName: ChestRenderer.rimName)?.removeFromParent()

        sprite.run(.sequence([
            .group([.rotate(toAngle: 0.14, duration: 0.04),
                    .scaleX(to: 1.42, y: 1.08, duration: 0.04)]),
            .group([.rotate(toAngle: -0.17, duration: 0.05),
                    .scaleX(to: 1.26, y: 1.44, duration: 0.05)]),
            .group([.rotate(toAngle: 0.08, duration: 0.06),
                    .scale(to: 1.72, duration: 0.06),
                    .fadeAlpha(to: 0.92, duration: 0.06)]),
            .group([.scale(to: 0.15, duration: 0.18),
                    .rotate(byAngle: -0.7, duration: 0.18),
                    .moveBy(x: 0, y: 8, duration: 0.18),
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
