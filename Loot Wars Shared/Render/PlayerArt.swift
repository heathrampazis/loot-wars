//
//  PlayerArt.swift
//  Loot Wars
//
//  The player figure, drawn in code rather than loaded from a picture.
//
//  Drawn to the same measurements as the PNGs it replaces (Player.png and the
//  PlayerCommon...Cosmic set, 292 by 562): the same green body with a round top,
//  the same domed helmet with its flat brim, the same eyes, the same even black
//  outline. What changes is that the parts are separate, so they can move on
//  their own: the eyes look where you aim and blink, and the helmet knocks when
//  you are hit. A new helmet simply swaps in.
//
//  Every texture is made once and shared by every figure on the map.
//
//  To go back to the pictures, set `enabled` to false. Nothing else changes.
//

import SpriteKit
import UIKit

enum PlayerArt {

    /// Drawn figures, or the PNGs. One switch for the whole game.
    static let enabled = true

    // MARK: - Measurements, in canvas pixels (y down), off the original art

    static let canvas = CGSize(width: 292, height: 562)
    private static let line: CGFloat = 23.5

    /// The body's outline runs down the middle of the black, so these are the
    /// centres of the stroke, not its edges.
    private static let bodyLeft: CGFloat = 34.5
    private static let bodyRight: CGFloat = 257.5
    private static let bodyBottom: CGFloat = 545.5
    private static let domeCentreY: CGFloat = 133
    private static var domeRadius: CGFloat { (bodyRight - bodyLeft) / 2 }

    static let helmetCentre = CGPoint(x: 145, y: 145)
    private static let helmetRadius: CGFloat = 129.25
    /// The helmet's own canvas: the top of the figure's, cut below the brim.
    static let helmetCanvasHeight: CGFloat = 164

    static let eyeXs: [CGFloat] = [116.5, 210.5]
    static let eyeYBare: CGFloat = 199
    static let eyeYHelmet: CGFloat = 208
    static let eyeDiameter: CGFloat = 58
    static let pupilDiameter: CGFloat = 17
    /// Where the pupils rest, ahead of the middle of the eye, and how far they
    /// can travel from the middle before they would leave the white.
    static let pupilRest: CGFloat = 9.5
    static let pupilReach = CGSize(width: 12, height: 10)

    // MARK: - Colours

    static let bodyColour = UIColor(red: 61 / 255, green: 161 / 255, blue: 125 / 255, alpha: 1)

    static func colour(of tier: HelmetTier) -> UIColor {
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
            UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
        }
        switch tier {
        case .none:      return bodyColour
        case .common:    return rgb(255, 196, 99)
        case .epic:      return rgb(189, 234, 116)
        case .legendary: return rgb(106, 178, 255)
        case .mythical:  return rgb(159, 121, 255)
        case .cosmic:    return rgb(80, 89, 161)
        }
    }

    // MARK: - Textures

    static let body: SKTexture = draw(canvas) { _ in
        let path = UIBezierPath()
        path.move(to: CGPoint(x: bodyLeft, y: bodyBottom))
        path.addLine(to: CGPoint(x: bodyLeft, y: domeCentreY))
        path.addArc(withCenter: CGPoint(x: (bodyLeft + bodyRight) / 2, y: domeCentreY),
                    radius: domeRadius, startAngle: .pi, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: bodyRight, y: bodyBottom))
        path.close()
        outlined(path, fill: bodyColour)
    }

    private static var helmets: [HelmetTier: SKTexture] = [:]

    /// The helmet for a tier, or nil for a bare head.
    static func helmet(_ tier: HelmetTier) -> SKTexture? {
        guard tier != .none else { return nil }
        if let made = helmets[tier] { return made }

        let made = draw(CGSize(width: canvas.width, height: helmetCanvasHeight)) { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: helmetCentre.x - helmetRadius, y: helmetCentre.y))
            path.addArc(withCenter: helmetCentre, radius: helmetRadius,
                        startAngle: .pi, endAngle: 0, clockwise: true)
            path.close()
            outlined(path, fill: colour(of: tier))
        }
        helmets[tier] = made
        return made
    }

    static let eyeWhite: SKTexture = disc(diameter: eyeDiameter, colour: .white)
    static let pupil: SKTexture = disc(diameter: pupilDiameter, colour: .black)

    /// A happy eye: a black arch, the ^ of a closed smiling eye, drawn in the
    /// eye's own square so it swaps in for the white and pupil without moving.
    static let happyEye: SKTexture = {
        let pad: CGFloat = 2
        let side = eyeDiameter + pad * 2
        return draw(CGSize(width: side, height: side)) { _ in
            // y runs DOWN here, so going clockwise from the left to the right
            // passes over the top.
            let arch = UIBezierPath(arcCenter: CGPoint(x: side / 2, y: side * 0.66),
                                    radius: eyeDiameter * 0.38,
                                    startAngle: .pi, endAngle: 0, clockwise: true)
            arch.lineWidth = line * 0.62
            arch.lineCapStyle = .round
            UIColor.black.setStroke()
            arch.stroke()
        }
    }()

    private static func disc(diameter: CGFloat, colour: UIColor) -> SKTexture {
        let pad: CGFloat = 2
        return draw(CGSize(width: diameter + pad * 2, height: diameter + pad * 2)) { _ in
            colour.setFill()
            UIBezierPath(ovalIn: CGRect(x: pad, y: pad, width: diameter, height: diameter)).fill()
        }
    }

    private static func outlined(_ path: UIBezierPath, fill: UIColor) {
        fill.setFill()
        path.fill()
        UIColor.black.setStroke()
        path.lineWidth = line
        path.lineJoinStyle = .miter
        path.stroke()
    }

    private static func draw(_ size: CGSize,
                             _ actions: @escaping (UIGraphicsImageRendererContext) -> Void) -> SKTexture {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image(actions: actions)
        let texture = SKTexture(image: image)
        texture.usesMipmaps = true
        return texture
    }
}

