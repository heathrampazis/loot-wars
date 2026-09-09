//
//  ChestSystem.swift
//  Loot Wars
//
//  Putting chests down, and moving things in and out of them.
//
//  Every transfer below checks there is somewhere for the item to GO before taking
//  it from where it is. That ordering is the whole safety property: get it the wrong
//  way round and a tap on a full chest quietly deletes what you were holding, which
//  is the worst bug an inventory can have and the hardest to notice.
//

enum ChestSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        restock(world, dt: dt)
        advanceCracks(world, dt: dt)

        for (id, list) in commands {
            for command in list {
                // Re-read the actor per command rather than once per list: two taps
                // can land in the same tick, and the second must see what the first
                // did to the inventory.
                guard let actor = world.actors[id], actor.isAlive else { break }

                switch command {
                case .placeChest(let point):
                    place(at: point, by: actor, in: world)
                case .storeItem(let chest, let slot):
                    store(from: slot, by: id, into: chest, in: world)
                case .takeItem(let chest, let slot):
                    take(from: slot, of: chest, by: id, in: world)
                case .raidChest(let chest):
                    beginCrack(chest, by: id, in: world)
                case .move, .placeBlock, .removeBlock, .shoot,
                     .openLootbox, .useItem, .dropItem, .buyItem, .sellItem,
                     .placeArcade:
                    break
                }
            }
        }
    }

    // MARK: - Putting one down

    static func canPlace(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard actor.inventory.firstSlot(holding: .chest) != nil else { return false }

        // No requirement that the wall be shut, and that is a deliberate reversal.
        //
        // It was a hard rule here for one commit, to stop anybody strolling into a
        // half-built base and helping themselves. But the thing that actually stops
        // that is the BOTS not putting furniture out early - which is where the rule
        // now lives, in AIBrain, as a preference rather than a law. Down here it was
        // also telling the player what to do with their own base, and refusing to
        // let somebody set a chest down in a base they have chosen not to finish is
        // a rule protecting them from a decision that is theirs to make. Leave it
        // out in the open and somebody will take it; that is the deal, and it is a
        // legible one.

        // The same ground rules a wall answers to: your own claim, nothing already
        // there. A chest is furniture in your base, not something you leave lying
        // in the open for anyone to walk up to.
        guard BuildSystem.isBuildableTile(point, for: actor.team, in: world) else { return false }

        // And placed from inside, like a wall - measured from the feet, so it is
        // standing on your own ground rather than leaning over the fence.
        guard world.claim(for: actor.team)?.contains(GridPoint(containing: actor.feet)) == true else {
            return false
        }

        // A chest is solid, so one appearing under somebody would shove them out of
        // the way - yourself included.
        let box = Box(tile: point)
        return !world.actors.values.contains { $0.isAlive && $0.hitbox.intersects(box) }
    }

    @discardableResult
    static func place(at point: GridPoint, by actor: Actor, in world: World) -> Bool {
        guard canPlace(at: point, by: actor, in: world) else { return false }

        var owner = actor
        guard let slot = owner.inventory.firstSlot(holding: .chest),
              owner.inventory.consume(at: slot) != nil else { return false }

        world.actors[actor.id] = owner
        let chest = world.spawnChest(at: point, owner: actor.team)

        // A bot's chest arrives with something in it. See GameConfig.Chest.stockCount
        // for why this is a credit rather than a simulation - and note it is bots
        // only, because a player's chest is theirs to fill.
        if actor.ai != nil { stock(chest, in: world) }

        world.award(GameConfig.Score.chestPlaced, to: actor.team)
        return true
    }

    /// Puts an item back into raided bot chests, a little at a time.
    ///
    /// Iterated in id order rather than dictionary order: this draws from the
    /// world's generator, and a dictionary's iteration order is not stable between
    /// runs, so doing it the obvious way would quietly break seeded replays.
    private static func restock(_ world: World, dt: Double) {
        for id in world.chests.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var chest = world.chests[id], chest.selfStocking else { continue }

            // Nothing comes back while there is a hole in the wall.
            //
            // The owner has to shut the base before it starts paying again, which
            // is what stops a raider standing in a broken base collecting an item
            // every half minute forever. Repair is the thing that turns the supply
            // back on, rather than a chore with no reward attached.
            //
            // PAUSED, not reset, and that one word was the whole "enemy bases never
            // have anything in them" problem. This used to shove the timer back up
            // to the full restockInterval on every frame the wall was open - so
            // restockAfterRaid, the short wait a robbed chest is supposed to get,
            // was overwritten before it could ever tick. It was unreachable by
            // construction: you cannot empty a chest without breaching the base
            // that holds it, so the short clock never once ran in a real match. The
            // actual turnaround was the grace period, plus the walk home, plus the
            // repair, plus a full 28 seconds - and then another 28 for the second
            // item, and another for the third.
            guard !world.baseIsBreached(chest.owner) else { continue }

            chest.restockTimer -= dt

            if chest.restockTimer <= 0 {
                chest.restockTimer = GameConfig.Chest.restockInterval

                // Room for more: put something back. Full: bring what is already in
                // there up to date instead.
                //
                // A full chest used to simply park its timer, which meant a base
                // nobody raided sat on its opening-minute Commons for the whole
                // match - the chests that were hardest to reach were the ones
                // holding the most out-of-date loot. Now the same clock that
                // refills a raided chest ages an unraided one forwards.
                let held = chest.contents.slots.compactMap { $0 }.reduce(0) { $0 + $1.count }

                if held < GameConfig.Chest.restockCeiling {
                    add(oneItemTo: &chest, in: world)

                    // A chest stripped to the boards puts back TWO on its first
                    // tick rather than one. One item in a chest is not a reason to
                    // cross a map and blow a hole in something, so a base coming
                    // back from a raid one item at a time spent most of its
                    // recovery not being worth raiding - which is the same as still
                    // being empty, just with a longer wait attached.
                    if held == 0 { add(oneItemTo: &chest, in: world) }
                } else {
                    refresh(&chest, in: world)
                }
            }

            world.chests[id] = chest
        }
    }

    /// Fills a chest and puts it on the restock clock.
    ///
    /// Called for a chest a bot has just put down, and for the one every base
    /// starts the match with - see World's setup. Both want the same thing: a base
    /// that is worth breaking into before anybody has done anything.
    ///
    /// Draws from world.rng in a fixed order, so a seed still replays exactly.
    static func stock(_ id: ChestID, in world: World) {
        guard var chest = world.chests[id] else { return }

        chest.selfStocking = true

        let count = Int.random(in: GameConfig.Chest.stockCount, using: &world.rng)
        for _ in 0..<count { add(oneItemTo: &chest, in: world) }

        world.chests[id] = chest
    }

    private static func add(oneItemTo chest: inout Chest, in world: World) {
        let rows = stockRows(in: world)
        let total = rows.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &world.rng)

        for entry in rows {
            if pick < entry.weight {
                _ = chest.contents.add(entry.item)
                return
            }
            pick -= entry.weight
        }
    }

    /// The band the match is in, minus anything it is too early for.
    ///
    /// Same grace period the crates observe: a chest full of bombs in the first two
    /// minutes would be a way round the one thing the grace period is for.
    private static func stockRows(in world: World) -> [(item: ItemType, weight: Int)] {
        let rows = GameConfig.Chest.stockTable(at: world.matchProgress)
        return world.bombsAllowed ? rows : rows.filter { $0.item != .bomb }
    }

    // MARK: - Keeping pace with the match

    /// Swaps the most out-of-date thing in a full chest for something the match
    /// would hand out now.
    ///
    /// Replaces rather than adds - the chest holds exactly what it held, so this
    /// cannot be farmed by leaving a base alone, and a raid on an old base is worth
    /// making rather than worth more.
    ///
    /// One conversion, then upgrades only. A chest with nothing but supplies in it
    /// turns ONE of them into gear and no more, because a rule that kept converting
    /// would end every long match with chests full of helmets and no bandages in
    /// them anywhere.
    private static func refresh(_ chest: inout Chest, in world: World) {
        let rows = stockRows(in: world)
        let gear = rows.filter { $0.item.isGear }
        guard !gear.isEmpty else { return }

        guard let slot = staleSlot(in: chest, against: gear) else { return }

        let total = gear.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &world.rng)

        var replacement: ItemType?
        for entry in gear {
            if pick < entry.weight { replacement = entry.item; break }
            pick -= entry.weight
        }

        guard let item = replacement,
              let removed = chest.contents.consume(at: slot) else { return }

        // Put the old one back if the new one will not fit. Everything else in this
        // file checks there is room BEFORE it takes, and it cannot here - freeing
        // the slot is sometimes what makes the room - so this is the same safety
        // property arrived at from the other end. A chest quietly losing an item to
        // an upgrade that never landed is the bug that ordering exists to prevent.
        if !chest.contents.add(item) { _ = chest.contents.add(removed) }
    }

    /// Somebody else's chest, broken open.
    ///
    /// A raider does not OPEN a chest, and this is the change that finally makes a
    /// raid feel like one. Standing in a base you bombed your way into, tapping
    /// through a storage panel slot by slot to decide what to carry - with the
    /// owner running home - was an inventory-management screen in the middle of the
    /// most exciting thing this game does. Worse, it made the fight optional: you
    /// could stand in the panel indefinitely.
    ///
    /// So it behaves like the crate it always should have been. One action, the
    /// thing bursts, a couple of items land on the grass, and from there it is the
    /// ordinary business of walking over loot while somebody shoots at you. Nothing
    /// is decided in a menu.
    ///
    /// The chest itself is destroyed, which is what makes rebuilding a wall worth
    /// doing: the base is not merely emptied, it is unfurnished, and it refurnishes
    /// when the wall goes back up. See World.recordSealIfNeeded.
    ///
    /// The owner still opens their own normally - storing and retrieving is not
    /// raiding, and it happens in your own base with nobody shooting at you.
    /// Starts breaking a chest open, which used to BE breaking it open.
    ///
    /// A raid was: throw a bomb, walk in, tap, walk out. Under five seconds, and
    /// the tap was instant - so the owner racing home to defend their base arrived
    /// to find the chest already gone, every time, however fast they ran. Defence
    /// existed and could not matter, because there was no moment during which it
    /// could happen.
    ///
    /// Now there is one. It is short - see GameConfig.Chest.crackTime - and the
    /// only things that end it early are being shot and walking away. Not a hold:
    /// you tap once and commit, and the commitment is the cost. Standing still in
    /// somebody's base for two seconds is a completely different proposition from
    /// touching a box on your way past, and it is the same two seconds for the
    /// seven bots who are on their way.
    ///
    /// Idempotent, because a bot issues this every tick it can reach the chest and
    /// restarting the count each time would mean it never finished.
    private static func beginCrack(_ chestID: ChestID, by id: ActorID, in world: World) {
        guard var actor = world.actors[id], actor.isAlive,
              let chest = world.chests[chestID],
              chest.owner != actor.team,
              canReach(chest, from: actor) else { return }

        guard actor.crackingChest != chestID else { return }

        actor.crackingChest = chestID
        actor.crackProgress = 0
        world.actors[id] = actor
    }

    /// Carries every attempt forward one tick, and drops the ones that have lost
    /// their claim to continue.
    private static func advanceCracks(_ world: World, dt: Double) {
        // Sorted, because this finishes chests and finishing a chest scores.
        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var actor = world.actors[id], let target = actor.crackingChest else { continue }

            // Dead, gone, out of reach, or somehow now yours: all the same answer.
            guard actor.isAlive,
                  let chest = world.chests[target],
                  chest.owner != actor.team,
                  canReach(chest, from: actor) else {
                actor.crackingChest = nil
                actor.crackProgress = 0
                world.actors[id] = actor
                continue
            }

            // Shot at, so back to the start. THIS is the whole mechanism: it is
            // what turns an owner running home into something that can actually
            // stop a raid rather than something that arrives to watch one.
            //
            // A reset rather than a pause, and the crack is kept short to pay for
            // it. Somebody who clears the defenders first still gets the chest in
            // under two seconds; somebody standing in a firefight does not get it
            // at all, which is the correct answer to both.
            if actor.secondsSinceHit < GameConfig.Chest.crackInterrupt {
                actor.crackProgress = 0
                world.actors[id] = actor
                continue
            }

            actor.crackProgress += dt

            guard actor.crackProgress >= GameConfig.Chest.crackTime else {
                world.actors[id] = actor
                continue
            }

            actor.crackingChest = nil
            actor.crackProgress = 0
            world.actors[id] = actor

            crack(target, by: id, in: world)
        }
    }

    private static func crack(_ chestID: ChestID, by id: ActorID, in world: World) {
        guard let actor = world.actors[id], actor.isAlive,
              let chest = world.chests[chestID],
              chest.owner != actor.team,
              canReach(chest, from: actor) else { return }

        // What survives being smashed, taken from the front of the chest so the
        // same chest in the same state always spills the same things.
        let held = chest.contents.slots.compactMap { $0 }
        let spill = held.prefix(GameConfig.Chest.raidSpill)

        for stack in spill {
            world.spawnGroundItem(.item(stack.type),
                                  at: world.scatteredSpot(near: chest.position))
        }

        world.removeChest(chestID)

        // Left alone no longer. Stamped here as well as on the breach, because a
        // base standing open can be robbed without anybody putting a fresh hole in
        // it, and the pressure this feeds is about being untouched rather than
        // about being bombed. See World.secondsSinceRaid.
        world.recordRaid(of: chest.owner)

        // Paid like the best crate on the map, because that is what it is: a rare
        // lootbox you had to spend a bomb and cross somebody's base to reach.
        //
        // And paid only if something came out. Breaking an empty chest is still
        // worth doing - it costs the owner the chest - but it is not a haul, and a
        // flat fee for opening a box that turned out to be bare is fifty-five
        // points for walking into a room. That mattered little while an empty chest
        // could not be a target; bases are now judged on more than their contents,
        // so bare ones will genuinely get visited.
        if !spill.isEmpty {
            world.award(GameConfig.Score.chestRaided, to: actor.team)
            world.awardTokens(GameConfig.Tokens.perChestRaided, to: id)
        }

        world.record(.chestCracked(at: chest.position, items: spill.count))
    }

    /// The slot worth replacing, or nil if the chest is already current.
    ///
    /// Gear the band has left behind goes first, and the two ladders are judged
    /// SEPARATELY - a helmet is compared against the helmets on offer and a blaster
    /// against the blasters. Ranking them on one scale would be arithmetic on two
    /// different things, and would eventually decide a Common helmet outranks a
    /// Blaster 4.
    ///
    /// Failing that, and only in a chest holding no gear at all, a supply slot is
    /// converted, so that a base sitting on two bandages still becomes worth
    /// breaking into.
    private static func staleSlot(in chest: Chest,
                                  against gear: [(item: ItemType, weight: Int)]) -> Int? {
        let helmetFloor = gear.compactMap { helmet(in: $0.item) }.min()
        let blasterFloor = gear.compactMap { blaster(in: $0.item) }.min()

        var worst: (slot: Int, gap: Int)?
        var holdsGear = false

        for (index, stack) in chest.contents.slots.enumerated() {
            guard let stack, stack.type.isGear else { continue }
            holdsGear = true

            var gap = 0

            if let worn = helmet(in: stack.type), let floor = helmetFloor, worn < floor {
                gap = rungs(from: worn, to: floor, in: HelmetTier.allCases)
            } else if let held = blaster(in: stack.type), let floor = blasterFloor, held < floor {
                gap = rungs(from: held, to: floor, in: BlasterTier.allCases)
            }

            guard gap > 0 else { continue }

            // Furthest behind first; ties fall to the lower slot, so the same chest
            // in the same state always makes the same swap.
            if worst == nil || gap > worst!.gap { worst = (index, gap) }
        }

        if let worst { return worst.slot }
        guard !holdsGear else { return nil }

        // Nothing but supplies. The last occupied slot, so the conversion is
        // deterministic rather than a second draw on the generator.
        return chest.contents.slots.lastIndex(where: { $0 != nil })
    }

    private static func helmet(in type: ItemType) -> HelmetTier? {
        if case .helmet(let tier) = type { return tier }
        return nil
    }

    private static func blaster(in type: ItemType) -> BlasterTier? {
        if case .blaster(let tier) = type { return tier }
        return nil
    }

    /// How many rungs apart two tiers are on their own ladder.
    private static func rungs<T: Comparable>(from lower: T, to upper: T, in ladder: [T]) -> Int {
        ladder.filter { $0 > lower && $0 <= upper }.count
    }

    // MARK: - Moving things in and out

    /// Whether this actor is close enough to be rummaging in this chest.
    ///
    /// Checked on every transfer, not only when the panel opens. The world keeps
    /// running while a chest is open - you can be shot, and an explosion can shove
    /// you out of reach - so an open panel is a picture of a chest, never a claim
    /// on it.
    static func canReach(_ chest: Chest, from actor: Actor) -> Bool {
        actor.hitbox.expanded(by: GameConfig.Chest.openReach).intersects(chest.hitbox)
    }

    /// Putting something IN is still yours alone - stocking somebody else's base
    /// is not a thing anyone wants to do.
    private static func store(from slot: Int, by id: ActorID,
                              into chestID: ChestID, in world: World) {
        guard var actor = world.actors[id],
              var chest = world.chests[chestID],
              chest.owner == actor.team,
              canReach(chest, from: actor),
              let stack = actor.inventory.stack(at: slot) else { return }

        // Room first, then move. Never the other way round.
        guard chest.contents.canAccept(stack.type),
              actor.inventory.consume(at: slot) != nil else { return }
        _ = chest.contents.add(stack.type)

        world.actors[id] = actor
        world.chests[chestID] = chest
    }

    /// Taking something OUT needs only that you are standing at it.
    ///
    /// Not owner-only, and that asymmetry is the whole of chest raiding. A chest
    /// that only its owner could open would be a safe, and a safe behind a wall is
    /// worth nothing to anyone who breaks the wall - which would leave bombs with
    /// nothing to be for.
    private static func take(from slot: Int, of chestID: ChestID,
                             by id: ActorID, in world: World) {
        // Your own only. Somebody else's is not opened, it is broken - see crack -
        // so this whole path is now the owner's own housekeeping, which is why
        // nothing here scores: taking your things back out of your own chest is
        // not an achievement.
        guard var actor = world.actors[id],
              var chest = world.chests[chestID],
              chest.owner == actor.team,
              canReach(chest, from: actor),
              let stack = chest.contents.stack(at: slot) else { return }

        // Same question the ground asks, so a helmet that would be worn where it
        // fell is worn when it comes out of a chest too - and a bag with no room
        // is no obstacle to an upgrade, because an upgrade does not need a slot.
        guard actor.canAcquire(stack.type),
              chest.contents.consume(at: slot) != nil else { return }
        _ = actor.acquire(stack.type)

        world.actors[id] = actor

        // Emptying your own chest puts it on the short restock clock.
        //
        // This whole path is the owner's now - a raider breaks a chest rather than
        // opening it, and the broken one is gone until the wall goes back up. So
        // what this handles is a bot pulling its spare helmet out after respawning,
        // and the right answer is that the chest starts refilling straight away
        // rather than waiting out a full interval for a hole its owner made.
        //
        // The clock RESTARTS rather than carrying on, so taking two things in a row
        // does not bank the wait.
        chest.restockTimer = GameConfig.Chest.restockAfterRaid
        world.chests[chestID] = chest
    }
}
