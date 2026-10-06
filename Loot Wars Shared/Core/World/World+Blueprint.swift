//
//  World+Blueprint.swift
//  Loot Wars
//
//  Where a team's next walls should go: the recommended base.
//
//  Lives in the world rather than in the renderer that draws it, because two
//  things need the same answer - the dark markers that show you where to build,
//  and auto building, which builds there for you as you walk past (see
//  AssistSystem). One answer means the walls go up exactly where the markers
//  said they would.
//

extension World {

    /// The shortest side a recommended base can have.
    ///
    /// Six, because the smallest legal base encloses sixteen tiles - a four-by-four
    /// room - and the outline round a four-by-four is six by six. Anything smaller
    /// would be recommending a shape that does not count when it is finished.
    static let smallestBaseSide = 6

    /// The base a team is building: a box, and the gaps still left in its
    /// outline. Interior is anything strictly inside the outline.
    struct BasePlan {
        let lowCol: Int, highCol: Int, lowRow: Int, highRow: Int
        let gaps: [GridPoint]
        /// Outline tiles that are free but cannot take a wall yet, because a wall
        /// just inside them would make the ring two thick - usually a corner with
        /// an old wall still standing diagonally inside it.
        var blocked: [GridPoint] = []
        /// False for the generated template, which has no box of its own.
        let hasBox: Bool

        func isInterior(_ point: GridPoint) -> Bool {
            hasBox && point.col > lowCol && point.col < highCol
                && point.row > lowRow && point.row < highRow
        }

        /// On the outline, or a single step either side of it.
        func isAlongOutline(_ point: GridPoint) -> Bool {
            guard hasBox else { return false }
            let near = point.col >= lowCol - 1 && point.col <= highCol + 1
                && point.row >= lowRow - 1 && point.row <= highRow + 1
            let deepInside = point.col > lowCol + 1 && point.col < highCol - 1
                && point.row > lowRow + 1 && point.row < highRow - 1
            return near && !deepInside
        }

        /// Outside the outline, but only by a single step.
        func isJustOutside(_ point: GridPoint) -> Bool {
            guard hasBox else { return false }
            let inside = point.col >= lowCol && point.col <= highCol
                && point.row >= lowRow && point.row <= highRow
            let near = point.col >= lowCol - 1 && point.col <= highCol + 1
                && point.row >= lowRow - 1 && point.row <= highRow + 1
            return near && !inside
        }
    }

    /// The gaps in the square this player looks like they are building.
    func recommendedWalls(for team: TeamID, walls: Set<GridPoint>,
                          towardsMiddle: Bool = false,
                          following feet: GridPoint? = nil) -> [GridPoint] {
        basePlan(for: team, walls: walls, towardsMiddle: towardsMiddle, following: feet)?.gaps ?? []
    }

    /// The square this team looks like it is building, and its gaps.
    ///
    /// With nothing laid there is no evidence, so the generated plan stands in -
    /// which is also what makes a first base feel like the game had a plan for it.
    /// From the first wall onwards the recommendation is drawn round the walls
    /// themselves, so it follows whoever is not following the plan.
    ///
    /// Auto building (see AssistSystem) draws it round the player as well as the
    /// walls - FOLLOWING - so the base goes where they walk rather than where the
    /// template put it, and grow it TOWARDS THE MIDDLE of the claim, so the player
    /// ends up on its edge rather than in a corner of it. When to follow is the
    /// caller's decision: AssistSystem only does once somebody has stood just
    /// over the outline for a moment.
    func basePlan(for team: TeamID, walls: Set<GridPoint>,
                  towardsMiddle: Bool = false,
                  following feet: GridPoint? = nil) -> BasePlan? {
        guard let claim = self.claim(for: team) else { return nil }

        let limitLow = claim.origin
        let limitHigh = GridPoint(col: claim.origin.col + claim.size - 1,
                                  row: claim.origin.row + claim.size - 1)
        let centre = claim.centreTile
        let follow = feet.flatMap { claim.contains($0) ? $0 : nil }

        // Grown to the smallest legal base, then pushed back inside the claim if
        // that took it over the edge. Growing first and clamping after is what
        // keeps a base started in a corner square rather than squashed against the
        // boundary.
        // Auto building makes a roomier square than the smallest legal one - see
        // GameConfig.Assist.baseSide.
        let smallest = towardsMiddle ? max(World.smallestBaseSide, GameConfig.Assist.baseSide)
                                     : World.smallestBaseSide

        func stretch(_ low: inout Int, _ high: inout Int, min lowest: Int, max highest: Int,
                     middle: Int) {
            let upFirst = !towardsMiddle || (low + high) / 2 <= middle
            while high - low + 1 < smallest {
                if upFirst {
                    if high < highest { high += 1 } else if low > lowest { low -= 1 } else { break }
                } else {
                    if low > lowest { low -= 1 } else if high < highest { high += 1 } else { break }
                }
            }
            low = max(lowest, low)
            high = min(highest, high)
        }

        func box(round points: Set<GridPoint>) -> (Int, Int, Int, Int) {
            var lowCol = points.map(\.col).min() ?? 0
            var highCol = points.map(\.col).max() ?? 0
            var lowRow = points.map(\.row).min() ?? 0
            var highRow = points.map(\.row).max() ?? 0
            stretch(&lowCol, &highCol, min: limitLow.col, max: limitHigh.col, middle: centre.col)
            stretch(&lowRow, &highRow, min: limitLow.row, max: limitHigh.row, middle: centre.row)
            return (lowCol, highCol, lowRow, highRow)
        }

        var points = walls
        if let follow { points.insert(follow) }

        guard !points.isEmpty else {
            let gaps = (baseLayouts[team]?.tiles ?? [])
                .filter { BuildSystem.isBuildableTile($0, for: team, in: self)
                          && BuildSystem.keepsWallThin($0, for: team, in: self) }
            return BasePlan(lowCol: 0, highCol: 0, lowRow: 0, highRow: 0, gaps: gaps, hasBox: false)
        }

        let (lowCol, highCol, lowRow, highRow) = box(round: points)

        // The outline of that box, and only the parts of it still missing.
        var outline: [GridPoint] = []

        for col in lowCol...highCol {
            outline.append(GridPoint(col: col, row: lowRow))
            outline.append(GridPoint(col: col, row: highRow))
        }
        for row in (lowRow + 1)..<highRow {
            outline.append(GridPoint(col: lowCol, row: row))
            outline.append(GridPoint(col: highCol, row: row))
        }

        let free = outline.filter { BuildSystem.isBuildableTile($0, for: team, in: self) }
        let gaps = free.filter { BuildSystem.keepsWallThin($0, for: team, in: self) }
        let blocked = free.filter { !BuildSystem.keepsWallThin($0, for: team, in: self) }
        return BasePlan(lowCol: lowCol, highCol: highCol, lowRow: lowRow, highRow: highRow,
                        gaps: gaps, blocked: blocked, hasBox: true)
    }
}
