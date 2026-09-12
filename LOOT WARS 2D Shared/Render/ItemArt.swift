//
//  ItemArt.swift
//  Loot Wars
//
//  The one place that knows what an item looks like.
//
//  Core deals in ItemType and nothing else; this is the translation into a texture,
//  shared by the items lying on the ground and the icons in the hotbar. Adding an
//  item means one new case here, not two.
//

import SpriteKit

enum ItemArt {

    private static var cache: [Pickup: SKTexture] = [:]

    static func texture(for pickup: Pickup) -> SKTexture {
        if let cached = cache[pickup] { return cached }

        let texture = SKTexture(imageNamed: assetName(for: pickup))
        texture.usesMipmaps = true
        cache[pickup] = texture
        return texture
    }

    static func texture(for type: ItemType) -> SKTexture {
        texture(for: .item(type))
    }

    /// The size to draw a texture at so it fits inside a square of `box`, whatever
    /// shape it is.
    ///
    /// Fitting rather than matching one axis. While every item happened to be
    /// roughly square this made no difference, and both the hotbar and the ground
    /// simply scaled by whichever axis was convenient - until one arrived that was
    /// half again wider than it was tall, and overflowed its hotbar slot. Fitting
    /// costs nothing and means art can be any shape.
    static func size(of texture: SKTexture, fittingInto box: CGFloat) -> CGSize {
        let art = texture.size()
        guard art.width > 0, art.height > 0 else {
            return CGSize(width: box, height: box)
        }

        let scale = min(box / art.width, box / art.height)
        return CGSize(width: art.width * scale, height: art.height * scale)
    }

    /// What to call it on screen.
    ///
    /// Here rather than on the panels because there are two of them now - the shop
    /// and the quick-buy prompt - and a second copy of this switch is a second
    /// place to forget an item when one is added.
    ///
    /// Gear is named by the SLOT - Helmet, Blaster - and not by the tier.
    ///
    /// The other way round was tried and reads badly on a shop card: "Common" and
    /// "Blaster 1" are the names of RUNGS, and a card headed Common tells somebody
    /// scanning the shelf what quality they are being offered while leaving them to
    /// work out what the thing actually is. The tier is already said twice over by
    /// the artwork and the rarity glow behind it, both of which are read faster
    /// than a word. What the card was missing was the noun.
    static func name(for type: ItemType) -> String {
        switch type {
        case .bandage: return "Bandage"
        case .medkit:  return "Medkit"
        case .bomb:    return "Bomb"
        case .stink:   return "Stink Bomb"
        case .chest:   return "Chest"
        case .arcade(let kind):
            return kind == .mini ? "Mini Arcade" : "Arcade"
        case .perk(let which):
            switch which {
            // "Power-Up" rather than "Overdrive", which is what the code calls
            // it. It is the one that does everything, so the noun a player needs
            // is the category - its own name would be a proper noun to learn
            // before it meant anything.
            //
            // The three singles get plain names instead, because a single IS its
            // effect and the word is the whole explanation. Nobody has to be told
            // what Speed does.
            case .overdrive:    return "Power-Up"
            case .strength:     return "Strength"
            case .speed:        return "Speed"
            case .regeneration: return "Regeneration"
            }
        case .helmet:  return "Helmet"
        case .blaster: return "Blaster"
        }
    }

    private static func assetName(for pickup: Pickup) -> String {
        switch pickup {
        case .item(.bandage):    return "Bandage"
        case .item(.medkit):     return "Medkit"
        case .item(.bomb):       return "Bomb"
        case .item(.stink):      return "StinkBomb"
        case .item(.chest):      return "Chest"
        case .item(.arcade(.full)): return "Arcade"
        case .item(.arcade(.mini)): return "Mini Arcade"
        case .item(.perk(.overdrive)):     return "Perk"
        case .item(.perk(.strength)):      return "StrengthPerk"
        case .item(.perk(.speed)):         return "SpeedPerk"
        case .item(.perk(.regeneration)):  return "RegenerationPerk"
        case .item(.helmet(let tier)):  return tier.name
        case .item(.blaster(let tier)): return tier.assetName
        // A golden token is the same pickup carrying a bigger number - Core has no
        // second kind of token and does not need one, because the VALUE is the
        // whole difference. This is the one place that difference has to be
        // visible, and it is a picture, which is exactly what this file is for.
        case .token(let value):
            return value >= GameConfig.Arcade.goldenValue ? "GoldenToken" : "Token"
        }
    }
}
