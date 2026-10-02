//
//  LootTable.swift
//  Loot Wars
//
//  What comes out of a crate.
//
//  Weighted so most of what you find keeps you alive and a little of it makes you
//  stronger. Getting on for a third of crates are something to patch up with; of
//  the rest, the ladder drops away steeply - a Common is ordinary, a Cosmic is the
//  find of the match.
//
//  The healing weights are not the old ones with a row deleted. Dropping the
//  smallest supply raises the average heal, so keeping the old weights would have
//  quietly handed everyone about forty per cent more healing per crate and made
//  every fight longer. These were solved back from the old figure instead: a crate
//  is still worth 17.5% of a health bar on average, exactly as before. You now find
//  healing less often and get more of it when you do.
//
//  Adding the chest meant solving them again - a new row dilutes every old one - so
//  bandage and medkit went up to hold that same 17.5%. Any future row means redoing
//  this, which is the price of a flat weighted table and worth paying while it is
//  still this short.
//
//  Bombs went from 22 to 36 - a bomb in one crate in seven rather than one in
//  eleven - because a bomb is the way into a base, and raids were rationed by how
//  rarely anyone was carrying one.
//
//  Then a balance pass took the ceiling off the table entirely. Gear stops at Rare
//  and Blaster 3; the four helmet tiers and three blaster tiers above them are
//  bought with tokens instead. A crate that can hand you a Cosmic makes the ladder a
//  lottery - won in the first minute or not at all - where an upgrade you save for
//  is a thing you climb.
//
//  With 12% of the table gone the rest was resolved rather than left to inflate:
//  healing up to 40% of crates and 24% of a health bar each, bombs down from one
//  crate in seven to one in nine.
//
//  Bombs then came back up to one in seven, and chests from one in twelve to one in
//  eleven, because raiding was still the thing not happening enough. Healing was
//  solved a fifth time and holds at 24% of a health bar per crate - the table grew
//  rather than the healing shrinking, which is the only way to make two things more
//  common without making a third rarer.
//

enum LootTable {

