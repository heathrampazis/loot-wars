//
//  ShadowRenderer.swift
//  Loot Wars
//
//  What everything on the map is standing on.
//
//  One file for every shadow in the game, and that is the whole design. Depth is a
//  claim the picture makes as a WHOLE - if the walls are lit from the top left and
//  the trees are lit from the left, the map does not look half right, it looks
//  broken - so the direction of the light, the softness and the darkness are three
//  numbers here rather than three numbers copied into eight renderers. It also
//  means the entire effect can be judged, tuned or deleted in one place, which is
//  the honest state of an idea nobody is sure about yet.
//
//  Two shapes, and the difference is what each thing IS. Walls and machines are
//  boxes with height, so they throw a hard-edged slab offset down and to the right,
//  the way a real box in low sun does. Everything else - people, trees, crates,
//  dropped items - gets a soft pool directly beneath it, squashed flat, because
//  what it is really saying is "this touches the ground here". A soft pool under a
//  wall would read as fog; a hard slab under a bandage would read as a hole.
//
//  Nothing here bobs. The figure rises on every step, a dropped item floats, a
//  crate breathes - and their shadows do not move a pixel, which is exactly what
//  makes the bobbing read as height rather than as jitter. That is the one rule in
//  this file worth defending: a shadow that follows its owner up is not a shadow.
//
//  Shadows of grid-aligned walls never overlap each other, because a uniform shift
//  of a tiling is still a tiling - which is what makes it safe to draw them with
//  simple transparency instead of stacking up dark seams along every wall.
//

import SpriteKit
import UIKit

final class ShadowRenderer {

    /// Above the ground and the claim tints, below the trees, the walls, the
    /// items and everybody - so everything on the map is standing ON its shadow.
    let node = SKNode()

    /// Where the light comes from, said as the offset a shadow takes, in tiles.
    ///
    /// Down and to the right, which puts the sun over the player's left shoulder.
    /// Small: at a quarter of a tile the map read as a diorama of floating pieces,
    /// and this game is played looking straight down at chunky flat art. An eighth
    /// of a tile is enough to say a wall has a top and a side.
    private static let offset = Vec2(x: 0.13, y: -0.15)

    /// How dark the darkest part of a shadow is.
    ///
    /// One number for the whole map. Anything past about a third stops reading as
    /// light and starts reading as a hole cut in the grass.
    private static let opacity: CGFloat = 0.26

    /// How squashed a contact pool is - a circle seen from a low angle.
    private static let flatten: CGFloat = 0.52

    private var wallSlabs: [GridPoint: SKSpriteNode] = [:]
    private var drawnMapRevision = -1

    private var actorPools: [ActorID: SKSpriteNode] = [:]
    private var itemPools: [GroundItemID: SKSpriteNode] = [:]
    private var chestPools: [ChestID: SKSpriteNode] = [:]
    private var cratePools: [LootboxID: SKSpriteNode] = [:]
    private var machineSlabs: [ArcadeID: SKSpriteNode] = [:]
    private var bombPools: [BombID: SKSpriteNode] = [:]

    init() {
        node.zPosition = -10
        node.alpha = ShadowRenderer.opacity
    }

    // MARK: - The things that never move

    /// Trees, laid down once. They spin, and their shadows do not: a clump turning
    /// on the spot is foliage moving in the wind, and the ground under it is not.
    func build(trees: [TreePatch]) {
        for patch in trees {
            let width = GridGeometry.length(ofTiles: patch.radius * 2.15)

            // Further out than everything else, because a tree is the tallest thing
            // on this map by some way.
            let pool = makePool(width: width,
                                at: patch.centre + ShadowRenderer.offset * 1.6)
            node.addChild(pool)
        }
    }

    // MARK: - Everything else

    func sync(with world: World) {
        if world.mapRevision != drawnMapRevision {
            drawnMapRevision = world.mapRevision
            rebuildWalls(from: world.map)
        }

        // People. Anchored at the FEET rather than the middle, which is where the
        // sprite stands and therefore where it meets the ground.
        sync(&actorPools,
             with: world.actors.filter { $0.value.isAlive },
             width: GridGeometry.length(ofTiles: GameConfig.Player.halfWidth * 2.4),
             position: { $0.feet + Vec2(x: 0, y: 0.06) })

        sync(&itemPools, with: world.groundItems,
             width: GridGeometry.length(ofTiles: 0.52),
             position: { $0.position + Vec2(x: 0, y: -0.18) })

        sync(&chestPools, with: world.chests,
             width: GridGeometry.length(ofTiles: GameConfig.Chest.size.x * 0.95),
             position: { $0.position + Vec2(x: 0, y: -0.22) })

        sync(&cratePools, with: world.lootboxes,
             width: GridGeometry.length(ofTiles: GameConfig.Loot.lootboxSize.x * 0.95),
             position: { $0.position + Vec2(x: 0, y: -0.18) })

        // A bomb in the air keeps its shadow on the ground under it, which is the
        // only thing on screen that says how far a throw has left to go.
        var live: [BombID: Bomb] = [:]
        for bomb in world.bombs { live[bomb.id] = bomb }

        sync(&bombPools, with: live,
             width: GridGeometry.length(ofTiles: 0.42),
             position: { $0.position + Vec2(x: 0, y: -0.1) })

        syncMachines(world.arcades)
    }

