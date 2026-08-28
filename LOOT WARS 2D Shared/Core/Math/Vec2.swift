//
//  Vec2.swift
//  Loot Wars
//
//  A 2D vector measured in TILES, never in screen points.
//  Core has no idea how big a tile is on screen - only Render does.
//

import Foundation

struct Vec2: Equatable {
    var x: Double
    var y: Double

    static let zero = Vec2(x: 0, y: 0)

    var length: Double { (x * x + y * y).squareRoot() }

    /// Same direction, length 1. A zero vector stays zero.
    func normalized() -> Vec2 {
        let l = length
        guard l > 0 else { return .zero }
        return Vec2(x: x / l, y: y / l)
    }

    /// Caps the length at 1. A joystick should never hand the simulation more than
    /// full speed, no matter how the maths shook out.
    func clampedToUnit() -> Vec2 {
        length > 1 ? normalized() : self
    }

    /// Direction as an angle in radians.
    var angle: Double { atan2(y, x) }

    /// A unit vector pointing along the given angle.
    static func fromAngle(_ radians: Double) -> Vec2 {
        Vec2(x: cos(radians), y: sin(radians))
    }

    static func + (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec2, b: Vec2) -> Vec2 { Vec2(x: a.x - b.x, y: a.y - b.y) }
    static func * (v: Vec2, scalar: Double) -> Vec2 { Vec2(x: v.x * scalar, y: v.y * scalar) }
}
