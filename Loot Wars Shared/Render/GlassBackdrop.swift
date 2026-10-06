//
//  GlassBackdrop.swift
//  Loot Wars
//
//  The frosted glass behind the in-match buttons and panels.
//
//  Each control has a GlassNode behind its own plate - see UI/GlassNode - and
//  this is what fills them: the map as it is right now, blurred, so a button
//  reads as a solid piece of frosted glass sitting over the game rather than a
//  tint painted on it.
//
//  One blur for the whole screen, shared by every control: the visible map is
//  drawn into a texture, shrunk, blurred, and each GlassNode shows its own patch
//  of the result. Kept cheap the same way the title screen's blur is - blurred
//  small and scaled back up - and redone every other frame rather than every
//  frame, which nobody can see through a blur.
//

import SpriteKit
import CoreImage

final class GlassBackdrop {

    /// Off draws the controls exactly as before, with no glass behind them -
    /// the switch to throw if a phone cannot keep up.
    static let enabled = true

    /// How small the map is drawn before it is blurred. A quarter of the pixels
    /// along each side is a sixteenth of the work, and a blur hides the loss.
    private static let downscale: CGFloat = 0.25

    /// Blur radius in the shrunk image; about four times this on screen.
    private static let radius: Double = 3.5

    /// Redrawn every this many frames.
    private static let refreshEvery = 2

    /// Extra map captured round the screen, in points, so the blur does not fade
    /// to nothing at the screen's edges.
    private static let pad: CGFloat = 32

    /// The blurred screen, ready to be shared out. Nil until the first capture.
    private(set) var texture: SKTexture?

    private let effect = SKEffectNode()
    private let sprite = SKSpriteNode()
    private var frame = 0

    init() {
        if let blur = CIFilter(name: "CIGaussianBlur",
                               parameters: ["inputRadius": GlassBackdrop.radius]) {
            effect.filter = blur
        }
        effect.shouldEnableEffects = true
        effect.shouldRasterize = false
        effect.addChild(sprite)
    }

    /// Captures and blurs what the camera sees of the world.
    ///
    /// - Parameters:
    ///   - world: the layer the map is drawn in, whose own space is the scene's.
    ///   - centre: the camera's position, in that space.
    ///   - zoom: the camera's scale.
    ///   - screen: the screen, in points.
    func refresh(view: SKView, world: SKNode, centre: CGPoint, zoom: CGFloat, screen: CGSize) {
        frame += 1
        guard texture == nil || frame % GlassBackdrop.refreshEvery == 0 else { return }

        let pad = GlassBackdrop.pad
        let padded = CGSize(width: screen.width + pad * 2, height: screen.height + pad * 2)
        let visible = CGRect(x: centre.x - padded.width * zoom / 2,
                             y: centre.y - padded.height * zoom / 2,
                             width: padded.width * zoom, height: padded.height * zoom)
        guard let raw = view.texture(from: world, crop: visible) else { return }

        let scale = GlassBackdrop.downscale
        sprite.texture = raw
        sprite.size = CGSize(width: padded.width * scale, height: padded.height * scale)

        // The screen's own part of the blurred image, without the pad.
        let crop = CGRect(x: -screen.width * scale / 2, y: -screen.height * scale / 2,
                          width: screen.width * scale, height: screen.height * scale)
        guard let blurred = view.texture(from: effect, crop: crop) else { return }
        blurred.filteringMode = .linear
        texture = blurred
    }
}
