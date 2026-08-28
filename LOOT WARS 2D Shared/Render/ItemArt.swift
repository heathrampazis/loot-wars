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

    private static var cache: [ItemType: SKTexture] = [:]

    static func texture(for type: ItemType) -> SKTexture {
        if let cached = cache[type] { return cached }

        let texture = SKTexture(imageNamed: assetName(for: type))
        texture.usesMipmaps = true
        cache[type] = texture
        return texture
    }

    private static func assetName(for type: ItemType) -> String {
        switch type {
        case .soda: return "Soda"
        }
    }
}
