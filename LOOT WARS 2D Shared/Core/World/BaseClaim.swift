//
//  BaseClaim.swift
//  Loot Wars
//
//  A team's patch of ground. The only place they may build, and where they will
//  respawn once dying is a thing.
//
//  Square and odd-sized on purpose, so it has a true centre tile to spawn on.
//

struct BaseClaim {
    let team: TeamID
    /// Bottom-left tile of the claim.
    let origin: GridPoint
    let size: Int

    func contains(_ point: GridPoint) -> Bool {
        point.col >= origin.col && point.col < origin.col + size
            && point.row >= origin.row && point.row < origin.row + size
    }

    var centreTile: GridPoint {
        GridPoint(col: origin.col + size / 2, row: origin.row + size / 2)
    }

    /// Builds a claim centred on a tile rather than anchored at its corner, which is
    /// almost always how you actually want to place one.
    init(team: TeamID, centredOn centre: GridPoint, size: Int) {
        self.team = team
        self.size = size
        self.origin = GridPoint(col: centre.col - size / 2,
                                row: centre.row - size / 2)
    }
}
