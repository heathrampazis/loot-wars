//
//  ArcadeRenderer.swift
//  Loot Wars
//
//  Machines standing on the map.
//
//  Built once and never touched, until they stopped being fixed for the match:
//  machines are bought and stood up in bases now, and blown up by whoever gets
//  through the wall. So this syncs against the world each frame like the chests do,
//  which is the same amount of code and stops being wrong the moment one appears.
//

import SpriteKit

final class ArcadeRenderer {

    let node = SKNode()

    private var nodesByArcade: [ArcadeID: SKSpriteNode] = [:]

    /// Each machine's payout clock last frame. A clock that has gone UP is a
    /// machine that has just paid: it counts down to zero, drops a token and resets
    /// to the full interval, so the reset is visible from the outside without the
    /// simulation having to announce anything.
    private var lastTimers: [ArcadeID: Double] = [:]
    private var mapHeight = 0

    /// Whether this renderer has ever caught up with the world.
    ///
    /// A machine that APPEARS is normally one somebody has just stood up, and that
    /// is worth an animation - but on the very first sync every machine on the map
    /// appears at once, and eight of them thumping down together would look like a
    /// bug. The map's own machines are all unowned, so today the ownership test
    /// below would have covered it on its own; this is here so that stays true if
    /// this renderer is ever rebuilt mid-match.
    private var hasSynced = false

    /// The damage bar over each machine, and what it is currently drawn at.
    ///
    /// Held so the path is rebuilt on a CHANGE rather than sixty times a second,
    /// the same reason the rims are held elsewhere in this folder.
    private var bars: [ArcadeID: SKShapeNode] = [:]
    private var drawnHealth: [ArcadeID: Int] = [:]

    /// How wide the bar is, in tiles. The footprint is two, and the bar sits just
    /// inside it so it reads as belonging to the machine rather than as a label
    /// laid over the ground beside it.
    private static let barWidthInTiles: Double = 1.7

    /// Shared, because the placement preview draws the same machine before it
    /// exists - and it is drawn WHOLE. This used to be cropped to five pixel
    /// numbers measured off the art by hand, so the sprite could be sized to its
    /// 2 x 3 footprint without the transparent margin pushing the machine in from
    /// the edges. That survived exactly one re-export: the fractions were of a
    /// 926 x 928 canvas, the new image is 818 x 1236, and the same fractions cut
    /// the sides off the cabinet. ArtFit measures the margin instead, every launch.
    static func texture(for kind: ArcadeKind) -> SKTexture {
        if let cached = textures[kind] { return cached }

        let made = SKTexture(imageNamed: kind == .mini ? "Mini Arcade" : "Arcade")
        made.usesMipmaps = true
        textures[kind] = made
        return made
    }

    private static var textures: [ArcadeKind: SKTexture] = [:]

    /// How the machine is drawn, here and in the preview: as big as it goes inside
    /// its 2 x 3 footprint without crossing the edge.
    ///
    /// Inside rather than across. Sizing it to the footprint's WIDTH stood a
    /// cabinet three and a quarter tiles tall on three tiles of ground, and a
    /// machine that overhangs the space it reserved is a machine that looks like it
    /// does not fit - which it does not. The art is drawn narrower than 2:3 for
    /// exactly this reason, so it fills the height and leaves a sliver at the sides.
    static func fit(_ kind: ArcadeKind) -> ArtFit.Fit {
        ArtFit.contained(kind == .mini ? "Mini Arcade" : "Arcade",
                         within: Vec2(x: Double(kind.width), y: Double(kind.height)))
    }

    func build(mapHeight: Int) {
        self.mapHeight = mapHeight
    }

