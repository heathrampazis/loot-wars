//
//  World.swift
//  Loot Wars
//
//  THE game state. If it is not in here, it is not game state.
//  Note there is no SpriteKit anywhere in Core - that is deliberate and worth
//  protecting. It is what would let this same code run on a host or a server.
//

import Foundation

final class World {

    private(set) var tick: Int = 0

    /// Seconds of match played. Accumulated from the steps actually taken rather
    /// than derived from the tick count, so it stays honest if the timestep ever
    /// changes. The match timer and scoreboard will want this too.
    private(set) var elapsed: Double = 0

    /// Whether bombs have started turning up yet.
    ///
    /// Asked by everything that could hand one out, so the grace period cannot be
    /// got round by finding a chest instead of a crate.
    var bombsAllowed: Bool { elapsed >= GameConfig.Match.bombGrace }

    /// Whether the bomb supply has finished ramping up - see Match.bombRampEnd.
    var bombsAtFullSupply: Bool { elapsed >= GameConfig.Match.bombRampEnd }

    /// How many bombs are lying on the ground right now.
    var looseBombCount: Int {
        groundItems.values.filter { $0.pickup == .item(.bomb) }.count
    }

    /// Whether another bomb may land on the ground - see Loot.maxLooseBombs.
    var roomForLooseBomb: Bool { looseBombCount < GameConfig.Loot.maxLooseBombs }

    /// How much of its weight a crate's bomb row carries right now, nought to one.
    ///
    /// Nothing before the grace period ends, then a climb from
    /// Match.bombStartShare to full by Match.bombRampEnd, and nothing again
    /// while the ground already holds its share of bombs.
    var bombShare: Double {
        guard bombsAllowed, roomForLooseBomb else { return 0 }
        let start = GameConfig.Match.bombGrace
        let span = max(1, GameConfig.Match.bombRampEnd - start)
        let t = min(1, max(0, (elapsed - start) / span))
        let low = GameConfig.Match.bombStartShare
        return low + (1 - low) * t
    }

    /// Seconds left on the clock, floored at zero.
    var timeRemaining: Double { max(0, duration - elapsed) }

    /// How long this match runs, in seconds. The full length unless the screen
    /// that made the world says otherwise - shorter while a player is early in
    /// the roadmap, see Roadmap.matchLength. Set before the first step.
    var duration: Double = GameConfig.Match.duration

    /// How hard the bots play this match - see Difficulty. Hard, the game as
    /// tuned, unless the screen that made the world says otherwise. Set before
    /// the first step.
    var difficulty: Difficulty = .hard

    /// How far the match has run, nought to one.
    ///
    /// The one place the phrase "late in the match" is defined. Chest loot and the
    /// respawn kit both read it, so "late" means the same thing to both and a
    /// change to the match length moves them together rather than leaving tuned
    /// constants behind in two files.
    var matchProgress: Double {
        min(1, max(0, elapsed / duration))
    }

    /// Whether the whistle has gone.
    ///
    /// Nothing in Core acts on this - systems do not check it and would happily
    /// keep running. Stopping is the scene's job, because "should the simulation
    /// advance" is a question about the app rather than about the world, and a
    /// networked host would answer it somewhere else again.
    var isOver: Bool { timeRemaining <= 0 }

    /// Who won, and by how much. Just the standings with a nicer name at the point
    /// where they stop changing.
    var winner: TeamID? { standings.first?.team }

    /// Read freely, but change only through setTile, so the renderer always knows
    /// when the map has moved on.
    private(set) var map: TileMap

    /// Bumped every time a tile changes. The renderer compares this against what it
    /// last drew, which is far cheaper than diffing four thousand tiles a frame.
    private(set) var mapRevision: Int = 0

    /// Bumped every time a crate, chest or machine starts or stops existing.
    ///
    /// Separate from mapRevision on purpose: the renderer redraws four thousand
    /// tiles when THAT moves, and a crate being opened is not a reason to do it.
    /// What this key covers is the enclosure, which cares whether a structure is
    /// standing in a gap, and structureTiles, which is the lookup that answers it.
    ///
    /// Moving a structure would need this too, and nothing does - a crate, a chest
    /// and a machine are each put down once and taken away once. Systems write
    /// mutated copies back into these dictionaries constantly (timers, contents,
    /// health) and none of those touch a position, which is why the write-backs do
    /// not bump it. Anything that ever DOES move one has to.
    private(set) var structureRevision: Int = 0

    private func structuresChanged() { structureRevision &+= 1 }

    let claims: [TeamID: BaseClaim]

    /// Round obstacles. Not tiles - see TreePatch for why.
    let trees: [TreePatch]

    /// Every tile a clump overlaps, worked out once at the start of the match.
    ///
    /// Forty-five clumps, and asking "is there a tree on this tile" used to walk
    /// all of them. That is fine once and ruinous sixty times a second: the
    /// enclosure fill alone asked it thousands of times a frame. Trees are declared
    /// `let` a line above, so there is no version of this that can go stale.
    let treeTiles: Set<GridPoint>

    let baseLayouts: [TeamID: BaseLayout]

    var actors: [ActorID: Actor] = [:]
    var projectiles: [Projectile] = []
    var bombs: [Bomb] = []

    /// Where bombs went off this tick. Drained by the renderer, which is the only
    /// thing that cares - the simulation has already applied the damage.
    /// What has happened since the screen last looked. See WorldEvent.
    private var recentEvents: [WorldEvent] = []

    /// An array rather than a dictionary, because machines never come or go during
    /// a match - and a fixed order is what keeps their payouts deterministic.
    /// Keyed rather than an array, because machines come and go now - bought and
    /// placed, and blown up by whoever gets through the wall. An array indexed
    /// during iteration was fine while the set was fixed for the match and is a
    /// bug waiting to happen once it is not.
    var arcades: [ArcadeID: Arcade] = [:]

    private var nextArcadeID = 0

    /// Guns standing in bases. Keyed for the reason machines are: they come and go
    /// mid-match, and an array indexed while something is being destroyed is a bug
    /// waiting for the second one.
    var turrets: [TurretID: Turret] = [:]

    private var nextTurretID = 0

    private(set) var lootboxes: [LootboxID: Lootbox] = [:]
    var chests: [ChestID: Chest] = [:]
    private(set) var groundItems: [GroundItemID: GroundItem] = [:]

    /// An opened crate, waiting to come back in the same spot.
    private struct PendingLootbox {
        let tile: GridPoint
        // No rarity carried: whether it comes back rare is rolled on the way
        // back - see tickLootboxRespawns and GameConfig.Loot.rareChance.
        var timer: Double
    }

    private var pendingLootboxes: [PendingLootbox] = []

    private var nextChestID = 0
    private var nextProjectileID = 0
    private var nextBombID = 0
    private var nextGroundItemID = 0
    private var nextLootboxID = 0

    /// The one source of randomness during play. Nothing in Core may call
    /// Int.random - everything goes through here, so a seed reproduces a match
    /// exactly, bots included.
    var rng: SeededRandom

    /// What each team has scored. The leaderboard reads this and nothing else.
    private(set) var scores: [TeamID: Int] = [:]

    /// What each player did this match - see MatchStats. Only ever written to
    /// during a match; the results screen is the one thing that reads it.
    private(set) var stats: [ActorID: MatchStats] = [:]

    /// Adds to a player's match stats.
    func tally(_ id: ActorID, _ change: (inout MatchStats) -> Void) {
        change(&stats[id, default: MatchStats()])
    }

    func score(for team: TeamID) -> Int { scores[team] ?? 0 }

    /// The leading score, or zero before anyone has any. What a bot measures a
    /// target's standing against when deciding who is worth going after.
    var bestScore: Int { scores.values.max() ?? 0 }

    /// How far clear of the field a team is, from nothing to running away with it.
    ///
    /// The one definition of "who is winning", because there were two ad-hoc ones
    /// and the bots read them differently: shouldEngage asked whether a target was
    /// level with the best score at all, and weightedDistance took a share of it.
    /// One was a cliff and the other a slope, and neither knew anything about
    /// raiding - which is the half of the game somebody good actually dominates.
    ///
    /// Measured against the AVERAGE of everyone else rather than against the
    /// runner-up. One other team having a good match should not make a runaway
    /// leader read as ordinary, and in an eight-way free-for-all the field is the
    /// thing you are ahead OF.
    ///
    /// It applies to bots exactly as it applies to the player. A rule that only
    /// pointed at whoever was holding the phone would be the game cheating; this
    /// one says that in a free-for-all the leader is everybody's problem, which is
    /// a fact about the shape of the match and true of all eight teams.
    func lead(of team: TeamID) -> Double {
        let mine = score(for: team)
        guard mine > 0 else { return 0 }

        var total = 0
        var count = 0
        for other in TeamID.all where other != team {
            total += score(for: other)
            count += 1
        }
        guard count > 0 else { return 0 }

        let average = Double(total) / Double(count)
        return min(1, max(0, (Double(mine) - average) / GameConfig.AI.leadScale))
    }

