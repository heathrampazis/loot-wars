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

    /// Uses whatever you have picked out of the hotbar, tucked above the corner.
    /// Small, and under the thumb that is already on the right-hand side - the
    /// whole point is healing, or lobbing a bomb, without reaching across to the
    /// hotbar mid-fight.
    ///
    /// It shows the selected item's own art and issues useItem for that slot, so it
    /// serves whatever gets picked out next without being taught about it.
    private let itemButton = ActionButtonNode(glyph: Glyphs.lootbox,
                                              radius: 40, grabRadius: 48)

    /// What the small button is currently showing, so its glyph is only rebuilt
    /// when the selection actually changes rather than every frame.
    private var itemGlyph: ItemType?

    /// What that corner is currently for.
    private enum CornerAction: Equatable {
        case aim
        case lootbox
        case chest(ChestID)
    }

    private var cornerAction: CornerAction = .aim

    private let hud = HUDNode()
    private let leaderboard = LeaderboardNode()
    private let matchTimer = MatchTimerNode()

    /// Opens the shop. Sits on the top edge between the clock and the leaderboard -
    /// the only gap that is clear on every size. Under the HUD, which was the
    /// obvious spot, it lands inside the move stick's grab radius on anything
    /// smaller than a Pro Max.
    private let shopButton = ActionButtonNode(glyph: ItemArt.texture(for: .token(1)),
                                              radius: 26, grabRadius: 40)
    private let shopPanel = ShopPanelNode()
    private let results = ResultsNode()
    private let hotbar = HotbarNode()
    private let chestPanel = ChestPanelNode()
    private let respawnBanner = RespawnBanner()

    /// The hotbar slot picked out, waiting to be acted on.
    ///
    /// Scene state, not world state, and deliberately so: a selection is a thing
    /// this screen remembers between two taps, and the simulation never hears about
    /// it. What crosses into Core is the finished intent - place a chest HERE, use
    /// the thing in THAT slot.
    private var selectedSlot: Int?

    /// How long a finger must stay put to become a hold rather than a tap.
    ///
    /// Shorter than the system's half-second long press. This is a game action, not
    /// a context menu, and half a second of nothing happening while you are being
    /// shot at feels like the game has stopped listening.
    private static let holdDuration: TimeInterval = 0.4

    #if os(iOS) || os(tvOS)
    /// Which finger owns which control.
    private var moveTouch: UITouch?
    private var aimTouch: UITouch?
    private var openTouch: UITouch?
    private var itemTouch: UITouch?

    /// A finger that has not yet decided whether it is a tap or a hold.
    ///
    /// One at a time, deliberately. Tapping and holding are opposite meanings of
    /// the same gesture, and two of them resolving at once on different targets is
    /// a class of bug nobody would enjoy reproducing.
    private struct PendingPress {
        enum Target {
            case map
            case hotbar(slot: Int)
        }

        let touch: UITouch
        let screenOrigin: CGPoint
        /// Where the press landed on the MAP, captured at press time.
        ///
        /// Not looked up again when the hold fires: the camera follows the player,
        /// so the same point on the screen is a different tile half a second later,
        /// and the wall you pressed is the one you meant.
        let worldOrigin: CGPoint
        let beganAt: TimeInterval
        let target: Target
        /// The hold has already fired, so the release must not act as well.
        var fired = false
    }

    private var pending: PendingPress?

    /// Slide further than this and it was a drag - neither a tap nor a hold.
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
        cameraController.node.addChild(itemButton)
        itemButton.isHidden = true
        cameraController.node.addChild(hud)
        cameraController.node.addChild(leaderboard)
        cameraController.node.addChild(matchTimer)
        cameraController.node.addChild(shopButton)
        cameraController.node.addChild(shopPanel)
        cameraController.node.addChild(results)
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

    /// How much the right edge is eaten by the Dynamic Island, in points.
    private var islandInset: CGFloat {
        #if os(iOS) || os(tvOS)
        return view?.safeAreaInsets.right ?? 0
        #else
        return 0
        #endif
    }

    private var laidOutForIsland: CGFloat = -1

    /// The insets are not known when the scene first lays itself out, and they
    /// change on rotation. Rather than hunt for the callback that covers both, this
    /// notices the value moving - one float compare a frame, against a reposition
    /// that is a single assignment.
    ///
    /// Scoped to the leaderboard alone on purpose. Laying the WHOLE interface out
    /// from the safe area moved the sticks sixty points inboard and you did not like
    /// it, so the controls still measure from the glass. Only the thing that has to
    /// be readable gets out of the island's way.
    private func repositionLeaderboardIfNeeded() {
        guard laidOutForIsland != islandInset else { return }
        layOutUI()
    }

    private func layOutUI() {
        // Tell the simulation how much of the map this screen is actually showing,
        // so bots will not open fire from somewhere the player cannot look. Done
        // here because this is where the size is known, and it is the only thing
        // Render ever pushes INTO the world - a plain number, no SpriteKit.
        if world != nil {
            world.visibleHalfExtent = Vec2(
                x: Double(size.width / 2 / GridGeometry.tileSize),
                y: Double(size.height / 2 / GridGeometry.tileSize))
        }

        let margin: CGFloat = 110
        moveStick.position = CGPoint(x: -size.width / 2 + margin,
                                     y: -size.height / 2 + margin)
        // Same corner: they take it in turns rather than sharing it.
        aimStick.position = CGPoint(x: size.width / 2 - margin,
                                    y: -size.height / 2 + margin)
        openButton.position = aimStick.position

        // Right edges flush with the stick below it, and tucked down close.
        //
        // The offset is solved, not eyeballed. This button has to be offered a
        // touch BEFORE the aim stick (see touchesBegan), because it sits inside the
        // stick's 120pt grab radius and would otherwise never be pressed at all.
        // That priority then makes its OWN grab radius the hazard: no part of the
        // stick you can see may fall inside it, or a thumb on the stick would heal
        // you instead. So the centres must stay further apart than 48 + 62 = 110,
        // and moving right buys some of that distance back - which is what lets it
        // come down as far as it has.
        itemButton.position = CGPoint(
            x: aimStick.position.x + JoystickNode.baseRadius - 40,
            y: aimStick.position.y + 115)


        // The HUD's origin is its own top-left corner, so this is just an inset.
        let inset: CGFloat = 16
        hud.position = CGPoint(x: -size.width / 2 + inset,
                               y: size.height / 2 - inset)

        // Mirrored in the opposite corner, and the ONE thing here that respects the
        // safe area. In landscape the Dynamic Island eats about sixty points off one
        // side and the top-right corner is exactly where it lands, so a leaderboard
        // measured from the glass would be half hidden behind it. The sticks stay
        // measured from the glass because that is where they felt right - this is a
        // thing you read rather than a thing you press, so it is the one that has to
        // move out of the way.
        leaderboard.position = CGPoint(x: size.width / 2 - inset - islandInset,
                                       y: size.height / 2 - inset)
        laidOutForIsland = islandInset

        // The one strip of the top edge nothing else wants: the HUD holds the left
        // corner, the leaderboard the right, and the middle is clear on every size
        // those two fit on.
        matchTimer.position = CGPoint(x: 0, y: size.height / 2 - inset)
        results.layOut(for: size)

        // Centred in the gap between the clock and the leaderboard, so it lands in
        // clear space whatever the width happens to be.
        let clockRight = MatchTimerNode.size.width / 2
        let boardLeft = size.width / 2 - inset - islandInset - LeaderboardNode.size.width
        shopButton.position = CGPoint(x: (clockRight + boardLeft) / 2,
                                      y: size.height / 2 - inset - 26)

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

        // The clock is the one thing that stops the simulation, and it stops it
        // HERE rather than inside Core. Whether the world should advance is a
        // question about the app - a networked host would answer it somewhere else
        // again - so nothing in a system has to know a match can end.
        while accumulator >= GameConfig.fixedTimeStep, !world.isOver {
            world.step(commands: gatherCommands(), dt: GameConfig.fixedTimeStep)
            accumulator -= GameConfig.fixedTimeStep
        }

        if world.isOver {
            accumulator = 0
            endMatch()
        }

        #if os(iOS) || os(tvOS)
        // Checked against the frame clock rather than a timer, so a hold fires while
        // the finger is still down - which is the whole difference between a hold
        // and a slow tap.
        resolveHold(at: currentTime)
        #endif

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
        repositionLeaderboardIfNeeded()
        leaderboard.update(with: world)
        matchTimer.update(with: world)
        shopPanel.update(with: world)
        hotbar.update(with: world)
        respawnBanner.update(with: world)

        // The panel closes itself if the chest stops existing, or if you are moved
        // out of reach of it. Nothing else has to remember to do that.
        chestPanel.update(with: world)

        // Forget a selection whose slot has emptied - spent, dropped, or stored in
        // a chest. This is what takes the heal button away when the last dressing
        // is used, and it stops a stale slot index acting on whatever lands there
        // next.
        if let slot = selectedSlot,
           world.localPlayer?.inventory.stack(at: slot) == nil {
            selectedSlot = nil
        }
        hotbar.setSelected(selectedSlot)

        updateRightControl(with: world)
        updateItemButton(with: world)
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
        // The match is finished; nothing gets its controls back.
        guard !world.isOver else { return }
        guard let player = world.localPlayer else { return }

        // Both sticks go away while you have your head in a chest.
        //
        // You therefore stand still to rummage, which is a real cost and the
        // intended one: a chest is inside your own walls, and a moment spent not
        // watching the door is the trade for reorganising your bag. The panel is
        // never a trap - the back button is large, and it closes itself the instant
        // anything puts the chest out of reach.
        // Note what is NOT touched here: cornerAction. It records what the corner
        // is SHOWING, and while the panel is up the corner shows nothing. Writing
        // .aim into it here - which this used to do - was a lie that outlived the
        // panel: on closing, the corner wanted .aim, found it already believed
        // .aim, and skipped the work of putting the stick back. The stick stayed
        // gone until walking back to the chest forced a different value through,
        // which is exactly how the bug presented.
        if chestPanel.openChest != nil || shopPanel.isOpen {
            moveStick.isHidden = true
            moveStick.end()
            aimStick.isHidden = true
            aimStick.end()
            openButton.isHidden = true
            shopButton.isHidden = shopPanel.isOpen
            hotbar.isHidden = shopPanel.isOpen
            return
        }

        shopButton.isHidden = false
        hotbar.isHidden = false


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

        // The glyph is the only thing here that is costly to change and the only
        // thing that must never change under a thumb, so the glyph is the only
        // thing the cache guards. Visibility is re-applied every frame from what is
        // wanted right now - which is what makes it impossible for the nodes and
        // the cache to disagree again, rather than merely fixing the one case where
        // they did.
        if wanted != cornerAction {
            cornerAction = wanted

            switch wanted {
            case .lootbox: openButton.setGlyph(Glyphs.lootbox)
            case .chest:   openButton.setGlyph(Glyphs.chest)
            case .aim:     break
            }
        }

        let offersButton = wanted != .aim
        let alreadyOffering = !openButton.isHidden

        aimStick.isHidden = offersButton
        openButton.isHidden = !offersButton

        // Do not leave the stick holding a direction it can no longer give up.
        if offersButton, !alreadyOffering { aimStick.end() }
    }

    /// Puts the controls away and brings the table up.
    ///
    /// Called every frame once the clock runs out, and guarded by the results node
    /// already being visible, so the work happens exactly once.
    private func endMatch() {
        guard results.isHidden else { return }

        results.show(with: world)

        // Everything you could press goes, including the chest panel if you happened
        // to have your head in one when the whistle went.
        chestPanel.close()
        shopPanel.close()
        shopButton.isHidden = true
        moveStick.isHidden = true
        moveStick.end()
        aimStick.isHidden = true
        aimStick.end()
        openButton.isHidden = true
        itemButton.isHidden = true
        hotbar.isHidden = true
        respawnBanner.isHidden = true

        #if os(iOS) || os(tvOS)
        moveTouch = nil
        aimTouch = nil
        openTouch = nil
        itemTouch = nil
        pending = nil
        #endif
    }

    /// Shows the picked-out item above the corner, or nothing.
    ///
    /// Deliberately not folded into updateRightControl. That one guards against
    /// swapping the corner under a thumb, and those guards do not apply here: this
    /// button never swaps places with anything, so it can answer honestly every
    /// frame.
    private func updateItemButton(with world: World) {
        guard !world.isOver else { return }
        guard let player = world.localPlayer,
              chestPanel.openChest == nil,
              !shopPanel.isOpen,
              let slot = selectedSlot,
              let stack = player.inventory.stack(at: slot),
              stack.type.use == .actionButton else {
            guard !itemButton.isHidden else { return }
            itemButton.isHidden = true
            itemButton.end()
            itemGlyph = nil
            return
        }

        if itemGlyph != stack.type {
            itemGlyph = stack.type
            itemButton.setGlyph(ItemArt.texture(for: stack.type))
        }

        itemButton.isHidden = false

        // Faint at full health, matching the hotbar slot it came from - the answer
        // is the actor's own, so what you see and what the simulation allows cannot
        // disagree.
        itemButton.setEnabled(player.canUse(slot: slot))
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
        // Once the whistle has gone there is exactly one thing left to press.
        if world != nil, world.isOver {
            for touch in touches
            where results.isPlayAgain(atLocalPoint: touch.location(in: results)) {
                restart()
                return
            }
            return
        }

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

            // Same for the shop.
            if shopPanel.isOpen {
                handleShopTouch(touch)
                continue
            }

            if !shopButton.isHidden,
               shopButton.begin(atLocalPoint: touch.location(in: shopButton)) {
                shopButton.end()
                shopPanel.open()
                continue
            }

            // BEFORE the aim stick, and that ordering is load-bearing. The small
            // button sits inside the stick's 120pt grab circle, so offering the
            // stick first would swallow every press aimed at it. Small precise
            // targets beat large forgiving ones; the stick loses nothing it needs.
            if itemTouch == nil, !itemButton.isHidden,
               itemButton.begin(atLocalPoint: touch.location(in: itemButton)) {
                itemTouch = touch

                // A one-shot action, so it fires on press. Refused politely when
                // the button is faint - pressing a disabled control should do
                // nothing rather than queue an intent the simulation will bin.
                if itemButton.isEnabled, let slot = selectedSlot {
                    queuedCommands.append(.useItem(slot: slot))
                }
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
                    selectedSlot = nil
                    chestPanel.open(id)

                    // Let go of the walking thumb. The move stick is about to be
                    // hidden, and a finger still tracked against a hidden stick
                    // kept driving it - walking the player straight out of range
                    // of the chest they had just opened. That is what made this
                    // look like a fault in the panel rather than in a touch that
                    // outlived its control.
                    moveStick.end()
                    moveTouch = nil
                case .aim:
                    break
                }
                continue
            }

            // Note the hotbar no longer acts on PRESS. It cannot: a hold means drop
            // it, and acting on press would use the item first and then drop it.
            // Both targets now decide what they meant on release.
            if let slot = hotbar.slotIndex(atLocalPoint: touch.location(in: hotbar)) {
                beginPress(touch, target: .hotbar(slot: slot))
                continue
            }

            beginPress(touch, target: .map)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // A hidden stick is not being driven, whatever the finger is doing.
        if let active = moveTouch, touches.contains(active), !moveStick.isHidden {
            moveStick.update(toLocalPoint: active.location(in: moveStick))
        }

        if let active = aimTouch, touches.contains(active) {
            aimStick.update(toLocalPoint: active.location(in: aimStick))
        }

        // A finger that wanders was neither a tap nor a hold.
        if let press = pending, touches.contains(press.touch) {
            let moved = press.touch.location(in: self) - press.screenOrigin
            if hypot(moved.x, moved.y) > tapSlop {
                cancelPress()
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseControls(matching: touches)

        guard let press = pending, touches.contains(press.touch) else { return }

        // A hold that already fired has had its turn. Letting the release act too
        // would delete a wall and then try to build one back on the same spot.
        if !press.fired {
            switch press.target {
            case .map:
                tapMap(at: press.touch.location(in: worldLayer))
            case .hotbar(let slot):
                tapHotbar(slot)
            }
        }

        cancelPress()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        releaseControls(matching: touches)

        if let press = pending, touches.contains(press.touch) {
            cancelPress()
        }
    }

    // MARK: - Tap or hold

    private func beginPress(_ touch: UITouch, target: PendingPress.Target) {
        guard pending == nil else { return }

        pending = PendingPress(touch: touch,
                               screenOrigin: touch.location(in: self),
                               worldOrigin: touch.location(in: worldLayer),
                               // UITouch timestamps share the frame clock's base,
                               // so this is directly comparable in resolveHold.
                               beganAt: touch.timestamp,
                               target: target)

        if case .hotbar(let slot) = target {
            hotbar.beginHold(slot, duration: GameScene.holdDuration)
        }
    }

    private func cancelPress() {
        if let press = pending, case .hotbar = press.target { hotbar.endHold() }
        pending = nil
    }

    /// Turns a finger that has stayed put into the second meaning of that gesture:
    /// take your own wall back down, or throw the item away.
    private func resolveHold(at now: TimeInterval) {
        guard var press = pending,
              !press.fired,
              now - press.beganAt >= GameScene.holdDuration else { return }

        press.fired = true
        pending = press

        switch press.target {
        case .map:
            queuedCommands.append(.removeBlock(GridGeometry.gridPoint(for: press.worldOrigin)))
        case .hotbar(let slot):
            queuedCommands.append(.dropItem(slot: slot))
            hotbar.endHold()
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

        if let active = itemTouch, touches.contains(active) {
            itemButton.end()
            itemTouch = nil
        }
    }

    /// Starts a whole new match by presenting a fresh scene.
    ///
    /// A new scene rather than resetting this one. Half a dozen renderers cache
    /// nodes against ids - chests, lootboxes, ground items, bombs - and clearing
    /// every one of those correctly is a list somebody eventually forgets to add to.
    /// Building a scene from nothing is the same code path as launching the game,
    /// which is the path that gets exercised every single time.
    private func restart() {
        guard let view else { return }
        view.presentScene(GameScene.newGameScene())
    }

    /// Picks a slot out, or puts it back.
    ///
    /// Nothing is spent by a tap on the hotbar any more - what acts on the picked
    /// item is either the button or a tap on the map, and which of those belongs to
    /// the item rather than to this screen (ItemType.use). Tapping the same slot
    /// again puts it back, because changing your mind should not cost you the item.
    private func tapHotbar(_ slot: Int) {
        guard world.localPlayer?.inventory.stack(at: slot) != nil else {
            selectedSlot = nil
            return
        }

        selectedSlot = (selectedSlot == slot) ? nil : slot
    }

    /// Taps while the shop is open: a tab, a card, or done.
    ///
    /// A card raises a buyItem and nothing more. Whether you can afford it, and
    /// whether it has anywhere to go, are ShopSystem's answers - the panel greys a
    /// card out from that same answer, so it never asks for something that will be
    /// refused, and could not charge you if it did.
    private func handleShopTouch(_ touch: UITouch) {
        let point = touch.location(in: shopPanel)

        if shopPanel.isBackButton(atLocalPoint: point) {
            shopPanel.close()
            return
        }

        if let tab = shopPanel.tabIndex(atLocalPoint: point) {
            shopPanel.selectTab(tab)
            return
        }

        if let item = shopPanel.item(atLocalPoint: point) {
            queuedCommands.append(.buyItem(item))
            return
        }
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

        // Only an item that wants a tile turns a map tap into a placement. Anything
        // else picked out of the hotbar leaves the map meaning what it always meant.
        if let slot = selectedSlot,
           world.localPlayer?.inventory.stack(at: slot)?.type.use == .mapTap {
            queuedCommands.append(.placeChest(tile))
            selectedSlot = nil
            return
        }

        queuedCommands.append(.placeBlock(tile))
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}
#endif
