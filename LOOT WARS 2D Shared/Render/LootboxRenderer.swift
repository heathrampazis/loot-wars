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
            sprite.removeFromParent()
        }
    }

    private func makeNode(for box: Lootbox) {
        // Drawn at exactly the collision size, so the crate you see is the crate
        // you bump into. GameConfig.Loot.lootboxSize matches the art's proportions.
        let size = CGSize(width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x),
                          height: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.y))

        let sprite = SKSpriteNode(texture: box.rare ? rare : ordinary, size: size)
        sprite.position = GridGeometry.point(for: box.position)
        sprite.zPosition = 3    // above trees, below walls and actors

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
            glow.color = RenderPalette.colour(of: .rare)
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
