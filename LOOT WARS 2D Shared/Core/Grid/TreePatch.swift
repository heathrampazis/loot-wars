//
//  TreePatch.swift
//  Loot Wars
//
//  A clump of trees, stored as a square rather than as loose tiles.
//
//  Collision still works tile by tile - every tile in the patch is marked .tree - but
//  keeping the rectangle around means the whole clump can be drawn with one sprite,
//  and later with one piece of art, instead of being reassembled from single tiles.
//

struct TreePatch {
    /// Bottom-left tile of the clump.
    let origin: GridPoint
    /// Width and height in tiles. Clumps are square.
    let size: Int

    var tiles: [GridPoint] {
        (0..<size).flatMap { dCol in
            (0..<size).map { dRow in
                GridPoint(col: origin.col + dCol, row: origin.row + dRow)
            }
        }
    }
}
