//
//  BlockRenderer.swift
//  Loot Wars
//
//  Draws player-placed blocks with an outline that follows the SHAPE of a group
//  rather than each individual block.
//
//  How it works: every block looks at its eight neighbours and builds an 8-bit mask
//  of which ones are also blocks. The outline is then only drawn on the sides facing
//  open ground. Two blocks side by side have no line between them, so the group reads
//  as one solid piece - which is exactly what you get in the mockup.
//
//  The subtle case is an inner corner. If the block above and the block to the right
//  are both filled but the diagonal between them is empty, neither edge gets a bar,
//  and the outline would have a notch missing. A small square in that corner closes it.
//
//  There are only a few dozen distinct arrangements, so textures are generated once
//  on demand and cached by mask.
//

import SpriteKit
import UIKit

final class BlockRenderer {

    let node = SKNode()

    private var textureCache: [UInt8: SKTexture] = [:]

    private enum Side {
        static let north: UInt8     = 1 << 0
        static let northEast: UInt8 = 1 << 1
        static let east: UInt8      = 1 << 2
        static let southEast: UInt8 = 1 << 3
        static let south: UInt8     = 1 << 4
        static let southWest: UInt8 = 1 << 5
        static let west: UInt8      = 1 << 6
        static let northWest: UInt8 = 1 << 7
    }

    // MARK: - Building

    func build(from map: TileMap) {
        node.removeAllChildren()

        let size = CGSize(width: GridGeometry.tileSize, height: GridGeometry.tileSize)

        for row in 0..<map.height {
            for col in 0..<map.width {
                let point = GridPoint(col: col, row: row)
                guard map[point] == .block else { continue }

                let sprite = SKSpriteNode(texture: texture(for: mask(at: point, in: map)),
                                          size: size)
                sprite.position = GridGeometry.pointAtCentre(of: point)
                sprite.zPosition = 5     // above terrain and trees, below actors
                node.addChild(sprite)
            }
        }
    }

    private func mask(at point: GridPoint, in map: TileMap) -> UInt8 {
        var mask: UInt8 = 0

        func isBlock(_ dCol: Int, _ dRow: Int) -> Bool {
            map[GridPoint(col: point.col + dCol, row: point.row + dRow)] == .block
        }

        if isBlock( 0,  1) { mask |= Side.north }
        if isBlock( 1,  1) { mask |= Side.northEast }
        if isBlock( 1,  0) { mask |= Side.east }
        if isBlock( 1, -1) { mask |= Side.southEast }
        if isBlock( 0, -1) { mask |= Side.south }
        if isBlock(-1, -1) { mask |= Side.southWest }
        if isBlock(-1,  0) { mask |= Side.west }
        if isBlock(-1,  1) { mask |= Side.northWest }

        return mask
    }

    // MARK: - Textures

    private func texture(for mask: UInt8) -> SKTexture {
        if let cached = textureCache[mask] { return cached }
        let made = BlockRenderer.makeTexture(mask: mask)
        textureCache[mask] = made
        return made
    }

    private static func makeTexture(mask: UInt8) -> SKTexture {
        let side: CGFloat = 128
        let edge: CGFloat = 14

        func has(_ bit: UInt8) -> Bool { mask & bit != 0 }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in

            RenderPalette.block.setFill()
            UIBezierPath(rect: CGRect(x: 0, y: 0, width: side, height: side)).fill()

            SKColor.black.setFill()

            // Images run top-down, tile space runs bottom-up: north is the top edge.
            if !has(Side.north) { fill(0, 0, side, edge) }
            if !has(Side.south) { fill(0, side - edge, side, edge) }
            if !has(Side.west)  { fill(0, 0, edge, side) }
            if !has(Side.east)  { fill(side - edge, 0, edge, side) }

            // Inner corners: both neighbours filled, the diagonal empty.
            if has(Side.north), has(Side.west), !has(Side.northWest) {
                fill(0, 0, edge, edge)
            }
            if has(Side.north), has(Side.east), !has(Side.northEast) {
                fill(side - edge, 0, edge, edge)
            }
            if has(Side.south), has(Side.west), !has(Side.southWest) {
                fill(0, side - edge, edge, edge)
            }
            if has(Side.south), has(Side.east), !has(Side.southEast) {
                fill(side - edge, side - edge, edge, edge)
            }
        }

        return SKTexture(image: image)
    }

    private static func fill(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) {
        UIBezierPath(rect: CGRect(x: x, y: y, width: width, height: height)).fill()
    }
}
