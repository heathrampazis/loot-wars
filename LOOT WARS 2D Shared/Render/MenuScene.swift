//
//  MenuScene.swift
//  Loot Wars
//
//  The door into the game: the name, one button, and the grass.
//
//  It is a SCENE rather than a panel over a paused world, and that is the design
//  decision worth keeping. A menu drawn on top of the game means the world has to
//  exist first - forty crates, eight bots and a generated map built before anybody
//  has pressed anything, torn down and rebuilt the moment they do. As its own scene
//  it costs a background and three nodes, and the match is built when it is asked
//  for.
//
//  Two versions came before this one and both were wrong in opposite directions.
//  The first put the game's furniture on the screen - grass in giant checks, a
//  token, a crate and a bomb bobbing about - and looked like the game with the
//  level missing. The second went dark and typographic, which was clean and had
//  nothing to do with this game at all.
//
//  This one is the middle: the map's own green, flat and uninterrupted, black type
//  on it, and a single button with a play triangle in it. The green is what makes
//  it belong to Loot Wars; the emptiness is what makes it a menu. Nothing on the
//  screen is decoration - the name, the button, and the one fact worth knowing
//  before pressing it.
//

import SpriteKit
import UIKit

final class MenuScene: SKScene {

    private let play = SKNode()
    /// Sized off the mockup's proportions rather than off a phone: a slab about
    /// two and a bit times as wide as it is tall, big enough that it is the only
    /// thing anybody could be reaching for.
    private static let playSize = CGSize(width: 216, height: 96)
    private static let playCorner: CGFloat = 26

    class func newMenuScene() -> MenuScene {
        let scene = MenuScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = MenuScene.ground
        removeAllChildren()
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard scene != nil, !children.isEmpty else { return }
        removeAllChildren()
        build()
    }

    // MARK: - The one palette this screen has

    /// The map's own grass, flat. No checks, no texture, no gradient - a single
    /// field of the colour the whole game is played on.
    private static let ground = RenderPalette.floorLight

    /// The button: a deeper, bluer green than anything in a match wears.
    ///
    /// Deliberately NOT the shop's affordable green, which is the colour of "you
    /// can pay for this" and belongs to a price. This is the only button in the
    /// game that is not answering a question, so it gets a colour of its own - and
    /// a teal reads as a button against grass in a way another leaf-green does not.
    private static let button = SKColor(red: 0.23, green: 0.64, blue: 0.51, alpha: 1)
    private static let buttonEdge = SKColor(red: 0.16, green: 0.47, blue: 0.38, alpha: 1)

    // MARK: - Building

    private func build() {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)

