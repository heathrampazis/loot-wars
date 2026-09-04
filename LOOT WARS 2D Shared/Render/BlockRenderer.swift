//
//  BlockRenderer.swift
//  Loot Wars
//
//  Draws player-placed walls with an outline that follows the SHAPE of a group
//  rather than each individual block.
//
//  How it works: every block looks at its eight neighbours and builds an 8-bit mask
//  of which ones are walls OF THE SAME TEAM. The outline is only drawn on the sides
//  facing something else, so your own walls merge into one solid piece while an
//  enemy's wall built alongside stays visibly separate.
//
//  The subtle case is an inner corner. If the wall above and the wall to the right
//  are both filled but the diagonal between them is empty, neither edge gets a bar,
//  and the outline would have a notch missing. A small square in that corner closes it.
//
//  Walls also fade out while their owner is walking through them - see sync(with:).
//

import SpriteKit
import UIKit

final class BlockRenderer {

    let node = SKNode()

    /// How see-through a wall goes while its owner is inside it.
    private static let passThroughAlpha: CGFloat = 0.4
    /// How quickly it fades, per frame. Purely cosmetic, so frame-rate dependence
    /// here is harmless - nothing in the simulation reads it.
    private static let fadeRate: CGFloat = 0.25

    private struct Wall {
        let sprite: SKSpriteNode
        let owner: TeamID
    }

    private struct TextureKey: Hashable {
        let mask: UInt8
        let team: TeamID
    }

    private var walls: [GridPoint: Wall] = [:]
    private var textureCache: [TextureKey: SKTexture] = [:]

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
        walls.removeAll()

        let size = CGSize(width: GridGeometry.tileSize, height: GridGeometry.tileSize)

        for row in 0..<map.height {
            for col in 0..<map.width {
                let point = GridPoint(col: col, row: row)
                guard let owner = map[point].blockOwner else { continue }

                let key = TextureKey(mask: mask(at: point, owner: owner, in: map),
                                     team: owner)
                let sprite = SKSpriteNode(texture: texture(for: key), size: size)
                sprite.position = GridGeometry.pointAtCentre(of: point)
                sprite.zPosition = 5     // above terrain and trees, below actors

                node.addChild(sprite)
                walls[point] = Wall(sprite: sprite, owner: owner)
            }
        }
    }

    /// Fades a wall out while the team that owns it is standing in it, so you can
    /// see yourself passing through instead of vanishing behind your own base.
    func sync(with world: World) {
        for (point, wall) in walls {
            let ownerIsInside = world.actors.values.contains {
                $0.team == wall.owner && $0.overlaps(point)
            }

            let target: CGFloat = ownerIsInside ? BlockRenderer.passThroughAlpha : 1.0
            wall.sprite.alpha += (target - wall.sprite.alpha) * BlockRenderer.fadeRate
        }
    }

    /// Only walls belonging to the same team count as neighbours - an enemy wall
    /// butted up against yours should read as a separate structure.
    private func mask(at point: GridPoint, owner: TeamID, in map: TileMap) -> UInt8 {
        var mask: UInt8 = 0

        func isFriendlyWall(_ dCol: Int, _ dRow: Int) -> Bool {
            map[GridPoint(col: point.col + dCol, row: point.row + dRow)].blockOwner == owner
        }

        if isFriendlyWall( 0,  1) { mask |= Side.north }
        if isFriendlyWall( 1,  1) { mask |= Side.northEast }
        if isFriendlyWall( 1,  0) { mask |= Side.east }
        if isFriendlyWall( 1, -1) { mask |= Side.southEast }
        if isFriendlyWall( 0, -1) { mask |= Side.south }
        if isFriendlyWall(-1, -1) { mask |= Side.southWest }
        if isFriendlyWall(-1,  0) { mask |= Side.west }
        if isFriendlyWall(-1,  1) { mask |= Side.northWest }

        return mask
    }

    // MARK: - Textures

    /// A single unattached wall in a team's colour, for anything that needs to draw
    /// one that is not on the map yet.
    ///
    /// Public and static because the blueprint draws a GHOST of a wall to teach
    /// building, and a ghost of a wall has to be the wall - a stand-in shape would
    /// be teaching the player to look for something the game never puts down. Mask
    /// zero is a block with no neighbours, which is what the first one you place
    /// always is.
    static func ghostTexture(for team: TeamID) -> SKTexture {
        if let cached = ghostCache[team] { return cached }

        let made = makeTexture(mask: 0, colour: RenderPalette.colour(for: team))
        ghostCache[team] = made
        return made
    }

    private static var ghostCache: [TeamID: SKTexture] = [:]

    private func texture(for key: TextureKey) -> SKTexture {
        if let cached = textureCache[key] { return cached }
        let made = BlockRenderer.makeTexture(mask: key.mask,
                                             colour: RenderPalette.colour(for: key.team))
        textureCache[key] = made
        return made
    }

    private static func makeTexture(mask: UInt8, colour: SKColor) -> SKTexture {
        let side: CGFloat = 128
        let edge: CGFloat = 14

        func has(_ bit: UInt8) -> Bool { mask & bit != 0 }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side),
            format: format
        ).image { _ in

            colour.setFill()
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
