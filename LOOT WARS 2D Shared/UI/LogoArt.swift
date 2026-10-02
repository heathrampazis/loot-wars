//
//  LogoArt.swift
//  Loot Wars
//
//  The name, drawn as a logo: fat, rounded bubble letters, white, with a black
//  outline - the same flat, outlined look as everything else in the game.
//
//  Three things make it a logo rather than a word set in a font, and each is
//  kept small:
//
//    - The letters are PUFFED, slightly. The rounded face is drawn with a thin
//      white stroke round every letter as well as filled, which softens every
//      corner. Only slightly: much more and the holes in the a, o and s close up
//      and the word stops being readable.
//    - They BOUNCE. Each letter sits a little up or down and leans a few degrees,
//      in a fixed pattern, so the word looks lively without looking random.
//
//  The letters are bunched up so they overlap, and each one is drawn whole -
//  its full outline, then its white - before the next goes on top of it. So
//  every outline you can see is the same thickness all the way round, including
//  the line where one letter sits over the last; nothing is ever squeezed thin
//  between two letters. White and black only - no colour, no gradient, no shine,
//  no glow.
//
//  Drawn from the font's letter shapes rather than set as a label with a stroke:
//  a label's stroke eats into the letter and spikes at the joins.
//

import SpriteKit
import UIKit
import CoreText

enum LogoArt {

    /// The name at this size, as a texture and the size to draw it at.
    static func make(_ text: String, size fontSize: CGFloat) -> (texture: SKTexture, size: CGSize) {
        // How much each letter is swollen, and the black round that.
        //
        // No puff any more: swelling the letters closed up the narrow gaps
        // INSIDE them - between the curls of the s, round the bowl of the a -
        // and left a squeezed sliver of black there instead of a full outline.
        // The rounded face is round enough on its own.
        let puff: CGFloat = 0
        let outline = fontSize * 0.075

        // Bunched, a hair tighter than the font's own spacing, so neighbours
        // overlap only very slightly. Where two outlines meet,
        // the later letter's goes over the top, so the line between them is
        // still a whole outline thick.
        let spacing = -fontSize * 0.01

        let font = roundedFont(size: fontSize)
        let letters = bouncedLetters(of: text, in: font, size: fontSize, spacing: spacing)

        let whole = CGMutablePath()
        for letter in letters { whole.addPath(letter) }
        let bounds = whole.boundingBoxOfPath

        let pad = puff + outline + 2
        let canvas = CGSize(width: bounds.width + pad * 2,
                            height: bounds.height + pad * 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false

        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let cg = context.cgContext

            // Letter shapes are y-up; the image is y-down.
            cg.translateBy(x: pad - bounds.minX, y: pad + bounds.maxY)
            cg.scaleBy(x: 1, y: -1)
            cg.setLineJoin(.round)
            cg.setLineCap(.round)

            // One letter at a time, left to right, each finished before the
            // next: its full outline, then its white. A letter laid over the one
            // before covers it with a whole outline of its own, so every line of
            // black on the logo is the same thickness.
            for letter in letters {
                cg.setStrokeColor(UIColor.black.cgColor)
                cg.setFillColor(UIColor.black.cgColor)
                cg.setLineWidth((puff + outline) * 2)
                cg.addPath(letter)
                cg.drawPath(using: .fillStroke)

                let puffed = letter.copy(strokingWithWidth: puff * 2,
                                         lineCap: .round, lineJoin: .round,
                                         miterLimit: 10)

                cg.setFillColor(UIColor.white.cgColor)
                cg.addPath(letter)
                cg.fillPath()
                cg.addPath(puffed)
                cg.fillPath()
            }
        }

        return (SKTexture(image: image), canvas)
    }

    /// The bounce: how far each letter sits up or down (as a share of the font
    /// size) and how far it leans (degrees). A fixed pattern, cycled, so the logo
    /// is the same every time it is drawn.
    private static let lift: [CGFloat] = [0.02, -0.03, 0.035, -0.015, 0.03, -0.035, 0.02, -0.025]
    private static let lean: [CGFloat] = [-4, 3, -2, 4, -3, 4, -4, 2]

    /// The system's rounded face at its heaviest. Arial Rounded if a device lacks
    /// it.
    private static func roundedFont(size: CGFloat) -> UIFont {
        let heavy = UIFont.systemFont(ofSize: size, weight: .black)
        if let rounded = heavy.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: rounded, size: size)
        }
        return UIFont(name: "ArialRoundedMTBold", size: size) ?? heavy
    }

    /// Every letter as its own path, laid out by Core Text, pulled together, and
    /// each nudged and turned about its own middle.
    private static func bouncedLetters(of text: String, in font: UIFont,
                                       size: CGFloat, spacing: CGFloat) -> [CGPath] {
        let attributed = NSAttributedString(string: text, attributes: [
            .font: font,
            .kern: spacing
        ])
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return [] }

        var letters: [CGPath] = []
        var index = 0

        for run in runs {
            let attributes = CTRunGetAttributes(run) as NSDictionary
            let runFont = attributes[kCTFontAttributeName] as! CTFont
            let count = CTRunGetGlyphCount(run)

            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)

            for glyph in 0..<count {
                // A space has no shape, and does not use up a step of the bounce.
                guard let shape = CTFontCreatePathForGlyph(runFont, glyphs[glyph], nil),
                      !shape.boundingBoxOfPath.isEmpty else { continue }

                let box = shape.boundingBoxOfPath
                let middle = CGPoint(x: box.midX, y: box.midY)
                let step = index % lift.count
                index += 1

                let turn = lean[step] * .pi / 180
                let transform = CGAffineTransform(translationX: positions[glyph].x,
                                                  y: positions[glyph].y + lift[step] * size)
                    .translatedBy(x: middle.x, y: middle.y)
                    .rotated(by: turn)
                    .translatedBy(x: -middle.x, y: -middle.y)

                let placed = CGMutablePath()
                placed.addPath(shape, transform: transform)
                letters.append(placed)
            }
        }
        return letters
    }
}
