//
//  RenderPalette.swift
//  Loot Wars
//
//  Placeholder colours, sampled straight out of the target mockup so the game reads
//  correctly long before there is any real art. Sprites replace all of this later;
//  until then, everything visual comes from here and nowhere else.
//

import SpriteKit

enum RenderPalette {

    // Terrain
    static let floorLight = rgb(0xC0, 0xDD, 0x7A)
    static let floorDark  = rgb(0xAF, 0xCC, 0x71)
    static let terrain    = rgb(0x6F, 0x8F, 0x4B)   // impassable scenery
    static let background = rgb(0x7E, 0x9A, 0x5C)   // only visible past the map edge

    // Actors
    static let player = rgb(0x3E, 0xA2, 0x7F)

    // UI
    static let joystickBase = SKColor(white: 0.0, alpha: 0.18)
    static let joystickKnob = SKColor(white: 0.0, alpha: 0.30)

    private static func rgb(_ r: Int, _ g: Int, _ b: Int) -> SKColor {
        SKColor(red: CGFloat(r) / 255.0,
                green: CGFloat(g) / 255.0,
                blue: CGFloat(b) / 255.0,
                alpha: 1.0)
    }
}
