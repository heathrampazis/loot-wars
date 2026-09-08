//
//  ArtFit.swift
//  Loot Wars
//
//  Draws a sprite so the PICTURE lands on the box, rather than the canvas.
//
//  Every image in this game is exported with transparent air around it, and how
//  much varies per asset - the chest carries 11% of its height as empty space top
//  and bottom, the machine 10% on each side. Size a sprite to its canvas and the
//  visible thing comes out smaller than the box it is supposed to occupy, by a
//  different amount for each asset. That is how a machine came to be two tiles
//  wide by collision and one and six tenths by sight: you were walking into two
//  fifths of a tile of nothing on each side.
//
//  The old fix was to write the margins down - ArcadeRenderer cropped its texture
//  to five numbers measured off the artwork by hand. That works exactly until the
//  art is redrawn at a different size, at which point the fractions carve a slice
//  out of the middle of the new image and nothing about the code looks wrong.
//
//  So the art is measured here, once, at load. Measured rather than written down
//  because these assets DO get redrawn, and a constant in a file somewhere is a
//  bug waiting for the next export.
//

import SpriteKit
import UIKit

enum ArtFit {

    /// A sprite size, and where the picture actually sits inside it.
    ///
    /// `content` is in the sprite's own coordinates with its centre at zero and y
    /// counting up, so a caller can put the picture's centre - or its feet - where
    /// it wants them, whatever the anchor point.
    struct Fit {
        let size: CGSize
        let content: CGRect
    }

    /// The picture covers this box exactly. Stretches the art if the box is not
    /// the shape the art is, so it is for things whose box was chosen to match.
    static func covering(_ name: String, _ tiles: Vec2) -> Fit {
        let art = measurement(of: name)

        return fit(art,
                   spriteWidth: GridGeometry.length(ofTiles: tiles.x / art.fill.x),
                   spriteHeight: GridGeometry.length(ofTiles: tiles.y / art.fill.y),
                   contentWidth: GridGeometry.length(ofTiles: tiles.x),
                   contentHeight: GridGeometry.length(ofTiles: tiles.y))
    }

    /// The picture fits INSIDE this box, keeping its shape - as large as it can be
    /// without any part of it crossing the edge.
    ///
    /// For anything standing on a grid footprint that it must not overflow. Art
    /// narrower than its box gets a sliver of spare tile at the sides; art wider
    /// gets it above and below. Either way what you see is inside what you
    /// reserved, which is the promise a footprint makes.
    static func contained(_ name: String, within tiles: Vec2) -> Fit {
        let art = measurement(of: name)

        // The art's own shape, in tiles, if it were one tile wide.
        let shape = art.fill.y / art.fill.x * art.canvasHeightOverWidth

        let width = min(tiles.x, tiles.y / shape)
        return covering(name, Vec2(x: width, y: width * shape))
    }

    /// The picture is this many tiles wide and however tall the art says. For
    /// things standing on a grid footprint, where the width is the part that has to
    /// agree with the tiles and the height is the artist's business.
    static func spanning(_ name: String, width tiles: Double) -> Fit {
        let art = measurement(of: name)

        let contentWidth = GridGeometry.length(ofTiles: tiles)
        let spriteWidth = GridGeometry.length(ofTiles: tiles / art.fill.x)

        return fit(art,
                   spriteWidth: spriteWidth,
                   spriteHeight: spriteWidth * CGFloat(art.canvasHeightOverWidth),
                   contentWidth: contentWidth,
                   contentHeight: contentWidth * CGFloat(art.fill.y / art.fill.x)
                                              * CGFloat(art.canvasHeightOverWidth))
    }

    private static func fit(_ art: Measurement,
                            spriteWidth: CGFloat, spriteHeight: CGFloat,
                            contentWidth: CGFloat, contentHeight: CGFloat) -> Fit {
        // How far the picture's middle is from the canvas's middle, as a share of
        // the canvas. Zero for anything exported sensibly; both current assets are
        // centred to within a pixel or two, and this is what stops the third one
        // from having to be.
        let driftX = CGFloat(art.left + art.fill.x / 2 - 0.5)
        let driftY = CGFloat(0.5 - (art.top + art.fill.y / 2))    // texture y counts down

        let centre = CGPoint(x: driftX * spriteWidth, y: driftY * spriteHeight)

        return Fit(
            size: CGSize(width: spriteWidth, height: spriteHeight),
            content: CGRect(x: centre.x - contentWidth / 2,
                            y: centre.y - contentHeight / 2,
                            width: contentWidth, height: contentHeight))
    }

    // MARK: - Measuring

    private struct Measurement {
        /// Share of the canvas the picture occupies, per axis.
        let fill: Vec2
        /// Where it starts, as a share of the canvas, from the left and the top.
        let left: Double
        let top: Double
        let canvasHeightOverWidth: Double

        /// What an unreadable image gets: "the picture is the whole canvas", which
        /// is how all of this behaved before it existed. A broken asset then looks
        /// wrong rather than vanishing or bringing the frame down.
        static let whole = Measurement(fill: Vec2(x: 1, y: 1), left: 0, top: 0,
                                       canvasHeightOverWidth: 1)
    }

    private static var cache: [String: Measurement] = [:]

    private static func measurement(of name: String) -> Measurement {
        if let known = cache[name] { return known }

        let measured = measure(name)
        cache[name] = measured
        return measured
    }

    private static func measure(_ name: String) -> Measurement {
        guard let image = UIImage(named: name)?.cgImage else { return .whole }

        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return .whole }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &pixels,
            width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return .whole }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width, maxX = -1, minY = height, maxY = -1

        // Anything more than faintly there counts. A hard zero would be fooled by
        // the soft edge an antialiased export leaves behind.
        for y in 0..<height {
            let row = y * width * 4
            for x in 0..<width where pixels[row + x * 4 + 3] > 8 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard maxX >= minX, maxY >= minY else { return .whole }

        return Measurement(
            fill: Vec2(x: Double(maxX - minX + 1) / Double(width),
                       y: Double(maxY - minY + 1) / Double(height)),
            left: Double(minX) / Double(width),
            top: Double(minY) / Double(height),
            canvasHeightOverWidth: Double(height) / Double(width))
    }
}
