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
    static let machine: SKTexture = {
        let texture = SKTexture(imageNamed: "Arcade")
        texture.usesMipmaps = true
        return texture
    }()

    /// How the machine is drawn, here and in the preview: as big as it goes inside
    /// its 2 x 3 footprint without crossing the edge.
    ///
    /// Inside rather than across. Sizing it to the footprint's WIDTH stood a
    /// cabinet three and a quarter tiles tall on three tiles of ground, and a
    /// machine that overhangs the space it reserved is a machine that looks like it
    /// does not fit - which it does not. The art is drawn narrower than 2:3 for
    /// exactly this reason, so it fills the height and leaves a sliver at the sides.
    static func fit() -> ArtFit.Fit {
        ArtFit.contained("Arcade",
                         within: Vec2(x: Double(Arcade.width), y: Double(Arcade.height)))
    }

    func build(mapHeight: Int) {
        self.mapHeight = mapHeight
    }

    func sync(with world: World) {
        for (id, machine) in world.arcades where nodesByArcade[id] == nil {
            make(machine)
        }

        for (id, machine) in world.arcades {
            defer { lastTimers[id] = machine.emitTimer }
            guard let sprite = nodesByArcade[id] else { continue }

            // A machine mid-jackpot flashes gold and will not stop until it is
            // over. Driven off the state rather than started by the event, so a
            // machine that was already going when you walked into view is visibly
            // going - the event only says when to CELEBRATE, and arriving late to
            // a jackpot should still look like arriving at a jackpot.
            setJackpot(machine.isJackpot, on: sprite)
            setHealth(of: machine, on: sprite)

            if let previous = lastTimers[id], machine.emitTimer > previous {
                payOut(sprite)
            }
        }

        for (id, sprite) in Array(nodesByArcade) where world.arcades[id] == nil {
            nodesByArcade[id] = nil
            lastTimers[id] = nil
            bars[id] = nil
            drawnHealth[id] = nil

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
    private func setHealth(of machine: Arcade, on sprite: SKSpriteNode) {
        guard machine.owner != nil else { return }
        guard drawnHealth[machine.id] != machine.health else { return }
        drawnHealth[machine.id] = machine.health

        let share = min(1, max(0, Double(machine.health) / Double(GameConfig.Arcade.health)))
        let full = GridGeometry.length(ofTiles: ArcadeRenderer.barWidthInTiles)

        guard share < 1 else {
            bars[machine.id]?.parent?.isHidden = true
            return
        }

        let fill = bars[machine.id] ?? makeBar(for: machine, on: sprite, full: full)
        fill.parent?.isHidden = false

        // Never shorter than it is tall, or the last sliver of health draws as a
        // rounded rectangle smaller than its own corner radius - which is to say,
        // as nothing, on the one machine you most want to see is nearly gone.
        fill.path = BarArt.path(full: full,
                                filled: max(BarArt.height, full * CGFloat(share)))
    }

    private func makeBar(for machine: Arcade, on sprite: SKSpriteNode, full: CGFloat) -> SKShapeNode {
        let colour = machine.owner.map { RenderPalette.colour(for: $0) } ?? .white
        let (bar, fill) = BarArt.make(full: full, colour: colour)

        // Above the cabinet, in the scene rather than on the sprite: the sprite is
        // shoved about by the payout squash and the jackpot flash, and a bar riding
        // on it would bounce every time the machine paid out.
        let footing = GridGeometry.point(
            for: Vec2(x: machine.centre.x, y: Double(machine.origin.row)))

        bar.position = CGPoint(
            x: footing.x,
            y: footing.y + GridGeometry.length(ofTiles: Double(Arcade.height) + 0.3))
        bar.zPosition = sprite.zPosition + 0.5

        node.addChild(bar)
        bars[machine.id] = fill
        return fill
    }

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
        let fit = ArcadeRenderer.fit()

        let sprite = SKSpriteNode(texture: ArcadeRenderer.machine, size: fit.size)

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
