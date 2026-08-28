//
//  JoystickNode.swift
//  Loot Wars
//
//  A fixed-position virtual thumbstick.
//
//  It reports a direction and nothing else. It does not know what a player is, how
//  fast anything moves, or that movement even exists - GameScene turns its direction
//  into a Command, and the simulation decides what that means.
//
//  Deliberately platform-neutral: it takes plain points, so the UITouch bookkeeping
//  stays in GameScene where it belongs.
//

import Foundation
import SpriteKit

final class JoystickNode: SKNode {

    /// How far the knob can travel from the centre.
    private static let baseRadius: CGFloat = 62
    private static let knobRadius: CGFloat = 26

    /// A touch this far from the centre still grabs the stick. Generous on purpose -
    /// thumbs are imprecise and nobody looks at the joystick while playing.
    private static let grabRadius: CGFloat = 150

    /// Ignore tiny movements so resting your thumb does not creep the player along.
    private static let deadZone: CGFloat = 8

    private let base = SKShapeNode(circleOfRadius: JoystickNode.baseRadius)
    private let knob = SKShapeNode(circleOfRadius: JoystickNode.knobRadius)

    /// Current direction, length 0...1. Zero when nobody is touching it.
    private(set) var direction: Vec2 = .zero

    override init() {
        super.init()

        base.fillColor = RenderPalette.joystickBase
        base.strokeColor = .clear
        knob.fillColor = RenderPalette.joystickKnob
        knob.strokeColor = .clear

        zPosition = 1000
        addChild(base)
        addChild(knob)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// - Parameter localPoint: the touch, in this node's own coordinate space.
    /// - Returns: true if the stick is taking ownership of this touch.
    func begin(atLocalPoint localPoint: CGPoint) -> Bool {
        guard hypot(localPoint.x, localPoint.y) <= Self.grabRadius else { return false }
        update(toLocalPoint: localPoint)
        return true
    }

    func update(toLocalPoint localPoint: CGPoint) {
        let distance = hypot(localPoint.x, localPoint.y)

        guard distance > Self.deadZone else {
            knob.position = .zero
            direction = .zero
            return
        }

        let clamped: CGPoint
        if distance > Self.baseRadius {
            clamped = CGPoint(x: localPoint.x / distance * Self.baseRadius,
                              y: localPoint.y / distance * Self.baseRadius)
        } else {
            clamped = localPoint
        }

        knob.position = clamped
        direction = Vec2(x: Double(clamped.x / Self.baseRadius),
                         y: Double(clamped.y / Self.baseRadius))
    }

    func end() {
        knob.position = .zero
        direction = .zero
    }
}
