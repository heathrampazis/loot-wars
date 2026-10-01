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

    // Tiles of ground drawn past each map edge, so the camera never shows empty space.
    private static let overhang = 24

    // How dark the ground beyond the edge is: just past it, and at the far end of the overhang.
    private static let outsideNear: CGFloat = 0.8
    private static let outsideFar: CGFloat = 0.7

    func build(from map: TileMap, biomes: BiomeMap) {
        node.removeAllChildren()

        let texture = SKTexture(image: bakeImage(of: map, biomes: biomes))
        // Without this the GPU smears the tiny image into mush when it scales up.
        texture.filteringMode = .nearest

        let span = TileMapRenderer.overhang * 2
        let sprite = SKSpriteNode(
            texture: texture,
            size: CGSize(width: GridGeometry.length(ofTiles: Double(map.width + span)),
                         height: GridGeometry.length(ofTiles: Double(map.height + span)))
        )
        // Anchored bottom-left and pulled back by the overhang, so tile (0, 0) still lands on the origin.
        sprite.anchorPoint = CGPoint(x: 0, y: 0)
        sprite.position = CGPoint(x: -GridGeometry.length(ofTiles: Double(TileMapRenderer.overhang)),
                                  y: -GridGeometry.length(ofTiles: Double(TileMapRenderer.overhang)))
        sprite.zPosition = -100

        node.addChild(sprite)
    }

    // One pixel per tile, including the overhang.
    private func bakeImage(of map: TileMap, biomes: BiomeMap) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let reach = TileMapRenderer.overhang
        let width = map.width + reach * 2
        let height = map.height + reach * 2

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height),
                                               format: format)

        return renderer.image { context in
            let cgContext = context.cgContext

            for row in -reach..<(map.height + reach) {
                for col in -reach..<(map.width + reach) {
                    cgContext.setFillColor(colour(col: col, row: row, in: map, biomes: biomes).cgColor)

                    // Images run top-down, tile space runs bottom-up, so flip the row.
                    cgContext.fill(CGRect(x: CGFloat(col + reach),
                                          y: CGFloat(map.height + reach - 1 - row),
                                          width: 1,
                                          height: 1))
                }
            }
        }
    }

    private func colour(col: Int, row: Int, in map: TileMap, biomes: BiomeMap) -> SKColor {
        // Blocks get plain ground baked underneath them; they are drawn as sprites on top.
        let ground = checker(biomes[GridPoint(col: col, row: row)], col: col, row: row)
        guard map[GridPoint(col: col, row: row)] == .stone else { return ground }

        // The edge ring and everything past it is the same ground, darkening the further out it is.
        let out = max(1 - col, col - (map.width - 2), 1 - row, row - (map.height - 2), 1)
        let along = CGFloat(out - 1) / CGFloat(max(1, TileMapRenderer.overhang))
        let near = TileMapRenderer.outsideNear
        return TileMapRenderer.shade(ground, by: near + (TileMapRenderer.outsideFar - near) * along)
    }

    private func checker(_ biome: Biome, col: Int, row: Int) -> SKColor {
        let tones = RenderPalette.tones(for: biome)
        return (col + row) % 2 == 0 ? tones.light : tones.dark
    }

    private static func shade(_ colour: SKColor, by factor: CGFloat) -> SKColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        colour.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SKColor(red: red * factor, green: green * factor, blue: blue * factor, alpha: alpha)
    }
}
