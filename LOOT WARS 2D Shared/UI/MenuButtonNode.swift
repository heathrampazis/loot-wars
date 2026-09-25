//
//  MenuButtonNode.swift
//  Loot Wars
//
//  The menu's buttons, built the way the game draws everything else: flat colour,
//  a heavy black outline, and a darker lip underneath that the button presses down
//  onto.
//
//  THE OUTLINE IS THE WHOLE THING. Two revisions of this screen had buttons that
//  were perfectly tidy and looked like they came from somewhere else - a white pill
//  with dark type, then three tasteful mid-tones. What was wrong with both is that
//  the entire map is drawn as flat colour inside a thick black line: every figure,
//  every crate, every chest, every health bar. A button without one is the only
//  object on the screen that is not part of the game.
//
//  The lip is the second half of it, and it is what makes a press feel like
//  something. A button drawn as one flat shape can only answer a finger by changing
//  size, which is a thing shapes do and not a thing buttons do. A shape standing on
//  a darker shape of itself has somewhere to GO: it drops onto its own shadow and
//  comes back up. That is the oldest trick in game UI and it is still the best one.
//
//  PRIMARY is the wide pill, SECONDARY a small circle with a glyph. One type rather
//  than two, because the difference between them is entirely fill, size and
//  contents - and two classes sharing a press animation is how a press animation
//  ends up with two slightly different timings that nobody meant.
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
        case primary
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

    /// The part that moves. Everything the player reads is on here, so the whole
    /// face drops as one rather than the fill moving out from under its own label.
    private let face = SKNode()

    /// How far the face falls when pressed, which is exactly the lip's depth - so
    /// a pressed button sits flush on its own shadow rather than somewhere near it.
    private let lipDepth: CGFloat

    /// Accessibility takes a touch that starts near a small button and is heading
    /// for it. Generous on the secondaries because they are barely fifty points
    /// across, which is Apple's floor rather than a comfortable target.
    private static let slop: CGFloat = 12

    // MARK: - Building

    /// The wide one: a play triangle, a gap, and a word.
    init(primary title: String, width: CGFloat, height: CGFloat,
         tone: RenderPalette.MenuTone) {
        self.weight = .primary
        self.box = CGSize(width: width, height: height)
        self.lipDepth = max(4, height * 0.11)
        super.init()

        let radius = height / 2
        let shape = CGRect(x: -width / 2, y: -height / 2, width: width, height: height)

        let outline = max(2.5, height * 0.055)

        addChild(MenuButtonNode.lip(shape, radius: radius, tone: tone,
                                    drop: lipDepth, outline: outline))
        addChild(face)

        let body = SKShapeNode(rect: shape, cornerRadius: radius)
        body.fillColor = tone.face
        body.strokeColor = RenderPalette.menuOutline
        body.lineWidth = outline
        face.addChild(body)

        // The triangle and the word are laid out as one row and centred together,
        // rather than the word centred with a triangle hung off it. A pill with
        // centred text and a mark to the left of it looks off-centre, because it is.
        let glyphSide = height * 0.30
        let gap = height * 0.22

        let label = SKLabelNode()
        label.attributedText = MenuButtonNode.text(title, size: height * 0.34,
                                                   weight: .bold, colour: .white)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .left

        let row = glyphSide + gap + label.frame.width
        let triangle = MenuButtonNode.play(side: glyphSide)

        triangle.position = CGPoint(x: -row / 2 + glyphSide / 2, y: 0)
        label.position = CGPoint(x: -row / 2 + glyphSide + gap, y: 0)

        face.addChild(triangle)
        face.addChild(label)
    }

    /// A small one: a circle and a glyph.
    init(secondary glyph: SKTexture, diameter: CGFloat,
         tone: RenderPalette.MenuTone) {
        self.weight = .secondary
        self.box = CGSize(width: diameter, height: diameter)
        self.lipDepth = max(3.5, diameter * 0.11)
        super.init()

        let radius = diameter / 2
        let shape = CGRect(x: -radius, y: -radius, width: diameter, height: diameter)

        let outline = max(2.5, diameter * 0.06)

        addChild(MenuButtonNode.lip(shape, radius: radius, tone: tone,
                                    drop: lipDepth, outline: outline))
        addChild(face)

        let body = SKShapeNode(circleOfRadius: radius)
        body.fillColor = tone.face
        body.strokeColor = RenderPalette.menuOutline
        body.lineWidth = outline
        face.addChild(body)

        // Hierarchy is carried by SIZE, not by fill. These were hollow outlines for
        // one revision, on the argument that only the thing you came to press
        // should be solid; what that actually reads as is two disabled controls.
        // Three solid buttons where one is three times the others says the same
        // thing without anything looking switched off.
        let side = diameter * 0.42
        let mark = SKSpriteNode(texture: glyph,
                                size: CGSize(width: side, height: side))

        // The glyphs are drawn white in Glyphs.swift and used white here, so the
        // tint is a no-op today. It is set anyway rather than left to chance: a
        // sprite carrying somebody else's texture and no opinion about its own
        // colour is a sprite that changes when the texture does.
        mark.color = .white
        mark.colorBlendFactor = 1
        face.addChild(mark)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The shadow the face stands on: the same shape, the same outline, a darker
    /// fill, sitting lower. Drawn once and never moved - the FACE is what moves,
    /// and a lip that moved with it would be a button with no depth that happened
    /// to be two shapes.
    private static func lip(_ shape: CGRect,
                            radius: CGFloat,
                            tone: RenderPalette.MenuTone,
                            drop: CGFloat,
                            outline: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rect: shape, cornerRadius: radius)
        node.fillColor = tone.lip
        node.strokeColor = RenderPalette.menuOutline

        // The SAME weight as the face, handed in rather than recomputed. A lip
        // drawn with a thinner line than the shape standing on it reads as two
        // objects that do not quite belong together, which is the one thing a
        // shadow must never look like.
        node.lineWidth = outline
        node.position = CGPoint(x: 0, y: -drop)
        node.zPosition = -1
        return node
    }

    /// The play mark, drawn rather than typed. A triangle with rounded corners and
    /// its optical centre nudged right: a triangle centred on its bounding box
    /// reads as sitting left of where it is, because most of its area is.
    private static func play(side: CGFloat) -> SKShapeNode {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: -side * 0.34, y: side * 0.5))
        path.addLine(to: CGPoint(x: side * 0.50, y: 0))
        path.addLine(to: CGPoint(x: -side * 0.34, y: -side * 0.5))
        path.close()

        let node = SKShapeNode(path: path.cgPath)
        node.fillColor = .white
        node.strokeColor = .white
        node.lineWidth = side * 0.16
        node.lineJoin = .round
        return node
    }

    // MARK: - Idle

    /// A slow bob on the primary, and nothing on the secondaries.
    ///
    /// It RISES off its lip rather than growing, which is the difference between
    /// playful and merely animated: a button that swells reads as a thing being
    /// zoomed; one that lifts and settles reads as a thing that weighs something.
    /// The lip stays put, so the shadow under it opens and closes as it moves.
    ///
    /// On a screen with three controls, the one that moves is the one you press.
    /// Bobbing all three would say they are equally important, which is the one
    /// thing this layout exists to deny.
    func breathe(after delay: TimeInterval) {
        guard weight == .primary else { return }

        let rise = SKAction.sequence([
            .moveTo(y: lipDepth * 0.42, duration: 1.15),
            .moveTo(y: 0, duration: 1.15)
        ])
        rise.timingMode = .easeInEaseOut

        face.run(.sequence([.wait(forDuration: delay), .repeatForever(rise)]),
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

    /// Down onto the lip, then back up past where it started, then settle.
    ///
    /// Position rather than scale, which is the change that made this feel like a
    /// button. A scale press is a shape acknowledging a touch; this is a thing
    /// being pushed in and springing out, and the lip going out of sight underneath
    /// it is what sells the push.
    ///
    /// It overshoots because a button that returns exactly to where it started
    /// reads as having been let go of rather than as having sprung back.
    ///
    /// Takes a completion rather than the caller running the press and acting on
    /// the next line, which is the bug the old menu records: presenting a scene on
    /// the same frame plays the animation on a node already being torn down, and
    /// the screen simply changes. Two tenths of a second is nothing to wait and is
    /// the difference between a button and a hotspot.
    func press(then done: @escaping () -> Void) {
        face.removeAction(forKey: "breathe")
        face.removeAllActions()

        let push = SKAction.sequence([
            .moveTo(y: -lipDepth, duration: 0.05),
            .moveTo(y: lipDepth * 0.35, duration: 0.10),
            .moveTo(y: 0, duration: 0.08)
        ])
        push.timingMode = .easeOut

        face.run(.sequence([push, .run(done)]))
    }

    /// Type, which SKLabelNode can only style through an attributed string.
    ///
    /// THE SYSTEM FONT, plain. It was AvenirNext tracked wide, then the system face
    /// at Black weight with tracking on top. Both were a font doing work the layout
    /// should be doing: on a screen this simple the type has one job, which is to
    /// be read instantly and get out of the way. Bold, no tracking, nothing else.
    static func text(_ string: String,
                     size: CGFloat,
                     weight: UIFont.Weight,
                     colour: SKColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour
        ])
    }
}
