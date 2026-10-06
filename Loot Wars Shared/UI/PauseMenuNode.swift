//
//  PauseMenuNode.swift
//  Loot Wars
//
//  The pause button by the match timer, and the card it opens.
//
//  The button is the in-match kind: see-through dark, like the hotbar slots,
//  with the same thin rim so it reads as something to press. The card is
//  the title screen's kind - the same near-white card and chunky buttons as the
//  results - because pausing is the moment the match stops and a menu starts.
//
//  Two choices and nothing else: carry on, or leave. Leaving ends the match
//  where it stands with no XP, and the card says so, so nobody quits by
//  accident thinking it saves anything.
//

import SpriteKit
import UIKit

/// The small square that opens the pause menu.
final class PauseButtonNode: SKNode {

    static let side: CGFloat = 32

    /// A thumb is bigger than the button, so a tap near it counts.
    private static let slop: CGFloat = 10

    override init() {
        super.init()
        let side = PauseButtonNode.side

        let plate = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2, width: side, height: side),
                                cornerRadius: 10)
        plate.fillColor = RenderPalette.hotbarSlot
        plate.strokeColor = RenderPalette.glassRim
        plate.lineWidth = RenderPalette.glassRimWidth
        addChild(plate)

        for x in [-4.5, 4.5] as [CGFloat] {
            let bar = SKShapeNode(rect: CGRect(x: x - 2.5, y: -7.5, width: 5, height: 15),
                                  cornerRadius: 2)
            bar.fillColor = .white
            bar.strokeColor = .clear
            bar.zPosition = 1
            addChild(bar)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func contains(localPoint point: CGPoint) -> Bool {
        let reach = PauseButtonNode.side / 2 + PauseButtonNode.slop
        return abs(point.x) <= reach && abs(point.y) <= reach
    }

    /// A quick dip, so the tap is felt.
    func press() {
        removeAllActions()
        run(.sequence([.scale(to: 0.88, duration: 0.05), .scale(to: 1, duration: 0.1)]))
    }
}

/// PAUSED, where the match stands, Resume and Quit match.
final class PauseMenuNode: SKNode {

    private static let cardSize = CGSize(width: 300, height: 252)

    private let scrim = SKShapeNode()
    private let card = SKShapeNode()
    private let detail = SKLabelNode()
    private let resume: MenuButtonNode
    private let quit: MenuButtonNode

    /// Once a choice has been made nothing else here answers, so a second tap
    /// during the press cannot do both.
    private var chosen = false

    var isShowing: Bool { !isHidden }

    override init() {
        resume = MenuButtonNode(label: "RESUME", width: 232, height: 52,
                                tone: RenderPalette.menuPlay)
        quit = MenuButtonNode(label: "QUIT MATCH", width: 232, height: 44,
                              tone: RenderPalette.menuDanger)
        super.init()
        zPosition = 1600
        isHidden = true

        scrim.fillColor = SKColor(white: 0, alpha: 0.45)
        scrim.strokeColor = .clear
        addChild(scrim)

        let size = PauseMenuNode.cardSize
        card.path = CGPath(roundedRect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                               width: size.width, height: size.height),
                           cornerWidth: 22, cornerHeight: 22, transform: nil)
        card.fillColor = SKColor(white: 0.99, alpha: 1)
        card.strokeColor = SKColor(white: 0.78, alpha: 1)
        card.lineWidth = 3
        addChild(card)

        let top = size.height / 2

        let title = SKLabelNode()
        title.attributedText = PauseMenuNode.ink("PAUSED", size: 24, weight: .heavy)
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: top - 34)
        card.addChild(title)

        detail.verticalAlignmentMode = .center
        detail.position = CGPoint(x: 0, y: top - 60)
        card.addChild(detail)

        resume.position = CGPoint(x: 0, y: top - 112)
        resume.zPosition = 2
        card.addChild(resume)

        quit.position = CGPoint(x: 0, y: top - 174)
        quit.zPosition = 2
        card.addChild(quit)

        let warning = SKLabelNode()
        warning.attributedText = PauseMenuNode.ink("Quitting ends the match with no XP",
                                                   size: 11, weight: .semibold, faint: true)
        warning.verticalAlignmentMode = .center
        warning.position = CGPoint(x: 0, y: top - 216)
        card.addChild(warning)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The veil covers the screen, and the card shrinks to fit a short one.
    func layOut(for screen: CGSize) {
        scrim.path = CGPath(rect: CGRect(x: -screen.width / 2, y: -screen.height / 2,
                                         width: screen.width, height: screen.height),
                            transform: nil)
        card.setScale(min(1, screen.height / (PauseMenuNode.cardSize.height + 24)))
    }

    /// Up, with where the match stands: "2:14 LEFT · 2ND PLACE".
    func show(timeLeft: Double, place: Int?) {
        chosen = false
        isHidden = false

        let seconds = max(0, Int(timeLeft.rounded(.up)))
        var line = String(format: "%d:%02d LEFT", seconds / 60, seconds % 60)
        if let place { line += " \u{00B7} \(PauseMenuNode.ordinal(place + 1)) PLACE" }
        detail.attributedText = PauseMenuNode.ink(line, size: 12, weight: .bold, faint: true)

        removeAllActions()
        alpha = 0
        run(.fadeIn(withDuration: 0.12))
        card.removeAllActions()
        let rest = card.xScale
        card.setScale(rest * 0.94)
        card.run(.scale(to: rest, duration: 0.14))
    }

    func hide() {
        removeAllActions()
        run(.sequence([.fadeOut(withDuration: 0.1), .hide()]))
    }

    func isResume(atLocalPoint point: CGPoint) -> Bool {
        !chosen && resume.contains(localPoint: convert(point, to: resume))
    }

    func isQuit(atLocalPoint point: CGPoint) -> Bool {
        !chosen && quit.contains(localPoint: convert(point, to: quit))
    }

    /// A tap anywhere off the card, which closes it the same as Resume.
    func isOffCard(atLocalPoint point: CGPoint) -> Bool {
        guard !chosen else { return false }
        let half = CGSize(width: PauseMenuNode.cardSize.width / 2 * card.xScale,
                          height: PauseMenuNode.cardSize.height / 2 * card.yScale)
        return abs(point.x - card.position.x) > half.width
            || abs(point.y - card.position.y) > half.height
    }

    /// Closed by a tap off the card: no button to press, so straight away.
    func dismiss(then done: () -> Void) {
        chosen = true
        done()
    }

    /// Plays the button's press, then does the thing.
    func pressResume(then done: @escaping () -> Void) {
        chosen = true
        resume.press(then: done)
    }

    func pressQuit(then done: @escaping () -> Void) {
        chosen = true
        quit.press(then: done)
    }

    private static func ink(_ text: String, size: CGFloat, weight: UIFont.Weight,
                            faint: Bool = false) -> NSAttributedString {
        MenuButtonNode.text(text, size: size, weight: weight,
                            colour: faint ? SKColor(white: 0.45, alpha: 1) : RenderPalette.menuInk)
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1ST"
        case 2: return "2ND"
        case 3: return "3RD"
        default: return "\(n)TH"
        }
    }
}
