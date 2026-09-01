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

    /// What one of these costs, wherever it is sold from.
    ///
    /// Shelf prices and upgrade prices are both looked up here, so a card cannot
    /// show one number while the till charges another.
    static func price(of type: ItemType) -> Int? {
        for tab in GameConfig.Shop.tabs {
            guard case .shelf(let items) = tab.stock else { continue }
            if let item = items.first(where: { $0.type == type }) { return item.price }
        }

        switch type {
        case .helmet(let tier):  return GameConfig.Shop.helmetPrices[tier]
        case .blaster(let tier): return GameConfig.Shop.blasterPrices[tier]
        case .bandage, .medkit, .bomb, .chest, .arcade: return nil
        }
    }

    /// The gear tab's offers, without the caller needing to know which tab that is.
    static func upgradeOffers(for actor: Actor) -> [GameConfig.Shop.Item] {
        for index in GameConfig.Shop.tabs.indices {
            if case .upgrades = GameConfig.Shop.tabs[index].stock {
                return offers(on: index, for: actor)
            }
        }
        return []
    }

    /// What this actor is being offered on a tab right now.
    ///
    /// A shelf is the same for everybody. The gear tab is not: it offers the ONE
    /// step up from whatever you are wearing, so the cards change as you climb and
    /// nobody is shown four tiers they cannot reach yet. Empty once you are wearing
    /// the best there is.
    static func offers(on tab: Int, for actor: Actor) -> [GameConfig.Shop.Item] {
        guard GameConfig.Shop.tabs.indices.contains(tab) else { return [] }

        switch GameConfig.Shop.tabs[tab].stock {
        case .shelf(let items):
            return items

        case .upgrades:
            var offers: [GameConfig.Shop.Item] = []

            if let next = nextTier(above: actor.helmet, in: HelmetTier.allCases),
               let price = GameConfig.Shop.helmetPrices[next] {
                offers.append(.init(type: .helmet(next), price: price))
            }

            if let next = nextTier(above: actor.blaster, in: BlasterTier.allCases),
               let price = GameConfig.Shop.blasterPrices[next] {
                offers.append(.init(type: .blaster(next), price: price))
            }

            return offers
        }
    }

    /// The next rung up, or nil at the top.
    ///
    /// Walks the cases rather than doing arithmetic on raw values, so a tier
    /// inserted into the middle of either ladder is picked up without anyone having
    /// to remember this exists.
    private static func nextTier<T: Comparable>(above current: T, in ladder: [T]) -> T? {
        ladder.first { $0 > current }
    }

    /// Whether this actor could buy this right now. Asked by the shop panel so a
    /// card it draws as affordable is one the simulation will actually sell.
    static func canBuy(_ type: ItemType, actor: Actor, in world: World) -> Bool {
        guard actor.isAlive, let price = price(of: type) else { return false }
        guard actor.tokens >= price, actor.canAcquire(type) else { return false }

        // One machine to a base, and the shop will not sell you a second you could
        // never put down - counting the one in your bag as well as the one already
        // standing, or you could buy a spare and be eighteen tokens out of pocket
        // for a thing with nowhere to go.
        if type == .arcade {
            guard !world.hasArcade(actor.team),
                  actor.inventory.firstSlot(holding: .arcade) == nil else { return false }

            // And not one your walls have no room for. A machine needs a clear
            // 2 x 3 inside the base, and about one base in seven is a small enough
            // rectangle that a chest already leaves it without one. Refusing the
            // sale is the only honest answer: the alternative is taking eighteen
            // tokens for something the map will never let you stand up.
            return world.nextArcadeOrigin(for: actor.team, near: actor.position) != nil
        }

        return true
    }

    private static func buy(_ type: ItemType, by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              canBuy(type, actor: actor, in: world),
              let price = price(of: type) else { return }

        actor.tokens -= price
        _ = actor.acquire(type)
        world.actors[id] = actor
    }
}
