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

    let claims: [TeamID: BaseClaim]

    /// Round obstacles. Not tiles - see TreePatch for why.
    let trees: [TreePatch]

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
        return chest.id
    }

    func removeChest(_ id: ChestID) {
        chests[id] = nil
    }

    @discardableResult
    func spawnArcade(at origin: GridPoint, owner: TeamID?) -> ArcadeID {
        let machine = Arcade(id: ArcadeID(nextArcadeID), origin: origin,
                             owner: owner, emitTimer: GameConfig.Arcade.emitInterval)
        nextArcadeID += 1
        arcades[machine.id] = machine
        return machine.id
    }

    func removeArcade(_ id: ArcadeID) {
        arcades[id] = nil
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

    /// Where a machine could stand inside this team's walls, nearest to here.
    ///
    /// Six tiles rather than one, checked as a block - a footprint half inside a
    /// wall is not a placement. Walks the region in a fixed order so the same seed
    /// puts machines in the same places.
    func nextArcadeOrigin(for team: TeamID, near position: Vec2) -> GridPoint? {
        guard let layout = baseLayouts[team] else { return nil }

        var best: GridPoint?
        var shortest = Double.greatestFiniteMagnitude

        for origin in layout.region.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            let machine = Arcade(id: ArcadeID(-1), origin: origin, owner: team, emitTimer: 0)

            var fits = true
            for tile in machine.tiles {
                guard layout.region.contains(tile),
                      tile != claims[team]?.centreTile,
                      map[tile] == .floor,
                      !structureIntersects(Box(tile: tile)),
                      !trees.contains(where: { $0.overlaps(tile) }) else { fits = false; break }
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
        guard let layout = baseLayouts[team] else { return nil }

        var best: GridPoint?
        var shortest = Double.greatestFiniteMagnitude

        // Sorted, because Set iteration order is not stable and two runs of the
        // same seed have to put the chest in the same place.
        for tile in layout.region.sorted(by: { ($0.row, $0.col) < ($1.row, $1.col) }) {
            guard tile != claims[team]?.centreTile else { continue }
            guard map[tile] == .floor else { continue }
            guard !structureIntersects(Box(tile: tile)) else { continue }
            guard !trees.contains(where: { $0.overlaps(tile) }) else { continue }

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

    /// Called when a team's wall goes from having a hole in it to not having one.
    ///
    /// The award lives here rather than in BuildSystem because it is about the
    /// WALL rather than about the brick: the last tile is not special, it is simply
    /// the one that happened to be laid last, and the same closing can be reached
    /// by two bots laying different halves. One question, asked in one place, after
    /// any change to the map.
    func recordSealIfNeeded(for team: TeamID) {
        guard !baseIsBreached(team) else { return }

        if haveSealed.contains(team) {
            // Only after somebody opened it. Without this, laying and removing your
            // own wall would print points.
            guard sealPending.contains(team) else { return }
            sealPending.remove(team)
            award(GameConfig.Base.resealed, to: team)
        } else {
            haveSealed.insert(team)
            award(GameConfig.Base.sealed, to: team)

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
    func recordBreach(of team: TeamID) {
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
    func baseIsBreached(_ team: TeamID) -> Bool {
        nextBuildTile(for: team) != nil
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

    func spawnBomb(owner: ActorID, team: TeamID, position: Vec2, velocity: Vec2) {
        let bomb = Bomb(id: BombID(nextBombID),
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
        CombatSystem.update(self, dt: dt)
        RespawnSystem.update(self, dt: dt)
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
                     .dropItem, .buyItem:
                    break   // other systems' business, not movement's
                }
            }
            actors[id] = actor
        }
    }
}