    /// How far behind the best team a team is.
    ///
    /// What a bot is measured by when it decides how hard to try. A bot at the top
    /// is under no pressure and plays as it always has; one being left behind
    /// sharpens up - see AIBrain.shotToTake, reactionDelay and worthBuying.
    ///
    /// NOT THE MIRROR OF lead, and the comment that used to sit here said it was.
    /// "Same number seen from the other end" is a pleasing sentence and it is
    /// false: lead measures against the AVERAGE of the other seven and this
    /// measures against the BEST of them, so a match can perfectly well have six
    /// teams reading as behind and nobody reading as ahead. That happens in every
    /// close match.
    ///
    /// They are different on purpose, and making them agree would break one of
    /// them. lead asks "is this team everybody's problem", and the field is what
    /// you are a problem relative to - one other team having a good match should
    /// not make a runaway read as ordinary. This asks "is this bot getting
    /// beaten", and the answer to that is about the person actually beating them.
    ///
    /// The difference matters most in exactly the match this was tuned for: one
    /// runaway leader on three times the field. Measured against the average,
    /// every bot above mid-table would read as comfortable - because the average
    /// has been dragged up by the very team that is crushing them - and the six
    /// bots who most need to sharpen up would get nothing. Measured against the
    /// best, they all correctly read as losing, which they all correctly are.
    ///
    /// Its own scale for the same reason. One constant serving both meant the
    /// thresholds on either side were not comparable numbers, and a max-based
    /// measure is far more easily saturated than a mean-based one.
    /// Whoever is furthest ahead of the field, other than `team`, and by how
    /// much - or nil when nobody is past GameConfig.AI.leaderChaseAt.
    ///
    /// Asked from a bot's point of view: "is somebody running away with this, and
    /// is it not me". Teams in id order, so a tie resolves the same way every run.
    func runaway(against team: TeamID) -> (team: TeamID, lead: Double)? {
        // Nobody is singled out for being ahead on Easy - see Difficulty.
        guard difficulty.pressesTheLeader else { return nil }

        var best: (team: TeamID, lead: Double)?

        for other in TeamID.all where other != team {
            let ahead = lead(of: other)
            guard ahead >= GameConfig.AI.leaderChaseAt, ahead > (best?.lead ?? 0) else { continue }
            best = (other, ahead)
        }

        return best
    }

    func behind(_ team: TeamID) -> Double {
        min(1, max(0, Double(bestScore - score(for: team)) / GameConfig.AI.deficitScale))
    }

    /// Adds to a team's score.
    ///
    /// Called from wherever the thing actually happened, which is why there is no
    /// ScoreSystem. One that ran afterwards would have to work out what had occurred
    /// by comparing states, and would get it wrong the first time two of them
    /// happened in the same tick.
    /// Puts tokens in an actor's pocket.
    ///
    /// Tokens belong to the ACTOR rather than the team, unlike score - they are
    /// spent by somebody standing at a shop, and a team-wide purse would be a
    /// different game.
    func awardTokens(_ count: Int, to id: ActorID) {
        guard count > 0, var actor = actors[id] else { return }
        actor.tokens += count
        actors[id] = actor
        tally(id) { $0.tokensEarned += count }
    }

    func award(_ points: Int, to team: TeamID) {
        guard points != 0 else { return }
        scores[team, default: 0] += points
    }

    /// Teams best first, ties broken by id so two teams on the same score never
    /// swap places from frame to frame.
    var standings: [(team: TeamID, score: Int)] {
        TeamID.all
            .map { (team: $0, score: score(for: $0)) }
            .sorted { $0.score == $1.score ? $0.team.raw < $1.team.raw : $0.score > $1.score }
    }

    /// How far the camera can see from the player, in tiles, on each axis.
    ///
    /// Set by the renderer, which is the only thing that knows the screen size, and
    /// read by the bots so they will not open fire on somebody who cannot see them.
    /// A plain Vec2 rather than anything SpriteKit-shaped, so Core stays Core.
    ///
    /// The default is deliberately generous: if nobody ever sets it, bots behave as
    /// they did before rather than standing around refusing to fight.
    var visibleHalfExtent = Vec2(x: 100, y: 100)

    /// Which actor this device is driving. Today it is the only one; later it is
    /// simply one of eight. Nothing else in the code assumes it is special.
    let localPlayerID: ActorID

    init(generated: GeneratedMap) {
        self.map = generated.map
        self.claims = generated.claims
        self.trees = generated.trees
        self.baseLayouts = generated.baseLayouts

        // Offset from the map's seed, so play does not replay the same number
        // sequence that built the terrain.
        var rng = SeededRandom(seed: generated.seed &+ 0x9E37)

        var crates: [LootboxID: Lootbox] = [:]
        for box in generated.lootboxes {
            crates[box.id] = box
        }
        self.lootboxes = crates

        var wooded: Set<GridPoint> = []
        for patch in generated.trees {
            for col in (patch.origin.col - 1)...(patch.origin.col + patch.size) {
                for row in (patch.origin.row - 1)...(patch.origin.row + patch.size) {
                    let tile = GridPoint(col: col, row: row)
                    if patch.overlaps(tile) { wooded.insert(tile) }
                }
            }
        }
        self.treeTiles = wooded
        self.nextLootboxID = generated.lootboxes.count
        var machines: [ArcadeID: Arcade] = [:]
        for machine in generated.arcades { machines[machine.id] = machine }
        self.arcades = machines
        self.nextArcadeID = generated.arcades.count

        // One actor per team, standing in the middle of its own claim.
        //
        // The local player is simply one of the eight. Nothing else about it is
        // special, and nothing downstream may assume otherwise - that is what makes
        // an AI or a remote player a drop-in replacement for the joystick.
        var spawned: [ActorID: Actor] = [:]
        var local = ActorID(0)
        var brainsGiven = 0

        for index in 0..<TeamID.count {
            let team = TeamID(index)
            guard let claim = generated.claims[team] else { continue }

            let id = ActorID(index)
            let spawn = claim.centreTile.center
            var actor = Actor(id: id, team: team, position: spawn)

            if team == generated.localTeam {
                local = id
            } else if brainsGiven < GameConfig.AI.botCount {
                brainsGiven += 1
                let heading = Vec2.fromAngle(Double.random(in: 0..<(2 * .pi), using: &rng))
                actor.ai = AIState(
                    heading: heading,
                    desiredHeading: heading,
                    // Staggered, so all seven do not change their minds in unison.
                    decisionTimer: Double.random(in: GameConfig.AI.decisionInterval,
                                                 using: &rng),
                    turnPreference: Bool.random(using: &rng) ? 1 : -1
                )
                actor.ai?.caution = Double.random(in: GameConfig.AI.cautionRange, using: &rng)
            }

            spawned[id] = actor
        }

        self.actors = spawned
        self.localPlayerID = local
        self.rng = rng

        // Names: the player's own until the screen sets it, and a different
        // handle for every bot, drawn from the world's generator so a seed
        // replays with the same names. Sorted, so the draw order is fixed.
        var pool = PlayerNames.bots.shuffled(using: &self.rng)
        for id in actors.keys.sorted(by: { $0.raw < $1.raw }) {
            if id == local {
                actors[id]?.name = PlayerNames.defaultName
            } else {
                actors[id]?.name = pool.isEmpty ? "bot \(id.raw)" : pool.removeFirst()
            }
        }
    }

    /// Switches easy controls on or off for the player - from Settings, before
    /// the first step. See AssistSystem.
    func setLocalAssist(_ on: Bool) {
        actors[localPlayerID]?.assisted = on
    }

    /// Sets the player's own name - from Settings, before the first step.
    func setLocalName(_ name: String) {
        actors[localPlayerID]?.name = PlayerNames.clean(name)
    }

    /// Whoever plays for a team - one actor a team - by name.
    func name(of team: TeamID) -> String {
        actors.values.first { $0.team == team }?.name ?? ""
    }

    var localPlayer: Actor? { actors[localPlayerID] }

    /// Which of the extras are in this match - see Unlocks. Everything unless the
    /// screen that made the world says otherwise; set before the first step.
    var unlocks: Unlocks = .all

    func claim(for team: TeamID) -> BaseClaim? { claims[team] }

    /// Every tile of a team's own claim, for when there is no enclosure to search.
    private func claimTiles(of team: TeamID) -> Set<GridPoint> {
        guard let claim = claims[team] else { return [] }

        var tiles: Set<GridPoint> = []
        for col in 0..<claim.size {
            for row in 0..<claim.size {
                tiles.insert(GridPoint(col: claim.origin.col + col,
                                       row: claim.origin.row + row))
            }
        }
        return tiles
    }

