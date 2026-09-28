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
        self.sink = max(3, height * 0.04)
        self.shadow = MenuButtonNode.dropShadow(width: width, height: height,
                                                corner: height * MenuButtonNode.primaryCorner)
        super.init()

        addChild(shadow)
        addChild(face)

        face.addChild(MenuButtonNode.slab(width: width, height: height,
                                          edge: height * MenuButtonNode.primaryEdge,
                                          corner: height * MenuButtonNode.primaryCorner,
                                          tone: tone))

        let mark = MenuButtonNode.play(side: height * 0.36)
        face.addChild(mark)
    }

    /// A small square one, with a glyph.
    init(glyph: SKTexture, side: CGFloat, tone: RenderPalette.MenuTone) {
        self.weight = .secondary
        self.box = CGSize(width: side, height: side)
        self.sink = max(2.5, side * 0.05)
        self.shadow = MenuButtonNode.dropShadow(width: side, height: side,
                                                corner: side * MenuButtonNode.secondaryCorner)
        super.init()

        addChild(shadow)
        addChild(face)

        face.addChild(MenuButtonNode.slab(width: side, height: side,
                                          edge: side * MenuButtonNode.secondaryEdge,
                                          corner: side * MenuButtonNode.secondaryCorner,
                                          tone: tone))

        let iconSide = side * 0.46
        let mark = SKSpriteNode(texture: glyph, size: CGSize(width: iconSide, height: iconSide))

        // The glyphs are drawn white in Glyphs.swift. Tinted white anyway, so a
        // change of texture cannot quietly change the colour.
        mark.color = .white
        mark.colorBlendFactor = 1
        face.addChild(mark)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The button itself: flat fill, edged inside in a darker shade.
    ///
    /// SKShapeNode strokes straddle the path, so the path is inset by half the
    /// edge - the outside of the edge then lands exactly on the laid-out size.
    private static func slab(width: CGFloat,
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
    private static func dropShadow(width: CGFloat, height: CGFloat, corner: CGFloat) -> SKNode {
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

    /// A slow bob on the primary, and nothing on the secondaries.
    ///
    /// It RISES off its shadow rather than growing: a button that swells reads as
    /// a thing being zoomed; one that lifts and settles reads as a thing that
    /// weighs something. On a screen with three controls, the one that moves is
    /// the one you press.
    func breathe(after delay: TimeInterval) {
        guard weight == .primary else { return }

        let rise = SKAction.sequence([
            .moveTo(y: sink * 0.8, duration: 1.15),
            .moveTo(y: 0, duration: 1.15)
        ])
        rise.timingMode = .easeInEaseOut

        face.run(.sequence([.wait(forDuration: delay), .repeatForever(rise)]),
                 withKey: "breathe")
    }

    // MARK: - Pressing

    func contains(localPoint point: CGPoint) -> Bool {
        let slop = MenuButtonNode.slop
        return abs(point.x) <= box.width / 2 + slop
            && abs(point.y) <= box.height / 2 + slop
    }

    /// Down towards its shadow with a squash, then back up past where it started,
    /// then settle. The shadow tightens as the face comes down to meet it.
    ///
    /// Takes a completion rather than the caller acting on the next line:
    /// presenting a scene on the same frame plays the animation on a node already
    /// being torn down, and the screen simply changes.
    func press(then done: @escaping () -> Void) {
        face.removeAllActions()
        shadow.removeAllActions()

        let push = SKAction.sequence([
            .group([.moveTo(y: -sink, duration: 0.05),
                    .scaleX(to: 1.03, y: 0.94, duration: 0.05)]),
            .group([.moveTo(y: sink * 0.5, duration: 0.10),
                    .scaleX(to: 0.98, y: 1.03, duration: 0.10)]),
            .group([.moveTo(y: 0, duration: 0.08),
                    .scale(to: 1, duration: 0.08)])
        ])
        push.timingMode = .easeOut

        // The shadow pulls in as the face comes down to meet it.
        shadow.run(.sequence([
            .scale(to: 0.93, duration: 0.05),
            .scale(to: 1, duration: 0.18)
        ]))

        face.run(.sequence([push, .run(done)]))
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
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: colour
        ])
    }
}
