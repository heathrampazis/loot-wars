//
//  Motion.swift
//  Loot Wars
//
//  How things move, in one place (Nov 2026 polish pass). Heath: "improve the
//  UI and animations to feel less AI... it needs to feel made by a human, look
//  like a real professional game".
//
//  Most of what made the old animations feel canned was timing: SKAction runs
//  linearly unless told otherwise, so a pop was two straight-line scales glued
//  together and everything arrived at the same speed it left. Hand-made game UI
//  is eased - things shoot in, overshoot a hair and settle; they leave quickly
//  and without fuss; and a screen's pieces arrive one after another rather than
//  all at once. These helpers are that, so every screen moves the same way.
//
//  Easing curves are plain functions of t in 0...1, set as an action's
//  timingFunction. Only ever on single actions, never on a group or sequence.
//

import SpriteKit
import UIKit

enum Motion {

    // MARK: - Timings

    /// The few durations everything uses.
    enum Time {
        static let tap: TimeInterval = 0.07
        static let quick: TimeInterval = 0.14
        static let standard: TimeInterval = 0.26
        static let pop: TimeInterval = 0.34
        static let slow: TimeInterval = 0.45
        /// The gap between pieces of a screen arriving one after another.
        static let stagger: TimeInterval = 0.06
    }

    // MARK: - Curves

    /// Shoots past the end and settles back: the pop.
    static func backOut(_ t: Float) -> Float { backOut(t, overshoot: 1.7) }

    static func backOut(_ t: Float, overshoot s: Float) -> Float {
        let u = t - 1
        return u * u * ((s + 1) * u + s) + 1
    }

    /// Fast, then gently into place.
    static func cubicOut(_ t: Float) -> Float {
        let u = 1 - t
        return 1 - u * u * u
    }

    /// Gently, then fast: for leaving.
    static func cubicIn(_ t: Float) -> Float { t * t * t }

