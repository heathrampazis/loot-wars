//
//  Command.swift
//  Loot Wars
//
//  Intents, not actions. Nothing outside the simulation is allowed to reach in and
//  change the world - input produces Commands, and only World.step applies them.
//
//  This is the single most important rule in the codebase. Keep it and multiplayer
//  stays a later addition; break it and it becomes a rewrite.
//

enum Command {
    case move(Vec2)
    case placeBlock(GridPoint)
    /// Take one of your own walls back down.
    case removeBlock(GridPoint)
    /// Fire in this direction, independently of where the actor is walking.
    ///
    /// Aiming used to be a side effect of moving, which meant nobody could shoot
    /// while backing off, and every fight collapsed into two actors walking at each
    /// other. Rate limiting is still the simulation's job, so holding the stick
    /// over is perfectly safe.
    case shoot(Vec2)
    /// Open the nearest lootbox in reach. Carries no coordinate on purpose: asking
    /// for a specific box would mean the input code deciding which one is closest,
    /// and that is the simulation's call.
    case openLootbox
    /// Use whatever is in this hotbar slot - apply it, or throw it. Which of those
    /// happens depends on the item, so input never has to know the difference.
    case useItem(slot: Int)

    /// Put a carried chest down on this tile.
    ///
    /// Separate from useItem because a chest is the first thing you carry that
    /// needs a TARGET. Everything else is used where you stand, or thrown where you
    /// are already pointed. Which chest is taken from the bag is the simulation's
    /// business, exactly as it is for a bomb.
    case placeChest(GridPoint)

    /// Buy one of something with tokens.
    ///
    /// Names the ITEM rather than a row in a menu, so the shop's layout can change
    /// without the simulation knowing. What it costs is the simulation's business -
    /// input never sends a price, or it could send the wrong one.
    case buyItem(ItemType)

    /// Sell what is in this bag slot, at the shop.
    ///
    /// By SLOT rather than by item, unlike buying. Buying names a thing you want
    /// and the shop finds it; selling names a thing you have, and two slots can
    /// hold the same type - if this named the item, selling one of two stacks of
    /// bandages would be ambiguous about which one shrank.
    case sellItem(slot: Int)

    /// Stand a carried arcade machine up on this tile, which is its bottom-left
    /// corner.
    ///
    /// Names the SIZE as well as the spot, and has to. Both sizes live in the same
    /// bag and the same hotbar, so "stand up the machine I am carrying" stopped
    /// being an unambiguous instruction the moment there were two - a player
    /// holding one of each would have got whichever the bag happened to list first.
    /// The tap already knows which slot it came from; this carries that through.
    case placeArcade(GridPoint, ArcadeKind)

    /// Stand a carried turret up with its footprint starting at this tile.
    case placeTurret(GridPoint)

    /// Move one item from a hotbar slot into an open chest, and back again.
    ///
    /// Both name the chest rather than assuming the nearest one. A panel can be
    /// open while the world moves on underneath it, and "the chest I am looking at"
    /// is not a thing the simulation can work out for itself.
    case storeItem(chest: ChestID, slot: Int)
    case takeItem(chest: ChestID, slot: Int)

    /// Throw one item out of a hotbar slot onto the ground.
    ///
    /// Where it lands is the simulation's business, not the input's - it has to
    /// clear your own hitbox or you would walk straight back over it, and it has to
    /// miss the walls and trees or nobody could reach it.
    case dropItem(slot: Int)
}
