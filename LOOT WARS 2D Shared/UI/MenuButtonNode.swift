//
//  MenuButtonNode.swift
//  Loot Wars
//
//  The menu's buttons, in two weights.
//
//  PRIMARY is the wide pill: one per screen. SECONDARY is a small circle carrying
//  a glyph. Both are filled in a colour of their own and both carry BLACK - see
//  RenderPalette's menu block for why every one of those colours is chosen to hold
//  dark type rather than light.
//
//  One type rather than two, because the difference between them is entirely a
//  matter of fill, size and what is inside - and two classes sharing a press
//  animation is how a press animation ends up with two slightly different timings
//  that nobody meant.
//
//  Drawn here rather than exported, so a button can be resized or recoloured by
//  changing a number rather than by redrawing a picture at three scales.
//
//  Not ActionButtonNode, which is the in-game control: that one knows about grab
//  radii wider than itself because it is pressed by a thumb that is also steering,
//  and about being drawn faint when the simulation would refuse it. Neither is true
//  here. A menu button is pressed by somebody looking at it.
//

import SpriteKit
import UIKit

final class MenuButtonNode: SKNode {

    enum Weight {
        /// The wide pill.
        case primary
        /// A small circle with a glyph in it.
        case secondary
    }

    /// The tap target, in this node's own space. Measured from what was drawn
    /// rather than written down twice - see GameScene, where exactly that pair
    /// coming apart is a recurring note.
    ///
    /// NOT called `size`. SKNode has no such property today, so it would compile -
    /// but SKSpriteNode does, and this project has a sibling note worth honouring:
    /// a `listener` declared on an SKScene subclass collided with SpriteKit's own
    /// and the file simply would not build, which is a class of error nothing here
    /// can catch before Xcode. A name of one's own costs nothing.
    private(set) var box: CGSize

    private let weight: Weight
    private let body: SKShapeNode
    private let content = SKNode()

    /// Accessibility takes a touch that starts near a small button and is heading
    /// for it. Generous on the secondaries because they are barely fifty points
    /// across, which is Apple's floor rather than a comfortable target.
    private static let slop: CGFloat = 12

    // MARK: - Building

    /// The wide one: a play triangle, a gap, and a word.
    init(primary title: String, width: CGFloat, height: CGFloat, fill: SKColor) {
        self.weight = .primary
        self.box = CGSize(width: width, height: height)

        body = SKShapeNode(rect: CGRect(x: -width / 2, y: -height / 2,
                                        width: width, height: height),
                           cornerRadius: height / 2)
        super.init()

        body.fillColor = fill
        body.strokeColor = .clear
        addChild(body)
        addChild(content)

        // The triangle and the word are laid out as one row and centred together,
        // rather than the word centred with a triangle hung off it. A pill with
        // centred text and a mark to the left of it looks off-centre, because it is.
        let glyphSide = height * 0.30
        let gap = height * 0.20

        let label = SKLabelNode()
        label.attributedText = MenuButtonNode.text(title,
                                                   size: height * 0.32,
                                                   weight: .heavy,
                                                   kern: height * 0.012,
                                                   colour: RenderPalette.menuInk)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left

        let row = glyphSide + gap + label.frame.width
        let triangle = MenuButtonNode.play(side: glyphSide, colour: RenderPalette.menuInk)

        triangle.position = CGPoint(x: -row / 2 + glyphSide / 2, y: 0)
        label.position = CGPoint(x: -row / 2 + glyphSide + gap, y: 0)

        content.addChild(triangle)
        content.addChild(label)
    }

