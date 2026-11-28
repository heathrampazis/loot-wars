//
//  MenuButtonNode.swift
//  Loot Wars
//
//  The menu's buttons, drawn to Heath's mock-up: a chunky rounded slab of flat
//  colour, edged in a darker shade of itself, sitting on a soft shadow - and an
//  icon, no words.
//
//  THE EDGE IS A DARKER SHADE OF THE FILL, not a black outline. A black line round
//  a sprite on grass separates it from a background it has to survive; round a
//  button it is a colour the button does not otherwise contain, and reads as an
//  object that was outlined rather than one that was moulded. The edge sits INSIDE
//  the shape, so the button's outer size is exactly the size it was laid out at.
//
//  The shadow replaces the old lip. The lip was a hard darker copy of the shape
//  underneath, which the mock-up does not have: there the buttons float a little
//  above the map on a soft blur. A press pushes the face down towards its shadow
//  and the shadow tightens, which is the same "somewhere to go" the lip gave a
//  finger, in the new look.
//
//  PRIMARY is the wide slab with a play mark, SECONDARY a rounded square with a
//  glyph. One type rather than two, because the difference between them is
//  entirely proportion and contents - and two classes sharing a press animation is
//  how a press animation ends up with two slightly different timings.
//
//  Not ActionButtonNode, which is the in-game control: that one knows about grab
//  radii wider than itself because it is pressed by a thumb that is also steering.
//  A menu button is pressed by somebody looking at it.
//

import SpriteKit
import UIKit
import CoreImage

final class MenuButtonNode: SKNode {

    enum Weight {
        case primary
        case secondary
    }

    /// The tap target, in this node's own space.
    ///
    /// NOT called `size` - see the note on SKScene's `listener` in the project
    /// notes. A name of one's own costs nothing.
    private(set) var box: CGSize

    private let weight: Weight

    /// The part that moves: the slab and its icon, as one.
    private let face = SKNode()

    /// The drop shadow under it, which stays put while the face moves: a wide soft
    /// one for depth and a tight dark one where the button meets the ground.
    private let shadow: SKNode

    /// How far the face sinks when pressed.
    private let sink: CGFloat

    /// The slab's corner radius, for the shine's mask.
    private var corner: CGFloat = 0

    /// Held down by a finger right now - see pressDown.
    private(set) var isHeld = false

    /// Accessibility takes a touch that starts near a button and is heading for it.
    private static let slop: CGFloat = 12

    // MARK: - Proportions, measured off the mock-up

    /// Edge thickness and corner radius as shares of the button's HEIGHT. The wide
    /// one has a thinner edge relative to itself than the squares do, because at
    /// the same absolute weight both edges read as the same line.
    private static let primaryEdge: CGFloat = 0.057
    private static let primaryCorner: CGFloat = 0.17
    private static let secondaryEdge: CGFloat = 0.093
    private static let secondaryCorner: CGFloat = 0.22

    // MARK: - Building

    /// The wide one, with a play mark.
    init(play width: CGFloat, height: CGFloat, tone: RenderPalette.MenuTone) {
        self.weight = .primary
        self.box = CGSize(width: width, height: height)
        self.sink = ButtonArt.depth(for: height)
        self.shadow = MenuButtonNode.dropShadow(width: width, height: height,
                                                corner: height * MenuButtonNode.primaryCorner)
        super.init()

        corner = height * MenuButtonNode.primaryCorner
        raise(size: box, edge: height * MenuButtonNode.primaryEdge, tone: tone)

        let under = MenuButtonNode.play(side: height * 0.36)
        under.fillColor = tone.edge
        under.strokeColor = tone.edge
        under.position = CGPoint(x: 0, y: -MenuButtonNode.markDrop(height))
        under.zPosition = 0.1
        face.addChild(under)
        let mark = MenuButtonNode.play(side: height * 0.36)
        mark.zPosition = 0.2
        face.addChild(mark)
    }

    /// A small square one, with a glyph.
    init(glyph: SKTexture, side: CGFloat, tone: RenderPalette.MenuTone) {
        self.weight = .secondary
        self.box = CGSize(width: side, height: side)
        self.sink = ButtonArt.depth(for: side)
        self.shadow = MenuButtonNode.dropShadow(width: side, height: side,
                                                corner: side * MenuButtonNode.secondaryCorner)
        super.init()

        corner = side * MenuButtonNode.secondaryCorner
        raise(size: box, edge: side * MenuButtonNode.secondaryEdge, tone: tone)

        let iconSide = side * 0.46
        let under = SKSpriteNode(texture: glyph, size: CGSize(width: iconSide, height: iconSide))
        under.color = tone.edge
        under.colorBlendFactor = 1
        under.position = CGPoint(x: 0, y: -MenuButtonNode.markDrop(side))
        under.zPosition = 0.1
        face.addChild(under)

        let mark = SKSpriteNode(texture: glyph, size: CGSize(width: iconSide, height: iconSide))

        // The glyphs are drawn white in Glyphs.swift. Tinted white anyway, so a
        // change of texture cannot quietly change the colour.
        mark.color = .white
        mark.colorBlendFactor = 1
        mark.zPosition = 0.2
        face.addChild(mark)
    }

