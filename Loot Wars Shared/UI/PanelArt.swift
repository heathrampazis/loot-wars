//
//  PanelArt.swift
//  Loot Wars
//
//  The look shared by every card that comes up over the game (Nov 2026
//  polish pass): the menu sheets, the pause menu and the results.
//
//  They were three plain white rounded rectangles with a thin grey line -
//  the default look of an app rather than of a game. Now they are made the
//  same way the menu buttons are: a solid face on a soft drop shadow, a thick
//  edge in a darker shade of the face rather than an outline, and a coloured
//  header band with the title on it, so each card says what it is from across
//  the room. Bars and plates inside use the same edge-and-face idea.
//

import SpriteKit
import UIKit

enum PanelArt {

    /// The card's face, and its edge: a cool off-white and a darker shade of it.
    static let face = SKColor(red: 0xFB / 255.0, green: 0xFB / 255.0, blue: 0xFC / 255.0, alpha: 1)
    /// Dark on the outside (Nov 2026): Heath, "dark on the outside border,
    /// light grey on the inside".
    /// Softened (Nov 2026): "it needs to be more soft". Still darker than the
    /// inside, but a mid slate rather than near-black.
    static let edge = SKColor(red: 0x8C / 255.0, green: 0x94 / 255.0, blue: 0xA3 / 255.0, alpha: 1)
    static let edgeWidth: CGFloat = 3

    /// Plates inside a card (stat tiles, bar tracks).
    static let plateFace = SKColor(red: 0.93, green: 0.945, blue: 0.97, alpha: 1)
    static let plateEdge = SKColor(red: 0.85, green: 0.875, blue: 0.92, alpha: 1)

    /// The header band's colour: a slate grey (Nov 2026). Heath: the blue and
    /// purple headers were wrong, "it should all be grey".
    /// Then light grey, with the dark border round the outside.
    static let band = RenderPalette.MenuTone(
        face: SKColor(red: 0xEE / 255.0, green: 0xF0 / 255.0, blue: 0xF4 / 255.0, alpha: 1),
        edge: SKColor(red: 0xE0 / 255.0, green: 0xE3 / 255.0, blue: 0xE9 / 255.0, alpha: 1))

    /// Titles on the band: dark ink, set clean (the white line under them was
    /// part of what looked off, and went).
    static let title = SKColor(red: 0x4A / 255.0, green: 0x51 / 255.0, blue: 0x5E / 255.0, alpha: 1)
    static let titleUnder = SKColor(white: 1, alpha: 0.85)

    private static let dressName = "panel.dress"

    /// Dresses a card shape (whose path is a rounded rect of `size` centred on
    /// its origin): shadow under it, then the card itself - border, face and an
    /// optional header band of `band` height in `tone` - drawn as ONE picture.
    /// Safe to call again after a resize; the old dressing is taken off first.
    ///
    /// One picture rather than stacked shapes (Nov 2026): Heath said the
    /// banners "need to look smooth, something about them is completely off".
    /// Layered SKShapeNodes - a band, a seam, a stroked rim - never quite line
    /// up at the corners, and each edge is antialiased on its own, so the joins
    /// looked rough. Drawn together in Core Graphics, with the band clipped to
    /// the inside of the border, every edge is clean.
    ///
    /// Give the card a zPosition above whatever is behind it (the scrim): the
    /// shadow sits just under the card.
    static func dress(_ card: SKShapeNode, size: CGSize, corner: CGFloat,
                      band: CGFloat? = nil, tone: RenderPalette.MenuTone = PanelArt.band) {
        for old in card.children where old.name == dressName { old.removeFromParent() }

        card.fillColor = .clear
        card.strokeColor = .clear
        card.lineWidth = 0

        let shadow = MenuButtonNode.dropShadow(width: size.width, height: size.height, corner: corner)
        shadow.name = dressName
        shadow.zPosition = -1
        card.addChild(shadow)

        let picture = SKSpriteNode(texture: SKTexture(image: image(size: size, corner: corner,
                                                                  band: band, tone: tone)),
                                   size: size)
        picture.name = dressName
        picture.zPosition = 0.1
        card.addChild(picture)
    }

