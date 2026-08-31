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
    private let arcadeRenderer = ArcadeRenderer()
    private let lootboxRenderer = LootboxRenderer()
    private let chestRenderer = ChestRenderer()
    private let groundItemRenderer = GroundItemRenderer()
    private let bombRenderer = BombRenderer()
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
    ///
    /// The bottom-right corner holds two controls that swap places: the aim stick
    /// while there is shooting to be done, and a plain Open button while there is a
    /// crate in reach. Only one is ever on screen.
    private let aimStick = JoystickNode(glyph: Glyphs.crosshair)
    private let openButton = ActionButtonNode(glyph: Glyphs.lootbox)

    /// What that corner is currently for.
    private enum CornerAction: Equatable {
        case aim
        case lootbox
        case chest(ChestID)
    }

    private var cornerAction: CornerAction = .aim

    private let hud = HUDNode()
    private let hotbar = HotbarNode()
    private let chestPanel = ChestPanelNode()
    private let respawnBanner = RespawnBanner()

    /// A chest tapped in the hotbar, waiting for you to pick a tile.
    ///
    /// Scene state, not world state, and deliberately so: arming is a thing this
    /// screen remembers between two taps, and the simulation never hears about it.
    /// What crosses into Core is the finished intent - place a chest HERE.
    private var armedChestSlot: Int?

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
        arcadeRenderer.build(arcades: generated.arcades, mapHeight: generated.map.height)
        worldLayer.addChild(tileRenderer.node)
        worldLayer.addChild(claimRenderer.node)
        worldLayer.addChild(treeRenderer.node)
        worldLayer.addChild(blockRenderer.node)
        worldLayer.addChild(arcadeRenderer.node)
        worldLayer.addChild(lootboxRenderer.node)
        worldLayer.addChild(chestRenderer.node)
        worldLayer.addChild(groundItemRenderer.node)
        worldLayer.addChild(bombRenderer.node)
        worldLayer.addChild(projectileRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        addChild(worldLayer)

        // The UI rides on the camera, so it stays put on screen while the map moves.
        camera = cameraController.node
        addChild(cameraController.node)
        cameraController.node.addChild(moveStick)
        cameraController.node.addChild(aimStick)
        cameraController.node.addChild(openButton)
        openButton.isHidden = true
        cameraController.node.addChild(hud)
        cameraController.node.addChild(hotbar)
        cameraController.node.addChild(chestPanel)
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
        // Same corner: they take it in turns rather than sharing it.
        aimStick.position = CGPoint(x: size.width / 2 - margin,
                                    y: -size.height / 2 + margin)
        openButton.position = aimStick.position


        // The HUD's origin is its own top-left corner, so this is just an inset.
        let inset: CGFloat = 16
        hud.position = CGPoint(x: -size.width / 2 + inset,
                               y: size.height / 2 - inset)

        // The hotbar's origin is its own centre, so it only needs a bottom edge.
        hotbar.position = CGPoint(x: 0,
                                  y: -size.height / 2 + inset + HotbarNode.size.height / 2)

        // Hung in the gap between the HUD and the hotbar, measured rather than
        // guessed at, so it lands correctly on every screen instead of on the one
        // this was written against.
        //
        // Not stacked directly on the hotbar: that put the panel's bottom-left
        // corner inside the move stick's grab radius, which is deliberately far
        // wider than the stick you can see. The stick gets first refusal on every
        // touch, so the leftmost slot would have quietly stopped responding.
        let hudBottom = hud.position.y - HUDNode.size.height
        let hotbarTop = hotbar.position.y + HotbarNode.size.height / 2
        chestPanel.position = CGPoint(x: 0, y: (hudBottom + hotbarTop) / 2)
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
        chestRenderer.sync(with: world)
        groundItemRenderer.sync(with: world)
        bombRenderer.sync(with: world)
        projectileRenderer.sync(with: world)
        actorRenderer.sync(with: world)
        hud.update(with: world)
        hotbar.update(with: world)
        respawnBanner.update(with: world)

        // The panel closes itself if the chest stops existing, or if you are moved
        // out of reach of it. Nothing else has to remember to do that.
        chestPanel.update(with: world)

        // Forget an armed chest that is no longer in that slot - spent on a tile,
        // or dropped on death. Otherwise the next map tap tries to place thin air.
        if let slot = armedChestSlot,
           world.localPlayer?.inventory.stack(at: slot)?.type != .chest {
            armedChestSlot = nil
        }
        hotbar.setSelected(armedChestSlot)

        updateRightControl(with: world)
        if let player = world.localPlayer {
            cameraController.follow(player.position)
        }
    }

    /// Swaps the bottom-right corner between the aim stick and the Open button.
    ///
    /// The swap waits for a lull: never while a thumb is on the stick, and never
    /// while a shot is still cooling down. Pulling the aim stick out from under
    /// somebody mid-fight because they happened to walk past a crate would be
    /// indefensible, and walking past crates during a fight is exactly what happens.
    private func updateRightControl(with world: World) {
        guard let player = world.localPlayer else { return }

        // Both sticks go away while you have your head in a chest.
        //
        // You therefore stand still to rummage, which is a real cost and the
        // intended one: a chest is inside your own walls, and a moment spent not
        // watching the door is the trade for reorganising your bag. The panel is
        // never a trap - the back button is large, and it closes itself the instant
        // anything puts the chest out of reach.
        if chestPanel.openChest != nil {
            moveStick.isHidden = true
            moveStick.end()
            aimStick.isHidden = true
            aimStick.end()
            openButton.isHidden = true
            cornerAction = .aim
            return
        }

        moveStick.isHidden = false

        #if os(iOS) || os(tvOS)
        guard aimTouch == nil, openTouch == nil else { return }
        #endif
        guard player.shootCooldown <= 0 else { return }

        // Asks the world the same questions the systems will, so the button can
        // never offer to open something the simulation would then refuse. Your own
        // chest wins over a crate: it is inside your base, and it is yours.
        let wanted: CornerAction
        if let chest = world.reachableChest(for: player) {
            wanted = .chest(chest.id)
        } else if world.reachableLootbox(for: player) != nil {
            wanted = .lootbox
        } else {
            wanted = .aim
        }

        guard wanted != cornerAction else { return }
        cornerAction = wanted

        switch wanted {
        case .aim:
            aimStick.isHidden = false
            openButton.isHidden = true
        case .lootbox:
            openButton.setGlyph(Glyphs.lootbox)
            aimStick.isHidden = true
            openButton.isHidden = false
        case .chest:
            openButton.setGlyph(Glyphs.chest)
            aimStick.isHidden = true
            openButton.isHidden = false
        }

        // Make sure the stick is not left holding a direction it can no longer be
        // asked to give up.
        if wanted != .aim { aimStick.end() }
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
            // the map - otherwise healing or opening would also try to lay a block.
            if moveTouch == nil, !moveStick.isHidden,
               moveStick.begin(atLocalPoint: touch.location(in: moveStick)) {
                moveTouch = touch
                continue
            }

            // With a chest open, every touch belongs to the panel.
            if chestPanel.openChest != nil {
                handleChestTouch(touch)
                continue
            }

            if aimTouch == nil, !aimStick.isHidden,
               aimStick.begin(atLocalPoint: touch.location(in: aimStick)) {
                aimTouch = touch
                continue
            }

            if openTouch == nil, !openButton.isHidden,
               openButton.begin(atLocalPoint: touch.location(in: openButton)) {
                openTouch = touch

                // A one-shot action, so it fires on press. Opening a chest is the
                // odd one out: it raises no Command at all, because looking into a
                // chest changes nothing about the world - only what this screen is
                // showing. Only moving something in or out is an intent.
                switch cornerAction {
                case .lootbox:
                    queuedCommands.append(.openLootbox)
                case .chest(let id):
                    armedChestSlot = nil
                    chestPanel.open(id)
                case .aim:
                    break
                }
                continue
            }

            if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
                tapHotbar(slot)
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
            tapMap(at: tap.location(in: worldLayer))
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

    /// A chest arms; everything else is used where you stand.
    ///
    /// The chest is the first item that takes two taps, because it is the first one
    /// that needs a target. Tapping it again puts it away - an armed chest you
    /// changed your mind about should not force you to place it somewhere.
    private func tapHotbar(_ slot: Int) {
        if world.localPlayer?.inventory.stack(at: slot)?.type == .chest {
            armedChestSlot = (armedChestSlot == slot) ? nil : slot
            return
        }

        armedChestSlot = nil
        queuedCommands.append(.useItem(slot: slot))
    }

    /// Taps while a chest is open: out of the chest, into the chest, or done.
    private func handleChestTouch(_ touch: UITouch) {
        guard let id = chestPanel.openChest else { return }

        if chestPanel.isBackButton(atLocalPoint: touch.location(in: chestPanel)) {
            chestPanel.close()
            return
        }

        if let slot = chestPanel.slotIndex(atLocalPoint: touch.location(in: chestPanel)) {
            queuedCommands.append(.takeItem(chest: id, slot: slot))
            return
        }

        if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
            queuedCommands.append(.storeItem(chest: id, slot: slot))
            return
        }

        // Anything else is ignored rather than closing the panel. A stray thumb on
        // the map should not throw you out of a chest you are halfway through.
    }

    /// Asks for a block, or for a chest if one is armed. Whether either appears is
    /// a system's call in Core, not the scene's. Bombs are thrown from the hotbar,
    /// like everything else you carry.
    private func tapMap(at pointInWorld: CGPoint) {
        let tile = GridGeometry.gridPoint(for: pointInWorld)

        if armedChestSlot != nil {
            queuedCommands.append(.placeChest(tile))
            armedChestSlot = nil
            return
        }

        queuedCommands.append(.placeBlock(tile))
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}
#endif
