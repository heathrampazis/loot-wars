//
//  GroundItemRenderer.swift
//  Loot Wars
//
//  Items lying on the map. They bob gently so they read as "pick me up" rather than
//  as scenery.
//

import SpriteKit

final class GroundItemRenderer {

    let node = SKNode()

    /// The square an item is drawn to fit inside on the ground, in tiles.
    private static let widthInTiles: Double = 0.8

    /// Tokens are drawn smaller. They arrive in threes and are worth less than
    /// anything else on the floor, so at full size a machine looks like it is
    /// surrounded by treasure.
    private static let tokenWidthInTiles: Double = 0.5

    /// Whether the LOCAL player would pick this up if they walked over it.
    ///
    /// The player's own answer, not a general one: what is junk depends entirely on
    /// what is on your head, so the same helmet is drawn bright for somebody who
    /// needs it and faint for somebody who does not. Bots are not consulted - this
    /// is a mark on the screen, and there is only one person reading it.
    private func wanted(_ item: GroundItem, in world: World) -> Bool {
        guard let player = world.localPlayer else { return true }
        guard case .item(let type) = item.pickup else { return true }
        return player.wantsFromGround(type)
    }

    private static func width(of pickup: Pickup) -> Double {
        if case .token = pickup { return tokenWidthInTiles }
        return widthInTiles
    }

    // Each item's root node: ground glow, beam and the bobbing sprite.
    private var nodesByItem: [GroundItemID: SKNode] = [:]
    /// What each one is, kept for the moment it goes - by then the world has
    /// already forgotten.
    private var pickupByItem: [GroundItemID: Pickup] = [:]

    /// Where the last thing YOU put in your bag was lying, so the icon that
    /// flies into the hotbar starts from there - see GameScene.flyPickup.
    /// Read once and cleared.
    private var collectedByYou: CGPoint?

    func takeCollectedByYou() -> CGPoint? {
        defer { collectedByYou = nil }
        return collectedByYou
    }

    // How tall the light beam above an item is, in tiles; the same for every rarity.
    private static let beamHeight: Double = 0.9

    func sync(with world: World) {
        for (id, item) in world.groundItems {
            guard let sprite = nodesByItem[id] else {
                makeNode(for: item)
                continue
            }

            // Flash once it is nearly gone, so nothing disappears from under
            // somebody who was running for it.
            if item.timeRemaining <= GameConfig.Loot.itemWarningTime,
               sprite.action(forKey: "expiring") == nil {
                sprite.run(.repeatForever(.sequence([
                    .fadeAlpha(to: 0.25, duration: 0.22),
                    .fadeAlpha(to: 1.0, duration: 0.22)
                ])), withKey: "expiring")
            }

            // Gear you already beat is drawn faint, because you will now walk
            // straight over it - see Actor.wantsFromGround. Something the game
            // silently refuses has to LOOK refused, or the player is left thinking
            // the pickup is broken; a helmet at half strength reads as "not for
            // you" at a glance and from a distance, which is where the decision to
            // detour for it is actually made.
            //
            // Skipped while it is flashing out: two things fighting over the same
            // alpha is how a fading item ends up stuck half-visible.
            if sprite.action(forKey: "expiring") == nil {
                sprite.alpha = wanted(item, in: world) ? 1.0 : 0.42
            }
        }

        for (id, sprite) in Array(nodesByItem) where world.groundItems[id] == nil {
            nodesByItem[id] = nil
            sprite.removeAction(forKey: "expiring")
            let pickup = pickupByItem.removeValue(forKey: id)
            let here = GridGeometry.position(for: sprite.position)
            let taker = world.actors.values
                .filter { $0.isAlive && ($0.position - here).length < 1.6 }
                .min { ($0.position - here).length < ($1.position - here).length }

            guard let taker else {
                // Nobody took it - it timed out - so it shrinks away.
                sprite.run(.sequence([
                    .group([Motion.eased(.scale(to: 0.2, duration: 0.16), Motion.cubicIn),
                            .fadeOut(withDuration: 0.16)]),
                    .removeFromParent()
                ]))
                continue
            }
            let hand = GridGeometry.point(for: taker.position + Vec2(x: 0, y: 0.35))

            // Tokens are pulled in like a magnet (Nov 2026): Heath, collecting
            // them "should like magnetise / point towards the player". A tiny
            // pull back, then they shoot into whoever took them, speeding up.
            if case .token = pickup {
                let away = CGVector(dx: sprite.position.x - hand.x, dy: sprite.position.y - hand.y)
                let length = max(1, hypot(away.dx, away.dy))
                let back = CGVector(dx: away.dx / length * 4, dy: away.dy / length * 4)
                sprite.zPosition += 2
                sprite.run(.sequence([
                    Motion.eased(.moveBy(x: back.dx, y: back.dy, duration: 0.05), Motion.cubicOut),
                    .group([Motion.eased(.move(to: hand, duration: 0.16), Motion.cubicIn),
                            Motion.eased(.scale(to: sprite.xScale * 0.45, duration: 0.16), Motion.cubicIn),
                            .sequence([.wait(forDuration: 0.11), .fadeOut(withDuration: 0.05)])]),
                    .removeFromParent()
                ]))
                continue
            }

            // Your own bag items go at once: the icon that flies into your
            // hotbar IS the pickup (GameScene.flyPickup), and drawing this one
            // being pulled in as well was the "double up" Heath saw. It starts
            // from here.
            if taker.id == world.localPlayerID, case .item(let type) = pickup,
               !wornOnPickup(type, by: taker) {
                collectedByYou = sprite.position
                sprite.removeFromParent()
                continue
            }

            // Anybody else's, and gear you put straight on: pulled in to them,
            // shrinking, rather than vanishing where it lay.
            let pull = Motion.eased(.move(to: hand, duration: 0.14), Motion.cubicIn)
            sprite.zPosition += 2
            sprite.run(.sequence([
                .group([pull, Motion.eased(.scale(to: sprite.xScale * 0.3, duration: 0.14), Motion.cubicIn),
                        .sequence([.wait(forDuration: 0.08), .fadeOut(withDuration: 0.06)])]),
                .removeFromParent()
            ]))
        }
    }

