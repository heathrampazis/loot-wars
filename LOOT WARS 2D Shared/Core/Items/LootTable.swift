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
        (.item(.juice),  60),
        (.item(.soda),   40),
        (.item(.slushy), 16),

        (.helmet(.common),    32),
        (.helmet(.uncommon),  22),
        (.helmet(.rare),      14),
        (.helmet(.epic),       8),
        (.helmet(.legendary),  5),
        (.helmet(.mythical),   2),
        (.helmet(.cosmic),     1)
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
