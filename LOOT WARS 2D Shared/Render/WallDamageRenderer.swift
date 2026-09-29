//
//  WallDamageRenderer.swift
//  Loot Wars
//
//  The little health bar over a wall you are shooting down.
//
//  Only while you are shooting it - it goes a moment after the last hit (see
//  linger), well before the wall itself mends. Same bar as a person, a machine or a
//  chest (BarArt), in the owner's colour, so it reads as "this is coming down"
//  without anything new to learn.
//

import SpriteKit

final class WallDamageRenderer {

    let node = SKNode()

    private var fills: [GridPoint: SKShapeNode] = [:]
    private var drawn: [GridPoint: Int] = [:]

    /// A little narrower than the tile, so neighbouring bars never touch.
    private static let widthInTiles: Double = 0.85

    /// How long the bar stays up after the last shot, in seconds. Much shorter
    /// than the wall takes to mend (GameConfig.Build.wallMendDelay): the bar is
    /// there while you are shooting and gone the moment you stop. Shoot the same
    /// wall again before it mends and the bar comes back where it left off.
    private static let linger: Double = 0.6

    init() {
        // Over the walls and the people walking past them.
        node.zPosition = 60
    }

    func sync(with world: World) {
        let full = GridGeometry.length(ofTiles: WallDamageRenderer.widthInTiles)

        for (tile, damage) in world.wallDamage where damage.sinceHit < WallDamageRenderer.linger {
            guard let owner = world.map[tile].blockOwner else { continue }
            let fill = fills[tile] ?? make(at: tile, owner: owner, full: full)

            guard drawn[tile] != damage.taken else { continue }
            drawn[tile] = damage.taken

            let share = max(0, 1 - Double(damage.taken) / Double(GameConfig.Build.wallShotHealth))
            fill.path = BarArt.path(full: full, filled: max(BarArt.height, full * CGFloat(share)))
        }

        for (tile, fill) in fills
        where (world.wallDamage[tile]?.sinceHit ?? .infinity) >= WallDamageRenderer.linger {
            fills[tile] = nil
            drawn[tile] = nil
            fill.parent?.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
        }
    }

    private func make(at tile: GridPoint, owner: TeamID, full: CGFloat) -> SKShapeNode {
        let (bar, fill) = BarArt.make(full: full, colour: RenderPalette.colour(for: owner))
        bar.position = GridGeometry.point(for: Vec2(x: Double(tile.col) + 0.5,
                                                    y: Double(tile.row) + 1.3))
        bar.alpha = 0
        bar.run(.fadeIn(withDuration: 0.08))
        node.addChild(bar)
        fills[tile] = fill
        return fill
    }
}
