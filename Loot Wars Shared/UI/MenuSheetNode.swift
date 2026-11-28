//
//  MenuSheetNode.swift
//  Loot Wars
//
//  A card that slides up over the menu, for the things that are not playing.
//
//  Holds either a line of text or a piece of content that lays itself out and
//  takes its own taps and swipes - the settings and the About page behind them
//  (SettingsSheetContent), and the How to Play pages (HowToPlayContent). The card grows to fit
//  whatever it is holding, within the screen.
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
    /// The title's hard drop shadow, in the band's darker shade.
    private let headingShade = SKLabelNode()
    private let body = SKLabelNode()
    private let close = SKNode()

    /// What the card is showing: a line of text, or content.
    private var message: String?
    private var content: MenuSheetContent?

    /// What the card was drawn at, for the hit test.
    private var cardSize: CGSize = .zero
    private var closeCentre: CGPoint = .zero
    private var screen: CGSize = .zero

    private static let closeRadius: CGFloat = 22

    /// Room at the top of the card for the heading and the X, and at the bottom
    /// below content.
    private static let headerHeight: CGFloat = 68
    /// The coloured band across the top, inside the header.
    private static let bandHeight: CGFloat = 54
    private static let tone = PanelArt.band
    private static let footerHeight: CGFloat = 18

    override init() {
        super.init()
        zPosition = 900
        isHidden = true
        alpha = 0

        scrim.zPosition = -0.5   // under the card's shadow - see PanelArt.dress
        addChild(scrim)

        // Near-white, because the screen it sits on is light. Edged in a darker
        // shade of its own fill, the way the buttons are - see MenuButtonNode.
        card.zPosition = 1
        // Dressed in layOut, once its size is known - see PanelArt.
        addChild(card)

        // Everything on the card is a child of it, so it all rides the card's
        // slide up rather than the card arriving underneath its own contents.
        heading.verticalAlignmentMode = .center
        heading.zPosition = 2
        card.addChild(heading)
        headingShade.verticalAlignmentMode = .center
        headingShade.zPosition = 1.9
        card.addChild(headingShade)

        body.verticalAlignmentMode = .center
        body.numberOfLines = 0
        body.zPosition = 2
        card.addChild(body)

        close.zPosition = 2
        card.addChild(close)

        // An X of two crossed bars, drawn rather than typed for the reason Glyphs
        // gives: a multiplication sign, a letter x and a dingbat are three different
        // widths in three different fallback fonts.
        // A round red button rather than a grey cross (Nov 2026 polish pass).
        close.addChild(PanelArt.closeButton(radius: 17))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Laying out

    /// Sized to the screen every time it opens rather than once when it is built,
    /// because a menu is the one screen somebody rotates the device on while
    /// looking at it.
    func layOut(for screen: CGSize) {
        self.screen = screen
        scrim.size = CGSize(width: screen.width * 1.4, height: screen.height * 1.4)

        let width = content?.preferredCardWidth(for: screen) ?? min(screen.width * 0.72, 460)
        let inner = width - 56
        let height: CGFloat

        if let content {
            let most = screen.height - 24
            let room = most - MenuSheetNode.headerHeight - MenuSheetNode.footerHeight
            let wanted = content.layOut(width: inner, maxHeight: room)
            height = min(MenuSheetNode.headerHeight + wanted + MenuSheetNode.footerHeight, most)
            content.node.position = CGPoint(x: 0, y: height / 2 - MenuSheetNode.headerHeight)
        } else {
            height = min(screen.height * 0.62, 280)
        }
        cardSize = CGSize(width: width, height: height)

        card.path = CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2,
                                               width: width, height: height),
                           cornerWidth: 22, cornerHeight: 22, transform: nil)
        // A game card rather than an app's (Nov 2026 polish pass): coloured
        // header band with the title on it, thick edge, soft shadow.
        PanelArt.dress(card, size: cardSize, corner: 22, band: MenuSheetNode.bandHeight,
                       tone: MenuSheetNode.tone)

        heading.position = CGPoint(x: 0, y: height / 2 - MenuSheetNode.bandHeight / 2)
        headingShade.position = CGPoint(x: 0, y: heading.position.y - 1.5)
        body.position = CGPoint(x: 0, y: 4)
        body.preferredMaxLayoutWidth = inner

        closeCentre = CGPoint(x: width / 2 - 30, y: height / 2 - MenuSheetNode.bandHeight / 2)
        close.position = closeCentre
    }

    // MARK: - Showing

    /// A heading and a line of text.
    func open(title: String, message: String, on screen: CGSize) {
        setContents(title: title, message: message, content: nil)
        layOut(for: screen)
        present()
    }

    /// A heading and a page of content that takes its own taps.
    func open(title: String, content: MenuSheetContent, on screen: CGSize) {
        setContents(title: title, message: nil, content: content)
        layOut(for: screen)
        present()
    }

    /// Swaps what an open sheet is showing - Settings to About and back - with a
    /// quick cross-fade rather than closing and reopening.
    func show(title: String, content: MenuSheetContent) {
        guard isOpen else { return }

        let fade: TimeInterval = 0.1
        card.removeAllActions()
        card.run(.sequence([
            .group([Motion.eased(.fadeAlpha(to: 0.0, duration: fade), Motion.cubicIn),
                    Motion.eased(.scale(to: 0.96, duration: fade), Motion.cubicIn)]),
            .run { [weak self] in
                guard let self else { return }
                self.setContents(title: title, message: nil, content: content)
                self.layOut(for: self.screen)
            },
            .group([.fadeAlpha(to: 1, duration: fade), Motion.pop(to: 1, duration: 0.26, overshoot: 1.8)])
        ]))
    }

    private func setContents(title: String, message: String?, content: MenuSheetContent?) {
        self.content?.node.removeFromParent()
        self.message = message
        self.content = content

        heading.attributedText = MenuSheetNode.text(title, size: 22, weight: .heavy,
                                                    colour: PanelArt.title)
        // Clean, with nothing under it (Nov 2026).
        headingShade.attributedText = nil
        // No text at all rather than an empty one: an SKLabelNode given an
        // attributed string with no characters crashes on newer iOS
        // ("NSMutableRLEArray ... Out of bounds"). Pages with their own content
        // have no message, so this is every Settings and How to Play sheet.
        if let message, !message.isEmpty {
            body.attributedText = MenuSheetNode.text(message, size: 14, weight: .regular,
                                                     colour: SKColor(white: 0, alpha: 0.45))
        } else {
            body.attributedText = nil
        }
        body.isHidden = message == nil

        if let content {
            content.node.zPosition = 2
            content.node.isHidden = false
            card.addChild(content.node)
        }
    }

    private func present() {
        isOpen = true
        isHidden = false
        content?.node.isHidden = false
        removeAllActions()

        // The card comes up from slightly below and the scrim just fades. Moving
        // both would be the whole screen lurching; moving neither would be a card
        // that was simply already there.
        // Eased now (Nov 2026 polish pass): it rises and swells into place,
        // overshooting a hair, instead of sliding at one speed.
        card.removeAllActions()
        card.alpha = 1
        card.setScale(0.9)
        card.position = CGPoint(x: 0, y: -16)
        run(.fadeIn(withDuration: 0.14))
        card.run(.group([
            Motion.eased(.moveTo(y: 0, duration: 0.34)) { Motion.backOut($0, overshoot: 1.4) },
            Motion.pop(to: 1, duration: 0.34, overshoot: 1.6)
        ]))
    }

    func dismiss() {
        guard isOpen else { return }
        isOpen = false

        removeAllActions()

        // The content goes at once rather than fading with the card. Some of it -
        // the How to Play pages, behind a crop node - does not take its alpha
        // from the card, so it stayed fully drawn through the fade and hung on
        // screen for a moment after the sheet had gone.
        content?.node.isHidden = true

        run(.sequence([Motion.eased(.fadeOut(withDuration: 0.14), Motion.cubicIn), .hide()]))
        card.removeAllActions()
        card.run(.group([
            Motion.eased(.moveTo(y: -12, duration: 0.14), Motion.cubicIn),
            Motion.eased(.scale(to: 0.94, duration: 0.14), Motion.cubicIn)
        ]))
    }

    // MARK: - Touches

    /// Whether this tap was the X, or anywhere off the card - both of which close
    /// it. A tap ON the card does nothing here, which is what stops a stray finger
    /// inside the sheet dismissing the thing it was reading.
    func closes(localPoint point: CGPoint) -> Bool {
        let onClose = hypot(point.x - closeCentre.x, point.y - closeCentre.y)
            <= MenuSheetNode.closeRadius

        let onCard = abs(point.x) <= cardSize.width / 2
            && abs(point.y) <= cardSize.height / 2

        return onClose || !onCard
    }

    /// A tap on the card that did not close it, handed to whatever it holds.
    func tap(localPoint point: CGPoint) {
        guard let content else { return }
        content.tap(at: convert(point, to: content.node))
    }

    /// A finger dragging on the card, handed on the same way - see
    /// HowToPlayContent, which swipes between pages.
    func dragBegan(localPoint point: CGPoint) {
        guard let content else { return }
        content.dragBegan(at: convert(point, to: content.node))
    }

    func dragMoved(localPoint point: CGPoint) {
        guard let content else { return }
        content.dragMoved(to: convert(point, to: content.node))
    }

    func dragEnded(localPoint point: CGPoint) {
        guard let content else { return }
        content.dragEnded(at: convert(point, to: content.node))
    }

    /// The system face, plain, like everything else on this screen - see
    /// MenuButtonNode.text. Centred and leaded, which is the one thing this needs
    /// that a button label does not.
    private static func text(_ string: String,
                             size: CGFloat,
                             weight: UIFont.Weight,
                             colour: SKColor) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 5

        return NSAttributedString(string: string, attributes: [
            .font: GameFont.of(size: size, weight: weight),
            .foregroundColor: colour,
            .paragraphStyle: paragraph
        ])
    }
}