    /// Whether this was gear the taker put straight on: they now wear exactly it.
    private func wornOnPickup(_ type: ItemType, by actor: Actor) -> Bool {
        switch type {
        case .helmet(let tier):  return actor.helmet == tier
        case .blaster(let tier): return actor.blaster == tier
        default:                 return false
        }
    }

    private func makeNode(for item: GroundItem) {
        let texture = ItemArt.texture(for: item.pickup)

        let box = GridGeometry.length(ofTiles: GroundItemRenderer.width(of: item.pickup))

        // The glow and beam stay on the ground while only the item itself bobs.
        let root = SKNode()
        root.position = GridGeometry.point(for: item.position)
        root.zPosition = 4

        let sprite = SKSpriteNode(texture: texture,
                                  size: ItemArt.size(of: texture, fittingInto: box))
        root.addChild(sprite)

        // A pool of light under it, the colour of what it is. This is the whole
        // rarity indicator on the map: at the size an item is drawn you cannot read
        // a border, but you can see from across a base whether the thing lying by
        // the crate is grey or gold - which is the difference between a detour and
        // a sprint.
        //
        // A golden token gets one, and ordinary tokens do not. Money is not loot
        // and a puddle of light under every coin would turn a machine into a disco -
        // but ten tokens lying on the grass is worth crossing a map for, and the
        // only way to know that from across one is for it to be lit.
        if case .token(let value) = item.pickup,
           value >= GameConfig.Arcade.goldenValue {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: box * 2.1, height: box * 2.1)
            glow.color = RenderPalette.treasure
            glow.colorBlendFactor = 1
            glow.alpha = 0.85
            glow.zPosition = -0.3
            root.addChild(glow)

            glow.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.5, duration: 0.7), .scale(to: 0.85, duration: 0.7)]),
                .group([.fadeAlpha(to: 0.85, duration: 0.7), .scale(to: 1.0, duration: 0.7)])
            ])))
        }

        if case .item(let type) = item.pickup {
            let colour = RenderPalette.colour(of: type.rarity)
            // Common is drawn at half strength so it does not compete for the eye.
            let strength = RenderPalette.glowStrength(of: type.rarity)
            // Offset per item, so twenty items on the floor do not pulse in unison.
            let phase = Double(item.id.raw % 7) * 0.14

            // A bright pool on the ground, bigger than the item.
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: box * 2.3, height: box * 1.5)
            glow.position = CGPoint(x: 0, y: -box * 0.3)
            glow.color = colour
            glow.colorBlendFactor = 1
            glow.alpha = strength
            glow.zPosition = -0.3
            root.addChild(glow)

            // A smaller, denser core in the middle of the pool, so the colour is rich where it matters.
            let core = SKSpriteNode(texture: GlowArt.pool)
            core.size = CGSize(width: box * 1.3, height: box * 0.8)
            core.position = glow.position
            core.color = colour
            core.colorBlendFactor = 1
            core.alpha = strength
            core.zPosition = -0.25
            root.addChild(core)

            // A crisp ring round it, so the colour still reads against busy ground.
            let ring = SKShapeNode(ellipseOf: CGSize(width: box * 1.35, height: box * 0.6))
            ring.position = glow.position
            ring.fillColor = .clear
            ring.strokeColor = colour
            ring.lineWidth = 2.5
            ring.alpha = 0.9 * strength
            ring.zPosition = -0.2
            root.addChild(ring)

            // A short pillar of light rising out of it, in the rarity colour.
            let tall = GridGeometry.length(ofTiles: GroundItemRenderer.beamHeight)
            let beam = SKSpriteNode(texture: GlowArt.beam)
            beam.size = CGSize(width: box * 0.95, height: tall)
            beam.anchorPoint = CGPoint(x: 0.5, y: 0)
            beam.position = glow.position
            beam.color = colour
            beam.colorBlendFactor = 1
            beam.alpha = 0.95 * strength
            beam.zPosition = -0.1
            root.addChild(beam)

            let breathe: (CGFloat, CGFloat, CGFloat) -> SKAction = { low, high, scale in
                .sequence([
                    .wait(forDuration: phase),
                    .repeatForever(.sequence([
                        .group([.fadeAlpha(to: low * strength, duration: 0.9), .scale(to: scale, duration: 0.9)]),
                        .group([.fadeAlpha(to: high * strength, duration: 0.9), .scale(to: 1.0, duration: 0.9)])
                    ]))
                ])
            }
            glow.run(breathe(0.7, 1.0, 0.9))
            core.run(breathe(0.75, 1.0, 1.1))
            ring.run(breathe(0.55, 0.9, 1.08))
            beam.run(breathe(0.7, 0.95, 1.0))
        }

        // The same sheen the hotbar puts on it, so a power-up is recognisable
        // lying under a tree before you have ever picked one up.
        // Power-ups and everything from Epic up - see ItemType.isEnchanted. On the
        // grass this is what makes a Cosmic helmet read as treasure from across a
        // base, rather than as the same shape with a different coloured puddle
        // under it.
        if case .item(let type) = item.pickup, type.isEnchanted {
            let enchant = EnchantArt.overlay(box: box * 1.15)
            enchant.tint(for: type)
            sprite.addChild(enchant)
        }

        let bob: CGFloat = 4
        sprite.run(.repeatForever(.sequence([
            .moveBy(x: 0, y: bob, duration: 0.6),
            .moveBy(x: 0, y: -bob, duration: 0.6)
        ])))

        // Tokens arrive rather than appear.
        //
        // A machine pays out every couple of seconds and the coin simply existed,
        // one frame to the next, a tile away from the cabinet - so the two things
        // never looked connected, and the payout was easy to miss entirely. It
        // spins up out of nothing now and settles, which is a fifth of a second of
        // animation that turns two separate facts into one event.
        //
        // Only tokens: a bandage that popped and spun would read as being thrown at
        // you, and everything else on the ground was dropped rather than issued.
        if case .token = item.pickup, item.launchedFrom == nil {
            sprite.setScale(0.1)
            sprite.zRotation = -0.9
            sprite.run(.group([
                .sequence([.scale(to: 1.25, duration: 0.14),
                           .scale(to: 1.0, duration: 0.12)]),
                .rotate(toAngle: 0, duration: 0.26)
            ]))
        }

        node.addChild(root)
        nodesByItem[item.id] = root
        pickupByItem[item.id] = item.pickup

        // Flung rather than dropped: something that burst out of a machine flies
        // from the cabinet to where it lands - see GroundItem.launchedFrom.
        if let source = item.launchedFrom {
            launch(root, sprite: sprite, from: source, id: item.id)
        }
    }

    /// Sends a freshly spawned item flying from a point to where it lies.
    ///
    /// A quadratic curve run at a steady pace is exactly the path of something
    /// thrown, so no easing is wanted on the flight itself. Staggered by id, so a
    /// machine's coins leave it one after another rather than as one lump, and
    /// spun in flight with a little squash where they land. Drawn above the
    /// machines while in the air, then dropped back to the ground layer.
    private func launch(_ root: SKNode, sprite: SKSpriteNode, from source: Vec2, id: GroundItemID) {
        let start = GridGeometry.point(for: source)
        let end = root.position
        let lift = GridGeometry.length(ofTiles: GroundItemRenderer.launchLift)

        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(to: end,
                          control: CGPoint(x: (start.x + end.x) / 2,
                                           y: max(start.y, end.y) + lift))

        let delay = 0.1 + Double(id.raw % 6) * 0.05
        let flight = GroundItemRenderer.launchDuration
        let spin: CGFloat = id.raw % 2 == 0 ? .pi * 2 : -.pi * 2

        root.position = start
        root.setScale(0)
        root.zPosition = 15

        root.run(.sequence([
            .wait(forDuration: delay),
            .group([.follow(path, asOffset: false, orientToPath: false, duration: flight),
                    .scale(to: 1, duration: 0.1)]),
            .run { [weak root] in root?.zPosition = 4 }
        ]))

        sprite.run(.sequence([
            .wait(forDuration: delay),
            .rotate(byAngle: spin, duration: flight),
            .scaleX(to: 1.3, y: 0.75, duration: 0.06),
            .scaleX(to: 1, y: 1, duration: 0.14)
        ]))
    }

    /// How high a flung item arcs above its start and end, in tiles, and how
    /// long it is in the air.
    private static let launchLift: Double = 1.4
    private static let launchDuration: Double = 0.45
}