    /// What a crate holds, and it MOVES with the match.
    ///
    /// One table meant a crate in the last minute paid out the same Commons and
    /// Blaster 2s as a crate in the first, and by then those are litter: you are
    /// wearing an Epic, the thing on the ground is worth nothing, and opening
    /// crates - which is most of what anybody does between fights - stops paying.
    ///
    /// Four bands. The first three follow a rule that is not "better loot later",
    /// which would undo the ladder; it is "nothing WORTHLESS later". The floor comes up so what
    /// you find is at least usable, the frequency of gear comes DOWN, and the
    /// weight goes to healing.
    ///
    /// The ladder stays the shop's. Late crates can hand out an Epic or a Blaster 4
    /// at about one crate in twenty, which is a moment rather than a supply -
    /// Legendary, Mythical and Cosmic are still bought and never found.
    ///
    /// Healing per crate deliberately RISES, 24% of a health bar to 27% to 36%,
    /// and this is the one number in this file that has been held constant through
    /// five previous rewrites, so breaking it on purpose deserves its reason: late
    /// fights are between people with more health and much better blasters, and a
    /// crate that cannot meaningfully patch you up is a crate that does not matter
    /// at the exact point in a match where being alive matters most.
    ///
    /// Bombs are nearly flat across the bands now, and scarce - about one crate
    /// in six or seven once the supply is up, one in seven or eight late. A bomb is a
    /// Mythical find and should feel like one. They used to be front-loaded (one in
    /// four early) to make up for the grace period, which only produced a flood
    /// the moment it ended. The early climb is World.bombShare's job instead, and
    /// the late glut is held off by Loot.maxLooseBombs.
    ///
    /// THE ENDGAME BAND (from 0.75). The rule above - "nothing worthless later",
    /// with the top of the ladder bought rather than found - made for a closing
    /// minute where a good player was in Mythical gear and everybody they met was
    /// in Epic, and the result was never in doubt. The last quarter now hands
    /// out top-half gear and a lot of healing, so the final fights are between
    /// people who are all properly kitted and all able to patch up, and are won
    /// by playing rather than by having got there first. Mythical and Blaster 5
    /// are findable here, at a low weight; a rare crate's upgrade can reach Cosmic
    /// and Blaster 6 in this band only, which is the one place the "never found"
    /// rule is deliberately broken.
    ///
    /// Up by a fifth across the board, and the early band most of all, because the
    /// opening minutes are where the shape of a match is decided: a base goes up,
    /// and then somebody has to be able to break into it. Without a bomb in the
    /// first two minutes the whole raiding half of the game waits for the crates to
    /// hand one over, and everybody spends that time building walls nobody is
    /// threatening. Early is
    /// when nobody has a wall worth blowing open yet and a bomb is what starts the
    /// raiding; late everybody has three and the map does not need more.
    private static let bands: [(from: Double, rows: [(pickup: Pickup, weight: Int)])] = [
        (0.00, [
            (.item(.bandage), 88),
            (.item(.medkit),  22),
            (.item(.bomb),    52),
            (.item(.stink),   18),

            // Three helmet rows became two, at the same total weight, so gear is
            // exactly as likely to come out of an early crate as it was - there is
            // simply one fewer rung for it to land on.
            (.item(.helmet(.common)),    34),
            (.item(.helmet(.epic)),      21),
            (.item(.blaster(.two)),      24),
            (.item(.blaster(.three)),    14)
        ]),
        (0.35, [
            (.item(.bandage), 88),
            (.item(.medkit),  24),
            (.item(.bomb),    50),
            (.item(.stink),   16),

            // The Blaster 2 is gone: by now everybody has better, so that row was a
            // roll that produced nothing.
            //
            // The Common is NOT gone, which is the one place the shorter ladder
            // shows. It used to be dropped here because Uncommon sat between it and
            // Epic; with the middle deleted, dropping it would leave this band
            // offering Epic and nothing else, and a band with one gear rung in it
            // is a coin toss rather than a table. It carries the smaller share.
            (.item(.helmet(.common)),    16),
            (.item(.helmet(.epic)),      26),
            (.item(.blaster(.two)),      26),
            (.item(.blaster(.three)),    12)
        ]),
        (0.55, [
            (.item(.bandage), 96),
            (.item(.medkit),  34),
            (.item(.bomb),    44),
            (.item(.stink),   14),

            // Legendary is where the crates stop, and everything above it is bought.
            //
            // The blaster rows sit on the matching rung, which they did not. They
            // ran a rung ahead in every band but the first - a leftover from when
            // the two ladders were different lengths - so a rare crate late in the
            // match handed out Blaster 6 while the helmet rows stopped one short of
            // Cosmic. Half of "the top rung is the one you cannot find, only buy"
            // was simply not true.
            // Same shape as before - the top natural roll is three fifths of the way
            // up the ladder, and a rare crate's upgrade reaches one rung past it -
            // so Cosmic remains the one rung nobody finds.
            (.item(.helmet(.epic)),      20),
            (.item(.helmet(.legendary)), 10),
            (.item(.blaster(.three)),    16),
            (.item(.blaster(.four)),      6)
        ]),
        (0.75, [
            // Healing up hard - medkits most of all - so a late fight is two
            // people trading heals rather than whoever landed the first volley.
            (.item(.bandage), 92),
            (.item(.medkit),  58),
            (.item(.bomb),    40),
            (.item(.stink),   12),

            // Gear is commoner here than in any other band, and a rung up: the
            // point of this band is that everybody finishes the match kitted out.
            (.item(.helmet(.legendary)), 24),
            (.item(.helmet(.mythical)),   8),
            (.item(.blaster(.four)),     20),
            (.item(.blaster(.five)),      8)
        ])
    ]

