//
//  TileMapRenderer.swift
//  Loot Wars
//
//  Draws the static terrain as ONE node instead of one node per tile.
//
//  The trick: render the map into an image at exactly one pixel per tile - a 64x64
//  map becomes a 64x64 image - then blow it up with nearest-neighbour filtering so
//  every tile stays a crisp, perfectly square block. A few kilobytes and a single
//  draw call, in place of 4,096 sprites.
//
//  This is only for terrain, which never changes during a match. Anything that can
//  appear, move or be destroyed - player-placed walls, lootboxes, bombs - stays a
//  real node so it can be added and removed independently.
//

import SpriteKit
import UIKit

final class TileMapRenderer {

    let node = SKNode()

    func build(from map: TileMap) {
        node.removeAllChildren()

        let texture = SKTexture(image: bakeImage(of: map))
        // Without this the GPU smears the tiny image into mush when it scales up.
        texture.filteringMode = .nearest

        let sprite = SKSpriteNode(
            texture: texture,
            size: CGSize(width: GridGeometry.length(ofTiles: Double(map.width)),
                         height: GridGeometry.length(ofTiles: Double(map.height)))
        )
        // Anchor bottom-left so tile (0, 0) lands on the origin, matching tile space.
        sprite.anchorPoint = CGPoint(x: 0, y: 0)
        sprite.position = .zero
        sprite.zPosition = -100

        node.addChild(sprite)
    }

    /// One pixel per tile.
    private func bakeImage(of map: TileMap) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1        // exactly map.width x map.height pixels
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: map.width, height: map.height),
            format: format
        )

        return renderer.image { context in
            let cgContext = context.cgContext

            for row in 0..<map.height {
                for col in 0..<map.width {
                    let tile = map[GridPoint(col: col, row: row)]
                    cgContext.setFillColor(colour(for: tile, col: col, row: row).cgColor)

                    // Images run top-down, tile space runs bottom-up, so flip the row.
                    cgContext.fill(CGRect(x: CGFloat(col),
                                          y: CGFloat(map.height - 1 - row),
                                          width: 1,
                                          height: 1))
                }
            }
        }
    }

    private func colour(for tile: TileType, col: Int, row: Int) -> SKColor {
        switch tile {
        case .stone:
            return RenderPalette.terrain
        case .floor, .tree, .block:
            // Trees and blocks get plain ground baked underneath them; they are
            // drawn as sprites on top, because they change or overflow their tile.
            // A checkerboard makes it obvious you are actually moving.
            return (col + row) % 2 == 0 ? RenderPalette.floorLight : RenderPalette.floorDark
        }
    }
}