/// The moving parts on one figure, hung off its sprite. The sprite itself is
/// the body; its mirror (xScale) flips the parts with it, so the eyes always
/// sit towards the way the figure faces.
final class PlayerFigure {

    static let helmetName = "helmet"

    let helmet = SKSpriteNode()
    private let eyeLine = SKNode()
    private var eyes: [SKNode] = []
    private var pupils: [SKSpriteNode] = []
    private var whites: [SKSpriteNode] = []
    private var happies: [SKSpriteNode] = []

    private let kx: CGFloat
    private let ky: CGFloat
    private(set) var tier: HelmetTier = .none

    /// Where the helmet sits on the head. It only ever moves UP from here,
    /// never down, so it can never come down over the eyes.
    private var helmetRest = CGPoint.zero

    /// Where the pupils are now, in canvas pixels from the middle of the eye.
    private var gaze = CGPoint(x: PlayerArt.pupilRest, y: 0)

    init(on sprite: SKSpriteNode) {
        kx = sprite.size.width / PlayerArt.canvas.width
        ky = sprite.size.height / PlayerArt.canvas.height
        sprite.texture = PlayerArt.body

        sprite.addChild(eyeLine)
        eyeLine.zPosition = 0.01

        for x in PlayerArt.eyeXs {
            let eye = SKNode()
            eye.position = CGPoint(x: (x - PlayerArt.canvas.width / 2) * kx, y: 0)
            eyeLine.addChild(eye)

            let white = SKSpriteNode(texture: PlayerArt.eyeWhite,
                                     size: CGSize(width: (PlayerArt.eyeDiameter + 4) * kx,
                                                  height: (PlayerArt.eyeDiameter + 4) * ky))
            eye.addChild(white)

            let pupil = SKSpriteNode(texture: PlayerArt.pupil,
                                     size: CGSize(width: (PlayerArt.pupilDiameter + 4) * kx,
                                                  height: (PlayerArt.pupilDiameter + 4) * ky))
            pupil.zPosition = 0.001
            eye.addChild(pupil)

            let happy = SKSpriteNode(texture: PlayerArt.happyEye,
                                     size: CGSize(width: (PlayerArt.eyeDiameter + 4) * kx,
                                                  height: (PlayerArt.eyeDiameter + 4) * ky))
            happy.zPosition = 0.002
            happy.isHidden = true
            eye.addChild(happy)

            eyes.append(eye)
            pupils.append(pupil)
            whites.append(white)
            happies.append(happy)
        }
        placePupils()

        helmet.name = PlayerFigure.helmetName
        // Pinned at the middle of the brim, so any tilt pivots there and the
        // brim never swings down over the eyes.
        let brim = PlayerArt.helmetCentre.y
        helmet.anchorPoint = CGPoint(x: 0.5, y: (PlayerArt.helmetCanvasHeight - brim)
                                                / PlayerArt.helmetCanvasHeight)
        helmet.size = CGSize(width: PlayerArt.canvas.width * kx,
                             height: PlayerArt.helmetCanvasHeight * ky)
        helmetRest = CGPoint(x: 0, y: (PlayerArt.canvas.height - brim) * ky)
        helmet.position = helmetRest
        helmet.zPosition = 0.02
        sprite.addChild(helmet)

        setHelmet(.none)
        startBlinking()
    }

