//
//  LootSystem.swift
//  Loot Wars
//
//  Opening lootboxes and picking things up.
//
//  Both halves are deliberately here rather than split between input and rendering:
//  the rule about how close you have to stand exists once, and an AI walking over a
//  bandage picks it up through exactly the same code a player does.
//

enum LootSystem {

    static func update(_ world: World, commands: [ActorID: [Command]], dt: Double) {
        openBoxes(world, commands: commands)
        sweepUpItems(world)

        // After the sweep, so something thrown down this tick is not picked back up
        // by the same tick that threw it.
        dropItems(world, commands: commands)

        // After the sweep, so something you reached on its very last tick still
        // counts as picked up rather than as having vanished under your feet.
        world.ageGroundItems(by: dt)
        world.tickLootboxRespawns(dt: dt)
    }

    // MARK: - Opening

    private static func openBoxes(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            guard let actor = world.actors[id], actor.isAlive else { continue }

            for command in list {
                guard case .openLootbox = command else { continue }

                guard let box = world.reachableLootbox(for: actor) else { break }

                world.removeLootbox(box.id)

                // A supply drop pays its own way: one piece of the best gear in
                // the game, and a fanfare - see SupplyDropSystem.
                if box.supply {
                    world.award(GameConfig.SupplyDrop.score, to: actor.team)
                    world.awardTokens(GameConfig.SupplyDrop.tokens, to: id)
                    world.spawnGroundItem(SupplyDropSystem.roll(using: &world.rng),
                                          at: box.position)
                    world.record(.supplyDropOpened(at: box.position))
                    break
                }

                let rare = box.rare
                world.award(rare ? GameConfig.Score.rareLootboxOpened
                                 : GameConfig.Score.lootboxOpened, to: actor.team)
                world.awardTokens(rare ? GameConfig.Tokens.perRareLootbox
                                       : GameConfig.Tokens.perLootbox, to: id)

                // ONE item, rare or not. A rare crate is a better roll, not a
                // bigger pile: two things out of it made it briefly better than
                // raiding somebody, and raiding has to stay the best thing you can
                // do with a minute. It is also the difference between a crate you
                // cross the map for and a crate you camp.
                world.spawnGroundItem(LootTable.roll(bombs: world.bombsAllowed,
                                                     at: world.matchProgress,
                                                     rare: rare,
                                                     using: &world.rng),
                                      at: box.position)
                break   // one box per tick, however many times it was asked
            }
        }
    }

    // MARK: - Putting something down

    private static func dropItems(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .dropItem(let slot) = command else { continue }

                // Re-read per command: two drops can land in one tick, and the
                // second has to see what the first did to the bag.
                guard var actor = world.actors[id], actor.isAlive,
                      let stack = actor.inventory.stack(at: slot),
                      let spot = spotToThrow(from: actor, in: world) else { continue }

                guard actor.inventory.consume(at: slot) != nil else { continue }
                world.actors[id] = actor
                world.spawnGroundItem(.item(stack.type), at: spot)
            }
        }
    }

    /// Somewhere BEHIND the actor an item can actually be left.
    ///
    /// Behind, and that is the whole of it. Thrown forwards, an item landed in the
    /// direction you were already travelling, so dropping something on the run put
    /// it exactly where your next step took you and the pickup sweep handed it
    /// straight back - you could only ever get rid of anything by stopping first.
    /// Dropped over your shoulder, walking away from it is the default rather than
    /// something you have to arrange.
    ///
    /// Behind means opposite the WALK, not opposite the aim, and the two are
    /// different on a twin-stick game: running one way while shooting another is
    /// the normal state of a fight, and it is the walking that decides where you
    /// are about to be. The aim is the fallback for somebody standing still, who
    /// has no direction of travel to be opposite to.
    ///
    /// The compass sweep behind it is unchanged: the spot still has to be reachable
    /// - not inside a wall, a tree or a crate - AND outside the thrower's own
    /// hitbox, so a drop against a wall at your back still finds somewhere to go
    /// rather than being refused.
    ///
    /// No randomness here, unlike a death drop. A fixed search order keeps a seeded
    /// match reproducible without touching the world's generator at all.
    private static func spotToThrow(from actor: Actor, in world: World) -> Vec2? {
        let travel = actor.moveInput.length > 0.01
            ? actor.moveInput.normalized()
            : (actor.aim.length > 0.01 ? actor.aim.normalized() : Vec2(x: 1, y: 0))

        // Over the shoulder. The sweep below starts here and works round.
        let facing = travel * -1
        let box = actor.hitbox
        let turn = 2 * Double.pi / 8

        for step in 0..<8 {
            let heading = Vec2.fromAngle(facing.angle + Double(step) * turn)

            for distance in GameConfig.Drops.throwDistances {
                let spot = actor.position + heading * distance
                guard world.isClearForDrop(spot), !box.contains(spot) else { continue }
                return spot
            }
        }

        // Walled in on every side at every distance. Refuse rather than drop it
        // somewhere it cannot be picked up again - keeping the item is the kinder
        // failure by a long way.
        return nil
    }

    // MARK: - Picking up

    /// Returns false when the actor has no use for it, and the pickup stays put.
    /// Walking over something and having it vanish is worse than leaving it.
    private static func take(_ pickup: Pickup, by actor: inout Actor, in world: World) -> Bool {
        switch pickup {
        case .item(let type):
            // Gear you already beat stays on the grass - see Actor.wantsFromGround.
            guard actor.wantsFromGround(type) else { return false }

            // And a machine you have nowhere to put stays there too.
            //
            // One to a base, so a second is unplaceable the moment it is picked up
            // - it would ride around in a slot until it was sold. That was merely
            // untidy while everybody had to find their own; now that bots are
            // issued one when their wall shuts, seven actors who cannot use a
            // machine would still have been sweeping every one off the map before
            // the player reached it, and the player is the only one who still has
            // to FIND theirs. Left where it fell, it is still there when they get
            // to it.
            //
            // The refusal that used to stand here is gone with the one-machine cap.
            // It read: leave a machine on the ground if this team already has one,
            // so that seven bots who could not use a second would stop sweeping
            // them off the map before the player found one. Nobody is full up any
            // more - a base takes as many as it has floor for - so there is nothing
            // left to protect the player from. See ArcadeSystem.canPlace for what
            // replaced the cap.

            // Worked out BEFORE acquire, because acquire is precisely what stops
            // it being true: a helmet that beats yours is on your head by the time
            // that call returns, and asking afterwards compares it with itself.
            let worn: Bool
            switch type {
            case .helmet(let tier):  worn = tier > actor.helmet
            case .blaster(let tier): worn = tier > actor.blaster
            case .bandage, .medkit, .bomb, .stink, .chest, .arcade, .turret, .perk:
                worn = false
            }

            // Worn if it beats what is on, bagged if it does not - and that rule
            // lives on the Actor, so walking over a helmet and pulling one out of a
            // chest cannot come to different conclusions.
            guard actor.acquire(type) else { return false }

            world.record(.pickedUp(type, by: actor.id, worn: worn))
            return true

        case .token(let value):
            actor.tokens += value
            world.award(GameConfig.Score.tokenCollected * value, to: actor.team)
            return true
        }
    }

    /// Whether this actor is standing on something their BAG has no room for.
    ///
    /// Almost exactly the sweep's own test now, which it has not been for a while.
    /// wantsFromGround used to turn gear down for being a rung you had already
    /// beaten, and this did not - so a player could stand on a Common helmet, be
    /// refused, and be told nothing. That special case is gone; gear is taken if it
    /// can be held, like everything else.
    ///
    /// One refusal is still not covered: a machine when your base already has one.
    /// That is deliberate, because the hint this drives says "hold an item to sell
    /// it", and selling something does not help - you have nowhere to put a second
    /// machine however much room is in the bag. A full bag remains a strict subset
    /// of what the sweep turns down, so this can never claim a refusal about
    /// something that is quietly being collected.
    ///
    /// A token is excluded because a token is never refused: it goes to a counter
    /// rather than into a pocket, so it cannot be the thing somebody is standing
    /// over wondering about.
    static func blockedPickup(for actor: Actor, in world: World) -> Bool {
        guard actor.isAlive else { return false }
        let reach = actor.hitbox

        return world.groundItems.values.contains { item in
            guard reach.contains(item.position) else { return false }
            guard case .item(let type) = item.pickup else { return false }
            return !actor.canAcquire(type)
        }
    }

    private static func sweepUpItems(_ world: World) {
        guard !world.groundItems.isEmpty else { return }

        var collected: [GroundItemID] = []

        for actorID in Array(world.actors.keys) {
            guard var actor = world.actors[actorID], actor.isAlive else { continue }

            let reach = actor.hitbox

            for item in world.groundItems.values {
                guard !collected.contains(item.id) else { continue }

                // The actor's real hitbox, the same one walls and crates are tested
                // against. No separate pickup radius to drift out of step with it.
                guard reach.contains(item.position) else { continue }

                if take(item.pickup, by: &actor, in: world) {
                    collected.append(item.id)
                }
            }

            world.actors[actorID] = actor
        }

        for id in collected {
            world.removeGroundItem(id)
        }
    }
}
