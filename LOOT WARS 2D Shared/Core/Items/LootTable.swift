//
//  LootTable.swift
//  Loot Wars
//
//  What comes out of a crate.
//
//  Weighted so most of what you find keeps you alive and a little of it makes you
//  stronger. Roughly three crates in five are a drink; of the rest, the ladder
//  drops away steeply - a Common is ordinary, a Cosmic is the find of the match.
//

enum LootTable {

    private static let table: [(pickup: Pickup, weight: Int)] = [
        (.item(.juice),  55),
        (.item(.soda),   35),
        (.item(.slushy), 14),

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

    static func roll(using rng: inout SeededRandom) -> Pickup {
        let total = table.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &rng)

        for entry in table {
            if pick < entry.weight { return entry.pickup }
            pick -= entry.weight
        }

        return .item(.juice)
    }
}
