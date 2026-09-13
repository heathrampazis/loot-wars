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
        /// What the sprite is currently DRAWN as. Kept so a rebuild can tell the
        /// walls that changed from the walls that merely still exist.
        var mask: UInt8
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

    /// Brings the drawing into line with the map, touching only what moved.
    ///
    /// This used to throw every wall away and build them all again, and it is
    /// called every time a single tile changes - which is thirty or forty times a
    /// second once seven bots are building and repairing. Two hundred SKSpriteNodes
    /// destroyed and allocated afresh, thirty times a second, for one block: the
    /// node churn alone was costing more than the whole simulation.
    ///
    /// Now it walks the map and compares. Scanning four thousand tiles is four
    /// thousand integer reads, which is nothing; what is expensive is touching
    /// nodes, and laying one block touches exactly the nine that can have changed
    /// shape. The walk stays rather than being replaced by a list of changed tiles
    /// from the world, because a full scan cannot drift out of step with the map
    /// and a change list can.
    func build(from map: TileMap) {
        let size = CGSize(width: GridGeometry.tileSize, height: GridGeometry.tileSize)
        var seen: Set<GridPoint> = []
        seen.reserveCapacity(walls.count)

        for row in 0..<map.height {
            for col in 0..<map.width {
                let point = GridPoint(col: col, row: row)
                guard let owner = map[point].blockOwner else { continue }

                seen.insert(point)

                let shape = mask(at: point, owner: owner, in: map)

                // Already drawn, and drawn correctly. The common case by far - a
                // block laid on one side of a base leaves every wall on the other
                // three sides exactly as it was.
                if let existing = walls[point], existing.owner == owner {
                    guard existing.mask != shape else { continue }

                    existing.sprite.texture = texture(for: TextureKey(mask: shape, team: owner))
                    walls[point]?.mask = shape
                    continue
                }

                // Changed hands, which means the old sprite is the wrong colour.
                walls[point]?.sprite.removeFromParent()

                let sprite = SKSpriteNode(texture: texture(for: TextureKey(mask: shape,
                                                                          team: owner)),
                                          size: size)
                sprite.position = GridGeometry.pointAtCentre(of: point)
                sprite.zPosition = BlockRenderer.wallZ

                node.addChild(sprite)
                walls[point] = Wall(sprite: sprite, owner: owner, mask: shape)
            }
        }

        // And whatever is no longer there - blown up, or taken back down.
        for (point, wall) in walls where !seen.contains(point) {
            if prising == point { prising = nil }
            walls[point] = nil
            crumble(wall.sprite)
        }
    }

    // MARK: - Coming apart

    /// A wall that has stopped existing, on its way out.
    ///
    /// It used to be removeFromParent on the same frame the tile changed, which is
    /// correct and reads as nothing at all: a bomb takes four tiles out and they
    /// simply are not there any more, so the hole appears without anything having
    /// visibly happened to make it. A wall you prised up yourself was worse - you
    /// held a finger down for four tenths of a second and the thing under it
    /// vanished, which is indistinguishable from a misfire.
    ///
    /// Lifted off its neighbours before it goes, so it is not drawn half behind the
    /// walls either side while it comes apart.
    private func crumble(_ sprite: SKSpriteNode) {
        sprite.removeAction(forKey: "prise")
        sprite.removeAction(forKey: "shudder")

        // Deliberately NOT reset to full size first. A wall that was being prised
        // up is already swollen to about 1.12 and the first beat below takes it to
        // 1.16, so it carries straight on; snapping it back to 1 would put a flinch
        // in the middle of the one moment it is meant to be coming apart.
        sprite.zPosition = BlockRenderer.crumbleZ

        sprite.run(.sequence([
            .group([.scale(to: 1.16, duration: 0.05),
                    .rotate(toAngle: CGFloat.random(in: -0.12...0.12), duration: 0.05)]),
            .group([.scale(to: 0.25, duration: 0.17),
                    .rotate(byAngle: CGFloat.random(in: -0.7...0.7), duration: 0.17),
                    .fadeOut(withDuration: 0.17)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Being prised up

    /// The tile currently being held down on, if any.
    private var prising: GridPoint?

    /// How far the wall has swollen by the end of the hold.
    ///
    /// OVER one, and it started at 0.82 - under. Shrinking was the obvious reading
    /// of prising something out of the ground and it was wrong for a reason
    /// specific to how these walls are drawn: makeTexture bakes a black band onto
    /// every side that has no friendly neighbour, which is what makes a run of wall
    /// seamless down its middle and hard-edged against the world. Shrink one tile
    /// and it pulls away from the run, and the seam it was hiding - its own black
    /// outside edge, and the grass in the gap - is suddenly visible all the way
    /// round it. It reads as a black border being drawn on the tile you touched,
    /// because that is exactly what it looks like.
    ///
    /// Growing cannot do that. A block over full size covers its neighbours rather
    /// than retreating from them, so no seam is ever exposed, and on the two sides
    /// that DO carry black the band simply moves a little further out over grass it
    /// was already against.
    ///
    /// It has to clear the tilt as well. Rotating a square by θ needs about
    /// (cos θ + sin θ) to still cover the square it started in, which at the 0.055
    /// radians below is 1.055 - so anything over that is safe, and 1.12 has room
    /// to spare.
    private static let prisedScale: CGFloat = 1.12

    /// Above terrain and trees, below actors.
    private static let wallZ: CGFloat = 5

    /// Higher again, so a wall coming apart is not drawn half behind the ones
    /// either side of it while it goes.
    private static let crumbleZ: CGFloat = 6

    /// A swelling wall has to be above the walls it is swelling over, or the growth
    /// happens underneath them and reads as nothing at all.
    private static let prisedZ: CGFloat = 5.5

    /// A wall with a finger held on it, working loose.
    ///
    /// Four tenths of a second with no response at all reads as a tap that failed
    /// to register, and the player lifts off just before the thing they were
    /// waiting for would have happened. ItemSlotNode.beginHold makes exactly this
    /// argument about the hotbar and answers it by squeezing the slot over the
    /// length of the hold; this is the same answer for the other half of the
    /// gesture, which had no answer at all.
    ///
    /// Squeeze AND shudder, where the hotbar only squeezes. A slot is a button and
    /// a squeeze is what a button does; a wall is a solid thing being worked out of
    /// the ground, and the game already has a vocabulary for that - a chest being
    /// cracked shakes and swells, and then bursts. This shakes and shrinks, and then
    /// crumbles. Coming apart looks like coming apart either way round.
    ///
    /// The scale runs for the whole duration so it is also the timer: how far down
    /// the wall has been squeezed is how close it is to going.
    func prise(at point: GridPoint, duration: TimeInterval) {
        guard prising != point else { return }
        release()

        guard let wall = walls[point] else { return }
        prising = point

        wall.sprite.zPosition = BlockRenderer.prisedZ
        wall.sprite.run(.scale(to: BlockRenderer.prisedScale, duration: duration),
                        withKey: "prise")
        wall.sprite.run(.repeatForever(.sequence([
            .rotate(toAngle: 0.055, duration: 0.045),
            .rotate(toAngle: -0.055, duration: 0.045)
        ])), withKey: "shudder")
    }

    /// - Parameter settling: whether to put the wall back. False when it is about
    ///   to be removed anyway, so the crumble picks up from where the squeeze got
    ///   to rather than from a wall that has just sprung back to full size.
    func release(settling: Bool = true) {
        guard let point = prising else { return }
        prising = nil

        guard settling, let wall = walls[point] else { return }
        wall.sprite.removeAction(forKey: "prise")
        wall.sprite.removeAction(forKey: "shudder")

        // Back into the run before it is back to full size, so it never sits at
        // normal scale while still drawn over its neighbours.
        wall.sprite.run(.sequence([
            .group([.scale(to: 1, duration: 0.1),
                    .rotate(toAngle: 0, duration: 0.1)]),
            .run { wall.sprite.zPosition = BlockRenderer.wallZ }
        ]))
    }

    /// Fades a wall out while the team that owns it is standing in it, so you can
    /// see yourself passing through instead of vanishing behind your own base.
    func sync(with world: World) {
        // Which tiles have somebody standing on them, worked out once.
        //
        // The question is asked of every wall on the map every frame, and it used
        // to be answered by scanning all eight actors each time - two hundred walls
        // times eight actors, sixty times a second, to find the one or two walls
        // anybody is actually inside. Eight actors cover a couple of tiles each, so
        // gathering them first turns the whole thing into a dictionary lookup.
        var standing: [GridPoint: Set<TeamID>] = [:]

        for actor in world.actors.values {
            let box = actor.hitbox

            for col in Int(box.lower.x.rounded(.down))...Int(box.upper.x.rounded(.down)) {
                for row in Int(box.lower.y.rounded(.down))...Int(box.upper.y.rounded(.down)) {
                    let tile = GridPoint(col: col, row: row)

                    // Asked rather than assumed, so this stays the same question
                    // Actor.overlaps asks - the bounds above are a candidate list.
                    guard box.intersects(Box(tile: tile)) else { continue }
                    standing[tile, default: []].insert(actor.team)
                }
            }
        }

        for (point, wall) in walls {
            let ownerIsInside = standing[point]?.contains(wall.owner) == true
            let target: CGFloat = ownerIsInside ? BlockRenderer.passThroughAlpha : 1.0
            let delta = target - wall.sprite.alpha

            // Already there, which is true of every wall nobody is standing in -
            // so the frame does no work at all for almost all of them.
            guard abs(delta) > 0.001 else { continue }

            wall.sprite.alpha += delta * BlockRenderer.fadeRate
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
