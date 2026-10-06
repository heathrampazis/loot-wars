//
//  LootboxRenderer.swift
//  Loot Wars
//
//  Lootboxes never move, so their sprites are positioned once and then left alone.
//  The renderer only watches for boxes appearing and disappearing - and gives each
//  one an idle, because forty-two things standing perfectly still is what makes a
//  map look like a diagram of a level rather than a place.
//
//  The idle is a ROCK and an occasional THUMP, and the pair is doing something the
//  breathing figures are not. A person breathing says "alive". A crate cannot be
//  alive, so the animation has to say the other true thing about it: there is
//  something in here. It leans very slightly side to side, as though not quite
//  settled on the ground, and every few seconds something inside knocks and the
//  whole box jumps.
//
//  Nothing is in step with anything else. Every crate takes its phase and its
//  timings from its own id, which is what stops forty-two of them reading as one
//  mechanism - and takes them from the ID rather than at random so a fixed seed
//  still replays identically.
//

import SpriteKit

final class LootboxRenderer {

    let node = SKNode()

    private var nodesByBox: [LootboxID: SKSpriteNode] = [:]

    /// Which crate is currently wearing the "you can open this" rim.
    ///
    /// Held so the rim is faded in and out on a CHANGE rather than re-run every
    /// frame. sync is called sixty times a second, and an action started on each of
    /// them never gets past its first frame - which is how you end up with an
    /// outline that is permanently half visible and never animates.
    private var lit: LootboxID?

    /// Whether this renderer has caught up with the world once. A rare crate that
    /// appears after that has just respawned rare mid-match, and gets an entrance.
    private var hasSynced = false

    private static let rimName = "reach"


    private lazy var ordinary: SKTexture = Self.load("LootboxRed")
    private lazy var rare: SKTexture = Self.load("LootboxRare")

    private static func load(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true
        return texture
    }

    func sync(with world: World) {
        // Supply drops are drawn by SupplyDropRenderer.
        for (id, box) in world.lootboxes where nodesByBox[id] == nil && !box.supply {
            makeNode(for: box)
            if hasSynced, box.rare { arrive(id) }
        }
        hasSynced = true

        for (id, sprite) in Array(nodesByBox) where world.lootboxes[id] == nil {
            nodesByBox[id] = nil
            sprite.removeFromParent()
        }

        // The one crate within arm's reach wears a rim, so "you can touch this"
        // is answered by the thing itself rather than by a button somewhere else.
        //
        // Asked of the world with the same question the tap and the corner button
        // both use, so the outline can never light up on something the simulation
        // would then refuse to open.
        let reachable = world.localPlayer.flatMap { player in
            player.isAlive ? world.reachableLootbox(for: player)?.id : nil
        }

        guard reachable != lit else { return }

        if let lit { setRim(on: nodesByBox[lit], showing: false) }
        lit = reachable
        if let reachable { setRim(on: nodesByBox[reachable], showing: true) }
    }

    private func setRim(on sprite: SKSpriteNode?, showing: Bool) {
        guard let rim = sprite?.childNode(withName: LootboxRenderer.rimName) else { return }

        rim.removeAllActions()
        rim.run(.fadeAlpha(to: showing ? 0.85 : 0, duration: showing ? 0.12 : 0.18))
    }