    /// A wide one with a word on it, for a choice that has to be read - the
    /// pause menu's Resume and Quit match.
    init(label: String, width: CGFloat, height: CGFloat, tone: RenderPalette.MenuTone) {
        self.weight = .primary
        self.box = CGSize(width: width, height: height)
        self.sink = ButtonArt.depth(for: height)
        self.shadow = MenuButtonNode.dropShadow(width: width, height: height,
                                                corner: height * MenuButtonNode.primaryCorner)
        super.init()

        corner = height * MenuButtonNode.primaryCorner
        raise(size: box, edge: max(3, height * MenuButtonNode.primaryEdge), tone: tone)

        let size = (height * 0.36).rounded()
        let under = SKLabelNode()
        under.attributedText = MenuButtonNode.text(label, size: size, weight: .heavy, colour: tone.edge)
        under.verticalAlignmentMode = .center
        under.horizontalAlignmentMode = .center
        under.position = CGPoint(x: 0, y: -MenuButtonNode.markDrop(height))
        under.zPosition = 0.9
        face.addChild(under)

        let word = SKLabelNode()
        word.attributedText = MenuButtonNode.text(label, size: size, weight: .heavy, colour: .white)
        word.verticalAlignmentMode = .center
        word.horizontalAlignmentMode = .center
        word.zPosition = 1
        face.addChild(word)
    }

    /// The raised look (Nov 2026) - see ButtonArt. The face (and everything
    /// on it) moves; the lip and the shadow under it stay put, so pressing
    /// pushes the face down onto its lip.
    private func raise(size: CGSize, edge: CGFloat, tone: RenderPalette.MenuTone) {
        let parts = ButtonArt.parts(size: size, corner: corner, tone: tone, edge: edge)
        shadow.position = CGPoint(x: 0, y: -parts.depth)
        addChild(shadow)
        addChild(parts.lip)
        addChild(face)
        face.addChild(parts.face)
    }

    /// How far below an icon or word its darker copy sits - a little depth.
    private static func markDrop(_ height: CGFloat) -> CGFloat {
        max(1.5, (height * 0.035).rounded())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The button itself: flat fill, edged inside in a darker shade.
    ///
    /// SKShapeNode strokes straddle the path, so the path is inset by half the
    /// edge - the outside of the edge then lands exactly on the laid-out size.
    static func slab(width: CGFloat,
                             height: CGFloat,
                             edge: CGFloat,
                             corner: CGFloat,
                             tone: RenderPalette.MenuTone) -> SKShapeNode {
        let inset = edge / 2
        let rect = CGRect(x: -width / 2 + inset, y: -height / 2 + inset,
                          width: width - edge, height: height - edge)

        let node = SKShapeNode(rect: rect, cornerRadius: max(0, corner - inset))
        node.fillColor = tone.face
        node.strokeColor = tone.edge
        node.lineWidth = edge
        return node
    }

    /// The drop shadow: two blurred copies of the button's shape, below it.
    ///
    /// Two layers because that is what makes a shadow look like a shadow rather
    /// than a smudge. The wide soft one says the button is lifted off the map; the
    /// tight dark one, barely offset, is where it would touch the ground, and gives
    /// the edge underneath a crisp base to sit on.
    ///
    /// Drawn once into textures and blurred there, rather than an SKEffectNode
    /// blurring live - it never changes, so there is nothing to recompute, and an
    /// effect node crops its blur to its children's bounds, which cuts the soft
    /// edge off exactly where it should be fading out.
    static func dropShadow(width: CGFloat, height: CGFloat, corner: CGFloat) -> SKNode {
        let node = SKNode()
        node.zPosition = -1

        // Soft: well below the button, blurred wide.
        let soft = shadowLayer(width: width, height: height, corner: corner,
                               blur: max(5, height * 0.10))
        soft.alpha = 0.34
        soft.position = CGPoint(x: 0, y: -max(4, height * 0.08))
        node.addChild(soft)

        // Contact: just under the bottom edge, barely blurred.
        let contact = shadowLayer(width: width * 0.97, height: height, corner: corner,
                                  blur: max(2, height * 0.025))
        contact.alpha = 0.30
        contact.position = CGPoint(x: 0, y: -max(2, height * 0.035))
        node.addChild(contact)

        return node
    }

    /// One blurred, black, button-shaped layer.
    private static func shadowLayer(width: CGFloat, height: CGFloat,
                                    corner: CGFloat, blur: CGFloat) -> SKSpriteNode {
        let pad = blur * 3
        let canvas = CGSize(width: width + pad * 2, height: height + pad * 2)

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        format.scale = 2

        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            SKColor.black.setFill()
            UIBezierPath(roundedRect: CGRect(x: pad, y: pad, width: width, height: height),
                         cornerRadius: corner).fill()
        }

        // Blurred through Core Image directly, into a fresh image the same size as
        // the canvas. The padding is transparent, so clamping the edges costs
        // nothing and keeps the blur from fading in from the border.
        var texture = SKTexture(image: image)
        if let source = image.cgImage {
            let input = CIImage(cgImage: source)
            let blurred = input.clampedToExtent()
                .applyingGaussianBlur(sigma: Double(blur * format.scale) / 2)
                .cropped(to: input.extent)
            if let output = shadowContext.createCGImage(blurred, from: input.extent) {
                texture = SKTexture(cgImage: output)
            }
        }

        return SKSpriteNode(texture: texture, size: canvas)
    }

