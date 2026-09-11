//
//  AIGoal.swift
//  Loot Wars
//
//  What a bot is currently trying to do.
//
//  Only .wander exists so far. The rest of the plan, in the order they are coming:
//
//  Priority runs top down: retreat beats fighting, fighting beats loot, loot
//  beats roaming. Still to come is .raid, once bombs exist.
//
//  Nothing about a bot is privileged. It shoots in the direction it is walking,
//  exactly like the player, so turning to aim and moving are the same action - and
//  it cannot strafe while firing any more than you can.
//

enum AIGoal: Equatable {
    case wander
    case loot(LootboxID)
    case collect(GroundItemID)
    case fight(ActorID)
    case retreat(from: ActorID)
    case build(GridPoint)
    case raid(GridPoint)
    /// Walk to an arcade machine and stand in its payouts.
    case farm(ArcadeID)
    /// Walk to somebody else's chest and empty it.
    case robChest(ChestID)
    /// Walk home to stand a carried chest up.
    case stash(GridPoint)
    /// Walk home to take gear back OUT of your own chest.
    case rearm(ChestID)
    /// Stand in somebody's base and shoot their machine apart.
    case wreck(ArcadeID)
    /// Get home, because somebody is in your base.
    case defend(ActorID)

    /// Cross the map to find a particular person, because they are winning.
    ///
    /// The one goal with no place attached to it. Every other errand here names a
    /// tile, a crate or a machine that sits still and can be walked at; this one
    /// names a PERSON, who does not, and that is the whole difficulty of it - see
    /// AIState.huntMark for where a hunt actually walks, which is the last place
    /// the quarry was seen rather than wherever they happen to be now.
    ///
    /// It deliberately does not shoot. A hunt is the part before the fight: it gets
    /// a bot into the same postcode, and then the ordinary threat scan promotes it
    /// to .fight the moment there is something to shoot at. Keeping the two apart
    /// is what stops a hunt being an aimbot with a long lead.
    case hunt(ActorID)

    var isBuild: Bool {
        if case .build = self { return true }
        return false
    }

    var isRetreat: Bool {
        if case .retreat = self { return true }
        return false
    }

    /// Whether this is a raid on somebody's chest. Used to tell a NEW raid from a
    /// raid already under way, so the urge is spent once per trip rather than once
    /// per tick.
    var isRob: Bool {
        if case .robChest = self { return true }
        return false
    }

    /// Whether this is business inside somebody else's base - emptying it or
    /// breaking it. Used to tell "already raiding" from "thinking about raiding",
    /// so the urge is spent once per break-in rather than once per thing broken.
    var isRaiding: Bool {
        switch self {
        case .robChest, .wreck, .raid: return true
        default: return false
        }
    }

    var isFight: Bool {
        if case .fight = self { return true }
        return false
    }

    /// Whether this is a bot trying to shoot a person - a chosen fight, a fighting
    /// retreat, or somebody caught in your own base. They share the aiming code and
    /// the reaction delay, and defending should not be the one that stands there
    /// politely while it is robbed.
    var isCombat: Bool {
        switch self {
        case .fight, .retreat, .defend: return true
        default: return false
        }
    }

    var debugName: String {
        switch self {
        case .rearm: return "re-arm"
        case .wreck: return "wreck"
        case .defend: return "defend"
        case .wander: return "roam"
        case .loot: return "loot"
        case .collect: return "grab"
        case .fight: return "fight"
        case .retreat: return "flee"
        case .build: return "build"
        case .raid:  return "raid"
        case .farm:  return "coin"
        case .robChest: return "rob"
        case .stash: return "stash"
        case .hunt: return "hunt"
        }
    }
}