    /// The card as a picture: dark border, light face, and the band across the
    /// top clipped to the inside of the border.
    private static func image(size: CGSize, corner: CGFloat, band: CGFloat?,
                              tone: RenderPalette.MenuTone) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            edge.setFill()
            UIBezierPath(roundedRect: bounds, cornerRadius: corner).fill()

            let inside = bounds.insetBy(dx: edgeWidth, dy: edgeWidth)
            let face = UIBezierPath(roundedRect: inside, cornerRadius: max(0, corner - edgeWidth))
            PanelArt.face.setFill()
            face.fill()

            guard let band else { return }
            context.cgContext.saveGState()
            face.addClip()
            tone.face.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: size.width, height: band))
            tone.edge.setFill()
            UIRectFill(CGRect(x: 0, y: band - 1, width: size.width, height: 1.5))
            context.cgContext.restoreGState()
        }
    }

    /// A rectangle whose top two corners are rounded, hanging down from `top`.
    static func topRounded(width: CGFloat, top: CGFloat, height: CGFloat, corner: CGFloat) -> CGPath {
        let left = -width / 2, right = width / 2, bottom = top - height
        let r = min(corner, height, width / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: bottom))
        path.addLine(to: CGPoint(x: left, y: top - r))
        path.addArc(tangent1End: CGPoint(x: left, y: top), tangent2End: CGPoint(x: left + r, y: top), radius: r)
        path.addLine(to: CGPoint(x: right - r, y: top))
        path.addArc(tangent1End: CGPoint(x: right, y: top), tangent2End: CGPoint(x: right, y: top - r), radius: r)
        path.addLine(to: CGPoint(x: right, y: bottom))
        path.closeSubpath()
        return path
    }

    /// A small plate: face and edge, the stat tiles' look.
    static func plate(size: CGSize, corner: CGFloat) -> SKShapeNode {
        let node = SKShapeNode(rect: CGRect(x: -size.width / 2 + 1, y: -size.height / 2 + 1,
                                            width: size.width - 2, height: size.height - 2),
                               cornerRadius: corner)
        node.fillColor = plateFace
        node.strokeColor = plateEdge
        node.lineWidth = 2
        return node
    }

    /// The round close button: a red chunky disc with a white cross.
    static func closeButton(radius: CGFloat) -> SKNode {
        let node = SKNode()
        let tone = RenderPalette.menuDanger

        let under = SKShapeNode(circleOfRadius: radius)
        under.fillColor = SKColor(white: 0, alpha: 0.22)
        under.strokeColor = .clear
        under.position = CGPoint(x: 0, y: -2)
        node.addChild(under)

        let disc = SKShapeNode(circleOfRadius: radius - 1.5)
        disc.fillColor = tone.face
        disc.strokeColor = tone.edge
        disc.lineWidth = 3
        disc.zPosition = 0.1
        node.addChild(disc)

        let arm = radius * 0.42
        for angle in [CGFloat.pi / 4, -CGFloat.pi / 4] {
            let bar = SKShapeNode(rect: CGRect(x: -arm, y: -1.8, width: arm * 2, height: 3.6),
                                  cornerRadius: 1.8)
            bar.fillColor = .white
            bar.strokeColor = .clear
            bar.zRotation = angle
            bar.zPosition = 0.2
            node.addChild(bar)
        }
        return node
    }

    /// Words with a hard drop under them in a darker shade - how titles are set
    /// on a coloured band. Returns the drop label; put it just under `label`.
    static func drop(for label: SKLabelNode, text: NSAttributedString, shade: SKColor,
                     offset: CGFloat = 2) -> SKLabelNode {
        let shadow = SKLabelNode()
        let copy = NSMutableAttributedString(attributedString: text)
        copy.addAttribute(.foregroundColor, value: shade, range: NSRange(location: 0, length: copy.length))
        shadow.attributedText = copy
        shadow.verticalAlignmentMode = label.verticalAlignmentMode
        shadow.horizontalAlignmentMode = label.horizontalAlignmentMode
        shadow.position = CGPoint(x: label.position.x, y: label.position.y - offset)
        shadow.zPosition = label.zPosition - 0.1
        return shadow
    }
}
