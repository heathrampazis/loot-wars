//
//  MenuScene.swift
//  Loot Wars
//
//  The door into the game: the name, one button, and the grass.
//
//  The button is artwork rather than shapes. It was drawn here for a while - a
//  rounded slab, a lip, a stand-in for a shadow SpriteKit cannot blur, a triangle
//  nudged off centre - which was a program describing a button. The drawing is in
//  the asset catalogue now and this only has to put it in the right place.
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
    /// A share of the screen's width, capped so it cannot get silly on an iPad.
    /// The height comes from the artwork.
    private static let playWidthShare: CGFloat = 0.38
    private static let playMaxWidth: CGFloat = 260

    /// What the button was actually drawn at, kept for the hit test - which has to
    /// measure the picture on screen rather than a number written down twice.
    private var buttonSize = CGSize(width: 216, height: 96)

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

    /// The only thing on the screen you can press, and it is a picture now.
    ///
    /// It was drawn here for a while - a rounded slab, a lip under it, two faint
    /// offset slabs standing in for a shadow SpriteKit cannot blur, and a triangle
    /// nudged right of centre because a centred one looks left-heavy. All of that
    /// was a program describing a button. An artist drawing one is better at it and
    /// far easier to change, so the drawing lives in the asset catalogue and this
    /// puts it on the screen at the right size.
    ///
    /// Sized by WIDTH against the screen, with the height following the artwork's
    /// own proportions - so the button is the same share of every phone rather than
    /// a fixed slab that dominates a small one and gets lost on a large one.
    private func buildPlayButton(centredOn centre: CGPoint) {
        let texture = SKTexture(imageNamed: "Play")
        texture.usesMipmaps = true

        let width = min(MenuScene.playMaxWidth, size.width * MenuScene.playWidthShare)
        let art = texture.size()
        let height = art.width > 0 ? width * (art.height / art.width) : width

        let sprite = SKSpriteNode(texture: texture,
                                  size: CGSize(width: width, height: height))

        // The holder is a property and this runs again on every rotation or resize,
        // so it is emptied rather than appended to - otherwise a second sprite
        // lands on top of the first, at whatever scale the press animation happened
        // to leave behind.
        play.removeAllActions()
        play.removeAllChildren()
        play.removeFromParent()
        play.setScale(1)

        play.position = centre
        play.addChild(sprite)
        addChild(play)

        buttonSize = CGSize(width: width, height: height)
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

        let box = buttonSize
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