    private static func table(at progress: Double) -> [(pickup: Pickup, weight: Int)] {
        bands.last { progress >= $0.from }?.rows ?? bands[0].rows
    }

    /// - Parameters:
    ///   - bombShare: how much of its weight the bomb row keeps, nought to one -
    ///     see World.bombShare. At nought the row is dropped and the rest of the
    ///     table is renormalised around it, so a crate still gives you something.
    ///   - progress: how far the match has run, which picks the band above.
    /// The good crates.
    ///
    /// A rare crate does not roll a different table - it rolls the SAME band and
    /// then, if what came out was gear, hands you the rung above it. That is the
    /// whole mechanism, and it is worth doing this way rather than writing three
    /// more tables: the healing, the bombs and the chests stay exactly as common,
    /// so the bands keep their balance and a rare crate is unambiguously about the
    /// gear. It also cannot hand out something the ladder does not have, and it
    /// tracks the bands automatically as they move through the match - late, when
    /// the band already offers an Epic, a rare crate is where a Legendary comes
    /// from, and that is the only place one is ever found.
    private static func upgraded(_ pickup: Pickup, unlocks: Unlocks) -> Pickup {
        switch pickup {
        case .item(.helmet(let tier)):
            // The rung above, if this match has it - Cosmic is a levelling unlock.
            let next = HelmetTier.allCases.first { $0 > tier } ?? tier
            return .item(unlocks.allows(.helmet(next)) ? .helmet(next) : .helmet(tier))
        case .item(.blaster(let tier)):
            let next = BlasterTier.allCases.first { $0 > tier } ?? tier
            return .item(unlocks.allows(.blaster(next)) ? .blaster(next) : .blaster(tier))
        default:
            // Not gear. A rare crate holding a bandage would be a let-down, so it
            // pays out a second one instead - see LootSystem, which asks for two
            // rolls out of a rare crate and gets exactly one upgrade attempt.
            return pickup
        }
    }

    ///   - unlocks: what this match has - see Unlocks. A locked item's row is
    ///     taken out and the rest of the table renormalised round it.
    static func roll(bombShare: Double,
                     at progress: Double,
                     rare: Bool = false,
                     unlocks: Unlocks = .all,
                     using rng: inout SeededRandom) -> Pickup {
        let rolled = plain(bombShare: bombShare, at: progress, rare: rare,
                           unlocks: unlocks, using: &rng)
        return rare ? upgraded(rolled, unlocks: unlocks) : rolled
    }

