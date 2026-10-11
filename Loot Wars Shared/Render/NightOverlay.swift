//
//  NightOverlay.swift
//  Loot Wars
//
//  The dark over a night match. Nothing about the game changes; the map is
//  just drawn as if the sun had gone down.
//
//  One sprite multiplied over the map. Most of it is a flat moonlit blue, so
//  the night is the same everywhere, right out to the edges of the screen. In
//  the middle, round the player, it lifts towards white: a torch. The torch is
//  a circle on the ground rather than the screen's shape, and it follows you
//  rather than the camera.
//
//  It lives in the WORLD layer rather than on the camera, so it is under every
//  button and panel, and so the frosted glass behind them, which is a blurred
//  copy of the world layer, is night too. On the camera, the glass would show
//  a bright day map through a dark screen.
//

import SpriteKit

final class NightOverlay {

    let node: SKSpriteNode

    /// Above everything on the map, under the interface (which starts at 1000).
    static let z: CGFloat = 300

    /// Multiplied, so white would be no change and every other colour tints and
    /// darkens what is under it. A moonlit blue: plainly night, still easy to
    /// play in.
    static let tint = (r: CGFloat(0.52), g: CGFloat(0.57), b: CGFloat(0.84))

    /// How far the torch reaches, in tiles. Fully lit to about a third of the
    /// way out, then fading into the night by the edge.
    static let torchRadius: Double = 6

    /// The torch at its brightest. Not quite white, so the ground you stand on
    /// still looks like night, only lit.
    static let torchLight = (r: CGFloat(0.93), g: CGFloat(0.94), b: CGFloat(1.0))

    /// How much ground the sprite covers, in tiles. Far more than any screen
    /// shows, so the flat night reaches every edge wherever you stand in view.
    private static let span = (width: 60, height: 40)

    /// Pixels per tile in the texture. A soft gradient needs very few.
    private static let detail = 8

    init() {
        node = SKSpriteNode(texture: NightOverlay.texture)
        node.size = CGSize(width: GridGeometry.length(ofTiles: Double(NightOverlay.span.width)),
                           height: GridGeometry.length(ofTiles: Double(NightOverlay.span.height)))
        node.blendMode = .multiply
        node.zPosition = NightOverlay.z
    }

    /// Centred on whoever holds the torch, every frame.
    func follow(_ point: CGPoint) {
        node.position = point
    }

    // MARK: - The picture

    private static let texture: SKTexture = {
        let width = NightOverlay.span.width * NightOverlay.detail
        let height = NightOverlay.span.height * NightOverlay.detail
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

        func colour(_ light: CGFloat) -> CGColor {
            // light 1 is the torch, 0 is the night.
            let r = NightOverlay.tint.r + (NightOverlay.torchLight.r - NightOverlay.tint.r) * light
            let g = NightOverlay.tint.g + (NightOverlay.torchLight.g - NightOverlay.tint.g) * light
            let b = NightOverlay.tint.b + (NightOverlay.torchLight.b - NightOverlay.tint.b) * light
            return CGColor(colorSpace: space, components: [r, g, b, 1])!
        }

        // Eased rather than a straight line, so the edge of the light has no
        // visible rim: steady in the middle, a long soft fall, then nothing.
        let steps: [CGFloat] = [0, 0.2, 0.35, 0.5, 0.65, 0.8, 1]
        let colours = steps.map { at -> CGColor in
            let fall = max(0, (at - 0.2) / 0.8)
            let light = 1 - fall * fall * (3 - 2 * fall)
            return colour(light)
        }

        guard let context = CGContext(data: nil, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let gradient = CGGradient(colorsSpace: space, colors: colours as CFArray,
                                        locations: steps) else {
            return SKTexture()
        }

        // The night everywhere first, then the torch drawn over the middle.
        context.setFillColor(colour(0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let middle = CGPoint(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        let reach = CGFloat(NightOverlay.torchRadius) * CGFloat(NightOverlay.detail)
        context.drawRadialGradient(gradient, startCenter: middle, startRadius: 0,
                                   endCenter: middle, endRadius: reach, options: [])

        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }()
}
