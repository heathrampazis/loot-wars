//
//  Chest.swift
//  Loot Wars
//
//  Storage you place in your own base.
//
//  Note what it holds: an Inventory, the same type the player carries. A chest and
//  a pocket obey identical stacking rules, so four bandages stack in a chest exactly
//  as they do in a hotbar slot, and moving something between the two can never find
//  the two sides disagreeing about whether it fits. Reusing the type is not a
//  shortcut here - it is the reason no item can be lost in transit.
//

struct ChestID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}

struct Chest {
    let id: ChestID
    let tile: GridPoint

    /// Whose base it stands in. Only the owner may open it - for now. Once raiding
    /// takes what is inside, this is the field that decides who is robbing whom.
    let owner: TeamID

    var contents = Inventory()

    var position: Vec2 { tile.center }

    /// Solid, and exactly the size the renderer draws.
    var hitbox: Box {
        Box(centre: position, size: GameConfig.Chest.size)
    }
}