    /// One Core Image context for every shadow on the screen - they are
    /// expensive to make and there is no reason to make more than one.
    private static let shadowContext = CIContext()

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

    /// The primary's idle (Nov 2026 polish pass): still, with a gleam running
    /// across it every few seconds. It used to bob up and down forever, and a
    /// screen where something is always gently moving is one of the things that
    /// makes UI feel generated rather than made. A shine says "press me" the way
    /// a real game's main button does, and is still the rest of the time.
    /// Secondaries keep still.
    func breathe(after delay: TimeInterval) {
        guard weight == .primary else { return }
        let mask = SKShapeNode(rect: CGRect(x: -box.width / 2, y: -box.height / 2,
                                            width: box.width, height: box.height),
                               cornerRadius: corner)
        mask.fillColor = .white
        mask.strokeColor = .clear
        Motion.shine(on: face, mask: mask, size: box, every: 3.2, after: delay + 0.4, strength: 0.32)
    }

    // MARK: - Pressing

    func contains(localPoint point: CGPoint) -> Bool {
        let slop = MenuButtonNode.slop
        return abs(point.x) <= box.width / 2 + slop
            && abs(point.y) <= box.height / 2 + slop
    }

    /// Whether a finger that went down on this button is still near enough to
    /// count when it lets go - more forgiving than the press itself, so a thumb
    /// that rolls a little does not lose the tap.
    func stillOver(localPoint point: CGPoint) -> Bool {
        let slop = MenuButtonNode.slop * 2.5
        return abs(point.x) <= box.width / 2 + slop
            && abs(point.y) <= box.height / 2 + slop
    }

    /// Finger down: the face sinks onto its shadow, squashed, and STAYS there
    /// until the finger lifts (Nov 2026). Real buttons do something when you
    /// let go, not when you touch - and a button that is visibly held down is
    /// most of what makes it feel physical.
    func pressDown() {
        isHeld = true
        face.removeAction(forKey: "press")
        shadow.removeAllActions()
        face.run(.group([
            Motion.eased(.moveTo(y: -sink, duration: Motion.Time.tap), Motion.cubicOut),
            Motion.eased(.scaleX(to: 1.03, y: 0.93, duration: Motion.Time.tap), Motion.cubicOut)
        ]), withKey: "press")
        shadow.run(Motion.eased(.scale(to: 0.93, duration: Motion.Time.tap), Motion.cubicOut))
    }

    /// Finger up on the button: springs back past where it rests and settles,
    /// and `done` runs a beat in, while it is still springing.
    func release(then done: @escaping () -> Void) {
        springBack()
        run(.sequence([.wait(forDuration: 0.1), .run(done)]), withKey: "release")
    }

    /// The finger slid off before letting go: back up, nothing happens.
    func cancelPress() {
        guard isHeld else { return }
        springBack()
    }

    private func springBack() {
        isHeld = false
        face.removeAction(forKey: "press")
        face.run(.group([
            Motion.eased(.moveTo(y: 0, duration: 0.32)) { Motion.backOut($0, overshoot: 3) },
            Motion.eased(.scale(to: 1, duration: 0.32)) { Motion.backOut($0, overshoot: 3) }
        ]), withKey: "press")
        shadow.run(Motion.pop(to: 1, duration: 0.3))
    }

    /// Down and straight back up, for a button pressed in one go (the results
    /// and pause screens, which act on the touch).
    func press(then done: @escaping () -> Void) {
        pressDown()
        run(.sequence([.wait(forDuration: Motion.Time.tap + 0.02),
                       .run { [weak self] in self?.release(then: done) }]), withKey: "tap")
    }

    /// Type, which SKLabelNode can only style through an attributed string.
    ///
    /// Still used by the sheet and the record line under the buttons; the buttons
    /// themselves no longer carry words.
    static func text(_ string: String,
                     size: CGFloat,
                     weight: UIFont.Weight,
                     colour: SKColor) -> NSAttributedString {
        NSAttributedString(string: string, attributes: [
            .font: GameFont.of(size: size, weight: weight),
            .foregroundColor: colour
        ])
    }
}
