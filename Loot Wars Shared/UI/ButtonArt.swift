//
//  ButtonArt.swift
//  Loot Wars
//
//  The raised, chunky button (Nov 2026). Heath: "i want the buttons to look
//  nicer, they are super static atm... more like a nice button design" - and
//  chose the chunky 3D look for every button: in game, the menu and the
//  panels.
//
//  A button is two pictures. The FACE: its colour, flat, edged inside in a
//  darker shade - no drawn lighting or gradients (both tried, both dropped).
//  The LIP: the same shape in a deeper shade, sitting a few points lower, so
//  the face looks like a solid block standing on the screen. Pressing pushes the face down onto the lip
//  and letting go springs it back up - see MenuButtonNode and
//  ActionButtonNode, which both use this.
//
//  Drawn in Core Graphics rather than built from shapes, for the same reason
//  as PanelArt: one picture has clean edges; stacked shapes never quite meet.
//  Cached, since the same few buttons are made again on every layout.
//

import SpriteKit
import UIKit

enum ButtonArt {

    /// A neutral tone for buttons that are not about anything in particular
    /// (pause).
    static let slate = RenderPalette.MenuTone(
        face: SKColor(red: 0x86 / 255.0, green: 0x90 / 255.0, blue: 0xA2 / 255.0, alpha: 1),
        edge: SKColor(red: 0x6C / 255.0, green: 0x75 / 255.0, blue: 0x87 / 255.0, alpha: 1))

    /// How tall the lip under a button of this height shows.
    static func depth(for height: CGFloat) -> CGFloat {
        max(3, (height * 0.085).rounded())
    }

    /// The face and the lip, ready to add: the lip goes BEHIND the face and
    /// `depth` lower. Sized exactly `size`.
    static func parts(size: CGSize, corner: CGFloat, tone: RenderPalette.MenuTone,
                      edge: CGFloat? = nil) -> (face: SKSpriteNode, lip: SKSpriteNode, depth: CGFloat) {
        let rim = edge ?? max(2, (min(size.width, size.height) * 0.06).rounded())
        let face = SKSpriteNode(texture: texture(.face, size: size, corner: corner, tone: tone, rim: rim),
                                size: size)
        let lip = SKSpriteNode(texture: texture(.lip, size: size, corner: corner, tone: tone, rim: rim),
                               size: size)
        let depth = ButtonArt.depth(for: size.height)
        lip.position = CGPoint(x: 0, y: -depth)
        lip.zPosition = -0.5
        return (face, lip, depth)
    }

    private enum Part { case face, lip }

    private static var cache: [String: SKTexture] = [:]

    private static func texture(_ part: Part, size: CGSize, corner: CGFloat,
                                tone: RenderPalette.MenuTone, rim: CGFloat) -> SKTexture {
        let key = "\(part)|\(size.width)x\(size.height)|\(corner)|\(rim)|\(tone.face.description)"
        if let held = cache[key] { return held }

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let outer = UIBezierPath(roundedRect: bounds, cornerRadius: corner)

            switch part {
            case .lip:
                shade(tone.edge, by: 0.78).setFill()
                outer.fill()

            case .face:
                // The edge, then the face inside it.
                tone.edge.setFill()
                outer.fill()
                let inner = bounds.insetBy(dx: rim, dy: rim)
                let face = UIBezierPath(roundedRect: inner, cornerRadius: max(0, corner - rim))
                tone.face.setFill()
                face.fill()

                // Flat (Nov 2026): no light, no gradient. The bright ring went
                // first, then the soft light on the top half - Heath, "i dont
                // rly like the gradient look". An edge and a solid face on a
                // darker lip is the whole button.
            }
        }

        let made = SKTexture(image: image)
        cache[key] = made
        return made
    }

    /// A colour made darker.
    static func shade(_ colour: SKColor, by amount: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        colour.getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: r * amount, green: g * amount, blue: b * amount, alpha: a)
    }
}
