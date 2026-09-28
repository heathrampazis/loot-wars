//
//  World+Footing.swift
//  Loot Wars
//
//  Where somebody can actually stand, and keeping it that way.
//
//  Furniture used to be put down nearest-to-the-centre with nothing asking what
//  that did to the room. The centre tile itself was kept clear, but not the tiles
//  above and below it, and not the ways out of it - so a base that sealed, filled
//  its chests, stood a machine up and then a turret could close a ring of solid
//  furniture round the one tile everybody respawns on. You came back to life
//  inside a cupboard and could not move.
//
//  Two answers, both here so they share one idea of "open":
//
//    - keepsBaseOpen: furniture may never cover the spawn pad, and may never cut
//      off any part of the base somebody could previously walk to. Every piece of
//      placement - the bots, the player's preview, and furnish on seal - asks it.
//    - spawnPoint: and if a base is boxed in anyway, by walls or by anything this
//      did not foresee, a respawn goes to the nearest spot with room to move
//      rather than into the box.
//
//  The unit here is a BERTH rather than a tile, because an actor is not a tile. Its
//  hitbox is under one tile wide and nearly two tall, so standing somewhere needs
//  a tile and the tile above it clear, walking sideways needs a two-tall gap, and
//  walking up or down needs only a one-wide one. A berth is named by its lower
//  tile; two berths next to each other are a step somebody can take.
//

import Foundation

extension World {

    // MARK: - Spawning

    /// Where this team's actor comes back to life.
    ///
    /// The centre of the claim, as it always was, whenever that is somewhere you
    /// can move from. When it is not, the nearest berth that has room around it -
    /// searched outward from the centre, so it is inside your own walls whenever
    /// your walls have any room left in them, and just outside them when they do
    /// not.
    func spawnPoint(for team: TeamID) -> Vec2 {
        guard let claim = claims[team] else { return .zero }
        let centre = claim.centreTile
        let need = GameConfig.Base.spawnRoom

        // The old spot, whenever it is still a good one. An actor standing on the
        // centre tile's middle reaches into the tile above and the one below, so
        // all three have to be clear, and there has to be somewhere to go.
        let column = [GridPoint(col: centre.col, row: centre.row - 1),
                      centre,
                      GridPoint(col: centre.col, row: centre.row + 1)]
        if column.allSatisfy({ isPassable($0, for: team) }),
           reachableBerths(from: spawnAnchors(of: centre), for: team,
                           within: nil, besides: [], limit: need).count >= need {
            return centre.center
        }

        // Otherwise the nearest berth with room around it. Distance first and then
        // row and column, so two runs of a seed always pick the same one.
        let reach = claim.size / 2 + GameConfig.Base.spawnSearchMargin
        var candidates: [(slot: GridPoint, distance: Double)] = []

        for dc in -reach...reach {
            for dr in -reach...reach {
                let slot = GridPoint(col: centre.col + dc, row: centre.row + dr)
                guard isBerth(slot, for: team, besides: []) else { continue }
                candidates.append((slot, (berthCentre(slot) - centre.center).length))
            }
        }

        candidates.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return ($0.slot.row, $0.slot.col) < ($1.slot.row, $1.slot.col)
        }

        for candidate in candidates {
            let room = reachableBerths(from: [candidate.slot], for: team,
                                       within: nil, besides: [], limit: need)
            if room.count >= need { return berthCentre(candidate.slot) }
        }

