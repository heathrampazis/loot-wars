//
//  WallDamageRenderer.swift
//  Loot Wars
//
//  The state of a wall that has been hit and is still standing.
//
//  Drawn only on tiles that have TAKEN damage, which is the whole design of it. An
//  upgraded base is thirty-odd wall tiles, and a durability bar on every one of
//  them would be a base wearing a spreadsheet - while the moment the number matters
//  is the moment somebody has started work on it, and then it matters enormously to
//  both people: the raider needs to know whether one more bomb finishes the job,
//  and the owner needs to know which tile to stand behind.
//
//  Pips rather than a bar. A wall has one to four layers, and at this size four
//  discrete squares are read instantly where four fifths of a bar is arithmetic.
//

import SpriteKit

final class WallDamageRenderer {

    let node = SKNode()

    private var nodesByTile: [GridPoint: SKNode] = [:]
    private var drawnFor: [GridPoint: Int] = [:]

    func sync(with world: World) {
        for (tile, taken) in world.wallDamage {
            guard let owner = world.map[tile].blockOwner else { continue }

            // Redrawn only when the count changes, not every frame: this runs over
            // every damaged tile on the map and most frames nothing has been hit.
            guard drawnFor[tile] != taken else { continue }
            drawnFor[tile] = taken

            nodesByTile[tile]?.removeFromParent()
            nodesByTile[tile] = make(at: tile,
                                     taken: taken,
                                     of: world.wallLayers(for: owner))
        }

        for (tile, marks) in nodesByTile where world.wallDamage[tile] == nil {
            nodesByTile[tile] = nil
            drawnFor[tile] = nil

            // Rebuilt or destroyed, and either way the pips have stopped being
            // true. A quick fade rather than a disappearance, so a wall going down
            // is one continuous event rather than two things happening at once.
            marks.run(.sequence([.fadeOut(withDuration: 0.15), .removeFromParent()]))
        }
    }

    private func make(at tile: GridPoint, taken: Int, of layers: Int) -> SKNode {
        let holder = SKNode()
        holder.position = GridGeometry.pointAtCentre(of: tile)

        // Over the wall it describes, under anything standing on the map.
        holder.zPosition = 5

        let side = GridGeometry.tileSize
        let pip = side * 0.15
        let gap = side * 0.06
        let spread = CGFloat(layers) * pip + CGFloat(layers - 1) * gap

        for index in 0..<layers {
            let mark = SKShapeNode(
                rect: CGRect(x: -spread / 2 + CGFloat(index) * (pip + gap),
                             y: -side * 0.34,
                             width: pip,
                             height: pip),
                cornerRadius: pip * 0.3
            )

            // Filled for what is left, hollow for what has been knocked out - so
            // the pips read left to right as "this much wall remains" rather than
            // as a score somebody is running up.
            let intact = index < layers - taken

            mark.fillColor = intact
                ? SKColor(white: 1, alpha: 0.9)
                : SKColor(white: 0, alpha: 0.35)

            mark.strokeColor = SKColor(white: 0, alpha: 0.55)
            mark.lineWidth = 1

            holder.addChild(mark)
        }

        node.addChild(holder)
        return holder
    }
}
