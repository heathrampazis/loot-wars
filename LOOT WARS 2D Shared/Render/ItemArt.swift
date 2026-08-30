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

    private static func assetName(for pickup: Pickup) -> String {
        switch pickup {
        case .item(.juice):  return "Juice"
        case .item(.soda):   return "Soda"
        case .item(.slushy): return "Slushy"
        case .helmet(let tier): return tier.name
        }
    }
}
