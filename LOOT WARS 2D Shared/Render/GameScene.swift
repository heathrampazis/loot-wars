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
//  Notice that tapping a tile does not place a block here - it asks for one.
//  BuildSystem decides whether it happens.
//

import SpriteKit

final class GameScene: SKScene {

    // MARK: - Simulation

    private var world: World!

    /// Commands raised by one-off input (taps), waiting for the next tick.
    private var queuedCommands: [Command] = []

    // MARK: - Rendering

    private let worldLayer = SKNode()
    private let tileRenderer = TileMapRenderer()
    private let treeRenderer = TreeRenderer()
    private let blockRenderer = BlockRenderer()
    private let actorRenderer = ActorRenderer()
    private let cameraController = CameraController()

    /// The map revision the block layer was last drawn from, so it is only rebuilt
    /// when a tile actually changed.
    private var drawnMapRevision = -1

    // MARK: - UI

    private let joystick = JoystickNode()

    #if os(iOS) || os(tvOS)
    /// Which finger owns the stick, and which one might still turn out to be a tap.
    private var joystickTouch: UITouch?
    private var tapTouch: UITouch?
    private var tapOrigin: CGPoint = .zero
    /// Slide further than this and it was a drag, not a tap.
    private let tapSlop: CGFloat = 24
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
        worldLayer.addChild(blockRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        addChild(worldLayer)

        // The UI rides on the camera, so it stays put on screen while the map moves.
        camera = cameraController.node
        addChild(cameraController.node)
        cameraController.node.addChild(joystick)
        layOutUI()

        syncRenderers()
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

        syncRenderers()
    }

    private func syncRenderers() {
        // Blocks only get rebuilt when a tile actually changed.
        if world.mapRevision != drawnMapRevision {
            blockRenderer.build(from: world.map)
            drawnMapRevision = world.mapRevision
        }

        actorRenderer.sync(with: world)
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    /// Input becomes a Command. Later, AI brains and network packets produce their
    /// Commands exactly the same way, and the world cannot tell them apart.
    private func gatherCommands() -> [ActorID: [Command]] {
        var commands: [Command] = [.move(joystick.direction)]
        commands.append(contentsOf: queuedCommands)
        queuedCommands.removeAll()
        return [world.localPlayerID: commands]
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // The stick gets first refusal on every touch.
            if joystickTouch == nil,
               joystick.begin(atLocalPoint: touch.location(in: joystick)) {
                joystickTouch = touch
                continue
            }

            if tapTouch == nil {
                tapTouch = touch
                tapOrigin = touch.location(in: self)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let active = joystickTouch, touches.contains(active) {
            joystick.update(toLocalPoint: active.location(in: joystick))
        }

        // A finger that wanders was never a tap.
        if let tap = tapTouch, touches.contains(tap) {
            let moved = tap.location(in: self) - tapOrigin
            if hypot(moved.x, moved.y) > tapSlop {
                tapTouch = nil
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            requestBlock(at: tap.location(in: worldLayer))
            tapTouch = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            tapTouch = nil
        }
    }

    private func releaseJoystick(matching touches: Set<UITouch>) {
        guard let active = joystickTouch, touches.contains(active) else { return }
        joystick.end()
        joystickTouch = nil
    }

    /// Asks for a block. Whether one appears is BuildSystem's call, not the scene's.
    private func requestBlock(at pointInWorld: CGPoint) {
        queuedCommands.append(.placeBlock(GridGeometry.gridPoint(for: pointInWorld)))
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}
#endif
