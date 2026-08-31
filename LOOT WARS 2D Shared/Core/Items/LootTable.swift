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
//  rarely anyone was carrying one. Healing was solved a third time to hold 17.5%
//  through it.
//

enum LootTable {

    private static let table: [(pickup: Pickup, weight: Int)] = [
        (.item(.bandage), 60),
        (.item(.medkit),  15),
        (.item(.bomb),    36),
        (.item(.chest),   14),

        (.helmet(.common),    28),
        (.helmet(.uncommon),  19),
        (.helmet(.rare),      12),
        (.helmet(.epic),       7),
        (.helmet(.legendary),  4),
        (.helmet(.mythical),   2),
        (.helmet(.cosmic),     1),

        // No starter blasters: everybody already has one, so dropping them would
        // only be a way of finding nothing.
        (.blaster(.two),   26),
        (.blaster(.three), 16),
        (.blaster(.four),  10),
        (.blaster(.five),   5),
        (.blaster(.six),    2)
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
