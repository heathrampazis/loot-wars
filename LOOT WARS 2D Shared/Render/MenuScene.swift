//
//  MenuScene.swift
//  Loot Wars
//
//  The door into the game: a name, a button, and as little else as possible.
//
//  It is a SCENE rather than a panel over a paused world, and that is the design
//  decision worth keeping. A menu drawn on top of the game means the world has to
//  exist first - forty crates, eight bots and a generated map built before anybody
//  has pressed anything, torn down and rebuilt the moment they do. As its own scene
//  it costs a background and three labels, and the match is built when it is asked
//  for.
//
//  The first version of this screen put the game's own furniture on it: the map's
//  grass in giant checks, a token, a crate and a bomb bobbing about. The idea was
//  that a title screen made of the same pieces as the match cannot go out of date.
//  What it actually looked like was the game with the level missing - the same
//  colours doing none of the same work, and three little sprites floating in a
//  field with nothing to do. A menu is not a scene from the game, it is the quiet
//  before one.
//
//  So: a dark ground the game never uses, one bright thing to press, and space.
//  Everything here is either the name, the button, or the one fact worth knowing
//  before you press it. Nothing decorates.
//

import SpriteKit
import UIKit

final class MenuScene: SKScene {

    private let play = SKNode()
    private static let playSize = CGSize(width: 260, height: 64)

    class func newMenuScene() -> MenuScene {
        let scene = MenuScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = MenuScene.deep
        removeAllChildren()
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard scene != nil, !children.isEmpty else { return }
        removeAllChildren()
        build()
    }

    // MARK: - The one palette this screen has

    /// A slate two shades under the HUD's, which is the point: every panel in the
    /// game sits ON something, and this sits on nothing. Going darker than anything
    /// in a match is what makes the menu read as a different place rather than as
    /// the game with the map switched off.
    private static let deep = SKColor(red: 0.10, green: 0.13, blue: 0.16, alpha: 1)
    private static let lift = SKColor(red: 0.16, green: 0.20, blue: 0.24, alpha: 1)

    // MARK: - Building

    private func build() {
        let middle = CGPoint(x: size.width / 2, y: size.height / 2)

        buildBackdrop()

        // Measured off the middle rather than off the edges, so the layout holds
        // its shape on every phone: a tall screen gets more air, not more gaps
        // between things that belong together.
        buildTitle(centredOn: CGPoint(x: middle.x, y: middle.y + 76))
        buildPlayButton(centredOn: CGPoint(x: middle.x, y: middle.y - 30))
        buildRecord(centredOn: CGPoint(x: middle.x, y: middle.y - 100))
    }

    /// A single soft gradient, lighter behind the title and falling away to the
    /// corners. It is doing one job - putting the brightest part of the screen
    /// behind the thing you are meant to read first - and no other.
    private func buildBackdrop() {
        let glow = SKSpriteNode(texture: GlowArt.pool)

        glow.size = CGSize(width: size.width * 1.5, height: size.height * 1.9)
        glow.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        glow.color = MenuScene.lift
        glow.colorBlendFactor = 1
        glow.alpha = 0.85
        glow.zPosition = -10
        addChild(glow)
    }

    /// The name, tracked wide.
    ///
    /// No outline, and that is a departure from the game's own artwork on purpose.
    /// The black line round every sprite is there to hold a small bright shape
    /// against a busy map; there is no map here, and at this size an outline stops
    /// being a silhouette and becomes a thick edge on the letters. Letter spacing
    /// does the work instead - it is the whole difference between a word and a
    /// title.
    private func buildTitle(centredOn centre: CGPoint) {
        let label = SKLabelNode()
        label.attributedText = MenuScene.text("LOOT WARS", size: 46, kern: 9,
                                              colour: .white)
        label.verticalAlignmentMode = .center
        label.position = centre
        addChild(label)

        let rule = SKSpriteNode(color: SKColor(white: 1, alpha: 0.16),
                                size: CGSize(width: 132, height: 2))
        rule.position = CGPoint(x: centre.x, y: centre.y - 34)
        addChild(rule)
    }

    /// The only thing on the screen you can press.
    private func buildPlayButton(centredOn centre: CGPoint) {
        let box = MenuScene.playSize
        play.position = centre
        addChild(play)

        func capsule(offsetBy drop: CGFloat, colour: SKColor) -> SKShapeNode {
            let shape = SKShapeNode(path: CGPath(
                roundedRect: CGRect(x: -box.width / 2, y: -box.height / 2 - drop,
                                    width: box.width, height: box.height),
                cornerWidth: box.height / 2, cornerHeight: box.height / 2,
                transform: nil))

            shape.fillColor = colour
            shape.strokeColor = .clear
            return shape
        }

        // The lip the shop's buttons wear, and no black outline. Same reason as the
        // title: an outline is for holding a shape against grass.
        play.addChild(capsule(offsetBy: 4, colour: RenderPalette.affordableDeep))
        play.addChild(capsule(offsetBy: 0, colour: RenderPalette.affordable))

        let label = SKLabelNode()
        label.attributedText = MenuScene.text("PLAY", size: 22, kern: 4, colour: .white)
        label.verticalAlignmentMode = .center
        label.zPosition = 1
        play.addChild(label)

        // One slow breath. It is the only movement on the screen, which is what
        // makes it read as an invitation rather than as decoration.
        play.run(.repeatForever(.sequence([
            .scale(to: 1.035, duration: 1.1),
            .scale(to: 1.0, duration: 1.1)
        ])))
    }

    /// What the game remembers about you. Nothing at all, the first time.
    private func buildRecord(centredOn centre: CGPoint) {
        guard Prefs.matchesFinished > 0 else { return }

        let matches = Prefs.matchesFinished
        let played = "\(matches) MATCH\(matches == 1 ? "" : "ES")"

        let label = SKLabelNode()
        label.attributedText = MenuScene.text("BEST \(Prefs.bestScore)   ·   \(played)",
                                              size: 12, kern: 3,
                                              colour: SKColor(white: 1, alpha: 0.45))
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