    /// One kind of contact pool, made where it is missing, moved where it is not,
    /// and dropped where its owner has stopped existing.
    private func sync<Key: Hashable, Thing>(_ pools: inout [Key: SKSpriteNode],
                                            with things: [Key: Thing],
                                            width: CGFloat,
                                            position: (Thing) -> Vec2) {
        for (key, thing) in things {
            let point = GridGeometry.point(for: position(thing) + ShadowRenderer.offset)

            if let pool = pools[key] {
                pool.position = point
            } else {
                let pool = makePool(width: width, at: position(thing) + ShadowRenderer.offset)
                node.addChild(pool)
                pools[key] = pool
            }
        }

        for (key, pool) in pools where things[key] == nil {
            pools[key] = nil
            pool.removeFromParent()
        }
    }

    /// Machines are boxes, so they get the wall treatment rather than a pool.
    ///
    /// At the BASE of the footprint rather than across all of it, and the reason is
    /// how the machine is drawn: three tiles of art anchored at its feet, standing
    /// up out of the map. A slab covering the whole footprint would say the cabinet
    /// was lying face-up on the grass. Just over a tile deep is what a thing
    /// standing against the ground actually puts down.
    private func syncMachines(_ arcades: [ArcadeID: Arcade]) {
        for (id, arcade) in arcades where machineSlabs[id] == nil {
            let slab = makeSlab(size: CGSize(
                width: GridGeometry.length(ofTiles: Double(Arcade.width) * 0.92),
                height: GridGeometry.length(ofTiles: 1.15)))

            let base = Vec2(x: arcade.centre.x, y: Double(arcade.origin.row) + 0.55)
            slab.position = GridGeometry.point(for: base + ShadowRenderer.offset)
            node.addChild(slab)
            machineSlabs[id] = slab
        }

        for (id, slab) in machineSlabs where arcades[id] == nil {
            machineSlabs[id] = nil
            slab.removeFromParent()
        }
    }

    /// Off the same revision counter the walls themselves are drawn from, so a wall
    /// and its shadow can never be a frame apart.
    ///
    /// A DIFFERENCE rather than a rebuild, which the walls opposite do not bother
    /// with because their sprites have to be re-masked against their new
    /// neighbours anyway. A shadow has no neighbours - it is a plain slab under one
    /// tile - so the twelve that changed can be the only twelve touched. That
    /// matters more than it sounds: bots repair their walls every fifth of a
    /// second, and a full rebuild here would have doubled the cost of the single
    /// most frequent structural change in the game.
    private func rebuildWalls(from map: TileMap) {
        let size = CGSize(width: GridGeometry.tileSize, height: GridGeometry.tileSize)
        var standing: Set<GridPoint> = []

        for row in 0..<map.height {
            for col in 0..<map.width {
                let point = GridPoint(col: col, row: row)
                guard map[point].blockOwner != nil else { continue }

                standing.insert(point)
                guard wallSlabs[point] == nil else { continue }

                let slab = makeSlab(size: size)
                let centre = GridGeometry.pointAtCentre(of: point)

                slab.position = CGPoint(
                    x: centre.x + GridGeometry.length(ofTiles: ShadowRenderer.offset.x),
                    y: centre.y + GridGeometry.length(ofTiles: ShadowRenderer.offset.y))

                node.addChild(slab)
                wallSlabs[point] = slab
            }
        }

        for (point, slab) in wallSlabs where !standing.contains(point) {
            wallSlabs[point] = nil
            slab.removeFromParent()
        }
    }

    // MARK: - The two shapes

    private func makePool(width: CGFloat, at position: Vec2) -> SKSpriteNode {
        let pool = SKSpriteNode(texture: GlowArt.pool)
        pool.size = CGSize(width: width, height: width * ShadowRenderer.flatten)
        pool.color = .black
        pool.colorBlendFactor = 1
        pool.position = GridGeometry.point(for: position)
        return pool
    }

    private func makeSlab(size: CGSize) -> SKSpriteNode {
        let slab = SKSpriteNode(texture: ShadowArt.slab, size: size)
        slab.color = .black
        slab.colorBlendFactor = 1
        return slab
    }
}

/// The hard shape, drawn once.
///
/// Its corners are rounded by about a sixth, which is what the wall art does, so a
/// shadow reads as belonging to the thing above it rather than as a rectangle that
/// happens to be nearby.
enum ShadowArt {

    static let slab: SKTexture = {
        let side: CGFloat = 64

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(
            size: CGSize(width: side, height: side), format: format
        ).image { _ in
            let path = UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
                cornerRadius: side * 0.16)

            SKColor.white.setFill()
            path.fill()
        }

        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }()
}
