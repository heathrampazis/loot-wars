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

    private lazy var texture: SKTexture = {
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

        for (id, sprite) in Array(nodesByArcade) where world.arcades[id] == nil {
            nodesByArcade[id] = nil

            // Blown apart rather than switched off.
            sprite.run(.sequence([
                .group([.scale(to: 1.2, duration: 0.08), .fadeAlpha(to: 0.9, duration: 0.08)]),
                .group([.scale(to: 0.2, duration: 0.2), .fadeOut(withDuration: 0.2)]),
                .removeFromParent()
            ]))
        }
    }

    private func make(_ machine: Arcade) {
        let sprite = SKSpriteNode(
            texture: texture,
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
