//
//  TileMapRenderer.swift
//  Loot Wars
//
//  Draws the map once into a container node.
//
//  One sprite per tile is fine at 64x64 (about 4,000 nodes, which SpriteKit batches
//  happily). If the map ever grows a lot, this is the first thing to replace - with
//  SKTileMapNode, or by only building tiles near the camera.
//

import SpriteKit

final class TileMapRenderer {

    let node = SKNode()

    func build(from map: TileMap) {
        node.removeAllChildren()

        let tileSize = CGSize(width: GridGeometry.tileSize, height: GridGeometry.tileSize)

        for row in 0..<map.height {
            for col in 0..<map.width {
                let point = GridPoint(col: col, row: row)

                let colour: SKColor
                switch map[point] {
                case .stone:
                    colour = RenderPalette.stone
                case .floor:
                    // A checkerboard makes it obvious you are actually moving.
                    colour = (col + row) % 2 == 0 ? RenderPalette.floorLight : RenderPalette.floorDark
                }

                let tile = SKSpriteNode(color: colour, size: tileSize)
                tile.position = GridGeometry.pointAtCentre(of: point)
                node.addChild(tile)
            }
        }
    }
}
