//
//  LootTable.swift
//  Loot Wars
//
//  What comes out of a crate.
//
//  Weighted so the big heal is a find rather than a given: opening a crate is
//  usually a juice, sometimes a soda, and occasionally the slushy that wins you a
//  fight you had no business surviving.
//

enum LootTable {

    private static let drinks: [(type: ItemType, weight: Int)] = [
        (.juice, 55),
        (.soda, 33),
        (.slushy, 12)
    ]

    static func roll(using rng: inout SeededRandom) -> ItemType {
        let total = drinks.reduce(0) { $0 + $1.weight }
        var pick = Int.random(in: 0..<total, using: &rng)

        for entry in drinks {
            if pick < entry.weight { return entry.type }
            pick -= entry.weight
        }

        return .juice
    }
}