    /// The next wall this team should lay, or nil once the base is finished.
    ///
    /// Walks the plan in order and takes the first tile that is still free, so a
    /// spot temporarily blocked by a crate is skipped rather than stalling the
    /// whole build.
    func nextBuildTile(for team: TeamID) -> GridPoint? {
        baseLayouts[team]?.tiles.first {
            BuildSystem.isBuildableTile($0, for: team, in: self)
                && BuildSystem.keepsWallThin($0, for: team, in: self)
        }
    }

    // MARK: - Loot

    /// The nearest lootbox this actor can reach, or nil.
    ///
    /// Reach is the actor's own hitbox grown slightly, tested against the crate's
    /// hitbox - not a distance between two points. Since crates are solid you are
    /// already touching one when you are next to it, so the margin only has to cover
    /// the hair of clearance collision leaves behind.
    ///
    /// Lives here so the Open button and the system that actually opens a crate can
    /// never disagree about which one, or about whether you are close enough.
    func reachableLootbox(for actor: Actor) -> Lootbox? {
        let reach = actor.hitbox.expanded(by: GameConfig.Loot.openReach)

        var closest: Lootbox?
        var shortest = Double.greatestFiniteMagnitude

        for box in lootboxes.values {
            // A supply drop still counting down cannot be reached for, so the
            // Open button, the rim and the bots all agree it is not open yet.
            guard !box.isLocked else { continue }
            guard reach.intersects(box.hitbox) else { continue }

            let distance = (box.position - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            closest = box
        }

        return closest
    }

    func removeLootbox(_ id: LootboxID) {
        guard let crate = lootboxes[id] else { return }
        lootboxes[id] = nil
        structuresChanged()

        // A supply drop is a one-off. It lands, somebody takes it, it is gone.
        guard !crate.supply else { return }

        // Crates come back. Without that, seven bots strip the map bare within a
        // minute and there is nothing left to play around.
        pendingLootboxes.append(PendingLootbox(tile: crate.tile,
                                               timer: GameConfig.Loot.respawnDelay))
    }

    // MARK: - Supply drops

    /// How many supply drops have landed this match - see SupplyDropSystem.
    var supplyDropsSent = 0

    /// Every supply drop on the map, oldest first.
    var supplyDrops: [Lootbox] {
        lootboxes.values.filter { $0.supply }.sorted { $0.id.raw < $1.id.raw }
    }

    /// - Parameter seconds: how long it stays locked. Always the full countdown in
    ///   a match; the How to Play picture shortens it so the scene fits a loop.
    @discardableResult
    func spawnSupplyDrop(at tile: GridPoint,
                         lockedFor seconds: Double = GameConfig.SupplyDrop.unlockTime) -> LootboxID {
        let crate = Lootbox(id: LootboxID(nextLootboxID), tile: tile, rare: false,
                            supply: true, lockTimer: seconds)
        nextLootboxID += 1
        lootboxes[crate.id] = crate
        supplyDropsSent += 1
        structuresChanged()
        return crate.id
    }

    /// Whether an opened crate is waiting to come back on or right beside this
    /// tile - so a supply drop never lands where a crate is about to reappear.
    func awaitsCrate(near tile: GridPoint) -> Bool {
        pendingLootboxes.contains { abs($0.tile.col - tile.col) <= 1 && abs($0.tile.row - tile.row) <= 1 }
    }

    /// Counts every supply drop's lock down.
    func tickSupplyLocks(dt: Double) {
        for id in lootboxes.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var crate = lootboxes[id], crate.supply, crate.isLocked else { continue }
            crate.lockTimer = max(0, crate.lockTimer - dt)
            lootboxes[id] = crate
        }
    }

    func tickLootboxRespawns(dt: Double) {
        guard !pendingLootboxes.isEmpty else { return }

        var stillWaiting: [PendingLootbox] = []

        for var pending in pendingLootboxes {
            pending.timer -= dt

            if pending.timer > 0 {
                stillWaiting.append(pending)
                continue
            }

            // Crates are solid, so one appearing under somebody would shove them
            // out of the way. Wait for them to move on instead.
            // Rare or not is decided HERE, on the way back, by how far the match
            // has run - see GameConfig.Loot.rareChance - and never past the cap.
            // Rolled only once the spot is clear, so waiting for somebody to move
            // off it does not get extra chances at a rare one.
            let crate = Lootbox(id: LootboxID(nextLootboxID),
                                tile: pending.tile,
                                rare: false)
            if actors.values.contains(where: { $0.isAlive && $0.hitbox.intersects(crate.hitbox) }) {
                pending.timer = 1
                stillWaiting.append(pending)
                continue
            }

            var placed = crate
            let rareStanding = lootboxes.values.filter { $0.rare }.count
            if rareStanding < GameConfig.Loot.rareCap(at: matchProgress) {
                placed.rare = Double.random(in: 0..<1, using: &rng)
                    < GameConfig.Loot.rareChance(at: matchProgress)
            }

            nextLootboxID += 1
            lootboxes[placed.id] = placed
            structuresChanged()
        }

        pendingLootboxes = stillWaiting
    }

    // MARK: - Structures

    /// Everything solid that is not a tile: crates and arcade machines.
    ///
    /// This exists as ONE question because the answer is needed in five places -
    /// walking, shooting, dropping, a bot's pathing and a bot's line of sight - and
    /// the arcade proved the point: adding a second kind of structure to five
    /// separate `lootboxes.values.contains` checks means four of them are one day
    /// going to be right and one is not.
    func structureBlocks(_ point: Vec2) -> Bool {
        if lootboxes.values.contains(where: { $0.hitbox.contains(point) }) { return true }
        if arcades.values.contains(where: { $0.hitbox.contains(point) }) { return true }
        if chests.values.contains(where: { $0.hitbox.contains(point) }) { return true }
        if turrets.values.contains(where: { $0.hitbox.contains(point) }) { return true }
        return false
    }

    /// Which whole tiles have something standing on them.
    ///
    /// The tile-sized version of structureIntersects, answered from a set instead
    /// of by asking seventy-odd structures one at a time. Everything that reasons
    /// about a GRID - can I build here, is this gap plugged, where does a chest go -
    /// wants this one; structureIntersects stays for the callers with a real box.
    func structureOccupies(_ tile: GridPoint) -> Bool {
        structureTiles.contains(tile)
    }

    /// Every tile any crate, chest or machine covers, worked out once per change.
    ///
    /// Built by walking each structure's own bounds rather than by testing every
    /// tile against every structure, so this costs about a hundred insertions
    /// instead of the four thousand times seventy it would take the other way round.
    private var structureTileCache: (revision: Int, value: Set<GridPoint>)?

    var structureTiles: Set<GridPoint> {
        if let held = structureTileCache, held.revision == structureRevision {
            return held.value
        }

        var tiles: Set<GridPoint> = []

        func cover(_ box: Box) {
            for col in Int(box.lower.x.rounded(.down))...Int(box.upper.x.rounded(.down)) {
                for row in Int(box.lower.y.rounded(.down))...Int(box.upper.y.rounded(.down)) {
                    let tile = GridPoint(col: col, row: row)

                    // Asked rather than assumed, so this agrees with
                    // structureIntersects exactly - a box that only grazes the edge
                    // of a tile does not cover it, and the bounds above are a
                    // candidate list rather than an answer.
                    if box.intersects(Box(tile: tile)) { tiles.insert(tile) }
                }
            }
        }

        for crate in lootboxes.values { cover(crate.hitbox) }
        for machine in arcades.values { cover(machine.hitbox) }
        for chest in chests.values { cover(chest.hitbox) }
        for turret in turrets.values { cover(turret.hitbox) }

        structureTileCache = (structureRevision, tiles)
        return tiles
    }

    /// The same question asked of an area rather than a point, for the things that
    /// reason about whole tiles - building, and putting a chest down.
    func structureIntersects(_ box: Box) -> Bool {
        if lootboxes.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        if arcades.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        if chests.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        if turrets.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        return false
    }

    // MARK: - Chests

    @discardableResult
    func spawnChest(at tile: GridPoint, owner: TeamID) -> ChestID {
        let chest = Chest(id: ChestID(nextChestID), tile: tile, owner: owner)
        nextChestID += 1
        chests[chest.id] = chest
        structuresChanged()
        return chest.id
    }

    /// Takes a chest off the map.
    ///
    /// Nothing calls this today: a stripped chest stays standing and refills - see
    /// ChestSystem. It is kept because a chest caught in a blast is the obvious
    /// next thing to want, and because "how does a chest stop existing" should have
    /// one answer rather than being reinvented at the call site.
    func removeChest(_ id: ChestID) {
        chests[id] = nil
        structuresChanged()
    }

