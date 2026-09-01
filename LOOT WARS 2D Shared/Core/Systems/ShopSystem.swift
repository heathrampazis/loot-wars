//
//  ShopSystem.swift
//  Loot Wars
//
//  Spending tokens.
//
//  Both halves of a purchase are checked before either happens: enough tokens, and
//  somewhere for the thing to go. Taking payment first and then discovering a full
//  bag is how a shop charges somebody for nothing, and it is the same ordering rule
//  the chest transfers follow.
//
//  The price is looked up here rather than sent in. Input asks for a bandage; what
//  a bandage costs is not something the interface should be able to be wrong about.
//

enum ShopSystem {

    static func update(_ world: World, commands: [ActorID: [Command]]) {
        for (id, list) in commands {
            for command in list {
                guard case .buyItem(let type) = command else { continue }
                buy(type, by: id, in: world)
            }
        }
    }

    static func price(of type: ItemType) -> Int? {
        for tab in GameConfig.Shop.tabs {
            if let item = tab.items.first(where: { $0.type == type }) { return item.price }
        }
        return nil
    }

    /// Whether this actor could buy this right now. Asked by the shop panel so a
    /// card it draws as affordable is one the simulation will actually sell.
    static func canBuy(_ type: ItemType, actor: Actor) -> Bool {
        guard actor.isAlive, let price = price(of: type) else { return false }
        return actor.tokens >= price && actor.canAcquire(type)
    }

    private static func buy(_ type: ItemType, by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              canBuy(type, actor: actor),
              let price = price(of: type) else { return }

        actor.tokens -= price
        _ = actor.acquire(type)
        world.actors[id] = actor
    }
}
