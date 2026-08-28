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
    private let claimRenderer = ClaimRenderer()
    private let treeRenderer = TreeRenderer()
    private let blockRenderer = BlockRenderer()
    private let lootboxRenderer = LootboxRenderer()
    private let groundItemRenderer = GroundItemRenderer()
    private let projectileRenderer = ProjectileRenderer()
    private let actorRenderer = ActorRenderer()
    private let cameraController = CameraController()

    /// The map revision the block layer was last drawn from, so it is only rebuilt
    /// when a tile actually changed.
    private var drawnMapRevision = -1

    // MARK: - UI

    private let joystick = JoystickNode()
    private let fireButton = ActionButtonNode(glyph: Glyphs.crosshair)
    /// Only shown when there is actually a lootbox in reach.
    private let openButton = ActionButtonNode(glyph: SKTexture(imageNamed: "LootboxRed"))
    private let hud = HUDNode()
    private let hotbar = HotbarNode()

    #if os(iOS) || os(tvOS)
    /// Which finger owns which control, and which one might still turn out to be a tap.
    private var joystickTouch: UITouch?
    private var fireTouch: UITouch?
    private var openTouch: UITouch?
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

        let generated = MapFactory.generate(seed: seed)
        world = World(generated: generated, localTeam: TeamID(0))

        tileRenderer.build(from: generated.map)
        claimRenderer.build(claims: generated.claims)
        treeRenderer.build(patches: generated.trees)
        worldLayer.addChild(tileRenderer.node)
        worldLayer.addChild(claimRenderer.node)
        worldLayer.addChild(treeRenderer.node)
        worldLayer.addChild(blockRenderer.node)
        worldLayer.addChild(lootboxRenderer.node)
        worldLayer.addChild(groundItemRenderer.node)
        worldLayer.addChild(projectileRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        addChild(worldLayer)

        // The UI rides on the camera, so it stays put on screen while the map moves.
        camera = cameraController.node
        addChild(cameraController.node)
        cameraController.node.addChild(joystick)
        cameraController.node.addChild(fireButton)
        cameraController.node.addChild(openButton)
        cameraController.node.addChild(hud)
        cameraController.node.addChild(hotbar)
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
        fireButton.position = CGPoint(x: size.width / 2 - margin,
                                      y: -size.height / 2 + margin)

        // Sits above the fire button, where a right thumb can reach it.
        openButton.position = CGPoint(x: size.width / 2 - margin,
                                      y: -size.height / 2 + margin + 92)

        // The HUD's origin is its own top-left corner, so this is just an inset.
        let inset: CGFloat = 16
        hud.position = CGPoint(x: -size.width / 2 + inset,
                               y: size.height / 2 - inset)

        // The hotbar's origin is its own centre, so it only needs a bottom edge.
        hotbar.position = CGPoint(x: 0,
                                  y: -size.height / 2 + inset + HotbarNode.size.height / 2)
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

        blockRenderer.sync(with: world)
        lootboxRenderer.sync(with: world)
        groundItemRenderer.sync(with: world)
        projectileRenderer.sync(with: world)
        actorRenderer.sync(with: world)
        hud.update(with: world)
        hotbar.update(with: world)

        // The button only appears when there is something to open, and it asks the
        // world the same question LootSystem will - so it can never light up for a
        // box the simulation would then refuse to open.
        let inReach = world.localPlayer.flatMap {
            world.nearestLootbox(to: $0.feet, within: GameConfig.Loot.openRange)
        }
        openButton.isHidden = inReach == nil
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    /// Input becomes a Command. Later, AI brains and network packets produce their
    /// Commands exactly the same way, and the world cannot tell them apart.
    private func gatherCommands() -> [ActorID: [Command]] {
        var commands: [Command] = [.move(joystick.direction)]
        if fireButton.isPressed {
            // Asked every tick while held. WeaponSystem owns the fire rate, so this
            // cannot shoot faster than the blaster allows.
            commands.append(.shoot)
        }
        commands.append(contentsOf: queuedCommands)
        queuedCommands.removeAll()
        return [world.localPlayerID: commands]
    }
}

#if os(iOS) || os(tvOS)
extension GameScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            // The controls get first refusal on every touch; whatever is left over
            // is a tap on the map.
            if joystickTouch == nil,
               joystick.begin(atLocalPoint: touch.location(in: joystick)) {
                joystickTouch = touch
                continue
            }

            if fireTouch == nil,
               fireButton.begin(atLocalPoint: touch.location(in: fireButton)) {
                fireTouch = touch
                continue
            }

            if openTouch == nil, !openButton.isHidden,
               openButton.begin(atLocalPoint: touch.location(in: openButton)) {
                openTouch = touch
                // A one-shot action, unlike the fire button - queued on press.
                queuedCommands.append(.openLootbox)
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
        releaseFireButton(matching: touches)
        releaseOpenButton(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            requestBlock(at: tap.location(in: worldLayer))
            tapTouch = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseJoystick(matching: touches)
        releaseFireButton(matching: touches)
        releaseOpenButton(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            tapTouch = nil
        }
    }

    private func releaseJoystick(matching touches: Set<UITouch>) {
        guard let active = joystickTouch, touches.contains(active) else { return }
        joystick.end()
        joystickTouch = nil
    }

    private func releaseFireButton(matching touches: Set<UITouch>) {
        guard let active = fireTouch, touches.contains(active) else { return }
        fireButton.end()
        fireTouch = nil
    }

    private func releaseOpenButton(matching touches: Set<UITouch>) {
        guard let active = openTouch, touches.contains(active) else { return }
        openButton.end()
        openTouch = nil
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
