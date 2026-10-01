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

    /// The soft shadow on the ground under each machine. Kept apart from the
    /// sprite so the squash of a payout or a hit does not stretch the shadow.
    private var shadows: [ArcadeID: SKSpriteNode] = [:]

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

            if let shadow = shadows.removeValue(forKey: id) {
                shadow.run(.sequence([
                    .wait(forDuration: 0.12),
                    .group([.scale(to: 0.3, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                    .removeFromParent()
                ]))
            }

            breakApart(sprite)
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

        spurt(from: sprite)
    }

    /// Tokens knocked out of a machine being shot.
    ///
    /// Purely for show: they are not on the ground, nobody can pick them up, and
    /// they vanish as they land. What they say is that the thing being shot has
    /// money in it - which is the reason to be shooting it - and every hit shakes
    /// a little loose. The real payout is the spill when it breaks.
    ///
    /// Held to one spurt every so often per machine, so a fast blaster pours a
    /// steady stream rather than a fountain.
    private func spurt(from sprite: SKSpriteNode) {
        guard sprite.action(forKey: "spurt") == nil else { return }
        sprite.run(.wait(forDuration: ArcadeRenderer.spurtGap), withKey: "spurt")

        let texture = ItemArt.texture(for: .token(GameConfig.Arcade.tokenValue))
        let box = GridGeometry.length(ofTiles: ArcadeRenderer.spurtCoinSize)
        let size = ItemArt.size(of: texture, fittingInto: box)

        // From the cabinet's face, a little above its middle.
        let mouth = CGPoint(x: sprite.position.x,
                            y: sprite.position.y + sprite.size.height * 0.55)

        for index in 0..<ArcadeRenderer.spurtCount {
            let coin = SKSpriteNode(texture: texture, size: size)
            coin.position = CGPoint(x: mouth.x + CGFloat.random(in: -0.2...0.2) * sprite.size.width,
                                    y: mouth.y)
            coin.zPosition = sprite.zPosition + 0.6
            coin.setScale(0.5)
            node.addChild(coin)

            // Up and out to one side, then falling past where it started.
            let side: CGFloat = (index % 2 == 0 ? 1 : -1) * (Bool.random() ? 1 : 0.7)
            let across = GridGeometry.length(ofTiles: Double.random(in: 0.5...1.1)) * side
            let rise = GridGeometry.length(ofTiles: Double.random(in: 0.5...0.9))
            let drop = GridGeometry.length(ofTiles: Double.random(in: 0.9...1.4))

            let up = SKAction.moveBy(x: across * 0.45, y: rise, duration: 0.2)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: across * 0.55, y: -drop, duration: 0.32)
            down.timingMode = .easeIn

            coin.run(.sequence([
                .group([
                    .sequence([up, down]),
                    .rotate(byAngle: .pi * 3 * side, duration: 0.52),
                    .sequence([.scale(to: 1, duration: 0.1),
                               .wait(forDuration: 0.24),
                               .group([.scale(to: 0.4, duration: 0.18),
                                       .fadeOut(withDuration: 0.18)])])
                ]),
                .removeFromParent()
            ]))
        }
    }

    /// How many coins a hit knocks out, how big they are in tiles, and the
    /// shortest gap between two spurts from one machine.
    private static let spurtCount = 2
    private static let spurtCoinSize: Double = 0.38
    private static let spurtGap: Double = 0.09

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
    /// It grows into place where it stands - no fall, no landing - overshooting a
    /// touch and settling, while a white flash drains out of it and a few gold
    /// sparkles twinkle round it. The shadow fades in underneath at the same time.
    /// The counterpart to breakApart, and deliberately gentler: arriving is good
    /// news, not an impact.
    ///
    /// Anchored at its feet, so it grows up out of its footprint rather than
    /// swelling about its middle.
    ///
    /// Nothing here can be interrupted in practice. A placed machine cannot jackpot
    /// - those are rolled only on the map's own - and its first payout is a full
    /// emitInterval away, so the scale is this animation's alone while it runs.
    private func standUp(_ machine: Arcade) {
        guard let sprite = nodesByArcade[machine.id] else { return }

        sprite.setScale(0.6)
        sprite.alpha = 0
        sprite.color = .white
        sprite.colorBlendFactor = 0.75

        let grow = SKAction.scale(to: 1.06, duration: 0.2)
        grow.timingMode = .easeOut
        let settle = SKAction.scale(to: 1, duration: 0.14)
        settle.timingMode = .easeInEaseOut

        sprite.removeAction(forKey: "placed")
        sprite.run(.group([
            .sequence([grow, settle]),
            .fadeIn(withDuration: 0.16),
            .sequence([.wait(forDuration: 0.12),
                       .colorize(withColorBlendFactor: 0, duration: 0.3)])
        ]), withKey: "placed")

        if let shadow = shadows[machine.id] {
            shadow.setScale(0.6)
            shadow.alpha = 0
            shadow.run(.group([
                .scale(to: 1, duration: 0.3),
                .fadeAlpha(to: ArcadeRenderer.shadowAlpha, duration: 0.3)
            ]))
        }

        sparkle(round: machine, on: sprite)
    }

    /// A few gold stars twinkling round a machine as it appears.
    private func sparkle(round machine: Arcade, on sprite: SKSpriteNode) {
        let width = sprite.size.width
        let height = sprite.size.height

        for index in 0..<6 {
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.22...0.36))
            star.size = CGSize(width: side, height: side)
            star.color = RenderPalette.treasure
            star.colorBlendFactor = 0.5
            star.position = CGPoint(
                x: sprite.position.x + CGFloat.random(in: -0.6...0.6) * width,
                y: sprite.position.y + CGFloat.random(in: 0.15...0.95) * height)
            star.zPosition = sprite.zPosition + 0.5
            star.setScale(0)
            node.addChild(star)

            star.run(.sequence([
                .wait(forDuration: 0.08 + Double(index) * 0.05),
                .group([.scale(to: 1, duration: 0.14),
                        .rotate(byAngle: 1.2, duration: 0.4)]),
                .group([.scale(to: 0, duration: 0.2),
                        .fadeOut(withDuration: 0.2)]),
                .removeFromParent()
            ]))
        }
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

        // A soft shadow under its feet, so the cabinet stands ON the ground rather
        // than being pasted over it. Wider than tall and a little in from the
        // footprint's edges, so it reads as contact rather than as a dark patch.
        let shadow = SKSpriteNode(texture: GlowArt.pool)
        shadow.size = CGSize(
            width: GridGeometry.length(ofTiles: Double(machine.kind.width) * ArcadeRenderer.shadowWidth),
            height: GridGeometry.length(ofTiles: ArcadeRenderer.shadowHeight))
        shadow.position = CGPoint(x: footing.x,
                                  y: footing.y + GridGeometry.length(ofTiles: ArcadeRenderer.shadowLift))
        shadow.color = .black
        shadow.colorBlendFactor = 1
        shadow.alpha = ArcadeRenderer.shadowAlpha

        // On the ground: above the floor and the claim tint, below chests, items
        // and everything standing up.
        shadow.zPosition = 1
        node.addChild(shadow)
        shadows[machine.id] = shadow
    }

    /// The shadow's size against the footprint, in tiles, and how dark it is.
    private static let shadowWidth: Double = 0.95
    private static let shadowHeight: Double = 0.75
    private static let shadowLift: Double = 0.2
    private static let shadowAlpha: CGFloat = 0.4

    /// Broken apart rather than switched off.
    ///
    /// Three beats. It shudders and rings white - the hit that finished it - then
    /// swells as if something inside has gone, then bursts: the cabinet drops away
    /// to nothing while chunks of it are thrown off. The tokens it held fly out at
    /// the same moment (GroundItemRenderer, from GroundItem.launchedFrom), so the
    /// burst is the coins leaving rather than a separate thing that happens near
    /// them.
    private func breakApart(_ sprite: SKSpriteNode) {
        sprite.removeAllActions()
        sprite.color = .white

        let jolt: CGFloat = 4
        let shudder = SKAction.sequence([
            .moveBy(x: jolt, y: 0, duration: 0.025),
            .moveBy(x: -jolt * 2, y: 0, duration: 0.03),
            .moveBy(x: jolt * 2, y: 0, duration: 0.03),
            .moveBy(x: -jolt, y: 0, duration: 0.025)
        ])

        sprite.run(.sequence([
            .group([shudder,
                    .colorize(withColorBlendFactor: 0.8, duration: 0.05)]),
            .group([.scaleX(to: 1.14, y: 1.08, duration: 0.07),
                    .colorize(withColorBlendFactor: 1, duration: 0.07)]),
            .run { [weak self] in self?.debris(from: sprite) },
            .group([.scaleX(to: 1.3, y: 0.15, duration: 0.18),
                    .fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
    }

    /// Pieces of cabinet thrown off as it goes. Plain blocks in the machine's
    /// dark trim, tumbling up and out and falling away - the same flat, outlined
    /// look as everything else rather than a particle cloud.
    private func debris(from sprite: SKSpriteNode) {
        let middle = CGPoint(x: sprite.position.x,
                             y: sprite.position.y + sprite.size.height * 0.4)
        let count = 7

        for index in 0..<count {
            let side = GridGeometry.length(ofTiles: Double.random(in: 0.16...0.28))
            let chunk = SKShapeNode(rectOf: CGSize(width: side, height: side * 0.8),
                                    cornerRadius: side * 0.15)
            chunk.fillColor = index % 3 == 0 ? RenderPalette.treasure
                                             : SKColor(white: 0.22, alpha: 1)
            chunk.strokeColor = .black
            chunk.lineWidth = 1.5
            chunk.position = middle
            chunk.zPosition = sprite.zPosition + 0.6
            node.addChild(chunk)

            let angle = (Double(index) / Double(count)) * 2 * .pi
                + Double.random(in: -0.3...0.3)
            let reach = GridGeometry.length(ofTiles: Double.random(in: 0.8...1.4))
            let dx = CGFloat(cos(angle)) * reach
            let rise = GridGeometry.length(ofTiles: Double.random(in: 0.5...0.9))
            let fall = CGFloat(sin(angle)) * reach * 0.5 - rise * 0.6

            let up = SKAction.moveBy(x: dx * 0.5, y: rise, duration: 0.18)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: dx * 0.5, y: fall, duration: 0.3)
            down.timingMode = .easeIn

            chunk.run(.sequence([
                .group([.sequence([up, down]),
                        .rotate(byAngle: CGFloat.random(in: -6...6), duration: 0.48),
                        .sequence([.wait(forDuration: 0.3),
                                   .fadeOut(withDuration: 0.18)])]),
                .removeFromParent()
            ]))
        }
    }
}
