//
//  GameViewController.swift
//  Loot Wars
//
//  Created by Heath Rampazis on 28/8/2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // The menu, not a match. A game that starts before anybody has agreed to
        // play gives you no moment to arrive in and no way to stop without killing
        // the app - and the world is built by GameScene when the menu asks for it,
        // so nothing about a match exists until somebody presses PLAY.
        let skView = self.view as! SKView
        skView.presentScene(MenuScene.newMenuScene())
        
        skView.ignoresSiblingOrder = true

        // The performance readout in the corner: frame rate, how many nodes are
        // in the scene, and how many draw calls each frame takes. Draw calls are
        // the number that matters most - see the notes on performance. Turn this
        // off before release.
        let showStats = true
        skView.showsFPS = showStats
        skView.showsNodeCount = showStats
        skView.showsDrawCount = showStats
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        // Loot Wars is landscape only - the map needs the width.
        return .landscape
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
