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

    private static let rimName = "reach"


    private lazy var ordinary: SKTexture = Self.load("LootboxRed")
    private lazy var rare: SKTexture = Self.load("LootboxRare")

    private static func load(_ name: String) -> SKTexture {
        let texture = SKTexture(imageNamed: name)
        texture.usesMipmaps = true
        return texture
    }

    func sync(with world: World) {
        for (id, box) in world.lootboxes where nodesByBox[id] == nil {
            makeNode(for: box)
        }

        for (id, sprite) in Array(nodesByBox) where world.lootboxes[id] == nil {
            nodesByBox[id] = nil
            if lit == id { lit = nil }
            burst(sprite)
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

    /// The lid goes, for a crate somebody has just opened.
    ///
    /// It used to be removeFromParent, which is the one thing a crate must not do:
    /// forty-two of them spend the match rocking and knocking to say there is
    /// something inside, and then the moment somebody finds out what, the box
    /// blinks out of existence. The items land on the grass with nothing to say
    /// where they came from.
    ///
    /// So it shudders once - the same knock the idle has been making all match,
    /// harder, and now with a reason - and comes apart upwards. Two tenths of a
    /// second, because whatever fell out of it is the thing worth looking at and
    /// this must not still be going when the player reaches for it.
    private func burst(_ sprite: SKSpriteNode) {
        // The idle owns this sprite's rotation, scale and position, and it runs
        // forever. Nothing else can move any of them until it is stopped.
        sprite.removeAllActions()
        sprite.childNode(withName: LootboxRenderer.rimName)?.removeFromParent()

        sprite.run(.sequence([
            .group([.scaleX(to: 1.20, y: 0.80, duration: 0.05),
                    .rotate(toAngle: 0.09, duration: 0.05)]),
            .group([.scaleX(to: 0.86, y: 1.24, duration: 0.06),
                    .rotate(toAngle: -0.12, duration: 0.06),
                    .moveBy(x: 0, y: 6, duration: 0.06)]),
            .group([.scale(to: 0.18, duration: 0.19),
                    .rotate(byAngle: 0.7, duration: 0.19),
                    .moveBy(x: 0, y: 12, duration: 0.19),
                    .fadeOut(withDuration: 0.19)]),
            .removeFromParent()
        ]))
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
        if box.rare {
            let glow = SKSpriteNode(texture: GlowArt.pool)
            glow.size = CGSize(width: size.width * 2.1, height: size.height * 2.1)
            glow.color = RenderPalette.colour(of: .legendary)
            glow.colorBlendFactor = 1
            glow.alpha = 0.7
            glow.zPosition = -1
            sprite.addChild(glow)

            glow.run(.repeatForever(.sequence([
                .group([.fadeAlpha(to: 0.45, duration: 1.1), .scale(to: 0.9, duration: 1.1)]),
                .group([.fadeAlpha(to: 0.7, duration: 1.1), .scale(to: 1.0, duration: 1.1)])
            ])))
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