    private func makeNode(for box: Lootbox) {
        // Drawn at exactly the collision size, so the crate you see is the crate
        // you bump into. GameConfig.Loot.lootboxSize matches the art's proportions.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x),
                          height: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.y))

        let sprite = SKSpriteNode(texture: box.rare ? rare : ordinary, size: size)
        sprite.position = GridGeometry.point(for: box.position)
        sprite.zPosition = 3    // above trees, below walls and actors

        // The rim that says it can be opened. Built with every crate and left
        // invisible, because a node that already exists can be faded in on the
        // frame it is wanted; one that has to be created first arrives late.
        //
        // White, and the only white outline in the game. Every other colour here
        // means something already - rarity, teams, money, danger - so a plain white
        // edge is the one that can mean "reachable" without being confused for any
        // of them. It sits OUTSIDE the artwork rather than over it, so the crate
        // still looks like itself and the rim reads as a highlight rather than as
        // damage.
        let rim = SKShapeNode(rect: CGRect(x: -size.width / 2 - 3,
                                           y: -size.height / 2 - 3,
                                           width: size.width + 6,
                                           height: size.height + 6),
                              cornerRadius: 6)
        rim.name = LootboxRenderer.rimName
        rim.strokeColor = .white
        rim.lineWidth = 2
        rim.fillColor = .clear
        rim.alpha = 0
        rim.zPosition = 2
        sprite.addChild(rim)

        // A rare crate is lit from underneath, in the same blue the gear inside it
        // will be wearing - the same pool of light that sits under a dropped item,
        // scaled up. That consistency is the point: nobody has to be taught what
        // the glow means twice.
        //
        // Blue rather than gold, because a rare crate is a crate with better GEAR
        // in it rather than a jackpot, and it should read as worth crossing the map
        // for rather than as worth abandoning a fight for.
        //
        // PURPLE now, the Mythical colour, and more of it: rare crates are an event
        // rather than a feature of the map (see GameConfig.Loot.rareChance), so the
        // few there are have to be unmistakable. A wide soft halo, a tighter
        // bright pool breathing on top of it, and purple sparkles winking in and
        // out around the box.
        if box.rare {
            let purple = RenderPalette.colour(of: .mythical)

            let halo = SKSpriteNode(texture: GlowArt.pool)
            halo.size = CGSize(width: size.width * 3.6, height: size.width * 3.6)
            halo.color = purple
            halo.colorBlendFactor = 1
            halo.alpha = 0.35
            halo.zPosition = -1.1
            sprite.addChild(halo)
            halo.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.2, duration: 1.3), .scale(to: 0.92, duration: 1.3)]),
                .group([.fadeAlpha(to: 0.35, duration: 1.3), .scale(to: 1.0, duration: 1.3)])
            ])))

            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: size.width * 2.3, height: size.width * 1.9)
            glow.color = purple
            glow.colorBlendFactor = 1
            glow.alpha = 0.8
            glow.zPosition = -1
            sprite.addChild(glow)
            glow.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.5, duration: 0.9), .scale(to: 0.88, duration: 0.9)]),
                .group([.fadeAlpha(to: 0.8, duration: 0.9), .scale(to: 1.0, duration: 0.9)])
            ])))

            sparkle(around: sprite, size: size, colour: purple, seed: box.id.raw)
        }

        idle(sprite, for: box)

        node.addChild(sprite)
        nodesByBox[box.id] = sprite
    }

    /// A slow lean, and something knocking to get out.
    ///
    /// Amplitudes are deliberately tiny - two degrees of rock, six per cent of a
    /// jump - because there are forty-two of these on a map and they are scenery
    /// for most of a match. The test an idle has to pass is that you notice it when
    /// you look at one crate and never notice it while you are looking at a fight.
    ///
    /// A rare crate knocks harder and more often. It already glows; this is the
    /// same claim made in movement, and movement is what carries at the distance
    /// where the glow is just a smudge of blue.
    /// Purple stars winking in and out around a rare crate, forever. Each one pops
    /// up somewhere near the box, twinkles and fades; they come a few a second, at
    /// uneven gaps, so the effect glitters rather than ticks.
    private func sparkle(around sprite: SKSpriteNode, size: CGSize, colour: SKColor, seed: Int) {
        let spawn = SKAction.run { [weak sprite] in
            guard let sprite else { return }
            let star = SKSpriteNode(texture: ImpactArt.star)
            let side = CGFloat.random(in: 7...12)
            star.size = CGSize(width: side, height: side)
            star.color = colour
            star.colorBlendFactor = 0.45
            star.blendMode = .add
            star.zPosition = 3
            star.position = CGPoint(x: CGFloat.random(in: -size.width * 0.75...size.width * 0.75),
                                    y: CGFloat.random(in: -size.height * 0.5...size.height * 1.1))
            star.setScale(0.2)
            star.alpha = 0
            sprite.addChild(star)
            star.run(.sequence([
                .group([.fadeIn(withDuration: 0.15), .scale(to: 1, duration: 0.15),
                        .rotate(byAngle: 0.8, duration: 0.5)]),
                .group([.fadeOut(withDuration: 0.35), .scale(to: 0.3, duration: 0.35),
                        .moveBy(x: 0, y: 6, duration: 0.35)]),
                .removeFromParent()
            ]))
        }

        sprite.run(.sequence([
            .wait(forDuration: Double(seed % 5) * 0.13),
            .repeatForever(.sequence([spawn, .wait(forDuration: 0.28, withRange: 0.3)]))
        ]), withKey: "sparkle")
    }

    /// A rare crate that has just respawned rare mid-match: it pops up out of a
    /// purple flash, so it is noticed by anybody looking that way.
    private func arrive(_ id: LootboxID) {
        guard let sprite = nodesByBox[id] else { return }

        let flash = SKSpriteNode(texture: GlowArt.pool)
        flash.size = CGSize(width: sprite.size.width * 2, height: sprite.size.width * 2)
        flash.color = RenderPalette.colour(of: .mythical)
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        flash.position = sprite.position
        flash.zPosition = sprite.zPosition + 0.5
        node.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 2.4, duration: 0.45), .fadeOut(withDuration: 0.45)]),
            .removeFromParent()
        ]))

        sprite.setScale(0.1)
        sprite.run(.sequence([
            .scale(to: 1.25, duration: 0.14),
            .scale(to: 0.94, duration: 0.08),
            .scale(to: 1, duration: 0.1)
        ]))
    }

    private func idle(_ sprite: SKSpriteNode, for box: Lootbox) {
        let phase = Double(box.id.raw % 13) * 0.31
        let lean = box.rare ? 0.05 : 0.035
        let period = box.rare ? 1.5 : 1.9

        sprite.zRotation = CGFloat(-lean)
        sprite.run(.sequence([
            .wait(forDuration: phase),
            .repeatForever(.sequence([
                .rotate(toAngle: CGFloat(lean), duration: period),
                .rotate(toAngle: CGFloat(-lean), duration: period)
            ]))
        ]), withKey: "rock")

        // The knock: a squash and a hop, then a long wait. The wait is most of it -
        // an idle that never stops moving is a fidget, and the pause is what makes
        // the next one read as something happening rather than as a loop.
        let gap = (box.rare ? 2.6 : 4.4) + Double(box.id.raw % 7) * 0.4
        let jump = box.rare ? 0.09 : 0.06

        sprite.run(.repeatForever(.sequence([
            .wait(forDuration: gap),
            .group([
                .scaleX(to: 1 + CGFloat(jump) * 0.6, y: 1 - CGFloat(jump), duration: 0.07),
                .moveBy(x: 0, y: -1.5, duration: 0.07)
            ]),
            .group([
                .scaleX(to: 1 - CGFloat(jump) * 0.35, y: 1 + CGFloat(jump), duration: 0.09),
                .moveBy(x: 0, y: 4.5, duration: 0.09)
            ]),
            .group([
                .scaleX(to: 1, y: 1, duration: 0.13),
                .moveBy(x: 0, y: -3, duration: 0.13)
            ])
        ])), withKey: "knock")
    }
}
