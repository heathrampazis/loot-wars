//
//  ArcadePadRenderer.swift
//  Loot Wars
//
//  The arcade floor under each of the map's machines.
//
//  A cabinet standing on bare grass looked dropped there at random. Each of the
//  map's own machines now stands on a patch of purple arcade floor, so it reads
//  as a place rather than a prop. One tile wider than the machine on every side,
//  which is also about where its tokens land, so the payout falls on the floor
//  too.
//
//  A see-through purple laid OVER the ground, not a floor drawn in its place -
//  the same way a base's claim is tinted - so it takes its shade from whatever
//  it is on: deeper on grass, lighter on snow and sand, with nothing to keep in
//  step per biome. (Fixed tiles per biome were tried first.)
//
//  It is a little thicker on every other tile, on the ground's own checkerboard,
//  because a flat tint washed the ground's faint checker out and the grid
//  disappeared under it.
//
//  Only the map's machines (no owner). One you stand up in your own base sits on
//  your floor like the rest of your furniture.
//

import SpriteKit
import UIKit

final class ArcadePadRenderer {

    let node = SKNode()

    /// How far the floor reaches past the machine's footprint, in tiles.
    static let margin = 1

    /// Over the claim tint (-50) and the ground, under everything that stands.
    static let z: CGFloat = -40

    /// The purple, and how much of it covers the ground on the light and dark
    /// tiles of the checkerboard. Strong enough to read as purple on green grass,
    /// where a weaker one went grey; the pale snow and sand lift it to a lighter
    /// lavender on their own. The gap between the two opacities is what keeps
    /// the grid visible.
    static let colour = SKColor(red: 0xA0 / 255.0, green: 0x70 / 255.0, blue: 0xF8 / 255.0, alpha: 1)
    static let lightTileOpacity: CGFloat = 0.62
    static let darkTileOpacity: CGFloat = 0.68

    func build(arcades: [Arcade]) {
        node.removeAllChildren()

        for arcade in arcades where arcade.owner == nil {
            let margin = ArcadePadRenderer.margin
            let size = CGSize(width: GridGeometry.length(ofTiles: Double(arcade.width + margin * 2)),
                              height: GridGeometry.length(ofTiles: Double(arcade.height + margin * 2)))

            let pad = SKSpriteNode(texture: ArcadePadRenderer.tint(
                                       tilesWide: arcade.width + margin * 2,
                                       tilesHigh: arcade.height + margin * 2,
                                       from: GridPoint(col: arcade.origin.col - margin,
                                                       row: arcade.origin.row - margin)),
                                   size: size)
            // Anchored bottom-left on the tile one out from the machine's origin.
            pad.anchorPoint = .zero
            pad.position = GridGeometry.point(for: Vec2(x: Double(arcade.origin.col - margin),
                                                        y: Double(arcade.origin.row - margin)))
            pad.zPosition = ArcadePadRenderer.z
            node.addChild(pad)
        }
    }

    /// The tint, tile by tile: the purple at one opacity on the ground's light
    /// tiles and a little more on its dark ones. Parity from the real tile
    /// coordinates, the same test the ground uses, so the two line up.
    private static func tint(tilesWide: Int, tilesHigh: Int, from corner: GridPoint) -> SKTexture {
        let tile = GridGeometry.tileSize
        let size = CGSize(width: CGFloat(tilesWide) * tile, height: CGFloat(tilesHigh) * tile)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            for dx in 0..<tilesWide {
                for dy in 0..<tilesHigh {
                    let light = (corner.col + dx + corner.row + dy) % 2 == 0
                    colour.withAlphaComponent(light ? lightTileOpacity : darkTileOpacity).setFill()
                    // Images run top-down, tiles bottom-up.
                    UIRectFill(CGRect(x: CGFloat(dx) * tile,
                                      y: CGFloat(tilesHigh - 1 - dy) * tile,
                                      width: tile, height: tile))
                }
            }
        }

        let texture = SKTexture(image: image)
        texture.filteringMode = .nearest
        return texture
    }
}