    /// A small one: a filled circle and a glyph.
    init(secondary glyph: SKTexture, diameter: CGFloat, fill: SKColor) {
        self.weight = .secondary
        self.box = CGSize(width: diameter, height: diameter)

        body = SKShapeNode(circleOfRadius: diameter / 2)
        super.init()

        body.fillColor = fill
        body.strokeColor = .clear
        addChild(body)
        addChild(content)

        // Hierarchy is carried by SIZE here rather than by fill, which is the change
        // from the version before this. These were outlined and hollow on a dark
        // screen, on the argument that only the thing you came to press should be
        // solid. On a light screen that reads as two disabled controls. Three solid
        // shapes where one is three times the size of the others says the same thing
        // without anything looking switched off.
        let side = diameter * 0.40
        let mark = SKSpriteNode(texture: glyph,
                                size: CGSize(width: side, height: side))

        // The glyphs are drawn white in Glyphs.swift. Tinted rather than redrawn,
        // because a glyph that knows its own colour is a glyph that cannot be
        // reused - and these sit on three different fills.
        mark.color = RenderPalette.menuInk
        mark.colorBlendFactor = 1
        content.addChild(mark)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The play mark, drawn rather than typed. A triangle with rounded corners and
    /// its optical centre nudged right: a triangle centred on its bounding box
    /// reads as sitting left of where it is, because most of its area is.
    private static func play(side: CGFloat, colour: SKColor) -> SKShapeNode {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -side * 0.34, y: side * 0.5))
        path.addLine(to: CGPoint(x: side * 0.50, y: 0))
        path.addLine(to: CGPoint(x: -side * 0.34, y: -side * 0.5))
        path.close()

        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = colour
        node.strokeColor = colour
        node.lineWidth = side * 0.16
        node.lineJoin = .round
        return node
    }

    // MARK: - Idle

    /// A slow breath on the primary, and nothing on the secondaries.
    ///
    /// On a screen with three controls, the one that MOVES is the one you press.
    /// Breathing all three would say they are equally important, which is the one
    /// thing this layout exists to deny.
    ///
    /// Started by the scene rather than in init, so the phase can be offset from
    /// whatever else is moving - two things pulsing in step read as one mechanism.
    func breathe(after delay: TimeInterval) {
        guard weight == .primary else { return }

        let breath = SKAction.sequence([.scale(to: 1.028, duration: 1.3),
                                        .scale(to: 1.0, duration: 1.3)])
        breath.timingMode = .easeInEaseOut
        run(.sequence([.wait(forDuration: delay), .repeatForever(breath)]),
            withKey: "breathe")
    }

    // MARK: - Pressing

    func contains(localPoint point: CGPoint) -> Bool {
        let slop = MenuButtonNode.slop
        switch weight {
        case .primary:
            return abs(point.x) <= box.width / 2 + slop
                && abs(point.y) <= box.height / 2 + slop
        case .secondary:
            return hypot(point.x, point.y) <= box.width / 2 + slop
        }
    }

    /// Down hard, up past its own size, settle.
    ///
    /// It overshoots because a button that returns exactly to where it started
    /// reads as having been let go of rather than as having sprung back - the same
    /// shape the figures use when something happens to them.
    ///
    /// Takes a completion rather than the caller running the press and acting on
    /// the next line, which is the bug the old menu records: presenting a scene on
    /// the same frame plays the animation on a node already being torn down, and
    /// the screen simply changes. Two tenths of a second is nothing to wait and is
    /// the difference between a button and a hotspot.
    func press(then done: @escaping () -> Void) {
        removeAction(forKey: "breathe")
        removeAllActions()

        let press = SKAction.sequence([
            .scale(to: 0.92, duration: 0.05),
            .scale(to: 1.05, duration: 0.09),
            .scale(to: 1.0, duration: 0.07)
        ])
        press.timingMode = .easeOut

        run(.sequence([press, .run(done)]))
    }

    /// Type, which SKLabelNode can only track through an attributed string.
    ///
    /// THE SYSTEM FONT, which is the change from every version of this screen
    /// before it. It was AvenirNext, set heavy and tracked wide. Avenir is a
    /// perfectly good typeface and it is not the device's - so a menu set in it
    /// reads as a menu that has chosen a font, which is the opposite of what
    /// "modern" looks like on a phone. The system face is what every other app the
    /// player opens is set in, it carries real weights rather than two, and it is
    /// the one typeface guaranteed to be there.
    static func text(_ string: String,
                     size: CGFloat,
                     weight: UIFont.Weight,
                     kern: CGFloat,
                     colour: SKColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour,
            .kern: kern
        ])
    }
}
