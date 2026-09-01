//
//  ItemType.swift
//  Loot Wars
//
//  What an item IS. Deliberately says nothing about what it looks like - the art
//  for each type lives in Render/ItemArt, so Core never learns about textures.
//
//  Note what the two supplies trade, because it is not total healing: four
//  bandages and two medkits both come to twice your health bar, so a slot holds the
//  same either way. What you are choosing is how FAST - a medkit is one action
//  where a bandage is two, and mid-fight that is the whole difference.
//

enum ItemType: Hashable {
    case bandage
    case medkit
    case bomb
    case chest

    /// Gear you can carry rather than wear.
    ///
    /// Worn gear lives on the Actor - helmet and blaster - and always has. These
    /// are the SPARE: a tier sitting in a bag or a chest waiting to be put on.
    /// Making them item types rather than a second parallel system is what lets a
    /// chest hold one, a raider steal one, and the hotbar show one, all through
    /// code that already existed.
    case helmet(HelmetTier)
    case blaster(BlasterTier)

    /// A machine you carry home and stand up in your own base, where it pays out
    /// somewhere nobody can reach without breaking in.
    case arcade

    /// How many fit in one inventory slot.
    var maxStack: Int {
        switch self {
        case .bandage: return 4
        case .medkit:  return 2
        case .bomb:    return 3
        case .chest:   return 2
        // One apiece. Two tiers of the same gear are different item types anyway,
        // so a stack of them could never have meant anything.
        case .helmet, .blaster: return 1
        case .arcade: return 1
        }
    }

    /// Whether this is something you patch yourself up with. A bomb sits in the
    /// same four slots but is thrown at a wall - and without this the hotbar would
    /// happily let you dress a wound with one.
    var isHealing: Bool { healFraction > 0 }

    /// Share of maximum health restored when used.
    var healFraction: Double {
        switch self {
        case .bandage: return 0.50
        case .medkit:  return 1.00
        case .bomb, .chest, .helmet, .blaster, .arcade: return 0
        }
    }

    /// What acts on this item once it has been picked out of the hotbar.
    ///
    /// Everything is now picked out first and acted on second, so this is the whole
    /// difference between the items: most want the button under the thumb already
    /// on the right of the screen, and a chest wants you to say WHERE.
    ///
    /// This replaced a boolean for "used the moment you tap it", which stopped
    /// being true of anything once the bomb moved to the button.
    enum Use {
        /// The small button above the corner.
        case actionButton
        /// Tap the map to say where.
        case mapTap
    }

    var use: Use {
        switch self {
        case .bandage, .medkit, .bomb, .helmet, .blaster: return .actionButton
        // Both want you to say WHERE.
        case .chest, .arcade: return .mapTap
        }
    }

    /// Whether this is something you put on rather than use up.
    var isGear: Bool {
        switch self {
        case .helmet, .blaster: return true
        case .bandage, .medkit, .bomb, .chest, .arcade: return false
        }
    }

    /// Health restored, in points, for an actor with this much health at full.
    ///
    /// A share rather than a fixed number, so a bandage is worth proportionally the
    /// same whether you are bare-headed or wearing a Cosmic.
    func healAmount(of maxHealth: Int) -> Int {
        Int((Double(maxHealth) * healFraction).rounded())
    }
}
