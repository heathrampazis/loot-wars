//
//  ArcadeRenderer.swift
//  Loot Wars
//
//  Machines standing on the map. Built once and never touched again - they do not
//  move, they are not destroyed, and there are only a handful.
//

import SpriteKit

final class ArcadeRenderer {

    let node = SKNode()

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

    func build(arcades: [Arcade], mapHeight: Int) {
        node.removeAllChildren()

        let sheet = SKTexture(imageNamed: "Arcade")
        let texture = SKTexture(rect: ArcadeRenderer.artwork, in: sheet)
        texture.usesMipmaps = true

        for arcade in arcades {
            let sprite = SKSpriteNode(
                texture: texture,
                size: CGSize(width: GridGeometry.length(ofTiles: Double(Arcade.width)),
                             height: GridGeometry.length(ofTiles: Double(Arcade.height))))

            // Anchored at its feet, so the sprite stands ON the footprint rather
            // than being centred over it.
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
            sprite.position = GridGeometry.point(
                for: Vec2(x: arcade.centre.x, y: Double(arcade.origin.row)))

            // Sorted into the same band as the actors, by the line its base sits on.
            // A machine three tiles tall is the first thing in the game big enough
            // for this to matter: walk below one and you pass in front of it, walk
            // above and you go behind.
            let baseLine = Double(arcade.origin.row) + GameConfig.Player.halfDepth
            sprite.zPosition = 10 + (Double(mapHeight) - baseLine) * 0.001

            node.addChild(sprite)
        }
    }
}
