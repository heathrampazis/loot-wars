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
    /// Three bands. The rule they follow is not "better loot later", which would
    /// undo the ladder; it is "nothing WORTHLESS later". The floor comes up so what
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
    /// Bombs go the other way: about one crate in FOUR early, one in five late.
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
            (.item(.bomb),    92),
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
            (.item(.bomb),    78),
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
            (.item(.blaster(.three)),    26),
            (.item(.blaster(.four)),     12),

            // A machine, from an ORDINARY crate, and this row is the whole fix for
            // "bases never have an arcade in them".
            //
            // It was rare-crate-only, and no weight in that table could ever have
            // solved it: rare crates are one in eight of forty-two boxes, so there
            // are about five of them in a match, and even handing out a machine on
            // three rare crates in five only reaches three machines between eight
            // teams. The supply was capped by the number of rare crates rather than
            // by the odds inside one - the same shape of fault as the chest clock,
            // where the dial everybody would have reached for was not connected to
            // the thing being complained about.
            //
            // Nothing early. The opening minutes are for bombs and walls, and a
            // machine handed out before there is anywhere to stand it is a machine
            // carried around until somebody kills you for it.
            (.item(.arcade),             26)
        ]),
        (0.70, [
            (.item(.bandage), 96),
            (.item(.medkit),  34),
            (.item(.bomb),    52),
            (.item(.stink),   14),

            // Legendary is where the crates stop, and everything above it is bought.
            // Same shape as before - the top natural roll is three fifths of the way
            // up the ladder, and a rare crate's upgrade reaches one rung past it -
            // so Cosmic remains the one rung nobody finds.
            (.item(.helmet(.epic)),      20),
            (.item(.helmet(.legendary)), 10),
            (.item(.blaster(.four)),     16),
            (.item(.blaster(.five)),      6),
            (.item(.arcade),             34)
        ])
    ]

    private static func table(at progress: Double) -> [(pickup: Pickup, weight: Int)] {
        bands.last { progress >= $0.from }?.rows ?? bands[0].rows
    }

    /// - Parameters:
    ///   - bombs: false during the opening grace period, when the bomb row is
    ///     dropped and the rest of the table is renormalised around it. Everything
    ///     else simply becomes correspondingly likelier, which is what should
    ///     happen - a crate still gives you something.
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
    private static func upgraded(_ pickup: Pickup) -> Pickup {
        switch pickup {
        case .item(.helmet(let tier)):
            let next = HelmetTier.allCases.first { $0 > tier } ?? tier
            return .item(.helmet(next))
        case .item(.blaster(let tier)):
            let next = BlasterTier.allCases.first { $0 > tier } ?? tier
            return .item(.blaster(next))
        default:
            // Not gear. A rare crate holding a bandage would be a let-down, so it
            // pays out a second one instead - see LootSystem, which asks for two
            // rolls out of a rare crate and gets exactly one upgrade attempt.
            return pickup
        }
    }

    static func roll(bombs: Bool,
                     at progress: Double,
                     rare: Bool = false,
                     using rng: inout SeededRandom) -> Pickup {
        let rolled = plain(bombs: bombs, at: progress, rare: rare, using: &rng)
        return rare ? upgraded(rolled) : rolled
    }

    private static func plain(bombs: Bool,
                              at progress: Double,
                              rare: Bool,
                              using rng: inout SeededRandom) -> Pickup {
        let table = table(at: progress)
        var rows = bombs ? table : table.filter { $0.pickup != .item(.bomb) }

        // The power-up, added here rather than written into every band by hand.
        //
        // One row now, where there were four. The four used to carry different
        // weights - the blue pair twice as often as the purple pair - and that
        // arithmetic is now this multiplier: the old table offered a perk at six
        // times the base weight in total, this offers it at four, so a power-up
        // turns up about two thirds as often as SOME power-up used to. Rarer,
        // because it is now worth four times as much, and not much rarer, because
        // a perk you never see is a mechanic the game does not have.
        //
        // The weight climbs with the match for the same reason the gear rungs do:
        // nine seconds of anything is worth more in a late fight than an early one.
        let perkWeight = GameConfig.Loot.perkWeight(at: progress) * 4

        rows += Perk.allCases.map { perk in
            (pickup: Pickup.item(.perk(perk)), weight: perkWeight)
        }

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
            rows.append((pickup: .item(.arcade), weight: GameConfig.Loot.rareArcadeWeight))
        }

        let total = rows.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &rng)

        for entry in rows {
            if pick < entry.weight { return entry.pickup }
            pick -= entry.weight
        }

        return .item(.bandage)
    }
}
