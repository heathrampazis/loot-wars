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

    private static let table: [(pickup: Pickup, weight: Int)] = [
        (.item(.bandage), 88),
        (.item(.medkit),  22),
        (.item(.bomb),    38),
        (.item(.chest),   26),

        // Stops at Rare. Everything above it is bought, not found - see
        // GameConfig.Shop. A crate that can hand you a Cosmic makes the whole
        // upgrade ladder a lottery you either win in the first minute or do not.
        (.item(.helmet(.common)),    28),
        (.item(.helmet(.uncommon)),  19),
        (.item(.helmet(.rare)),      12),

        // No starter blasters: everybody already has one, so dropping them would
        // only be a way of finding nothing.
        (.item(.blaster(.two)),   26),
        (.item(.blaster(.three)), 16)
    ]

    /// - Parameter bombs: false during the opening grace period, when the bomb row
    ///   is dropped and the rest of the table is renormalised around it. Everything
    ///   else simply becomes correspondingly likelier, which is what should happen -
    ///   a crate still gives you something.
    static func roll(bombs: Bool, using rng: inout SeededRandom) -> Pickup {
        let rows = bombs ? table : table.filter { $0.pickup != .item(.bomb) }

        let total = rows.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &rng)

        for entry in rows {
            if pick < entry.weight { return entry.pickup }
            pick -= entry.weight
        }

        return .item(.bandage)
    }
}
