//
//  MenuSheetNode.swift
//  Loot Wars
//
//  A card that slides up over the menu, for the things that are not playing.
//
//  EMPTY ON PURPOSE, for now. Info and Settings both open one of these and both
//  are a heading and a line saying so. That is a deliberate half-step rather than
//  an oversight: the buttons, the layout, the animation, the dismissal and the
//  hit-testing are the part that is tedious to get right and the part that does not
//  change when the contents arrive. What goes inside is a decision about the GAME -
//  which settings are worth having, how much of the game needs explaining - and
//  making that decision badly now would be harder to undo than leaving the room.
//
//  A sheet rather than a scene, which is the same call MenuScene makes about
//  itself: a second scene means a second background, a second layout pass and a way
//  back, for a card with four lines on it.
//
//  Dismissed by tapping anywhere off it as well as by the X, because a card with
//  one way out is a card somebody gets stuck behind - and tapping the dimmed area
//  around a sheet is what every app on the device has already taught them.
//

import SpriteKit
import UIKit

final class MenuSheetNode: SKNode {

    private(set) var isOpen = false

    /// Dimmed rather than darkened: enough to push the menu back, not enough to
    /// hide the map that is still drifting behind all of it.
    private let scrim = SKSpriteNode(color: SKColor(white: 0, alpha: 0.35), size: .zero)
    private let card = SKShapeNode()
    private let heading = SKLabelNode()
    private let body = SKLabelNode()
    private let close = SKNode()

    /// What the card was drawn at, for the hit test.
    private var cardSize: CGSize = .zero
    private var closeCentre: CGPoint = .zero

    private static let closeRadius: CGFloat = 22

    override init() {
        super.init()
        zPosition = 900
        isHidden = true
        alpha = 0

        scrim.zPosition = 0
        addChild(scrim)

        // Near-white, because the screen it sits on is light now. A dark card over
        // a light menu is a hole rather than a sheet - it reads as the screen
        // behind having been switched off rather than as something laid on top.
        card.zPosition = 1
        card.fillColor = SKColor(white: 0.99, alpha: 1)
        card.strokeColor = SKColor(white: 0, alpha: 0.08)
        card.lineWidth = 1
        addChild(card)

        heading.verticalAlignmentMode = .center
        heading.zPosition = 2
        addChild(heading)

        body.verticalAlignmentMode = .center
        body.numberOfLines = 0
        body.zPosition = 2
        addChild(body)

        close.zPosition = 2
        addChild(close)

        // An X of two crossed bars, drawn rather than typed for the reason Glyphs
        // gives: a multiplication sign, a letter x and a dingbat are three different
        // widths in three different fallback fonts.
        for angle in [CGFloat.pi / 4, -CGFloat.pi / 4] {
            let bar = SKShapeNode(rect: CGRect(x: -8, y: -1.1, width: 16, height: 2.2),
                                  cornerRadius: 1.1)
            bar.fillColor = SKColor(white: 0, alpha: 0.4)
            bar.strokeColor = .clear
            bar.zRotation = angle
            close.addChild(bar)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Laying out

    /// Sized to the screen every time it opens rather than once when it is built,
    /// because a menu is the one screen somebody rotates the device on while
    /// looking at it.
    func layOut(for screen: CGSize) {
        scrim.size = CGSize(width: screen.width * 1.4, height: screen.height * 1.4)

        let width = min(screen.width * 0.72, 460)
        let height = min(screen.height * 0.62, 280)
        cardSize = CGSize(width: width, height: height)

        card.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                               width: width, height: height),
                           cornerWidth: 22, cornerHeight: 22, transform: nil)

        heading.position = CGPoint(x: 0, y: height / 2 - 44)
        body.position = CGPoint(x: 0, y: 4)
        body.preferredMaxLayoutWidth = width - 56

        closeCentre = CGPoint(x: width / 2 - 26, y: height / 2 - 26)
        close.position = closeCentre
    }

    // MARK: - Showing

    func open(title: String, message: String, on screen: CGSize) {
        layOut(for: screen)

        heading.attributedText = MenuSheetNode.text(title, size: 22, weight: .heavy,
                                                    kern: 0.5,
                                                    colour: RenderPalette.menuInk)
        body.attributedText = MenuSheetNode.text(message, size: 14, weight: .medium,
                                                 kern: 0,
                                                 colour: SKColor(white: 0, alpha: 0.45))

        isOpen = true
        isHidden = false
        removeAllActions()

        // The card comes up from slightly below and the scrim just fades. Moving
        // both would be the whole screen lurching; moving neither would be a card
        // that was simply already there.
        card.position = CGPoint(x: 0, y: -18)
        run(.fadeIn(withDuration: 0.16))
        card.run(.moveTo(y: 0, duration: 0.22))
    }

    func dismiss() {
        guard isOpen else { return }
        isOpen = false

        removeAllActions()
        run(.sequence([.fadeOut(withDuration: 0.14), .hide()]))
        card.run(.moveTo(y: -14, duration: 0.14))
    }

    /// Whether this tap was the X, or anywhere off the card - both of which close
    /// it. A tap ON the card does nothing, which is what stops a stray finger
    /// inside the sheet dismissing the thing it was reading.
    func closes(localPoint point: CGPoint) -> Bool {
        let onClose = hypot(point.x - closeCentre.x, point.y - closeCentre.y)
            <= MenuSheetNode.closeRadius

        let onCard = abs(point.x) <= cardSize.width / 2
            && abs(point.y) <= cardSize.height / 2

        return onClose || !onCard
    }

    /// The system face, like everything else on this screen - see
    /// MenuButtonNode.text for why. Centred and leaded, which is the one thing this
    /// needs that a button label does not.
    private static func text(_ string: String,
                             size: CGFloat,
                             weight: UIFont.Weight,
                             kern: CGFloat,
                             colour: SKColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 5

        return NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour,
            .kern: kern,
            .paragraphStyle: paragraph
        ])
    }
}