    @discardableResult
    func spawnArcade(at origin: GridPoint,
                     kind: ArcadeKind = .full,
                     owner: TeamID?) -> ArcadeID {
        let machine = Arcade(id: ArcadeID(nextArcadeID), kind: kind, origin: origin,
                             owner: owner, emitTimer: GameConfig.Arcade.emitInterval)
        nextArcadeID += 1
        arcades[machine.id] = machine
        structuresChanged()
        return machine.id
    }

    func removeArcade(_ id: ArcadeID) {
        arcades[id] = nil
        structuresChanged()
    }

    // MARK: - Turrets

    @discardableResult
    func spawnTurret(at origin: GridPoint, owner: TeamID) -> TurretID {
        var turret = Turret(id: TurretID(nextTurretID), origin: origin, owner: owner)

        // A bot's turret is the stronger kind - see GameConfig.Turret.botHealth.
        if isBotTeam(owner), difficulty.fortifiesBotTurrets {
            turret.fortified = true
            turret.health = turret.maxHealth
        }

        nextTurretID += 1
        turrets[turret.id] = turret
        structuresChanged()
        return turret.id
    }

    func removeTurret(_ id: TurretID) {
        turrets[id] = nil
        structuresChanged()
    }

    func hasTurret(_ team: TeamID) -> Bool {
        turrets.values.contains { $0.owner == team }
    }

    func turretCount(ownedBy team: TeamID) -> Int {
        turrets.values.reduce(0) { $0 + ($1.owner == team ? 1 : 0) }
    }

    /// Whether this team is played by a bot rather than a person.
    func isBotTeam(_ team: TeamID) -> Bool {
        actors.values.contains { $0.team == team && $0.ai != nil }
    }

    /// The one person on a team, for a turret's shots to be credited to.
    ///
    /// A turret is not an actor, and a projectile has to say who fired it - that
    /// is what pays a kill and what stops a bullet hitting its own side. Teams are
    /// one person each, so a turret's shots are that person's: they bought it,
    /// carried it home and stood it up, and a kill it makes while they are across
    /// the map is theirs in every way that matters to a scoreboard.
    ///
    /// Sorted, because a dictionary's order must never decide who gets paid.
    func actorID(of team: TeamID) -> ActorID? {
        actors.keys.sorted { $0.raw < $1.raw }.first { actors[$0]?.team == team }
    }

    /// Where a turret would go in this team's base, nearest to a point - the
    /// machine's search for a two-by-two, asked of a turret's own footprint.
    ///
    /// Written out rather than borrowed from nextArcadeOrigin with a mini's size,
    /// which would work today and is exactly the coupling that stops working the
    /// day somebody resizes the mini.
    func nextTurretOrigin(for team: TeamID,
                          near position: Vec2,
                          avoidingActors: Bool = true) -> GridPoint? {
        let ground = baseGround(of: team)

        var candidates: [(spot: GridPoint, distance: Double)] = []

        for origin in ground.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            let turret = Turret(id: TurretID(-1), origin: origin, owner: team)

            if avoidingActors, actors.values.contains(where: {
                $0.isAlive && $0.hitbox.intersects(turret.hitbox)
            }) { continue }

            var fits = true
            for tile in turret.tiles {
                guard ground.contains(tile),
                      tile != claims[team]?.centreTile,
                      map[tile] == .floor,
                      !structureOccupies(tile),
                      !treeTiles.contains(tile) else { fits = false; break }
            }
            guard fits else { continue }

            candidates.append((origin, (turret.centre - position).length))
        }