    private static func plain(bombShare: Double,
                              at progress: Double,
                              rare: Bool,
                              unlocks: Unlocks,
                              using rng: inout SeededRandom) -> Pickup {
        let table = table(at: progress)
        let share = min(1, max(0, bombShare))
        var rows = table.compactMap { row -> (pickup: Pickup, weight: Int)? in
            guard row.pickup == .item(.bomb) else { return row }
            let weight = Int((Double(row.weight) * share).rounded())
            return weight > 0 ? (pickup: row.pickup, weight: weight) : nil
        }

        // The power-ups, added here rather than written into every band by hand.
        //
        // Four rows, and each one names its own weight for this point in the match -
        // see Perk.lootWeight. There is no multiplier left here to reason about,
        // which is the improvement: this was a base weight times a share, and the
        // rounding meant the number that actually landed in the table was neither of
        // the two numbers you had just read.
        //
        // The three plain ones climb with the match for the same reason the gear
        // rungs do - seven seconds of anything is worth more in a late fight than an
        // early one.
        //
        // obtainable rather than allCases, and that is the ONE gate on which
        // power-ups exist as far as the map is concerned - see Perk.obtainable.
        //
        // The singles share ONE pool however many of them are unlocked, so a
        // player who has only Strength sees it as often as a power-up of any kind
        // will turn up later - early on, the power-up you have is the one you
        // find. Locked ones are taken out further down.
        let singles = max(1, unlocks.singlePerkCount)
        rows += Perk.obtainable.map { perk in
            let weight = perk.lootWeight(at: progress)
            let pooled = perk == .overdrive ? weight : weight * 4 / singles
            return (pickup: Pickup.item(.perk(perk)), weight: pooled)
        }

        // The mini machine, out of ANY crate.
        //
        // This is the whole difference between the two sizes as far as this file is
        // concerned. The cabinet is added further down, inside the rare branch, and
        // is therefore something you go looking for; this is something you find. A
        // base used to either have THE machine or have nothing, decided by whichever
        // crate you happened to open in the first two minutes, and a base with no
        // machine in it has no economy and nothing worth breaking in for.
        //
        // One crate in thirteen or so, which is about one and a half a match.
        // Together with the one bots are handed on seal, that is most bases holding
        // one or two machines and a few holding four - which is the spread the raid
        // pricing was rebuilt to read, and it cannot come from a rare drop.
        rows.append((pickup: .item(.arcade(.mini)),
                     weight: GameConfig.Loot.miniArcadeWeight))

        // A turret, from the same crates for the same reason: something you find
        // rather than go looking for. The bots are handed one on seal most of the
        // time; this is how everybody else gets theirs.
        rows.append((pickup: .item(.turret),
                     weight: GameConfig.Loot.turretWeight))

        // A rare crate cannot hand you a bandage.
        //
        // This is what makes opening one worth the walk. The bandage row comes out
        // entirely - it is the thing you trip over anywhere on the map, and finding
        // one inside something that had been glowing at you from forty tiles away
        // is the single most deflating thing this game can do. (The chest row used
        // to come out here too, and now there is no chest row anywhere: a base
        // furnishes itself when the wall shuts, so a chest in a crate was a spare
        // for a room that already had all it was getting.) What is left is gear,
        // which the upgrade below then bumps a rung, a medkit, and bombs nudged up
        // a little further, because bombs are the
        // supply line for raiding and were rationed by one row in a table shared
        // with the supplies.
        //
        // A stink bomb is not filtered out either: it is a rung rarer than a bomb
        // everywhere it appears, so a rare crate is where most of them come from.
        //
        // So a rare crate is about half gear, a third bombs and the rest medkits.
        // There is nothing in it you would throw away, which is the entire point of
        // it having its own artwork.
        if rare {
            rows = rows.compactMap { row in
                switch row.pickup {
                case .item(.bandage):
                    return nil
                case .item(.bomb):
                    return (pickup: row.pickup,
                            weight: Int(Double(row.weight) * GameConfig.Loot.rareBombBoost))
                default:
                    return row
                }
            }

            // And the machine, which is now found and never bought.
            //
            // This is the only place one comes from, and the scarcity is the point:
            // rare crates are one in fourteen, so a whole match turns up one or two
            // machines between eight teams. Whoever opens that crate has something
            // worth defending and everybody else has something worth raiding, which
            // is a better shape than eight bases each with the same appliance in
            // the corner because the shop sold it to them.
            rows.append((pickup: .item(.arcade(.full)),
                         weight: GameConfig.Loot.rareArcadeWeight))
        }

        // Nothing this match has not unlocked - and the newest unlocks turned up,
        // so something just unlocked actually turns up while it is new. See
        // Unlocks.featured.
        rows = rows.compactMap { row in
            guard case .item(let type) = row.pickup else { return row }
            guard unlocks.allows(type) else { return nil }
            guard unlocks.isFeatured(type) else { return row }
            return (pickup: row.pickup,
                    weight: Int((Double(row.weight) * GameConfig.Loot.featuredBoost).rounded()))
        }

        let total = rows.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return .item(.bandage) }
        var pick = Int.random(in: 0..<total, using: &rng)

        for entry in rows {
            if pick < entry.weight { return entry.pickup }
            pick -= entry.weight
        }

        return .item(.bandage)
    }
}
