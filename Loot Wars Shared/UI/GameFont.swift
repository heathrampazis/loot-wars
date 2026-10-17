//
//  GameFont.swift
//  Loot Wars
//
//  The game's one typeface: the system's rounded face, SF Pro Rounded - the
//  same letters as the title logo, without the logo's bounce or outline.
//
//  Everything that draws words asks here, so the whole game can be switched
//  between the rounded face and what it used before with one line. Set
//  `rounded` to false to go back: attributed text returns to the plain system
//  face and every GameLabel to the Avenir it was created with.
//

import SpriteKit
import UIKit

enum GameFont {

    /// The switch for the whole experiment.
    static let rounded = true

    /// The game's face at this size and weight.
    static func of(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: weight)
        guard rounded,
              let design = system.fontDescriptor.withDesign(.rounded) else { return system }
        return UIFont(descriptor: design, size: size)
    }
}

/// An SKLabelNode in the game's face.
///
/// A drop-in for SKLabelNode(fontNamed:). The rounded face is a system font with
/// no name SpriteKit can look up, so it can only be reached through attributed
/// text - and every label in the game sets plain `text`, `fontSize` and
/// `fontColor`. This keeps those working: whenever one of them changes, the
/// label rebuilds its attributed text from them. The Avenir name it was made
/// with picks the weight, so the old hierarchy carries over.
final class GameLabel: SKLabelNode {

    private var weight: UIFont.Weight = .heavy
    private var restyling = false
    private var drawn: (text: String, size: CGFloat, weight: UIFont.Weight, colour: UIColor?)?

    override var fontName: String? {
        didSet {
            weight = GameLabel.weight(for: fontName)
            restyle()
        }
    }

    override var text: String? {
        didSet { restyle() }
    }

    override var fontSize: CGFloat {
        didSet { restyle() }
    }

    override var fontColor: UIColor? {
        didSet { restyle() }
    }

    /// The Avenir weights this game used, in the rounded face.
    private static func weight(for name: String?) -> UIFont.Weight {
        guard let name else { return .heavy }
        if name.hasSuffix("DemiBold") { return .bold }
        if name.hasSuffix("Heavy") { return .black }
        return .heavy
    }

    private func restyle() {
        guard GameFont.rounded, !restyling else { return }
        restyling = true
        defer { restyling = false }

        guard let text, !text.isEmpty else {
            drawn = nil
            attributedText = nil
            return
        }

        // A label set to the same thing every frame must not redraw every frame.
        if let drawn, drawn.text == text, drawn.size == fontSize,
           drawn.weight == weight, drawn.colour == fontColor {
            return
        }
        drawn = (text, fontSize, weight, fontColor)

        attributedText = NSAttributedString(string: text, attributes: [
            .font: GameFont.of(size: fontSize, weight: weight),
            .foregroundColor: fontColor ?? SKColor.white
        ])
    }
}