        return nearestOpen(candidates, for: team) {
            Turret(id: TurretID(-1), origin: $0, owner: team).tiles
        }
    }

    // What there is worth raiding in this team's base: its machines. The one place a base is
    // priced, so every raiding decision agrees on which base is the rich one.
    func lootValue(of team: TeamID) -> Int {
        // What is in the chests does not count: raiders come for the points, not the items.
        var value = 0

        // Every machine, not "does it have one". A base can hold several now, and
        // a room with three in it is worth more to break into than a room with one
        // - which this could not say while the answer was a boolean. It is also the
        // reason lifting the cap did not need a separate rule to keep raiding
        // pointed at the rich bases: the price follows the furniture.
        for machine in arcades.values where machine.owner == team {
            value += machine.kind.raidWorth
        }
        return value
    }

    /// What this base is worth GOING FOR, which is more than what is inside it.
    ///
    /// lootValue answers "what would I leave with". This answers "should I go",
    /// and the difference is the two things that are true of a base rather than of
    /// its contents: how long its owner has been left alone, and how well they are
    /// doing. Both were already being added - by chestWorthRobbing, privately, on
    /// its way to picking a chest - and the function that decides whether to open a
    /// wall at all knew about neither.
    ///
    /// That split is why the player was never raided. It is not that their base
    /// scored low: it is that the ONE path that opens a wall priced them at what
    /// was provably in their chests, and a player who has not banked anything, or
    /// whose chest was cracked and has not come back, prices at nothing. Meanwhile
    /// the leader bonus and the untouched-for-minutes bonus sat in a different
    /// function, behind a loop over chests that a player may not even own.
    ///
    /// So it is one price now, and lootValue's own comment finally holds: the bot
    /// deciding whether to cross the map and the bot deciding which wall to open
    /// cannot come to different conclusions about which base is the rich one.
    func raidWorth(of team: TeamID) -> Double {
        var worth = Double(lootValue(of: team))

        // Left alone. What finds a turtle, and what makes a base that has already
        // been emptied worth visiting again later.
        worth += min(GameConfig.AI.raidPressureCap,
                     secondsSinceRaid(of: team) * GameConfig.AI.raidPressurePerSecond)

        // And the WALL, which is the part this never counted.
        //
        // lootValue prices what a raider carries home, and that is genuinely all
        // it should price - but it is not all a raid pays. A bomb through a
        // standing wall is Score.wallDestroyed a tile and clears three to five of
        // them, so the hole alone is worth 45 to 75 points, more than the 55 a
        // cracked chest pays. None of that was in the price.
        //
        // The omission had a shape, and the shape was the player. Bot bases are
        // stocked and handed a machine the moment they seal, so they price at 55
        // on contents before anything happens; a player's chests are theirs to
        // fill and mostly are not, so they priced at nothing and the bots
        // correctly went elsewhere, all match, every match. Counting the wall
        // prices every base on the one thing every base has.
        //
        // Sealed only. A base already standing open does not need a bomb, and its
        // hole has been paid for.
        if !baseIsBreached(team) { worth += GameConfig.AI.breachWorth }

        // And winning. Whoever is out in front is worth breaking into whoever they
        // are - see World.lead, which says the same of all eight teams.
        if difficulty.pressesTheLeader {
            worth += lead(of: team) * GameConfig.AI.leaderWorth
        }

        // People are raided as readily as bots, whatever they have banked.
        if !isBotTeam(team) { worth += GameConfig.AI.playerBaseWorth }

        return worth
    }

    /// Where that loot actually stands, so a hole can be made in front of it.
    ///
    /// A base is not a point: the wall worth opening is the one nearest the thing
    /// you came for, and blowing the far side open and walking round is what makes
    /// a bot look like it is following a rule rather than robbing somebody.
    func lootSpots(of team: TeamID) -> [Vec2] {
        // Built in id order rather than dictionary order. Nothing here draws from
        // the generator, but the caller picks a minimum out of it, and two spots at
        // the same distance would otherwise resolve differently between runs of the
        // same seed - which is the kind of divergence that shows up once in a
        // thousand replays and takes a day to find.
        var spots: [Vec2] = []

        for id in chests.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let chest = chests[id], chest.owner == team else { continue }
            spots.append(chest.position)
        }

        for id in arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let machine = arcades[id], machine.owner == team else { continue }
            spots.append(machine.centre)
        }

        // Nothing standing in there, which is not the same as nothing worth doing.
        // A sealed base with an empty chest still pays its owner to hold, and
        // breaking it costs them that - so the middle of the claim stands in, and a
        // raider aims at the wall in front of it rather than not coming at all.
        // Without this, emptying somebody's base made them permanently safe.
        if spots.isEmpty, let claim = claims[team] {
            spots.append(claim.centreTile.center)
        }

        return spots
    }

    func hasArcade(_ team: TeamID) -> Bool {
        arcades.values.contains { $0.owner == team }
    }

    /// How many machines this team has standing.
    ///
    /// What crowding is measured against - see ArcadeSystem.interval, where each
    /// machine in a base slows the others down. Counted rather than asked about,
    /// because "does this base have a machine" stopped being the interesting
    /// question the moment a base could have four.
    func arcadeCount(ownedBy team: TeamID) -> Int {
        arcades.values.reduce(0) { $0 + ($1.owner == team ? 1 : 0) }
    }

    /// The ground this team may stand furniture on.
    ///
    /// Inside the walls once there are walls, anywhere on their own claim before
    /// that - chests and machines can be set down in an unfinished base on purpose,
    /// so a rule that only ever answered with enclosed ground would refuse until
    /// the wall was shut, which is the rule that was deliberately removed.
    ///
    /// One definition, because there used to be two and they disagreed. The search
    /// for somewhere to put a machine asked the ENCLOSURE - the room you actually
    /// walled in - while ArcadeSystem.canPlace asked the LAYOUT, the rectangle the
    /// generator picked for this claim and nobody is obliged to build to. Follow the
    /// blueprint and the two agree; wander off it by a couple of tiles, as the
    /// adaptive recommendation invites you to, and the game would suggest a spot
    /// inside your own base and then refuse to let you use it. That is precisely the
    /// disagreement PlacementSystem exists to make impossible, so it cannot be two
    /// pieces of code that happen to match.
    func baseGround(of team: TeamID) -> Set<GridPoint> {
        let room = enclosure(of: team).room
        guard room.isEmpty else { return room }

        return baseLayouts[team]?.region ?? claimTiles(of: team)
    }

    /// Where a machine could stand inside this team's walls, nearest to here.
    ///
    /// Six tiles rather than one, checked as a block - a footprint half inside a
    /// wall is not a placement. Walks the region in a fixed order so the same seed
    /// puts machines in the same places.
    /// - Parameter avoidingActors: whether spots somebody is standing in count as
    ///   taken. True for anybody about to PUT a machine down, since a solid six
    ///   tiles cannot appear on top of a person; false for anybody asking the
    ///   different question of whether the base has room for one at all, which is a
    ///   fact about the walls and not about where its owner happens to be standing.
    func nextArcadeOrigin(for team: TeamID,
                          kind: ArcadeKind = .full,
                          near position: Vec2,
                          avoidingActors: Bool = true) -> GridPoint? {
        let ground = baseGround(of: team)

        var candidates: [(spot: GridPoint, distance: Double)] = []

        for origin in ground.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            let machine = Arcade(id: ArcadeID(-1), kind: kind, origin: origin,
                                 owner: team, emitTimer: 0)

            // Four or six tiles of solid machine, so the same rule as a chest: not
            // on top of anybody, the placer included.
            if avoidingActors, actors.values.contains(where: {
                $0.isAlive && $0.hitbox.intersects(machine.hitbox)
            }) { continue }

            var fits = true
            for tile in machine.tiles {
                guard ground.contains(tile),
                      tile != claims[team]?.centreTile,
                      map[tile] == .floor,
                      !structureOccupies(tile),
                      !treeTiles.contains(tile) else { fits = false; break }
            }
            guard fits else { continue }

            candidates.append((origin, (machine.centre - position).length))
        }

        return nearestOpen(candidates, for: team) {
            Arcade(id: ArcadeID(-1), kind: kind, origin: $0, owner: team, emitTimer: 0).tiles
        }
    }

    /// The nearest chest you are standing close enough to open - anyone's.
    ///
    /// Lives here so the button that offers to open one and the system that moves
    /// items can never disagree about which chest, or about whether you are near
    /// enough to be reaching into it. Whether you may take from it or only look is
    /// ChestSystem's call, not this one's.
    func reachableChest(for actor: Actor) -> Chest? {
        var closest: Chest?
        var shortest = Double.greatestFiniteMagnitude

        for chest in chests.values {
            guard ChestSystem.canReach(chest, from: actor) else { continue }

            let distance = (chest.position - actor.position).length
            guard distance < shortest else { continue }
            shortest = distance
            closest = chest
        }

        return closest
    }

    /// Whether a dropped item would be reachable here.
    ///
    /// Ground items have no collision of their own, so one flung into a tree or a
    /// wall is not blocked - it is simply somewhere nobody can walk to.
    func isClearForDrop(_ point: Vec2) -> Bool {
        let tile = GridPoint(containing: point)

        guard map.contains(tile), !map.isOccupied(tile) else { return false }
        guard !trees.contains(where: { $0.contains(point) }) else { return false }
        return !structureBlocks(point)
    }

    // MARK: - Arcades

    /// Somewhere inside this team's claim to stand a chest, nearest to here.
    ///
    /// NEAREST, and that is the whole fix. This used to return the first legal tile
    /// in scan order - one fixed corner of the base - while the only caller could
    /// place a chest within a couple of tiles of where it stood. A bot laying walls
    /// on the perimeter was essentially never near that one tile, so it carried
    /// chests around all match and never put one down.
    ///
    /// Searched over the ground the wall ENCLOSES, not the claim.
    ///
    /// The two are not the same: the wall goes round a random rectangle within the
    /// claim, so most claims have ground that is theirs and yet outside their own
    /// walls. Searching the claim put chests on that ground - protected by nothing,
    /// free to anyone who strolled past, and no reason to raid anybody.
    func nextChestTile(for team: TeamID, near position: Vec2) -> GridPoint? {
        // Inside the walls if there are any, anywhere on your own ground if not.
        //
        // The fallback is not a nicety. Chests and machines can be set down in an
        // unfinished base on purpose - it is your base and your risk - so a search
        // that only ever answered with enclosed ground would refuse to suggest
        // anywhere at all until the wall was shut, which is the rule that was
        // deliberately removed.
        let room = enclosure(of: team).room
        let ground = room.isEmpty ? claimTiles(of: team) : room

        var candidates: [(spot: GridPoint, distance: Double)] = []

        // Sorted, because Set iteration order is not stable and two runs of the
        // same seed have to put the chest in the same place.
        for tile in ground.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard tile != claims[team]?.centreTile else { continue }
            guard map[tile] == .floor else { continue }
            guard !structureOccupies(tile) else { continue }
            guard !treeTiles.contains(tile) else { continue }

            // Nobody standing on it, and this is the line that stops a bot locking
            // itself in its own base forever.
            //
            // A chest is solid, so ChestSystem.canPlace refuses to drop one where a
            // living actor is - the placer included. This search did not know that,
            // so it kept answering with the tile nearest the bot, which after the
            // walk was the tile the bot was standing on. It arrived, was refused,
            // re-picked the spot under its own feet, and stayed there.
            //
            // Excluded here rather than guarded at the call site because every
            // caller wants the same thing: the AI errand, the player's placement
            // preview, and World.furnish, which spawns chests directly and would
            // otherwise drop one on somebody's head the moment their wall shut.
            guard !actors.values.contains(where: {
                $0.isAlive && $0.hitbox.intersects(Box(tile: tile))
            }) else { continue }

            candidates.append((tile, (tile.center - position).length))
        }

        return nearestOpen(candidates, for: team) { [$0] }
    }

    /// The nearest of these spots that would not box anybody in - see
    /// keepsBaseOpen.
    ///
    /// Sorted by distance and then row and column, which is the same spot the old
    /// strict-less-than scan in row order would have picked, so bases furnish
    /// exactly as they did wherever that spot was fine. The flood fill behind
    /// keepsBaseOpen is only paid for until one passes, which is nearly always the
    /// first.
    private func nearestOpen(_ candidates: [(spot: GridPoint, distance: Double)],
                             for team: TeamID,
                             covering tiles: (GridPoint) -> [GridPoint]) -> GridPoint? {
        let ordered = candidates.sorted {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return ($0.spot.row, $0.spot.col) < ($1.spot.row, $1.spot.col)
        }
        return ordered.first { keepsBaseOpen(placing: tiles($0.spot), for: team) }?.spot
    }

    /// How much of this team's wall is standing, 0 to 1.
    func baseProgress(for team: TeamID) -> Double {
        guard let plan = baseLayouts[team]?.tiles, !plan.isEmpty else { return 1 }
        let built = plan.filter { map[$0].blockOwner == team }.count
        return Double(built) / Double(plan.count)
    }

    /// The best any team is doing.
    var bestBaseProgress: Double {
        var best = 0.0
        for index in 0..<TeamID.count {
            best = max(best, baseProgress(for: TeamID(index)))
        }
        return best
    }

    /// Whether this team's wall is far enough behind the leader to stop waiting
    /// its turn. One place, because two callers ask it and they must agree: the
    /// goal that sends a bot home, and the size of the armful it takes when it
    /// gets there.
    func isFallingBehind(_ team: TeamID) -> Bool {
        baseProgress(for: team) + GameConfig.Build.catchUpGap < bestBaseProgress
    }

    /// Teams whose wall has been finished at least once this match, so the big
    /// one-off award is paid once and repairs are paid as repairs.
    private var haveSealed: Set<TeamID> = []

    /// One enclosure per team, good until the map changes under it.
    private var enclosures: [TeamID: (map: Int, structures: Int, value: BaseEnclosure)] = [:]

    /// Called when a team's wall goes from having a hole in it to not having one.
    ///
    /// The award lives here rather than in BuildSystem because it is about the
    /// WALL rather than about the brick: the last tile is not special, it is simply
    /// the one that happened to be laid last, and the same closing can be reached
    /// by two bots laying different halves. One question, asked in one place, after
    /// any change to the map.
    /// Chests, stood up the moment the wall closes round them.
    ///
    /// This replaces two earlier attempts and is the one the shape of the game
    /// actually asks for. Standing them up at map generation put loot in a base
    /// before there was a wall round it, which anybody could stroll into. Dealing
    /// everyone a chest to CARRY fixed that and left the whole thing hanging on a
    /// bot remembering to run an errand - which it did, eventually, some of the
    /// time. Sealing is the moment that deserves the payoff anyway: it is the exact
    /// instant the base stops being a building site and starts being a place worth
    /// breaking into, and tying the reward to it is what makes finishing a wall
    /// mean something rather than being the point at which nothing more happens.
    ///
    /// How many depends on how big the base is, because the plan is a random
    /// rectangle between five and seven tiles a side and a seven-by-seven yard with
    /// one chest in it looks like somebody moved out. Bots get theirs stocked;
    /// yours arrive empty, because a player's chest is theirs to fill.
    ///
    /// - Returns: how many went up, for the event - so the celebration can be sized
    ///   to what was actually won.
    @discardableResult
    private func furnish(_ team: TeamID) -> Int {
        // Sized on the room that was actually walled in, not on the plan's. A
        // player who built their own smaller shape gets the chests that room is
        // worth, and one who walled in more than the plan asked for gets paid for
        // it - which is the whole point of letting anybody build any shape.
        let room = enclosure(of: team).room
        guard !room.isEmpty else { return 0 }

        let wanted = min(GameConfig.Base.chestsOnSeal(forRoomOf: room.count),
                         GameConfig.Base.maxChests)
        let centre = claims[team]?.centreTile.center ?? .zero
        let ownedByABot = actors.values.contains { $0.team == team && $0.ai != nil }
        var placed = 0

        // Topped UP rather than counted out, because this runs on every reseal now.
        // A base that lost one chest of two to a raid gets one back, not two.
        let standing = chestCount(ownedBy: team)

        for _ in standing..<max(standing, wanted) {
            // Re-asked each time rather than gathered up front: a chest occupies
            // the tile it lands on, so the next call answers with the next nearest
            // free one and they end up clustered round the middle rather than
            // stacked.
            guard let tile = nextChestTile(for: team, near: centre) else { break }

            let id = spawnChest(at: tile, owner: team)
            if ownedByABot { ChestSystem.stock(id, in: self) }
            placed += 1
        }

        // And a machine, if it is a BOT'S base and it has not got one.
        //
        // The asymmetry is deliberate and it is the same shortcut the chests take
        // three lines up: bots do not spend a match hunting for a machine, carrying
        // it home and finding a spot for it, so they are credited with having done
        // it. Without that, machines went only to whoever opened the right crate,
        // which meant most bases never had the thing that makes them worth raiding
        // twice - and a raiding loop that depends on the victim having got lucky is
        // not a loop.
        //
        // You still have to find yours. That is the half worth keeping: crossing
        // the map for a rare crate, carrying the thing home, and choosing where it
        // goes is a real errand with a real payoff, and handing it over for nothing
        // would delete an errand rather than fix one. What the bots' free machine
        // buys is that there is always somewhere worth taking a bomb - which is a
        // fact about THEIR bases, and no reason to do your work for you.
        //
        // It still cannot be hoarded: one to a base, destroyed when somebody shoots
        // it apart, and back only when the wall goes up again.
        // ONE, on seal, and usually the small one.
        //
        // Still only when the base has none, so this is the leg-up it always was
        // and not a supply: a bot that has already found a machine in a crate does
        // not get handed another. What has changed is that a bot can now stand up
        // everything else it finds, exactly as you can, so bases diverge over a
        // match instead of all ending on one identical cabinet. Some finish with a
        // single mini; a lucky few finish with three or four machines and are worth
        // raiding badly, which is the spread the raid pricing was rebuilt to read.
        //
        // Mini about two thirds of the time. The free machine is a floor under a
        // base being worth visiting at all, and the cabinet is the thing that
        // should be worth going out of your way for - handing every bot the good
        // one for nothing would make finding one yourself mean nothing.
        if ownedByABot, !hasArcade(team) {
            var kind: ArcadeKind =
                Double.random(in: 0..<1, using: &rng) < GameConfig.Arcade.botMiniShare
                ? .mini : .full

            // Only machines this match has. The cabinet unlocks after the mini,
            // so a bot that drew it before then gets the mini instead.
            if !unlocks.allows(.arcade(kind)) { kind = .mini }

            if unlocks.allows(.arcade(kind)),
               let origin = nextArcadeOrigin(for: team, kind: kind, near: centre) {
                spawnArcade(at: origin, kind: kind, owner: team)
            }
        }

        // And a turret, on the same terms and for the same reason: a bot is
        // credited with the errand rather than made to run it, and only when its
        // base has none, so this is a floor and not a supply.
        //
        // Not every base. See GameConfig.Turret.botShare - part of what makes
        // raiding interesting is the base that turns out to have nothing guarding
        // it, and a turret in every one of them would make it a fact of the map.
        //
        // Placed AFTER the machine rather than before, so that in a cramped base the
        // thing that earns gets the floor space and the thing that guards it takes
        // what is left.
        if ownedByABot, !hasTurret(team), unlocks.allows(.turret),
           Double.random(in: 0..<1, using: &rng) < GameConfig.Turret.botShare,
           let origin = nextTurretOrigin(for: team, near: centre) {
            spawnTurret(at: origin, owner: team)
        }

        return placed
    }

    func recordSealIfNeeded(for team: TeamID) {
        guard !baseIsBreached(team) else { return }

        if haveSealed.contains(team) {
            // Only after somebody opened it. Without this, laying and removing your
            // own wall would print points.
            guard sealPending.contains(team) else { return }
            sealPending.remove(team)
            award(GameConfig.Base.resealed, to: team)

            // And it refurnishes. A raid destroys the chest it cracks, so shutting
            // the wall again is what puts a new one in - which is the loop this
            // whole half of the game turns on: break in, take what is there, and
            // the owner rebuilds and restocks for the next person.
            //
            // Same event as a first seal, so it gets the same sweep of light round
            // the wall. Somebody who has just patched a hole and got their base
            // back deserves the same moment as somebody who has just finished one.
            record(.sealed(team, chests: furnish(team)))
        } else {
            haveSealed.insert(team)
            award(GameConfig.Base.sealed, to: team)
            record(.sealed(team, chests: furnish(team)))

            // Paid to whoever is standing in it, which for a bot's base is the bot
            // that built it and for yours is you.
            for id in actors.keys.sorted(by: { $0.raw < $1.raw }) {
                guard let actor = actors[id], actor.team == team else { continue }
                awardTokens(GameConfig.Base.sealedTokens, to: id)
                break
            }
        }
    }

    /// Teams that have been breached since they last sealed. See above.
    private var sealPending: Set<TeamID> = []

    /// When each team may start laying walls again after being breached.
    private var repairAllowedAt: [TeamID: Double] = [:]

    /// Called when a wall tile is destroyed, so the repair is worth paying for -
    /// and so the raider gets long enough to actually raid.
    /// When each team's base was last broken into. Match start counts as a raid,
    /// so nobody is a magnet in the first minute.
    private var lastRaid: [TeamID: Double] = [:]

    /// How long this base has been left alone.
    ///
    /// The anti-turtle clock. A base nobody has touched is a base whose owner has
    /// been banking loot and income unopposed, and the longer that goes on the more
    /// it is worth somebody's bomb - see AIBrain.chestWorthRobbing, which adds this
    /// to what a base is worth.
    func secondsSinceRaid(of team: TeamID) -> Double {
        elapsed - (lastRaid[team] ?? 0)
    }

    func recordRaid(of team: TeamID) {
        lastRaid[team] = elapsed
    }

    func recordBreach(of team: TeamID) {
        // A hole in the wall is a raid whether or not anything is taken. Stamped
        // here rather than only where a chest is cracked, because the pressure this
        // feeds is about being LEFT ALONE, and somebody who has just had their wall
        // opened has not been.
        recordRaid(of: team)

        // The buffer applies to anybody who has been bombed, sealed base or not.
        // Being walled in by somebody finishing their base around you is the same
        // experience as being walled in by a repair.
        repairAllowedAt[team] = elapsed + GameConfig.Build.raidGrace

        guard haveSealed.contains(team) else { return }
        sealPending.insert(team)
    }

    /// Whether this team may lay walls right now.
    ///
    /// False for a few seconds after somebody blows a hole in their base. A raid is
    /// a round trip - through the wall, into the chest, back out - and a hole that
    /// closes behind you turns the best part of the game into being trapped in
    /// somebody's cellar until they get bored of shooting you.
    ///
    /// It costs the owner very little: their machine's bank is halved while the
    /// hole is open, so the seconds are not free, and they can still fight for the
    /// place. What they cannot do is answer a raid with masonry.
    func canBuild(_ team: TeamID) -> Bool {
        guard let until = repairAllowedAt[team] else { return true }
        return elapsed >= until
    }

    /// Seconds until this team may lay walls again, or zero if it may now. For
    /// the screen to count down - see canBuild.
    func buildLockRemaining(for team: TeamID) -> Double {
        guard let until = repairAllowedAt[team] else { return 0 }
        return max(0, until - elapsed)
    }

    /// Whether this team's wall has a hole in it.
    ///
    /// The same question as "is there anything left to build", which is why an
    /// unfinished base and a bombed one look identical from here. Telling them
    /// apart needs to know the base was once finished, and that is a thing a bot
    /// remembers - see AIState.baseWasComplete.
    /// Whether this team's base is open.
    ///
    /// Asked of the WALLS now rather than of the generated plan - see BaseEnclosure
    /// for why the plan was the wrong authority. The plan is still what the bots
    /// build towards and still what nextBuildTile walks; it is simply no longer
    /// what decides whether anybody succeeded.
    func baseIsBreached(_ team: TeamID) -> Bool {
        !enclosure(of: team).isSealed
    }

    /// The flood fill, cached against the map.
    ///
    /// Asked several times a frame per team - by the arcade for its rate, its bank
    /// and its token lifetime, by every chest deciding whether to restock, by the
    /// bots, by the build markers - so it is worked out once per change to the map
    /// and handed out until something is built or blown up. mapRevision is a
    /// complete key for it: the only inputs are tiles and trees, and trees do not
    /// move.
    func enclosure(of team: TeamID) -> BaseEnclosure {
        if let held = enclosures[team],
           held.map == mapRevision, held.structures == structureRevision {
            return held.value
        }

        guard let claim = claims[team] else {
            return BaseEnclosure(room: [], wall: [], ownWalls: [])
        }

        // Hoisted out of the closures below rather than reached through self on
        // every call. Both are dictionary-free lookups once they are here, which is
        // the whole point: this used to walk forty-five tree clumps and seventy
        // structures per tile visited, thousands of times a frame.
        let wooded = treeTiles
        let occupied = structureTiles

        let found = BaseEnclosure.compute(
            claim: claim,
            solid: { [self] point in
                guard map.contains(point) else { return true }
                return map.isOccupied(point) || wooded.contains(point)
            },

            // Whatever is standing on the ground. A crate in the last gap is a gap
            // nobody can walk through and nobody can build on, so it has to hold the
            // base shut - see BaseEnclosure, where the two questions are why this
            // takes two closures.
            furniture: { occupied.contains($0) },
            ownWall: { [self] point in map[point].blockOwner == team }
        )

        enclosures[team] = (mapRevision, structureRevision, found)
        return found
    }

    /// Counts down to the next payment for standing bases - see VaultSystem.
    ///
    /// One clock for every team rather than one each, so eight bases pay on the
    /// same beat. Staggered timers would spread the leaderboard's movement out into
    /// a permanent shimmer; together, it reads as a tick.
    var holdTimer: Double = GameConfig.Score.holdInterval

    /// Everything this team has banked, counted across all of its chests.
    func storedItemCount(ownedBy team: TeamID) -> Int {
        chests.values
            .filter { $0.owner == team }
            .reduce(0) { total, chest in
                total + chest.contents.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
            }
    }

    /// How many chests this team has standing.
    func chestCount(ownedBy team: TeamID) -> Int {
        chests.values.filter { $0.owner == team }.count
    }

    /// Whether somebody from another team is alive and this close.
    ///
    /// A blunt distance test rather than the bots' line-of-sight one, and on
    /// purpose: this answers "is now a bad moment", which wants to be true a little
    /// too often rather than a little too rarely. Something that is deciding
    /// whether to interrupt the player should err towards not.
    /// Whoever is standing in this team's claim who should not be, nearest first.
    ///
    /// The claim rather than the walls, so it answers while somebody is still
    /// picking their way in through the hole - which is the only part of a raid an
    /// owner has any chance of arriving for.
    ///
    /// Sorted, because this decides who gets shot at.
    func intruder(in team: TeamID) -> ActorID? {
        guard let claim = claims[team] else { return nil }

        var nearest: ActorID?
        var shortest = Double.greatestFiniteMagnitude
        let home = claim.centreTile.center

        for id in actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = actors[id], actor.isAlive, actor.team != team,
                  actor.invulnerability <= 0,
                  claim.contains(GridPoint(containing: actor.feet)) else { continue }

            let distance = (actor.position - home).length
            guard distance < shortest else { continue }
            shortest = distance
            nearest = id
        }

        return nearest
    }

    func enemyNear(_ actor: Actor, within reach: Double) -> Bool {
        actors.values.contains {
            $0.isAlive && $0.team != actor.team
                && ($0.position - actor.position).length <= reach
        }
    }

    /// Enemy chests, for anyone deciding what is worth raiding.
    func chests(notOwnedBy team: TeamID) -> [Chest] {
        chests.values.filter { $0.owner != team }
            .sorted { $0.id.raw < $1.id.raw }
    }

    func arcade(_ id: ArcadeID) -> Arcade? {
        arcades[id]
    }

    /// How many of this machine's tokens are still lying around it.
    func uncollectedTokens(around arcade: Arcade) -> Int {
        let reach = arcade.hitbox.expanded(by: GameConfig.Arcade.collectionRadius)

        var count = 0
        for item in groundItems.values {
            guard case .token = item.pickup else { continue }
            if reach.contains(item.position) { count += 1 }
        }
        return count
    }

    /// Every loose token lying inside this team's base.
    ///
    /// The per-machine count above stopped being the right question when a base
    /// could hold more than one machine. Each machine had its own allowance,
    /// measured in its own small radius, so four of them meant four separate piles
    /// and the better part of twenty tokens on the floor - which is not a bank, it
    /// is litter, and it made the cap that is supposed to say "come home and clear
    /// this" say nothing at all.
    ///
    /// Counted over the whole base ground rather than round each machine, so the
    /// machines share one allowance however many of them there are and however
    /// close together they stand.
    func looseTokens(inside team: TeamID) -> Int {
        let ground = baseGround(of: team)

        var count = 0
        for item in groundItems.values {
            guard case .token = item.pickup else { continue }
            if ground.contains(GridPoint(containing: item.position)) { count += 1 }
        }
        return count
    }

    /// Whether a token is already lying on this tile.
    func hasToken(on tile: GridPoint) -> Bool {
        groundItems.values.contains { item in
            guard case .token = item.pickup else { return false }
            return GridPoint(containing: item.position) == tile
        }
    }

    /// Somewhere around the machine a token could actually be picked up from, or
    /// nil if it is boxed in.
    func freeSpot(around arcade: Arcade) -> Vec2? {
        // Built in the ring's fixed order and then chosen from with the world's own
        // generator, so the same seed drops tokens in the same places.
        //
        // Empty tiles FIRST, and that is the whole of "do not stack". isClearForDrop
        // asks about the map - walls, trees, furniture - and has never had an
        // opinion about what is already lying there, so two payouts landing on the
        // same tile landed on the same POINT and the second was drawn exactly on top
        // of the first. Three tokens looked like one, which is the worst way for a
        // machine to pay you: it looks like it has stopped.
        var empty: [Vec2] = []
        var shared: [GridPoint] = []

        for tile in arcade.surroundingTiles where isClearForDrop(tile.center) {
            if hasToken(on: tile) { shared.append(tile) } else { empty.append(tile.center) }
        }

        if let spot = empty.randomElement(using: &rng) { return spot }

        // Every clear tile round the machine already has something on it. Doubling
        // up is allowed rather than refused - a machine that stops because the ring
        // is busy is a machine that stops for a reason nobody can see - but the
        // second one is nudged off centre so it reads as two things rather than as
        // one that failed to appear.
        guard let tile = shared.randomElement(using: &rng) else { return nil }

        let nudge = GameConfig.Arcade.tokenNudge
        return Vec2(x: tile.center.x + Double.random(in: -nudge...nudge, using: &rng),
                    y: tile.center.y + Double.random(in: -nudge...nudge, using: &rng))
    }

    /// - Parameter lifetime: how long it lies there, defaulting to the item's own
    ///   answer. Overridden for tokens paid out inside a base that is shut - see
    ///   ArcadeSystem, where the point is that they can safely pile up.
    /// - Parameter origin: where it was flung from, for the screen to animate -
    ///   see GroundItem.launchedFrom. Changes nothing about where it lies.
    func spawnGroundItem(_ pickup: Pickup,
                         at position: Vec2,
                         lifetime: Double? = nil,
                         from origin: Vec2? = nil) {
        // The last line of defence for Unlocks: every drop on the map comes
        // through here, so nothing locked can reach the grass even if a table
        // somewhere forgets to ask. Cosmic steps down to Mythical; anything with
        // no stand-in simply does not appear.
        guard let pickup = unlocks.clamp(pickup) else { return }

        let id = GroundItemID(nextGroundItemID)
        nextGroundItemID += 1
        groundItems[id] = GroundItem(id: id,
                                     pickup: pickup,
                                     position: position,
                                     timeRemaining: lifetime ?? pickup.groundLifetime,
                                     launchedFrom: origin)
    }

    /// Flings a drop clear of a point.
    ///
    /// Lives here rather than in a system because two of them want it - a kill
    /// scattering gear, and a rare crate paying out twice - and because it draws
    /// from the world's generator, which means the alternative was two copies both
    /// consuming randomness and neither knowing about the other.
    ///
    /// Without it, two things dropped at once land on precisely the same point and
    /// only the top one is visible; the second looks like it was never dropped.
    func scatteredSpot(near position: Vec2) -> Vec2 {
        // Bounds hoisted out rather than written inline: a range operator wrapped
        // onto a new line parses as the PREFIX form (...x) instead of the infix
        // one, and the error it produces points nowhere near the cause.
        let nearest = GameConfig.Drops.scatterRadius * 0.4
        let furthest = GameConfig.Drops.scatterRadius

        for _ in 0..<GameConfig.Drops.scatterAttempts {
            let angle = Double.random(in: 0..<(2 * Double.pi), using: &rng)
            let distance = Double.random(in: nearest...furthest, using: &rng)

            let spot = position + Vec2.fromAngle(angle) * distance
            if isClearForDrop(spot) { return spot }
        }

        // Hemmed in on every side: better stacked than stuck in a wall.
        return position
    }

    func removeGroundItem(_ id: GroundItemID) {
        groundItems[id] = nil
    }

    func ageGroundItems(by dt: Double) {
        guard !groundItems.isEmpty else { return }

        // Rebuilt rather than edited in place: mutating a dictionary while walking
        // it copies the whole storage on every single write.
        var surviving: [GroundItemID: GroundItem] = [:]
        surviving.reserveCapacity(groundItems.count)

        for (id, item) in groundItems {
            var ageing = item
            ageing.timeRemaining -= dt
            if ageing.timeRemaining > 0 { surviving[id] = ageing }
        }

        groundItems = surviving
    }

    func spawnProjectile(owner: ActorID, team: TeamID, position: Vec2, velocity: Vec2,
                         damage: Int, fromTurret: Bool = false) {
        let projectile = Projectile(id: ProjectileID(nextProjectileID),
                                    owner: owner,
                                    team: team,
                                    position: position,
                                    velocity: velocity,
                                    damage: damage,
                                    distanceRemaining: GameConfig.Blaster.range,
                                    fromTurret: fromTurret)
        nextProjectileID += 1
        projectiles.append(projectile)
    }

    // MARK: - Gas

    /// Not private(set), unlike the ground items just above, and the difference is
    /// which half of the work happens outside this file. Ground items are only ever
    /// added and removed, so the helpers can own the storage - but a cloud is TICKED
    /// by GasSystem, which thins it and hands out doses and writes it back, the same
    /// way ArcadeSystem writes back a machine's payout clock.
    var gasClouds: [GasCloudID: GasCloud] = [:]
    private var nextGasID = 0

    @discardableResult
    func spawnGas(at centre: Vec2, owner: ActorID, team: TeamID) -> GasCloudID {
        let cloud = GasCloud(id: GasCloudID(nextGasID),
                             centre: centre,
                             owner: owner,
                             team: team,
                             timeRemaining: GameConfig.Stink.duration)
        nextGasID += 1
        gasClouds[cloud.id] = cloud
        return cloud.id
    }

    func removeGas(_ id: GasCloudID) {
        gasClouds[id] = nil
    }

    /// Whether this point is inside gas thick enough to hurt.
    ///
    /// Asked by the bots when they are deciding where to walk, so a bot routes
    /// round a cloud for exactly as long as the cloud is worth routing round.
    func gasAt(_ point: Vec2) -> Bool {
        gasClouds.values.contains {
            $0.density >= GameConfig.Stink.bitingDensity && $0.contains(point)
        }
    }

    func spawnBomb(_ kind: Bomb.Kind,
                   owner: ActorID,
                   team: TeamID,
                   position: Vec2,
                   velocity: Vec2) {
        let bomb = Bomb(id: BombID(nextBombID),
                        kind: kind,
                        owner: owner,
                        team: team,
                        position: position,
                        velocity: velocity,
                        distanceRemaining: GameConfig.Bomb.throwRange)
        nextBombID += 1
        bombs.append(bomb)
    }

    func record(_ event: WorldEvent) {
        recentEvents.append(event)
    }

    /// Hands the events over and forgets them.
    ///
    /// Drained once a frame by the scene, not once a TICK: the fixed step can run
    /// several times between two frames, and every explosion in there still
    /// deserves to be seen. Drained whether or not anything is listening for a
    /// particular kind, too, or a sale made behind a closed shop would pile up and
    /// arrive all at once the next time it opened.
    func takeEvents() -> [WorldEvent] {
        let events = recentEvents
        recentEvents.removeAll()
        return events
    }

    func setTile(_ tile: TileType, at point: GridPoint) {
        guard map.contains(point), map[point] != tile else { return }
        map[point] = tile
        mapRevision += 1

        // Whatever stands here now has taken no shots - see WallSystem.
        wallDamage[point] = nil
    }

    /// Damage players have shot into their own walls, by tile - see WallSystem.
    var wallDamage: [GridPoint: WallDamage] = [:]

    /// Advances the whole game by exactly one fixed step.
    func step(commands: [ActorID: [Command]], dt: Double) {
        // Whatever is driving actors from outside comes in; the brains fill in the
        // rest. From here down, nothing can tell which is which.
        var everyone = commands
        AISystem.contribute(to: &everyone, in: self, dt: dt)
        AssistSystem.contribute(to: &everyone, in: self, dt: dt)

        applyMovementInput(everyone)
        BuildSystem.update(self, commands: everyone)
        ChestSystem.update(self, commands: everyone, dt: dt)
        // Before movement, so a wall that comes down this tick is a gap somebody
        // can already walk through.
        BombSystem.update(self, commands: everyone, dt: dt)
        WeaponSystem.update(self, commands: everyone, dt: dt)
        ConsumableSystem.update(self, commands: everyone)
        EquipSystem.update(self, commands: everyone)
        ShopSystem.update(self, commands: everyone)
        MovementSystem.update(self, dt: dt)
        ProjectileSystem.update(self, dt: dt)
        WallSystem.update(self, dt: dt)
        // After movement, so picking things up uses where you actually ended up.
        LootSystem.update(self, commands: everyone, dt: dt)
        SupplyDropSystem.update(self, dt: dt)
        // After the sweep: a token paid out this tick should be lying there to be
        // seen, not swallowed instantly by whoever happens to be standing on it.
        ArcadeSystem.update(self, commands: everyone, dt: dt)
        TurretSystem.update(self, commands: everyone, dt: dt)
        // After movement, so a dose lands on where somebody actually ended up
        // rather than on where they started the tick.
        GasSystem.update(self, dt: dt)
        CombatSystem.update(self, dt: dt)
        PerkSystem.update(self, dt: dt)
        RespawnSystem.update(self, dt: dt)
        VaultSystem.update(self, dt: dt)
        tick += 1
        elapsed += dt
    }

    private func applyMovementInput(_ commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard var actor = actors[id] else { continue }
            for command in list {
                switch command {
                case .move(let direction):
                    let input = direction.clampedToUnit()
                    actor.moveInput = input

                    // Walking points the weapon. Firing overrides it later in the
                    // same tick, in WeaponSystem - which is the whole mechanism:
                    // movement sets the aim, and a trigger pull wins because it
                    // happens afterwards. Nothing has to know about the other.
                    if input.length > 0.01 {
                        actor.aim = input.normalized()
                    }

                    // Left/right is tracked separately so walking straight up or
                    // down does not turn the figure to face the camera - it keeps
                    // whichever side it was last heading.
                    if abs(input.x) > 0.01 {
                        actor.facesLeft = input.x < 0
                    }
                case .placeBlock, .removeBlock, .shoot, .openLootbox, .useItem,
                     .placeChest, .placeArcade, .placeTurret, .storeItem, .takeItem,
                     .dropItem, .buyItem, .sellItem:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
