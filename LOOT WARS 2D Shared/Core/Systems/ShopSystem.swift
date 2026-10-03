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
                // Re-read per command inside buy and sell: two taps can land in the
                // same tick, and the second has to see what the first did to the
                // purse and the bag.
                switch command {
                case .buyItem(let type): buy(type, by: id, in: world)
                case .sellItem(let slot): sell(from: slot, by: id, in: world)
                default: break
                }
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
        case .bandage, .medkit, .bomb, .stink, .chest, .arcade, .turret, .perk: return nil
        }
    }

    /// The gear tab's offers, without the caller needing to know which tab that is.
    static func upgradeOffers(for actor: Actor,
                              unlocks: Unlocks = .all) -> [GameConfig.Shop.Item] {
        // Every gear tab's offer, gathered - there are two of them now, one per
        // ladder, and the callers that want "what could this actor climb next"
        // want both. The bots buy the cheaper of them and the quick prompt offers
        // the same, so neither had to learn that the shop was reorganised.
        GameConfig.Shop.tabs.indices.flatMap { index -> [GameConfig.Shop.Item] in
            guard case .upgrades = GameConfig.Shop.tabs[index].stock else { return [] }
            return offers(on: index, for: actor, unlocks: unlocks)
        }
    }

    /// What this actor is being offered on a tab right now.
    ///
    /// A shelf is the same for everybody. The gear tab is not: it offers the ONE
    /// step up from whatever you are wearing, so the cards change as you climb and
    /// nobody is shown four tiers they cannot reach yet. Empty once you are wearing
    /// the best there is.
    ///
    /// - Parameter unlocks: what this match has. The ladders stop at Mythical
    ///   until Cosmic is unlocked, and nothing locked is put on a shelf.
    static func offers(on tab: Int, for actor: Actor,
                       unlocks: Unlocks = .all) -> [GameConfig.Shop.Item] {
        guard GameConfig.Shop.tabs.indices.contains(tab) else { return [] }

        switch GameConfig.Shop.tabs[tab].stock {
        case .shelf(let items):
            return items.filter { unlocks.allows($0.type) }


        case .upgrades:
            var offers: [GameConfig.Shop.Item] = []

            let helmets = HelmetTier.allCases.filter { unlocks.allows(.helmet($0)) }
            let blasters = BlasterTier.allCases.filter { unlocks.allows(.blaster($0)) }

            if let next = nextTier(above: actor.helmet, in: helmets),
               let price = GameConfig.Shop.helmetPrices[next] {
                offers.append(.init(type: .helmet(next), price: price))
            }

            if let next = nextTier(above: actor.blaster, in: blasters),
               let price = GameConfig.Shop.blasterPrices[next] {
                offers.append(.init(type: .blaster(next), price: price))
            }

            return offers
        }
    }

    /// Everything the shop will sell this actor right now, in catalogue order.
    ///
    /// The panel is one page, so this is what a page is: both gear rungs followed
    /// by the shelf. The TABS are still what the config groups by - they are how
    /// prices are looked up, and they order this list - but nobody pages through
    /// them any more, and a shop with four things in it never needed anybody to.
    ///
    /// Shorter than the full catalogue when a ladder has run out: somebody wearing
    /// the best helmet in the game is offered three things, not three things and a
    /// blank.
    static func everythingOffered(to actor: Actor,
                                  unlocks: Unlocks = .all) -> [GameConfig.Shop.Item] {
        GameConfig.Shop.tabs.indices.flatMap { offers(on: $0, for: actor, unlocks: unlocks) }
    }

    /// The next rung up, or nil at the top.
    ///
    /// Walks the cases rather than doing arithmetic on raw values, so a tier
    /// inserted into the middle of either ladder is picked up without anyone having
    /// to remember this exists.
    private static func nextTier<T: Comparable>(above current: T, in ladder: [T]) -> T? {
        ladder.first { $0 > current }
    }

    /// Whether this actor could buy this right now. The purchase itself asks this,
    /// and so does the tap, so nothing is ever charged for something it cannot have.
    static func canBuy(_ type: ItemType, actor: Actor, in world: World) -> Bool {
        guard actor.isAlive, world.unlocks.allows(type),
              let price = price(of: type) else { return false }
        guard actor.tokens >= price, actor.canAcquire(type) else { return false }
        return !isSoldOut(type, actor: actor, in: world)
    }

    /// Whether the SHOP itself refuses this, as opposed to you not affording it.
    ///
    /// Nothing, currently, and this is the second reason it went. It was written
    /// for machines - one to a base, so the card greyed out once you had one - and
    /// that argument had already stopped applying when the shop stopped selling
    /// them; ShopSystem.price returns nil for a machine, so canBuy was refusing
    /// before this was ever consulted. Lifting the one-machine cap took the
    /// reasoning away as well as the caller.
    ///
    /// Kept as a function rather than deleted because canBuy asks it and something
    /// on a future shelf will want it - a per-match limit, a thing sold out for
    /// everyone. A shape with nothing in it is easier to find than a concept that
    /// has to be reintroduced.
    static func isSoldOut(_ type: ItemType, actor: Actor, in world: World) -> Bool {
        false
    }

    /// What the shop pays for something out of your bag.
    ///
    /// A third of what it sells for, floored at one token. The margin is not
    /// meanness, it is what stops the shop being a laundry: at anything near full
    /// price you could buy a bomb, decide against it and sell it back, and the
    /// prices of everything else would stop meaning anything.
    ///
    /// Everything has a price, including things nobody would call junk. Deciding
    /// FOR the player which of their items are rubbish is the sort of rule that is
    /// right ninety per cent of the time and infuriating the rest - a spare Rare is
    /// junk to somebody wearing an Epic and a lifeline to somebody who just
    /// respawned. The shop makes an offer; you decide.
    static func sellPrice(of type: ItemType) -> Int {
        // A bomb is not on the shelf any more, so it has no price to take a share
        // of - but it is still a thing you can be carrying four of with a wall
        // nowhere in sight, which is exactly the situation this feature is for.
        // EVERYTHING sells (Oct 2026). Anything without a shelf price or an
        // off-shelf one used to be worth nothing, and the shop would refuse it -
        // stink bombs were, and a player holding one down saw nothing happen. A
        // price by rarity catches anything either list misses, now and in future.
        let price = price(of: type)
            ?? GameConfig.Shop.offShelf[type]
            ?? GameConfig.Shop.priceByRarity(type.rarity)
        return max(1, Int((Double(price) * GameConfig.Shop.sellShare).rounded(.down)))
    }

    /// Everything this actor is carrying, with what the shop would give for it.
    ///
    /// Indexed by slot, because that is what a sale names - two slots can hold the
    /// same item and only one of them should shrink.
    static func sellOffers(for actor: Actor) -> [(slot: Int, stack: ItemStack, price: Int)] {
        (0..<Inventory.slotCount).compactMap { slot in
            guard let stack = actor.inventory.stack(at: slot) else { return nil }
            return (slot: slot, stack: stack, price: sellPrice(of: stack.type))
        }
    }

    private static func sell(from slot: Int, by id: ActorID, in world: World) {
        guard var actor = world.actors[id], actor.isAlive,
              let stack = actor.inventory.stack(at: slot) else { return }

        let paid = sellPrice(of: stack.type)
        guard paid > 0, actor.inventory.consume(at: slot) != nil else { return }

        actor.tokens += paid
        world.actors[id] = actor
        world.record(.sold(slot: slot, tokens: paid, by: id))
    }

    /// The one thing worth offering out of the blue, or nil.
    ///
    /// What the quick-buy prompt shows, and it is deliberately ONE thing: a prompt
    /// that appears unasked has to be answerable at a glance, and three choices is
    /// a shop, which is what the shop is for.
    ///
    /// It is a gear prompt that yields to an emergency, rather than a shop that
    /// happens to sell gear. The ladder is what people forget to spend on and what
    /// decides fights, so it is the default answer; patching up takes over only
    /// when you are down past half a bar, where a bandage you can afford beats a
    /// rung you would have to survive to enjoy.
    ///
    /// The gear offer is the cheaper of the two rungs - the same rule the bots buy
    /// on, so the prompt never suggests something a bot would call a mistake.
    static func quickOffer(for actor: Actor, in world: World) -> GameConfig.Shop.Item? {
        guard actor.isAlive else { return nil }

        let shelf = GameConfig.Shop.tabs
            .flatMap { tab -> [GameConfig.Shop.Item] in
                if case .shelf(let items) = tab.stock { return items }
                return []
            }
            .filter { canBuy($0.type, actor: actor, in: world) }

        // Hurt, and it is offering to fix that. The biggest healing item you can
        // afford rather than the cheapest, because this fires when you are already
        // losing and half a solution is what gets you killed holding change.
        if Double(actor.health) < Double(actor.maxHealth) * GameConfig.Shop.quickHealBelow,
           let best = shelf.filter({ $0.type.isHealing }).max(by: { $0.price < $1.price }) {
            return best
        }

        // Otherwise the ladder, cheapest rung first. This is the purchase people
        // forget - healing is remembered because bleeding is loud, and a rung is
        // remembered only if something says so.
        if let rung = upgradeOffers(for: actor, unlocks: world.unlocks)
            .filter({ canBuy($0.type, actor: actor, in: world) })
            .min(by: { $0.price < $1.price }) {
            return rung
        }

        // And failing both, anything at all off the shelf, cheapest first.
        //
        // This last line is most of why the prompt is ever on screen. A rung costs
        // between 9 and 40 and a bandage costs 6, so for most of a match the honest
        // answer to "can I afford the next rung" is no while the answer to "can I
        // afford anything" is yes - and the prompt used to say nothing through all
        // of it. Saving towards a rung is a real choice, but it has to be a choice
        // somebody makes rather than one the interface makes for them by going
        // quiet.
        return shelf.min(by: { $0.price < $1.price })
    }

    private static func buy(_ type: ItemType, by id: ActorID, in world: World) {
        guard var actor = world.actors[id],
              canBuy(type, actor: actor, in: world),
              let price = price(of: type) else { return }

        actor.tokens -= price
        _ = actor.acquire(type)
        world.actors[id] = actor
        world.record(.purchase(type, by: id))
    }
}
