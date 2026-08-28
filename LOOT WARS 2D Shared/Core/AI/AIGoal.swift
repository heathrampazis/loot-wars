//
//  AIGoal.swift
//  Loot Wars
//
//  What a bot is currently trying to do.
//
//  Only .wander exists so far. The rest of the plan, in the order they are coming:
//
//    .fight(ActorID)   - close to blaster range and shoot, with reaction delay
//                        and aim error so it can actually be beaten
//    .retreat          - low on health: head for your own claim, where your own
//                        walls let you through and the enemy's shots do not
//
//  Each one is a new case here, a branch in AIBrain.chooseGoal, and a branch in
//  AIBrain.execute. Nothing else in the game changes - a bot produces the same
//  Commands a thumb does.
//

enum AIGoal: Equatable {
    case wander
    case loot(LootboxID)
    case collect(GroundItemID)

    var debugName: String {
        switch self {
        case .wander: return "roam"
        case .loot: return "loot"
        case .collect: return "grab"
        }
    }
}
