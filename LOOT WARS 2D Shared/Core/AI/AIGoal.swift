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
    case retreat
    case build(GridPoint)

    var isBuild: Bool {
        if case .build = self { return true }
        return false
    }

    var isFight: Bool {
        if case .fight = self { return true }
        return false
    }

    var debugName: String {
        switch self {
        case .wander: return "roam"
        case .loot: return "loot"
        case .collect: return "grab"
        case .fight: return "fight"
        case .retreat: return "flee"
        case .build: return "build"
        }
    }
}
