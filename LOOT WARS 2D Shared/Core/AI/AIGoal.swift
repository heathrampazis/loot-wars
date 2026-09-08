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

    var isFight: Bool {
        if case .fight = self { return true }
        return false
    }

    var debugName: String {
        switch self {
        case .rearm: return "re-arm"
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
        }
    }
}