        // Nowhere on the whole search with room to move, which the map generator
        // should make impossible. The centre is at least inside your own claim.
        return centre.center
    }

    // MARK: - Furniture

    /// Whether putting something solid on these tiles leaves the base usable.
    ///
    /// Two rules. The spawn pad - the centre tile and the tiles directly above
    /// and below it, which an actor standing there overlaps - is never covered.
    /// And nothing anybody could walk to from the centre before may be cut off
    /// after: no pockets, no sealed corners, no ring round the middle.
    ///
    /// Measured within the claim. Your own walls do not stop you - you walk
    /// through them - so what can box somebody in is furniture, stone and trees,
    /// and all of that that matters is inside the claim.
    func keepsBaseOpen(placing tiles: [GridPoint], for team: TeamID) -> Bool {
        guard let claim = claims[team] else { return true }
        let centre = claim.centreTile

        let pad: Set<GridPoint> = [GridPoint(col: centre.col, row: centre.row - 1),
                                   centre,
                                   GridPoint(col: centre.col, row: centre.row + 1)]
        guard !tiles.contains(where: { pad.contains($0) }) else { return false }

        let bounds = footprint(of: claim)
        let blocked = Set(tiles)
        let anchors = spawnAnchors(of: centre)

        let before = reachableBerths(from: anchors, for: team, within: bounds, besides: [])
        let after = reachableBerths(from: anchors, for: team, within: bounds, besides: blocked)

        // Every berth that was reachable and is not simply underneath the new
        // thing must still be reachable. `after` can only ever be a subset of
        // those, so equal counts means nothing was cut off.
        let survivors = before.filter { slot in
            !blocked.contains(slot) && !blocked.contains(GridPoint(col: slot.col, row: slot.row + 1))
        }
        return after.count == survivors.count
    }

    // MARK: - Berths

    /// Whether an actor of this team could be in this tile, as far as the grid
    /// can tell. Conservative on purpose: a chest is a little under a tile, but a
    /// tile with a chest in it counts as full.
    func isPassable(_ tile: GridPoint,
                    for team: TeamID,
                    besides blocked: Set<GridPoint> = []) -> Bool {
        guard map.contains(tile), !blocked.contains(tile) else { return false }
        guard !map.blocksMovement(at: tile, for: team) else { return false }
        guard !treeTiles.contains(tile) else { return false }
        return !structureOccupies(tile)
    }

    private func isBerth(_ slot: GridPoint, for team: TeamID, besides blocked: Set<GridPoint>) -> Bool {
        isPassable(slot, for: team, besides: blocked)
            && isPassable(GridPoint(col: slot.col, row: slot.row + 1), for: team, besides: blocked)
    }

    /// Where an actor stands in a berth: centred across its tile, and vertically
    /// in the middle of the two, so its whole hitbox is inside them.
    private func berthCentre(_ slot: GridPoint) -> Vec2 {
        Vec2(x: Double(slot.col) + 0.5, y: Double(slot.row) + 1.0)
    }

    /// The two berths that contain the centre tile - below-and-on, and on-and-above.
    private func spawnAnchors(of centre: GridPoint) -> [GridPoint] {
        [GridPoint(col: centre.col, row: centre.row - 1), centre]
    }

    private func footprint(of claim: BaseClaim) -> Set<GridPoint> {
        var tiles: Set<GridPoint> = []
        for col in 0..<claim.size {
            for row in 0..<claim.size {
                tiles.insert(GridPoint(col: claim.origin.col + col, row: claim.origin.row + row))
            }
        }
        return tiles
    }

    /// Every berth reachable from these by stepping between neighbours.
    ///
    /// - Parameters:
    ///   - within: tiles both halves of a berth must be inside, or nil for anywhere.
    ///   - besides: tiles to treat as solid on top of whatever is there - the
    ///     footprint of something about to be placed.
    ///   - limit: stop once this many are found. Most callers only need to know
    ///     there is SOME room, and that answer comes back in a handful of steps.
    private func reachableBerths(from starts: [GridPoint],
                                 for team: TeamID,
                                 within bounds: Set<GridPoint>?,
                                 besides blocked: Set<GridPoint>,
                                 limit: Int = Int.max) -> Set<GridPoint> {
        func admits(_ slot: GridPoint) -> Bool {
            if let bounds {
                guard bounds.contains(slot),
                      bounds.contains(GridPoint(col: slot.col, row: slot.row + 1)) else { return false }
            }
            return isBerth(slot, for: team, besides: blocked)
        }

        var seen: Set<GridPoint> = []
        var queue: [GridPoint] = []

        for start in starts where !seen.contains(start) && admits(start) {
            seen.insert(start)
            queue.append(start)
        }

        var head = 0
        while head < queue.count, seen.count < limit {
            let slot = queue[head]
            head += 1

            let neighbours = [GridPoint(col: slot.col + 1, row: slot.row),
                              GridPoint(col: slot.col - 1, row: slot.row),
                              GridPoint(col: slot.col, row: slot.row + 1),
                              GridPoint(col: slot.col, row: slot.row - 1)]

            for next in neighbours where !seen.contains(next) && admits(next) {
                seen.insert(next)
                queue.append(next)
            }
        }

        return seen
    }
}