        // Measured off the middle rather than off the edges, so the layout holds
        // its shape on every phone: a tall screen gets more air, not more gaps
        // between things that belong together.
        buildTitle(centredOn: CGPoint(x: middle.x, y: middle.y + 78))
        buildPlayButton(centredOn: CGPoint(x: middle.x, y: middle.y - 24))
        buildRecord(centredOn: CGPoint(x: middle.x, y: middle.y - 108))
    }

    /// The name: black, heavy, and sitting straight on the grass.
    ///
    /// Black rather than white, which is the one choice on this screen that took
    /// three goes. White on green is what the HUD does, and the HUD is a layer
    /// floating over the map - it needs to look like it is in front. A title is not
    /// in front of anything, and black on a light green reads as printed ON the
    /// field rather than hovering above it. It is also the colour every sprite in
    /// this game is outlined with, so the name belongs to the same set of pictures
    /// without borrowing the outline itself.
    ///
    /// Barely any tracking. The wide-set version was cleaner and quieter, and quiet
    /// is not what a title is for.
    private func buildTitle(centredOn centre: CGPoint) {
        let label = SKLabelNode()
        label.attributedText = MenuScene.text("LOOT WARS", size: 48, kern: 1,
                                              colour: SKColor(white: 0.04, alpha: 1))
        label.verticalAlignmentMode = .center
        label.position = centre
        addChild(label)
    }

    /// The only thing on the screen you can press.
    ///
    /// A slab rather than a pill, and a triangle rather than the word PLAY. Both
    /// for the same reason: this button has no neighbours and no alternatives, so
    /// it does not have to say which of several things it is. A shape that size
    /// with a play mark in it is already unambiguous in every app anybody has ever
    /// used, and a label would only be the screen explaining something nobody
    /// asked about.
    ///
    /// Three layers, drawn bottom up: a soft shadow on the grass, the darker edge
    /// it stands on, and the face. That is the same lip the shop's price buttons
    /// wear, at four times the size - a flat shape with a darker shade under it is
    /// how this game draws anything that can be pressed.
    private func buildPlayButton(centredOn centre: CGPoint) {
        let box = MenuScene.playSize
        play.position = centre
        addChild(play)

        func slab(offsetBy drop: CGFloat, colour: SKColor, inset: CGFloat = 0) -> SKShapeNode {
            let shape = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: -box.width / 2 + inset,
                                    y: -box.height / 2 - drop + inset,
                                    width: box.width - inset * 2,
                                    height: box.height - inset * 2),
                cornerWidth: MenuScene.playCorner, cornerHeight: MenuScene.playCorner,
                transform: nil))

            shape.fillColor = colour
            shape.strokeColor = .clear
            return shape
        }

        // Two faint slabs rather than one solid one: SpriteKit has no blur, and two
        // offsets at low alpha give the falloff a single hard shadow does not.
        play.addChild(slab(offsetBy: 14, colour: SKColor(white: 0, alpha: 0.07)))
        play.addChild(slab(offsetBy: 9, colour: SKColor(white: 0, alpha: 0.09)))

        play.addChild(slab(offsetBy: 0, colour: MenuScene.buttonEdge))
        play.addChild(slab(offsetBy: -5, colour: MenuScene.button, inset: 6))

        play.addChild(MenuScene.triangle())
    }

    /// The play mark: a triangle with rounded corners, nudged right of centre.
    ///
    /// The nudge is optical rather than arithmetic. A triangle centred by its
    /// bounding box looks left-heavy, because its mass is all down the flat edge -
    /// every play button ever drawn moves it a few points right, and the eye reads
    /// the result as centred.
    private static func triangle() -> SKShapeNode {
        let width: CGFloat = 30
        let height: CGFloat = 34

        let path = CGMutablePath()
        path.move(to: CGPoint(x: -width / 2, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
        path.closeSubpath()

        let mark = SKShapeNode(path: path)
        mark.fillColor = .white
        mark.strokeColor = .white
        mark.lineWidth = 6
        mark.lineJoin = .round
        mark.position = CGPoint(x: 3, y: -5)
        mark.zPosition = 1
        return mark
    }

    /// What the game remembers about you. Nothing at all, the first time.
    private func buildRecord(centredOn centre: CGPoint) {
        guard Prefs.matchesFinished > 0 else { return }

        let matches = Prefs.matchesFinished
        let played = "\(matches) MATCH\(matches == 1 ? "" : "ES")"

        let label = SKLabelNode()
        label.attributedText = MenuScene.text("BEST \(Prefs.bestScore)   ·   \(played)",
                                              size: 12, kern: 3,
                                              colour: SKColor(white: 0.04, alpha: 0.45))
        label.verticalAlignmentMode = .center
        label.position = centre
        addChild(label)
    }

    /// Tracked type, which SKLabelNode can only do through an attributed string.
    private static func text(_ string: String,
                             size: CGFloat,
                             kern: CGFloat,
                             colour: SKColor) -> NSAttributedString {
        let font = UIFont(name: "AvenirNext-Bold", size: size)
            ?? UIFont.boldSystemFont(ofSize: size)

        return NSAttributedString(string: string, attributes: [
            .font: font,
            .foregroundColor: colour,
            .kern: kern
        ])
    }

    // MARK: - Pressing it

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let view else { return }

        let box = MenuScene.playSize
        let point = touch.location(in: self)
        let local = CGPoint(x: point.x - play.position.x, y: point.y - play.position.y)

        // Generous, because it is the only thing on the screen to hit.
        guard abs(local.x) <= box.width / 2 + 24,
              abs(local.y) <= box.height / 2 + 24 else { return }

        play.removeAllActions()
        play.run(.sequence([
            .scale(to: 0.94, duration: 0.06),
            .scale(to: 1.0, duration: 0.08)
        ]))

        view.presentScene(GameScene.newGameScene(),
                          transition: .fade(withDuration: 0.35))
    }
    #endif
}