    func sync(with world: World) {
        for (id, machine) in world.arcades where nodesByArcade[id] == nil {
            make(machine)

            // Owned means placed. The map's four belong to nobody and have always
            // been standing there, so they are simply drawn; a machine with a team
            // on it was carried across the map and put down by somebody, which is
            // the single best thing that happens to a base all match.
            if hasSynced, machine.owner != nil {
                standUp(machine)
            }
        }

        hasSynced = true

        for (id, machine) in world.arcades {
            defer { lastTimers[id] = machine.emitTimer }
            guard let sprite = nodesByArcade[id] else { continue }

            // A machine mid-jackpot flashes gold and will not stop until it is
            // over. Driven off the state rather than started by the event, so a
            // machine that was already going when you walked into view is visibly
            // going - the event only says when to CELEBRATE, and arriving late to
            // a jackpot should still look like arriving at a jackpot.
            setJackpot(machine.isJackpot, on: sprite)
            setHealth(of: machine, on: sprite, in: world)

            if let previous = lastTimers[id], machine.emitTimer > previous {
                payOut(sprite)
            }
        }

        for (id, sprite) in Array(nodesByArcade) where world.arcades[id] == nil {
            nodesByArcade[id] = nil
            lastTimers[id] = nil
            drawnHealth[id] = nil

            // The bar goes WITH it, and forgetting the node is the bug this fixes.
            //
            // Dropping the dictionary entry only let go of this file's reference to
            // the fill; the bar node itself was added to the renderer's own node in
            // makeBar and stayed there, parented, drawn, and now belonging to
            // nothing. So a broken machine left an empty bar hanging in the air over
            // the rubble - and left it there for the rest of the match, one more
            // every time anybody broke anything.
            //
            // Faded rather than cut, over half the time the cabinet takes to come
            // apart, so the bar is gone before the machine finishes going and the
            // two read as one event. ChestRenderer has done exactly this for its
            // crack bars all along; this is the same line it has.
            if let bar = bars[id]?.parent {
                bar.run(.sequence([.fadeOut(withDuration: 0.14), .removeFromParent()]))
            }
            bars[id] = nil

            // Blown apart rather than switched off.
            sprite.run(.sequence([
                .group([.scale(to: 1.2, duration: 0.08), .fadeAlpha(to: 0.9, duration: 0.08)]),
                .group([.scale(to: 0.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent()
            ]))
        }
    }

    /// The bar over a machine somebody is shooting.
    ///
    /// Only once it has been hit, and gone again if it is ever repaired. A machine
    /// at full health has nothing to say, and eight of them wearing a full bar all
    /// match would be eight more things on a screen that already has plenty - the
    /// bar is news rather than a label.
    ///
    /// Built on first damage rather than with the machine, for the same reason: the
    /// map's own machines cannot be damaged at all, so most of them never need one.
    ///
    /// In the owner's colour, like the bar over a person, because that is already
    /// the question you are asking when you see one - whose is this.
    private func setHealth(of machine: Arcade, on sprite: SKSpriteNode, in world: World) {
        guard machine.owner != nil else { return }
        guard drawnHealth[machine.id] != machine.health else { return }
        drawnHealth[machine.id] = machine.health

        let share = min(1, max(0, Double(machine.health) / Double(machine.kind.health)))
        let full = GridGeometry.length(ofTiles: ArcadeRenderer.barWidthInTiles)

        guard share < 1 else {
            bars[machine.id]?.parent?.isHidden = true
            return
        }

        let fill = bars[machine.id] ?? makeBar(for: machine, on: sprite, full: full)
        fill.parent?.isHidden = false

        // Re-sited every time it changes rather than once when it is built, because
        // what is standing around a machine is not fixed: a base fills up over a
        // match, and the bar you most need to read is the one on the machine
        // somebody has just squeezed a second machine in beside.
        if let bar = fill.parent { place(bar, for: machine, in: world) }

        // Never shorter than it is tall, or the last sliver of health draws as a
        // rounded rectangle smaller than its own corner radius - which is to say,
        // as nothing, on the one machine you most want to see is nearly gone.
        fill.path = BarArt.path(full: full,
                                filled: max(BarArt.height, full * CGFloat(share)))
    }

    private func makeBar(for machine: Arcade, on sprite: SKSpriteNode, full: CGFloat) -> SKShapeNode {
        let colour = machine.owner.map { RenderPalette.colour(for: $0) } ?? .white
        let (bar, fill) = BarArt.make(full: full, colour: colour)

        // In the scene rather than on the sprite: the sprite is shoved about by the
        // payout squash and the jackpot flash, and a bar riding on it would bounce
        // every time the machine paid out.
        bar.zPosition = sprite.zPosition + 0.5

        node.addChild(bar)
        bars[machine.id] = fill
        return fill
    }

    /// Above the machine, or below it when there is something in the way.
    ///
    /// The bar always sat a third of a tile over the cabinet, which was fine while
    /// a base could hold one machine. Now that they come in twos and threes, the
    /// spot over a machine is quite often the spot ANOTHER machine is standing in -
    /// so the bar for the one being shot was drawn across the face of the one
    /// behind it, on the single occasion you most need to read it.
    ///
    /// So it asks. World.structureOccupies knows about every crate, chest and
    /// machine at once, which is the same question with one answer rather than this
    /// file learning to recognise furniture. If the tile overhead is taken the bar
    /// drops to the machine's feet instead, where there is nothing to collide with
    /// because the machine itself is standing on it.
    private func place(_ bar: SKNode, for machine: Arcade, in world: World) {
        let footing = GridGeometry.point(
            for: Vec2(x: machine.centre.x, y: Double(machine.origin.row)))

        let above = Double(machine.height) + 0.3
        let overhead = GridPoint(containing: Vec2(x: machine.centre.x,
                                                  y: Double(machine.origin.row) + above))

        let offset = world.structureOccupies(overhead)
            ? -ArcadeRenderer.barFootingDrop
            : above

        bar.position = CGPoint(x: footing.x,
                               y: footing.y + GridGeometry.length(ofTiles: offset))
    }

    /// How far below its feet a bar sits when it cannot go above.
    private static let barFootingDrop: Double = 0.45

    /// Shot, rather than blown up.
    ///
    /// A machine taking a bullet used to play the BOMB's flash, which is a blast:
    /// it says the cabinet has just been destroyed, every time, and then the
    /// cabinet is still standing there. This is the casing being struck instead -
    /// the machine flinches and rings white for a moment, and EffectsRenderer
    /// throws the sparks off it.
    func hit(_ id: ArcadeID) {
        guard let sprite = nodesByArcade[id] else { return }

        sprite.removeAction(forKey: "hit")
        sprite.run(.sequence([
            .group([.colorize(with: .white, colorBlendFactor: 0.85, duration: 0.04),
                    .scaleX(to: 1.05, y: 0.95, duration: 0.04)]),
            .group([.scaleX(to: 0.98, y: 1.02, duration: 0.06)]),
            .group([.colorize(withColorBlendFactor: 0, duration: 0.16),
                    .scaleX(to: 1, y: 1, duration: 0.16)])
        ]), withKey: "hit")
    }

    /// A shove and a flash of white, on the beat a token appears.
    ///
    /// A machine that pays out silently is a machine you have to remember to walk
    /// back to. This is the same information as the token itself, given a fifth of
    /// a second earlier and at the size of the cabinet rather than of a coin - so
    /// it is visible from across the base, which is the point.
    private func payOut(_ sprite: SKSpriteNode) {
        sprite.removeAction(forKey: "paid")
        sprite.run(.sequence([
            .group([.scaleX(to: 1.06, y: 0.94, duration: 0.07),
                    .colorize(with: .white, colorBlendFactor: 0.5, duration: 0.07)]),
            .group([.scaleX(to: 1, y: 1, duration: 0.22),
                    .colorize(withColorBlendFactor: 0, duration: 0.22)])
        ]), withKey: "paid")
    }

    /// Set down, rather than switched on.
    ///
    /// The counterpart to the blow-apart in sync, and deliberately its opposite
    /// shape: that one swells and then collapses, this one lands and then settles.
    ///
    /// The sprite is anchored at its feet, so scaling it grows the cabinet UPWARDS
    /// out of the ground rather than out from its middle - which is what makes the
    /// first frames read as a machine being stood up rather than as one being
    /// zoomed in on. It starts flat and wide, snaps up past full height, takes the
    /// weight with a squash, and settles. The white is the same flash a machine
    /// gives when it is hit or when it pays: this file only has one way of saying
    /// "that just happened to the cabinet", and a third one would be a third thing
    /// to learn.
    ///
    /// The aura is the same flourish a wall gets when you lay one - see
    /// BlueprintRenderer.fill, where a copy of the block blooms outward and fades
    /// so the wall looks like it came FROM somewhere rather than switching on. Same
    /// idea here and the same numbers, a third bigger over about a fifth of a
    /// second, with the machine's own silhouette as the shape.
    ///
    /// Struck white rather than tinted, because it is not saying whose this is - a
    /// team colour bloom would be a third thing in the base wearing that colour,
    /// after the walls and the damage bar. It is saying something just landed here,
    /// and white is how the rest of this file says that.
    ///
    /// Anchored at the feet like the cabinet, so it rises off the machine instead
    /// of swelling evenly around its middle three tiles up. That is the one place
    /// this deliberately differs from the wall's version: a wall is a square on the
    /// floor and blooms evenly; a cabinet is a tall thing standing on a footprint.
    ///
    /// Nothing here can be interrupted in practice. A placed machine cannot jackpot
    /// - those are rolled only on the map's own - and its first payout is a full
    /// emitInterval away, so the scale is this animation's alone for the half
    /// second it wants it.
    private func standUp(_ machine: Arcade) {
        guard let sprite = nodesByArcade[machine.id] else { return }

        sprite.xScale = 1.3
        sprite.yScale = 0.06
        sprite.alpha = 0.55
        sprite.color = .white
        sprite.colorBlendFactor = 0.6

        sprite.removeAction(forKey: "placed")
        sprite.run(.sequence([
            .group([.scaleX(to: 0.92, y: 1.12, duration: 0.13),
                    .fadeIn(withDuration: 0.1)]),
            .scaleX(to: 1.06, y: 0.94, duration: 0.07),
            .group([.scaleX(to: 1, y: 1, duration: 0.13),
                    .colorize(withColorBlendFactor: 0, duration: 0.18)])
        ]), withKey: "placed")

        // Copied off the real sprite rather than measured again, so the silhouette
        // cannot land anywhere but exactly over the machine however the fit changes.
        let aura = SKSpriteNode(texture: ArcadeRenderer.texture(for: machine.kind),
                                size: sprite.size)
        aura.anchorPoint = sprite.anchorPoint
        aura.position = sprite.position
        aura.color = .white
        aura.colorBlendFactor = 1
        aura.alpha = 0
        aura.zPosition = sprite.zPosition + 0.4
        node.addChild(aura)

        // Held back until the cabinet has reached its full height, so the bloom
        // punctuates the landing rather than racing it.
        aura.run(.sequence([
            .wait(forDuration: 0.1),
            .fadeAlpha(to: 0.8, duration: 0.04),
            .group([.scale(to: 1.3, duration: 0.2),
                    .fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))
    }

    /// Puts a machine into its jackpot colours, or takes it out of them.
    private func setJackpot(_ on: Bool, on sprite: SKSpriteNode) {
        let running = sprite.action(forKey: "jackpot") != nil
        guard on != running else { return }

        guard on else {
            sprite.removeAction(forKey: "jackpot")
            sprite.run(.colorize(withColorBlendFactor: 0, duration: 0.3))
            return
        }

        sprite.color = RenderPalette.treasure

        sprite.run(.repeatForever(.sequence([
            .colorize(withColorBlendFactor: 0.75, duration: 0.18),
            .colorize(withColorBlendFactor: 0.15, duration: 0.18)
        ])), withKey: "jackpot")
    }

    private func make(_ machine: Arcade) {
        let fit = ArcadeRenderer.fit(machine.kind)

        let sprite = SKSpriteNode(texture: ArcadeRenderer.texture(for: machine.kind),
                                  size: fit.size)

        // Anchored at its feet, so the sprite stands ON the footprint rather than
        // being centred over it - and then dropped by the transparent strip below
        // the cabinet, so it is the MACHINE standing on the footprint rather than
        // the canvas it was exported on.
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)

        let footing = GridGeometry.point(
            for: Vec2(x: machine.centre.x, y: Double(machine.origin.row)))
        sprite.position = CGPoint(x: footing.x - fit.content.midX,
                                  y: footing.y - fit.size.height / 2 - fit.content.minY)

        // Sorted into the same band as the actors, by the line its base sits on. A
        // machine three tiles tall is the first thing in the game big enough for
        // this to matter: walk below one and you pass in front of it, walk above and
        // you go behind.
        let baseLine = Double(machine.origin.row) + GameConfig.Player.halfDepth
        sprite.zPosition = 10 + (Double(mapHeight) - baseLine) * 0.001

        node.addChild(sprite)
        nodesByArcade[machine.id] = sprite
    }
}
