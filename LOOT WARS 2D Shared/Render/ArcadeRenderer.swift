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

    /// The machine's opaque pixels within its canvas, measured from the artwork:
    /// 496 x 808 at (215, 56) of a 926 x 928 image, with y flipped because texture
    /// coordinates count up from the bottom.
    ///
    /// Cropping to this rather than trimming the asset means the sprite can be
    /// drawn at exactly its 2 x 3 footprint - the machine you see is the machine
    /// you walk into. Re-export the art and these five numbers need remeasuring.
    private static let artwork = CGRect(x: 215.0 / 926.0,
                                        y: 64.0 / 928.0,
                                        width: 496.0 / 926.0,
                                        height: 808.0 / 928.0)

    /// Shared, because the placement preview draws the same machine before it
    /// exists. Two copies of the crop would be two chances to remeasure only one.
    static let machine: SKTexture = {
        let sheet = SKTexture(imageNamed: "Arcade")
        let cropped = SKTexture(rect: ArcadeRenderer.artwork, in: sheet)
        cropped.usesMipmaps = true
        return cropped
    }()

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

            if let previous = lastTimers[id], machine.emitTimer > previous {
                payOut(sprite)
            }
        }

        for (id, sprite) in Array(nodesByArcade) where world.arcades[id] == nil {
            nodesByArcade[id] = nil
            lastTimers[id] = nil

            // Blown apart rather than switched off.
            sprite.run(.sequence([
                .group([.scale(to: 1.2, duration: 0.08), .fadeAlpha(to: 0.9, duration: 0.08)]),
                .group([.scale(to: 0.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent()
            ]))
        }
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
        let sprite = SKSpriteNode(
            texture: ArcadeRenderer.machine,
            size: CGSize(width: GridGeometry.length(ofTiles: Double(Arcade.width)),
                         height: GridGeometry.length(ofTiles: Double(Arcade.height))))

        // Anchored at its feet, so the sprite stands ON the footprint rather than
        // being centred over it.
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.position = GridGeometry.point(
            for: Vec2(x: machine.centre.x, y: Double(machine.origin.row)))

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