    /// Smooth both ends.
    static func inOut(_ t: Float) -> Float {
        t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// The same action, eased.
    static func eased(_ action: SKAction, _ curve: @escaping (Float) -> Float) -> SKAction {
        action.timingFunction = curve
        return action
    }

    // MARK: - Actions

    /// Scale to this, overshooting a little on the way.
    static func pop(to scale: CGFloat, duration: TimeInterval = Time.pop,
                    overshoot: Float = 1.7) -> SKAction {
        eased(.scale(to: scale, duration: duration)) { backOut($0, overshoot: overshoot) }
    }

    static func move(to point: CGPoint, duration: TimeInterval = Time.standard) -> SKAction {
        eased(.move(to: point, duration: duration), cubicOut)
    }

    static func moveBy(_ x: CGFloat, _ y: CGFloat, duration: TimeInterval = Time.standard) -> SKAction {
        eased(.moveBy(x: x, y: y, duration: duration), cubicOut)
    }

    // MARK: - Entrances and exits

    /// Fades in and pops up from `from` times its resting size.
    static func popIn(_ node: SKNode, delay: TimeInterval = 0, from: CGFloat = 0.6,
                      to rest: CGFloat? = nil, duration: TimeInterval = Time.pop) {
        let target = rest ?? node.xScale
        node.removeAction(forKey: "motion")
        node.alpha = 0
        node.setScale(target * from)
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([.fadeIn(withDuration: min(0.12, duration)), pop(to: target, duration: duration)])
        ]), withKey: "motion")
    }

    /// Fades in while sliding home from an offset.
    static func slideIn(_ node: SKNode, delay: TimeInterval = 0, from offset: CGVector,
                        duration: TimeInterval = Time.slow, overshoot: Bool = false) {
        let home = node.position
        node.removeAction(forKey: "motion")
        node.alpha = 0
        node.position = CGPoint(x: home.x + offset.dx, y: home.y + offset.dy)
        let slide = overshoot
            ? eased(.move(to: home, duration: duration)) { backOut($0, overshoot: 1.2) }
            : move(to: home, duration: duration)
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([.fadeIn(withDuration: min(0.16, duration)), slide])
        ]), withKey: "motion")
    }

    /// Shrinks a touch and fades: leaving without fuss.
    static func exit(_ node: SKNode, delay: TimeInterval = 0,
                     duration: TimeInterval = Time.quick) {
        let scale = node.xScale
        node.removeAllActions()
        node.run(.sequence([
            .wait(forDuration: delay),
            .group([eased(.scale(to: scale * 0.86, duration: duration), cubicIn),
                    eased(.fadeOut(withDuration: duration), cubicIn)])
        ]))
    }

    /// A quick swell and a springy settle: "that just happened".
    static func punch(_ node: SKNode, by amount: CGFloat = 0.14, rest: CGFloat? = nil) {
        let base = rest ?? 1
        node.removeAction(forKey: "punch")
        node.run(.sequence([
            eased(.scale(to: base * (1 + amount), duration: Time.tap), cubicOut),
            pop(to: base, duration: 0.3, overshoot: 2.4)
        ]), withKey: "punch")
    }

    // MARK: - Shine

    /// A soft diagonal gleam sweeping across `mask`'s shape every so often -
    /// the polish on a button or a logo. Added as a child of `node`; `mask` is
    /// a white copy of the shape it should stay inside.
    static func shine(on node: SKNode, mask: SKNode, size: CGSize,
                      every gap: TimeInterval, after delay: TimeInterval = 0.8,
                      strength: CGFloat = 0.45) {
        node.childNode(withName: "motion.shine")?.removeFromParent()

        let crop = SKCropNode()
        crop.name = "motion.shine"
        crop.maskNode = mask
        crop.zPosition = 5
        node.addChild(crop)

        let width = max(size.height * 0.55, 18)
        let bar = SKSpriteNode(texture: shineTexture,
                               size: CGSize(width: width, height: size.height * 2.2))
        bar.zRotation = -0.35
        bar.alpha = strength
        bar.blendMode = .add
        let start = -size.width / 2 - width * 1.5
        let end = size.width / 2 + width * 1.5
        bar.position = CGPoint(x: start, y: 0)
        crop.addChild(bar)

        let sweep = eased(.moveTo(x: end, duration: 0.55), inOut)
        bar.run(.sequence([
            .wait(forDuration: delay),
            .repeatForever(.sequence([
                sweep,
                .moveTo(x: start, duration: 0),
                .wait(forDuration: gap, withRange: gap * 0.3)
            ]))
        ]))
    }

    /// One gleam across a shape and gone - for a moment, not an idle.
    static func shineOnce(on node: SKNode, mask: SKNode, size: CGSize,
                          after delay: TimeInterval = 0, strength: CGFloat = 0.7) {
        let crop = SKCropNode()
        crop.maskNode = mask
        crop.zPosition = 5
        node.addChild(crop)
        let width = max(size.height * 0.6, 10)
        let bar = SKSpriteNode(texture: shineTexture,
                               size: CGSize(width: width, height: max(size.height, size.width) * 2.2))
        bar.zRotation = -0.35
        bar.alpha = strength
        bar.blendMode = .add
        bar.position = CGPoint(x: -size.width / 2 - width, y: 0)
        crop.addChild(bar)
        bar.run(.sequence([
            .wait(forDuration: delay),
            eased(.moveTo(x: size.width / 2 + width, duration: 0.4), inOut)
        ]))
        crop.run(.sequence([.wait(forDuration: delay + 0.45), .removeFromParent()]))
    }

    /// A vertical strip of light, clear at both edges.
    private static let shineTexture: SKTexture = {
        let size = CGSize(width: 48, height: 8)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let colours = [UIColor(white: 1, alpha: 0).cgColor,
                           UIColor(white: 1, alpha: 0.9).cgColor,
                           UIColor(white: 1, alpha: 0).cgColor] as CFArray
            guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                            colors: colours, locations: [0, 0.5, 1]) else { return }
            context.cgContext.drawLinearGradient(gradient, start: .zero,
                                                 end: CGPoint(x: size.width, y: 0), options: [])
        }
        return SKTexture(image: image)
    }()
}
