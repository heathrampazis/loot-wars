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

    /// The damage bar over each chest, and what it is currently drawn at.
    ///
    /// The same pair ArcadeRenderer holds, for the same reasons, and this file now
    /// answers the question the same way the machines do.
    ///
    /// It used to draw the damage by SHAKING the chest instead - swelling it and
    /// buzzing it harder in four bands as a raid went on. That was written when a
    /// raid was a two second timer, where a chest under the clock was a chest
    /// somebody was actively holding, and a permanent rattle was true for exactly
    /// as long as that lasted. A chest has HEALTH now, and health is a state rather
    /// than an act: a chest somebody put two shots into and walked away from would
    /// have sat buzzing in an empty base for eleven seconds while it mended. A bar
    /// says how much is left; a shake says it is happening right now. Only one of
    /// those is the truth about a damaged chest standing still.
    private var bars: [ChestID: SKShapeNode] = [:]
    private var drawnHealth: [ChestID: Int] = [:]

    /// How wide the bar is, in tiles. A chest is 0.95 across and the bar sits just
    /// inside it, so it reads as belonging to the chest rather than as a label laid
    /// on the ground beside it.
    private static let barWidthInTiles: Double = 0.8

    func sync(with world: World) {
        for (id, chest) in world.chests where nodesByChest[id] == nil {
            make(chest)
        }

        for (id, sprite) in Array(nodesByChest) where world.chests[id] == nil {
            nodesByChest[id] = nil
            if lit == id { lit = nil }
            drawnHealth[id] = nil

            // The bar goes WITH it, faded over half the time the chest takes to
            // come apart, so it is gone before the burst finishes and the two read
            // as one event. Forgetting the NODE rather than the dictionary entry is
            // the bug ArcadeRenderer records at length: dropping the entry only
            // lets go of this file's reference, and leaves an empty bar hanging in
            // the air over the wreckage for the rest of the match.
            if let bar = bars[id]?.parent {
                bar.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
            }
            bars[id] = nil

            smash(sprite)
        }

        for (id, sprite) in nodesByChest {
            if let chest = world.chests[id] {
                setHealth(of: chest, on: sprite, in: world)
            }
        }

        // The chest within arm's reach wears a rim, exactly as a crate does.
        //
        // YOURS ONLY now, and it used to be both. The rim answers "can you touch
        // this", and touching somebody else's used to open it - the corner button
        // wore a crowbar glyph and that was the whole interaction. A chest is shot
        // open now, so the answer on an enemy chest is no, and a rim on one would
        // be the screen offering something that does not happen. The player is told
        // what DOES happen instead, once, by the hint in GameScene.updateHint.
        //
        // Asked with the same question the tap and the button use, so the outline
        // can never light up on something the simulation would then refuse.
        let reachable = world.localPlayer.flatMap { player -> ChestID? in
            guard player.isAlive,
                  let chest = world.reachableChest(for: player),
                  chest.owner == player.team else { return nil }
            return chest.id
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

    /// The bar over a chest somebody is shooting.
    ///
    /// Only once it has been hit, and gone again once it has mended. A chest at
    /// full health has nothing to say, and every chest on the map wearing a full
    /// bar all match would be several more things on a busy screen - the bar is
    /// news rather than a label.
    ///
    /// In the OWNER's colour, like the bar over a machine and the bar over a
    /// person, because whose this is happens to be the question you are asking the
    /// moment you see one.
    private func setHealth(of chest: Chest, on sprite: SKSpriteNode, in world: World) {
        guard drawnHealth[chest.id] != chest.health else { return }
        drawnHealth[chest.id] = chest.health

        let share = min(1, max(0, Double(chest.health) / Double(GameConfig.Chest.health)))
        let full = GridGeometry.length(ofTiles: ChestRenderer.barWidthInTiles)

        guard share < 1 else {
            bars[chest.id]?.parent?.isHidden = true
            return
        }

        let fill = bars[chest.id] ?? makeBar(for: chest, on: sprite, full: full)
        fill.parent?.isHidden = false

        // Re-sited every time it changes rather than once when it is built, for the
        // reason ArcadeRenderer.place gives: what is standing around a chest is not
        // fixed, and a base fills up over a match.
        if let bar = fill.parent { place(bar, for: chest, in: world) }

        // Never shorter than it is tall, or the last sliver draws as a rounded
        // rectangle smaller than its own corner radius - which is to say as
        // nothing, on the one chest you most want to see is nearly gone.
        fill.path = BarArt.path(full: full,
                                filled: max(BarArt.height, full * CGFloat(share)))
    }

    private func makeBar(for chest: Chest, on sprite: SKSpriteNode, full: CGFloat) -> SKShapeNode {
        let (bar, fill) = BarArt.make(full: full,
                                      colour: RenderPalette.colour(for: chest.owner))

        // In the scene rather than on the sprite: the sprite is knocked about by
        // the flinch on every hit, and a bar riding on it would jump with each one.
        bar.zPosition = sprite.zPosition + 0.5

        node.addChild(bar)
        bars[chest.id] = fill
        return fill
    }

    /// Above the chest, or below it when there is something in the way.
    ///
    /// The same question ArcadeRenderer.place asks, and it matters more here: a
    /// chest stands against the inside of somebody's wall as often as not, and the
    /// tile over it is frequently that wall. World.structureOccupies knows about
    /// every crate, chest and machine at once.
    private func place(_ bar: SKNode, for chest: Chest, in world: World) {
        let above = 0.75
        let overhead = GridPoint(containing: Vec2(x: chest.position.x,
                                                  y: chest.position.y + above))

        let offset = world.structureOccupies(overhead)
            ? -ChestRenderer.barFootingDrop
            : above

        let footing = GridGeometry.point(for: chest.position)
        bar.position = CGPoint(x: footing.x,
                               y: footing.y + GridGeometry.length(ofTiles: offset))
    }

    /// How far below its feet a bar sits when it cannot go above.
    private static let barFootingDrop: Double = 0.5

    /// Shot, and still standing.
    ///
    /// The machine's flinch, deliberately the same one: a struck chest and a struck
    /// cabinet are the same event, and giving them two different reactions would be
    /// two things to learn where the board already has one.
    ///
    /// A flinch is not the shake this replaced, and the difference is the whole
    /// point. This happens ON a hit and is over in a quarter of a second, so it
    /// says a shot just landed. The shake was a STATE, and a state is what the bar
    /// is for.
    func hit(_ id: ChestID) {
        guard let sprite = nodesByChest[id] else { return }

        sprite.removeAction(forKey: "hit")
        sprite.run(.sequence([
            .group([.colorize(with: .white, colorBlendFactor: 0.85, duration: 0.04),
                    .scaleX(to: 1.06, y: 0.94, duration: 0.04)]),
            .group([.scaleX(to: 0.97, y: 1.03, duration: 0.06)]),
            .group([.colorize(withColorBlendFactor: 0, duration: 0.16),
                    .scaleX(to: 1, y: 1, duration: 0.16)])
        ]), withKey: "hit")
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
    /// It BURSTS rather than shaking twice and shrinking: a hard wrench, a bigger
    /// one the other way, a swell, and then it is gone in a fifth of a second.
    ///
    /// It used to open bigger than this, because the shake it followed had already
    /// swollen the chest by a fifth and anything smaller would have begun by
    /// deflating. The shake is gone, so the chest is at REST when this starts and
    /// the first frame is back to being a squash - which is what a thing bursting
    /// does, and what the swell two frames later is measured against.
    ///
    /// The collapse at the end is what sells it as bursting rather than as
    /// exploding outward. Nothing here is thrown clear - the contents are already
    /// scattered on the grass by ChestSystem and they are the debris.
    private func smash(_ sprite: SKSpriteNode) {
        sprite.childNode(withName: ChestRenderer.rimName)?.removeFromParent()

        sprite.removeAction(forKey: "hit")
        sprite.run(.sequence([
            .group([.rotate(toAngle: 0.14, duration: 0.04),
                    .scaleX(to: 1.22, y: 0.86, duration: 0.04)]),
            .group([.rotate(toAngle: -0.17, duration: 0.05),
                    .scaleX(to: 1.30, y: 1.40, duration: 0.05)]),
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
