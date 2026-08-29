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

    /// Twin sticks: walk with the left, aim and fire with the right.
    ///
    /// Aiming used to be a side effect of walking, which meant you could never
    /// shoot at anything you were not walking towards - and neither could a bot.
    /// Every fight collapsed into two actors marching into each other.
    private let moveStick = JoystickNode()
    private let aimStick = JoystickNode(glyph: Glyphs.crosshair)

    /// Only shown when there is actually a crate in reach.
    private let openButton = ActionButtonNode(glyph: Glyphs.lootbox)
    private let hud = HUDNode()
    private let hotbar = HotbarNode()
    private let respawnBanner = RespawnBanner()

    #if os(iOS) || os(tvOS)
    /// Which finger owns which control, and which one might still turn out to be a tap.
    private var moveTouch: UITouch?
    private var aimTouch: UITouch?
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
        world = World(generated: generated)

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
        cameraController.node.addChild(moveStick)
        cameraController.node.addChild(aimStick)
        cameraController.node.addChild(openButton)
        cameraController.node.addChild(hud)
        cameraController.node.addChild(hotbar)
        cameraController.node.addChild(respawnBanner)
        layOutUI()

        syncRenderers()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layOutUI()
    }

    private func layOutUI() {
        let margin: CGFloat = 110
        moveStick.position = CGPoint(x: -size.width / 2 + margin,
                                     y: -size.height / 2 + margin)
        aimStick.position = CGPoint(x: size.width / 2 - margin,
                                    y: -size.height / 2 + margin)

        // Above the hotbar rather than beside a stick: both thumbs are busy, and a
        // contextual button overlapping a stick would steal touches meant for it.
        openButton.position = CGPoint(x: 0, y: -size.height / 2 + 132)

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
        respawnBanner.update(with: world)

        // The button only appears when there is something to open, and it asks the
        // world the same question LootSystem will, so it can never offer to open a
        // crate the simulation would then refuse.
        openButton.isHidden = world.localPlayer.flatMap {
            world.reachableLootbox(for: $0)
        } == nil
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    /// Input becomes a Command. Later, AI brains and network packets produce their
    /// Commands exactly the same way, and the world cannot tell them apart.
    private func gatherCommands() -> [ActorID: [Command]] {
        var commands: [Command] = [.move(moveStick.direction)]

        // Any deflection of the aim stick is both an aim and a trigger pull.
        // WeaponSystem owns the fire rate, so holding it over cannot shoot faster
        // than the blaster allows.
        if aimStick.direction.length > 0.01 {
            commands.append(.shoot(aimStick.direction))
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
            // Order matters. The two sticks get first refusal, then the hotbar and
            // the contextual button, and only what is left over counts as a tap on
            // the map - otherwise drinking or opening would also try to lay a block.
            if moveTouch == nil,
               moveStick.begin(atLocalPoint: touch.location(in: moveStick)) {
                moveTouch = touch
                continue
            }

            if aimTouch == nil,
               aimStick.begin(atLocalPoint: touch.location(in: aimStick)) {
                aimTouch = touch
                continue
            }

            if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
                queuedCommands.append(.useItem(slot: slot))
                continue
            }

            if openTouch == nil, !openButton.isHidden,
               openButton.begin(atLocalPoint: touch.location(in: openButton)) {
                openTouch = touch
                // A one-shot action, so it fires on press.
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
        if let active = moveTouch, touches.contains(active) {
            moveStick.update(toLocalPoint: active.location(in: moveStick))
        }

        if let active = aimTouch, touches.contains(active) {
            aimStick.update(toLocalPoint: active.location(in: aimStick))
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
        releaseControls(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            requestBlock(at: tap.location(in: worldLayer))
            tapTouch = nil
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseControls(matching: touches)

        if let tap = tapTouch, touches.contains(tap) {
            tapTouch = nil
        }
    }

    private func releaseControls(matching touches: Set<UITouch>) {
        if let active = moveTouch, touches.contains(active) {
            moveStick.end()
            moveTouch = nil
        }

        if let active = aimTouch, touches.contains(active) {
            // Letting go stops the firing, but Actor.aim keeps its last value, so
            // the character stays pointed where it was rather than snapping round.
            aimStick.end()
            aimTouch = nil
        }

        if let active = openTouch, touches.contains(active) {
            openButton.end()
            openTouch = nil
        }
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