    // MARK: - Dressing

    func setHelmet(_ tier: HelmetTier) {
        self.tier = tier
        helmet.texture = PlayerArt.helmet(tier)
        helmet.isHidden = tier == .none
        helmet.removeAction(forKey: "clank")
        helmet.position = helmetRest
        helmet.zRotation = 0
        helmet.setScale(1)
        helmet.alpha = 1
        helmet.colorBlendFactor = 0

        // The eyes sit a little lower under a brim, as they do in the art.
        let y = tier == .none ? PlayerArt.eyeYBare : PlayerArt.eyeYHelmet
        eyeLine.position = CGPoint(x: 0, y: (PlayerArt.canvas.height - y) * ky)
    }

    // MARK: - Moving every frame

    /// Turns the eyes towards a direction in the figure's own space, where +x
    /// is the way it faces. Eased rather than snapped, so a quick turn reads as
    /// a glance.
    func look(towards direction: CGVector, dt: TimeInterval) {
        let length = (direction.dx * direction.dx + direction.dy * direction.dy).squareRoot()
        let target: CGPoint
        if length > 0.01 {
            target = CGPoint(x: direction.dx / length * PlayerArt.pupilReach.width,
                             y: direction.dy / length * PlayerArt.pupilReach.height)
        } else {
            target = CGPoint(x: PlayerArt.pupilRest, y: 0)
        }
        let ease = CGFloat(1 - exp(-dt * 14))
        gaze.x += (target.x - gaze.x) * ease
        gaze.y += (target.y - gaze.y) * ease
        placePupils()
    }

    private func placePupils() {
        for pupil in pupils {
            pupil.position = CGPoint(x: gaze.x * kx, y: gaze.y * ky)
        }
    }

    // MARK: - Moments

    /// Hit: the helmet knocks up off the head and drops back, with a slight
    /// tilt about its brim. Up, never down, so it stays clear of the eyes.
    func flinch() {
        helmet.removeAction(forKey: "clank")
        helmet.position = helmetRest
        helmet.zRotation = 0
        let knock = CGFloat(18) * ky
        helmet.run(.sequence([
            .group([.moveTo(y: helmetRest.y + knock, duration: 0.05),
                    .rotate(toAngle: -0.08, duration: 0.05)]),
            .group([.moveTo(y: helmetRest.y, duration: 0.12),
                    .rotate(toAngle: 0, duration: 0.12)])
        ]), withKey: "clank")
    }

    /// A happy moment: the eyes close into happy arches briefly, popping in
    /// a little big, then open again. No blinking while they are shut - a blink
    /// squashing a smile reads as a wince.
    func cheer() {
        eyeLine.removeAction(forKey: "blink")
        eyeLine.removeAction(forKey: "cheer")
        eyeLine.yScale = 1

        let show = SKAction.run { [weak self] in
            guard let self else { return }
            for white in self.whites { white.isHidden = true }
            for pupil in self.pupils { pupil.isHidden = true }
            for happy in self.happies {
                happy.isHidden = false
                happy.removeAllActions()
                happy.setScale(0.6)
                happy.run(.sequence([.scale(to: 1.15, duration: 0.09),
                                     .scale(to: 1, duration: 0.12)]))
            }
        }
        let hide = SKAction.run { [weak self] in
            guard let self else { return }
            for white in self.whites { white.isHidden = false }
            for pupil in self.pupils { pupil.isHidden = false }
            for happy in self.happies { happy.isHidden = true }
            self.startBlinking()
        }
        eyeLine.run(.sequence([show, .wait(forDuration: 0.55), hide]), withKey: "cheer")
    }

    /// A blink every few seconds, at its own random pace, so a crowd of figures
    /// never blinks together.
    private func startBlinking() {
        let blink = SKAction.sequence([.scaleY(to: 0.1, duration: 0.05),
                                       .scaleY(to: 1, duration: 0.07)])
        eyeLine.run(.repeatForever(.sequence([
            .wait(forDuration: 3.4, withRange: 3),
            blink,
            // Now and then, a double blink.
            .wait(forDuration: 0.12, withRange: 0.1)
        ])), withKey: "blink")
    }
}
