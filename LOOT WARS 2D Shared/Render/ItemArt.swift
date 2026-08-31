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

    private static func assetName(for pickup: Pickup) -> String {
        switch pickup {
        case .item(.bandage):    return "Bandage"
        case .item(.medkit):     return "Medkit"
        case .item(.bomb):       return "Bomb"
        case .helmet(let tier):  return tier.name
        case .blaster(let tier): return tier.assetName
        case .token:             return "Token"
        }
    }
}
