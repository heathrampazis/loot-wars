//
//  GameScene.swift
//  Loot Wars
//
//  The seam between the simulation and SpriteKit, and it is allowed to do exactly
//  four things:
//
//    1. turn input into Commands
//    2. run the fixed-step loop
//    3. hand the world to the renderers
//    4. lay out the UI
//
//  If this file starts growing game rules, they belong in a system in Core instead.
//

import SpriteKit

final class GameScene: SKScene {

    // MARK: - Simulation

    private var world: World!

    // MARK: - Rendering

    private let worldLayer = SKNode()
    private let tileRenderer = TileMapRenderer()
    private let treeRenderer = TreeRenderer()
    private let actorRenderer = ActorRenderer()
    private let cameraController = CameraController()

    // MARK: - UI

    private let joystick = JoystickNode()

    #if os(iOS) || os(tvOS)
    /// Which finger owns the stick right now.
    private var joystickTouch: UITouch?
    #endif

    // MARK: - Fixed timestep

    private var lastUpdateTime: TimeInterval = 0
    private var accumulator: Double = 0

    // MARK: - Setup

    class func newGameScene() -> GameScene {
        let scene = GameScene(size: CGSize(width: 1024, height: 768))
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        backgroundColor = RenderPalette.background
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        // A fresh map every launch. The seed is logged so any map worth keeping -
        // or worth debugging - can be pinned in GameConfig.Map.fixedSeed.
        let seed = GameConfig.Map.fixedSeed ?? UInt64.random(in: UInt64.min...UInt64.max)
        print("Loot Wars map seed: \(seed)")

        let map = MapFactory.makeMap(seed: seed)
        world = World(map: map, playerSpawn: MapFactory.spawnPoint(in: map).center)

        tileRenderer.build(from: map)
        treeRenderer.build(from: map)
        worldLayer.addChild(tileRenderer.node)
        worldLayer.addChild(treeRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        addChild(worldLayer)

        // The UI rides on the camera, so it stays put on screen while the map moves.
        camera = cameraController.node
        addChild(cameraController.node)
        cameraController.node.addChild(joystick)
        layOutUI()

        actorRenderer.sync(with: world)
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layOutUI()
    }

    private func layOutUI() {
        let margin: CGFloat = 110
        joystick.position = CGPoint(x: -size.width / 2 + margin,
                                    y: -size.height / 2 + margin)
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard world != nil else { return }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        accumulator += currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        // After a stall (breakpoint, app backgrounded) do not try to catch up on
        // every missed tick at once, or the game freezes trying to fast-forward.
        accumulator = min(accumulator, 0.25)

        while accumulator >= GameConfig.fixedTimeStep {
            world.step(commands: gatherCommands(), dt: GameConfig.fixedTimeStep)
            accumulator -= GameConfig.fixedTimeStep
        }

        actorRenderer.sync(with: world)
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    /// Input becomes a Command. Later, AI brains and network packets produce their
    /// Commands exactly the same way, and the world cannot tell them apart.
    private func gatherCommands() -> [ActorID: [Command]] {
        [world.localPlayerID: [.move(joystick.direction)]]
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard joystickTouch == nil else { return }
        for touch in touches {
            if joystick.begin(atLocalPoint: touch.location(in: joystick)) {
                joystickTouch = touch
                return
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let active = joystickTouch, touches.contains(active) else { return }
        joystick.update(toLocalPoint: active.location(in: joystick))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(matching: touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(matching: touches)
    }

    private func releaseJoystick(matching touches: Set<UITouch>) {
        guard let active = joystickTouch, touches.contains(active) else { return }
        joystick.end()
        joystickTouch = nil
    }
}
#endif
