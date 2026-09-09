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

    /// Seconds left on the clock, floored at zero.
    var timeRemaining: Double { max(0, GameConfig.Match.duration - elapsed) }

    /// How far the match has run, nought to one.
    ///
    /// The one place the phrase "late in the match" is defined. Chest loot and the
    /// respawn kit both read it, so "late" means the same thing to both and a
    /// change to the match length moves them together rather than leaving tuned
    /// constants behind in two files.
    var matchProgress: Double {
        min(1, max(0, elapsed / GameConfig.Match.duration))
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

    private(set) var lootboxes: [LootboxID: Lootbox] = [:]
    var chests: [ChestID: Chest] = [:]
    private(set) var groundItems: [GroundItemID: GroundItem] = [:]

    /// An opened crate, waiting to come back in the same spot.
    private struct PendingLootbox {
        let tile: GridPoint
        /// A rare crate comes back rare. The spot is what was rare, not the box -
        /// otherwise the good crates would quietly disappear over a match as each
        /// one was opened and replaced with an ordinary one.
        let rare: Bool
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

    func score(for team: TeamID) -> Int { scores[team] ?? 0 }

    /// The leading score, or zero before anyone has any. What a bot measures a
    /// target's standing against when deciding who is worth going after.
    var bestScore: Int { scores.values.max() ?? 0 }

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
    }

    var localPlayer: Actor? { actors[localPlayerID] }

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

        // Crates come back. Without that, seven bots strip the map bare within a
        // minute and there is nothing left to play around.
        pendingLootboxes.append(PendingLootbox(tile: crate.tile,
                                               rare: crate.rare,
                                               timer: GameConfig.Loot.respawnDelay))
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
            let crate = Lootbox(id: LootboxID(nextLootboxID),
                                tile: pending.tile,
                                rare: pending.rare)
            if actors.values.contains(where: { $0.isAlive && $0.hitbox.intersects(crate.hitbox) }) {
                pending.timer = 1
                stillWaiting.append(pending)
                continue
            }

            nextLootboxID += 1
            lootboxes[crate.id] = crate
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

        structureTileCache = (structureRevision, tiles)
        return tiles
    }

    /// The same question asked of an area rather than a point, for the things that
    /// reason about whole tiles - building, and putting a chest down.
    func structureIntersects(_ box: Box) -> Bool {
        if lootboxes.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        if arcades.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
        if chests.values.contains(where: { $0.hitbox.intersects(box) }) { return true }
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
    func spawnArcade(at origin: GridPoint, owner: TeamID?) -> ArcadeID {
        let machine = Arcade(id: ArcadeID(nextArcadeID), origin: origin,
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

    /// What there is worth taking in this team's base.
    ///
    /// The one place a base is priced, so the bot deciding WHETHER to cross the map
    /// and the bot deciding WHICH wall to open cannot come to different conclusions
    /// about which base is the rich one. It counts the things a raider actually
    /// leaves with: items sitting in chests, and a machine, which pays out on being
    /// destroyed whether or not anything else in the base survives.
    func lootValue(of team: TeamID) -> Int {
        var value = 0

        for chest in chests.values where chest.owner == team {
            let items = chest.contents.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }
            value += items * GameConfig.AI.chestItemWorth
        }

        if hasArcade(team) { value += GameConfig.AI.machineWorth }
        return value
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
            guard let chest = chests[id], chest.owner == team,
                  chest.contents.slots.contains(where: { $0 != nil }) else { continue }
            spots.append(chest.position)
        }

        for id in arcades.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let machine = arcades[id], machine.owner == team else { continue }
            spots.append(machine.centre)
        }

        return spots
    }

    func hasArcade(_ team: TeamID) -> Bool {
        arcades.values.contains { $0.owner == team }
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
                          near position: Vec2,
                          avoidingActors: Bool = true) -> GridPoint? {
        let ground = baseGround(of: team)

        var best: GridPoint?
        var shortest = Double.greatestFiniteMagnitude

        for origin in ground.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            let machine = Arcade(id: ArcadeID(-1), origin: origin, owner: team, emitTimer: 0)

            // Six tiles of solid machine, so the same rule as a chest: not on top
            // of anybody, the placer included.
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

            let distance = (machine.centre - position).length
            guard distance < shortest else { continue }
            shortest = distance
            best = origin
        }

        return best
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

        var best: GridPoint?
        var shortest = Double.greatestFiniteMagnitude

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

            let distance = (tile.center - position).length
            guard distance < shortest else { continue }
            shortest = distance
            best = tile
        }

        return best
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

        let wanted = GameConfig.Base.chestsOnSeal(forRoomOf: room.count)
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
        if ownedByABot, !hasArcade(team),
           let origin = nextArcadeOrigin(for: team, near: centre) {
            _ = spawnArcade(at: origin, owner: team)
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

    /// Somewhere around the machine a token could actually be picked up from, or
    /// nil if it is boxed in.
    func freeSpot(around arcade: Arcade) -> Vec2? {
        // Built in the ring's fixed order and then chosen from with the world's own
        // generator, so the same seed drops tokens in the same places.
        var options: [Vec2] = []
        for tile in arcade.surroundingTiles where isClearForDrop(tile.center) {
            options.append(tile.center)
        }
        return options.randomElement(using: &rng)
    }

    /// - Parameter lifetime: how long it lies there, defaulting to the item's own
    ///   answer. Overridden for tokens paid out inside a base that is shut - see
    ///   ArcadeSystem, where the point is that they can safely pile up.
    func spawnGroundItem(_ pickup: Pickup, at position: Vec2, lifetime: Double? = nil) {
        let id = GroundItemID(nextGroundItemID)
        nextGroundItemID += 1
        groundItems[id] = GroundItem(id: id,
                                     pickup: pickup,
                                     position: position,
                                     timeRemaining: lifetime ?? pickup.groundLifetime)
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

    func spawnProjectile(owner: ActorID, team: TeamID, position: Vec2, velocity: Vec2, damage: Int) {
        let projectile = Projectile(id: ProjectileID(nextProjectileID),
                                    owner: owner,
                                    team: team,
                                    position: position,
                                    velocity: velocity,
                                    damage: damage,
                                    distanceRemaining: GameConfig.Blaster.range)
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
    }

    /// Advances the whole game by exactly one fixed step.
    func step(commands: [ActorID: [Command]], dt: Double) {
        // Whatever is driving actors from outside comes in; the brains fill in the
        // rest. From here down, nothing can tell which is which.
        var everyone = commands
        AISystem.contribute(to: &everyone, in: self, dt: dt)

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
        // After movement, so picking things up uses where you actually ended up.
        LootSystem.update(self, commands: everyone, dt: dt)
        // After the sweep: a token paid out this tick should be lying there to be
        // seen, not swallowed instantly by whoever happens to be standing on it.
        ArcadeSystem.update(self, commands: everyone, dt: dt)
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
                     .placeChest, .placeArcade, .storeItem, .takeItem,
                     .raidChest, .dropItem, .buyItem, .sellItem:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
