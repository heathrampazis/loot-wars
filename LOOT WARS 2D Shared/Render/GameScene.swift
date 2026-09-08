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
    private let gasRenderer = GasRenderer()
    private let effectsRenderer = EffectsRenderer()
    private let placementGhost = PlacementGhost()
    private let blueprint = BlueprintRenderer()
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
        /// Your own: opens the storage panel.
        case chest(ChestID)
        /// Somebody else's: breaks it open where it stands.
        case raid(ChestID)
    }

    private var cornerAction: CornerAction = .aim

    private let hud = HUDNode()
    private let leaderboard = LeaderboardNode()
    private let matchTimer = MatchTimerNode()

    /// Opens the shop. Sits on the top edge between the clock and the leaderboard -
    /// the only gap that is clear on every size. Under the HUD, which was the
    /// obvious spot, it lands inside the move stick's grab radius on anything
    /// smaller than a Pro Max.
    private static let shopButtonRadius: CGFloat = 34

    private let shopButton = ActionButtonNode(glyph: Glyphs.shoppingBag,
                                              radius: shopButtonRadius, grabRadius: 42,
                                              shape: .roundedSquare,
                                              fill: RenderPalette.hudPanel,
                                              // 0.73 of the plate, kept as the
                                              // button grew. The reference draws it
                                              // at 0.6, which left more air round it
                                              // than the button wanted.
                                              glyphSize: 50)
    private let shopPanel = ShopPanelNode()

    /// One offer, unprompted, for a few seconds - see QuickBuyNode.
    private let quickBuy = QuickBuyNode()

    /// Teaches the one gesture nothing on screen suggests: hold a slot to drop it.
    private let hint = HintNode()

    /// The hold hint's whole budget for a match.
    ///
    /// One showing, spent only on the moment that earns it: walking over something
    /// and not picking it up - which is the moment a full bag stops being an
    /// abstraction. After that it is gone for the rest of the match, one successful
    /// hold retires it early, and Prefs retires it for good: every lesson in this
    /// game is shown on a first match and never again.
    private var holdHintsLeft = 1
    private var hasUsedHold = false

    /// The build hint's own budget, on the same terms.
    ///
    /// Spent when you arrive in your own base with somewhere to build and have not
    /// built anything yet - the moment the outlines light up and the question "what
    /// are those?" is actually being asked. ONE showing, and only ever on a first
    /// match: see Prefs. A tip that keeps coming back is not teaching.
    private var buildHintsLeft = 1
    private var hasBuilt = false

    /// Walls laid this match, and how many it takes to have learned the gesture.
    ///
    /// Three. One could be an accident, two is a habit forming, and by the third
    /// the ghosts have said everything they have to say - so they go, and Prefs
    /// keeps them gone for every match after this one. A tutorial that outstays
    /// this is furniture.
    private var wallsBuilt = 0
    private static let wallsToLearn = 3

    /// Whether the player was standing in their own claim last frame, so the build
    /// hint fires on ARRIVING home rather than once per frame while standing there.
    /// The same shape as wasBlocked, and for the same reason: a hint is a reaction
    /// to a moment, and "being at home" is a state.
    private var wasHome = false

    /// Who killed you, while you are waiting to come back - see aimCamera.
    private var killedBy: ActorID?

    /// Whether the player was already standing on something they could not take.
    ///
    /// The hint fires on the EDGE - the step onto the item - rather than the whole
    /// time somebody is standing on it. Otherwise walking a line of loot with a
    /// full bag re-arms the message over and over and it never leaves the screen,
    /// which is exactly how a two-second hint turns into a permanent one.
    private var wasBlocked = false

    /// When the shop button next waves at somebody who has not been in.
    private var nextNudge: TimeInterval = 0
    private let results = ResultsNode()
    private let hotbar = HotbarNode()
    private let chestPanel = ChestPanelNode()
    private let respawnBanner = RespawnBanner()


    /// How much healing sat in each slot last frame, so PICKING ONE UP can be
    /// noticed. Per slot rather than a total: a bandage landing in an empty slot
    /// and a bandage joining a stack are the same event, and both are worth arming.
    private var lastHealingPerSlot: [Int] = []

    /// The local player's health last frame, so being HIT can be noticed.
    ///
    /// A moment rather than a state, which is what makes arming a heal safe: if the
    /// game re-armed whenever nothing was selected, tapping a slot to put it away
    /// would put it straight back, and the player could never have an empty hand.
    private var lastLocalHealth: Int?

    /// The hotbar slot picked out, waiting to be acted on.
    ///
    /// Scene state, not world state, and deliberately so: a selection is a thing
    /// this screen remembers between two taps, and the simulation never hears about
    /// it. What crosses into Core is the finished intent - place a chest HERE, use
    /// the thing in THAT slot.
    private var selectedSlot: Int?

    /// Where the thing being placed is currently pointed.
    ///
    /// Scene state like the selection, and for the same reason: an aim is a thing
    /// this screen is holding between two moments of a gesture. What crosses into
    /// Core is the finished intent - put it HERE - and only on release.
    private var ghostOrigin: GridPoint?

    /// What the ghost is aiming, so a fresh selection starts somewhere sensible
    /// rather than wherever the last one was left pointing.
    private var ghostType: ItemType?

    /// The item picked out of the hotbar that wants a tile, if there is one.
    ///
    /// Asked in three places, so it is one question rather than three spellings of
    /// it - and it reads from the inventory each time, so an item spent, dropped or
    /// stored stops being placeable the same frame.
    private var placingType: ItemType? {
        guard let slot = selectedSlot,
              let type = world?.localPlayer?.inventory.stack(at: slot)?.type,
              type.use == .mapTap else { return nil }
        return type
    }

    /// How far into a match the drop hint will still offer itself. The opening
    /// third, and no later.
    private static let hintWindow: Double = 0.35

    /// How near an enemy has to be, and how recently you have been shot, for the
    /// screen to stop trying to teach you anything.
    private static let hintCombatRange: Double = 11
    private static let hintCombatQuiet: Double = 4

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

    /// The finger aiming something onto the map.
    ///
    /// Deliberately NOT a PendingPress. Positioning is a drag, and a drag past the
    /// slop cancels a pending press - so lining a machine up would have quietly
    /// stopped counting as anything. It also has no hold meaning: holding the map
    /// takes a wall down, and doing that while placing a machine on the same spot
    /// is not a gesture anybody wants to discover by accident.
    private var placingTouch: UITouch?

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
        // Counted here rather than at the whistle: what it gates is the tutorial,
        // and somebody who quit halfway through their first match has still seen
        // it.
        Prefs.matchesStarted += 1

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
        arcadeRenderer.build(mapHeight: generated.map.height)
        worldLayer.addChild(tileRenderer.node)
        worldLayer.addChild(claimRenderer.node)

        // On the ground with the claim tint, under everything that stands on it.
        worldLayer.addChild(blueprint.node)

        worldLayer.addChild(treeRenderer.node)
        worldLayer.addChild(blockRenderer.node)
        worldLayer.addChild(arcadeRenderer.node)
        worldLayer.addChild(lootboxRenderer.node)
        worldLayer.addChild(chestRenderer.node)
        worldLayer.addChild(groundItemRenderer.node)
        worldLayer.addChild(bombRenderer.node)
        worldLayer.addChild(projectileRenderer.node)
        worldLayer.addChild(actorRenderer.node)
        worldLayer.addChild(gasRenderer.node)
        worldLayer.addChild(effectsRenderer.node)
        worldLayer.addChild(placementGhost.node)
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
        cameraController.node.addChild(quickBuy)
        cameraController.node.addChild(hint)
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

        // Tucked against the right-hand edge of the HUD, top-aligned with it.
        //
        // Clamped so it can never reach the clock. On a phone as narrow as an SE
        // there is only 51 points between the two and the button wants 70, so the
        // clamp bites and it overlaps the HUD's edge by about 8 instead. That is the
        // better of the two failures by a distance: the HUD is a readout nobody
        // presses, so a few points of overlap costs nothing, whereas lapping the
        // clock would cover a number you need.
        let radius = GameScene.shopButtonRadius
        let besideTheHUD = hud.position.x + HUDNode.size.width + 10 + radius
        let clearOfTheClock = -MatchTimerNode.size.width / 2 - 8 - radius

        shopButton.position = CGPoint(x: min(besideTheHUD, clearOfTheClock),
                                      y: size.height / 2 - inset - radius)

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

        // Hung in the gap the hotbar leaves behind: centred between the bottom of
        // the HUD and the bottom of the screen.
        //
        // Not the middle of the screen, which is where this sat first. The panel is
        // 230 tall and an SE gives it 234 points down there, so centring it moved
        // the whole thing up over the health bar - and health is the one number you
        // are still reading while you decide whether to buy a bandage. Hung here it
        // clears the HUD by a point on the smallest phone and by plenty on every
        // other one, which is also why the panel's own height is capped where it
        // is: it is sized to the gap it lives in.
        shopPanel.position = CGPoint(
            x: 0,
            y: (hudBottom + (-size.height / 2 + 12)) / 2)

        // Hung under the health panel, left edges flush with it. It is a reading
        // of your purse as much as an offer, so it belongs with the other numbers
        // about you rather than out among the controls - and the top-left corner is
        // where the eye already goes for those.
        //
        // Still offered to a finger BEFORE the move stick in touchesBegan: on a
        // phone this small the stick's grab circle reaches most of the left-hand
        // side, and the stick gets first refusal on everything it covers.
        quickBuy.position = CGPoint(
            x: hud.position.x + QuickBuyNode.size.width / 2,
            y: hudBottom - 10 - QuickBuyNode.size.height / 2)

        // The strip directly under the health panel, centred: the one band of
        // screen nothing else occupies mid-match. Measured off the HUD rather than
        // off the top edge, so it follows the panel if that ever changes height -
        // which it just did, when the ammo bar came out.
        hint.position = CGPoint(x: 0, y: hudBottom - 18)

    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        guard world != nil else { return }

        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        frameDelta = min(0.25, currentTime - lastUpdateTime)
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

    /// How long the last frame took, for the renderers that decay a value rather
    /// than animating one - see ActorRenderer's recoil, which cannot use an action
    /// because the thing it moves is rewritten every frame.
    private var frameDelta: TimeInterval = 1.0 / 60

    private func syncRenderers() {
        // Blocks only get rebuilt when a tile actually changed.
        if world.mapRevision != drawnMapRevision {
            blockRenderer.build(from: world.map)
            drawnMapRevision = world.mapRevision
        }

        blockRenderer.sync(with: world)
        blueprint.sync(with: world, dt: frameDelta)
        lootboxRenderer.sync(with: world)
        chestRenderer.sync(with: world)
        arcadeRenderer.sync(with: world)
        groundItemRenderer.sync(with: world)
        bombRenderer.sync(with: world)
        projectileRenderer.sync(with: world)
        actorRenderer.sync(with: world, dt: frameDelta)
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

        armHealingIfHit(in: world)
        armHealingWhenFound(in: world)
        hotbar.setSelected(shopPanel.isOpen ? nil : selectedSlot)

        updateRightControl(with: world)
        updateItemButton(with: world)
        updatePlacementGhost(with: world)
        updateQuickBuy(with: world)
        updateHint(with: world)
        gasRenderer.sync(with: world, dt: frameDelta)
        effectsRenderer.sync(with: world)
        dispatch(world.takeEvents(), in: world)
        aimCamera(in: world)
    }

    /// Offers the one thing worth offering, and waves at the shop button.
    ///
    /// Both hang off the same question - ShopSystem.quickOffer - so the prompt and
    /// the nudge can never disagree about whether there is anything to buy. The
    /// prompt now STAYS while the answer is yes, changing what it offers as the
    /// match changes; the button waves on a timer, and only while the shop is shut.
    ///
    /// The wave is back on whenever something is affordable, and stopping it was a
    /// mistake worth naming. The argument was that a permanent prompt plus a button
    /// waving at it every fourteen seconds is the same message twice - true, and
    /// beside the point, because the prompt was the half nobody could see. Making
    /// it permanent and silencing the button at the same time left NOTHING on that
    /// side of the screen moving, and watching people play, they found neither.
    private func updateQuickBuy(with world: World) {
        guard !world.isOver,
              !shopPanel.isOpen,
              chestPanel.openChest == nil,
              let player = world.localPlayer else {
            quickBuy.dismiss()
            return
        }

        let offer = ShopSystem.quickOffer(for: player, in: world)
        quickBuy.update(with: offer)

        guard offer != nil else { return }

        if lastUpdateTime >= nextNudge {
            nextNudge = lastUpdateTime + GameConfig.Shop.nudgeInterval
            shopButton.nudge()
        }
    }

    /// Floats the drop hint over the player, at the one moment it is worth saying.
    ///
    /// A full bag is that moment and the only one. It is when the gesture stops
    /// being a convenience and starts being the answer to a problem the player can
    /// see for themselves - they are standing on loot and nothing is happening.
    ///
    /// And it clears out the instant anybody is close enough to fight. A sentence
    /// floating over your own head while somebody shoots at you is worse than
    /// never having been told, and this is the one thing on screen with no claim
    /// on that attention.
    private func updateHint(with world: World) {
        guard let player = world.localPlayer, player.isAlive, !world.isOver else {
            wasBlocked = false
            hint.hide()
            return
        }

        // Walked over something and did not pick it up. LootSystem answers this,
        // not the scene, so the screen can never claim a refusal about an item that
        // is quietly being collected.
        let blocked = LootSystem.blockedPickup(for: player, in: world)
        let stepped = blocked && !wasBlocked
        wasBlocked = blocked

        let fighting = player.secondsSinceHit < GameScene.hintCombatQuiet
            || world.enemyNear(player, within: GameScene.hintCombatRange)

        guard !fighting, !shopPanel.isOpen, chestPanel.openChest == nil else {
            hint.hide()
            return
        }

        // Early only. A lesson has a shelf life: somebody four minutes into a match
        // has either worked the gesture out or settled into playing without it, and
        // a tip arriving then is not teaching, it is interrupting.
        guard world.matchProgress < GameScene.hintWindow else { return }

        // Arriving home with a wall to lay and no idea that is a thing you can do.
        //
        // On the rising edge of being home, not while standing there: a hint is a
        // reaction to a moment. Offered before the selling lesson because it is the
        // one the game cannot teach any other way - selling at least has a hotbar
        // you are already looking at, while building is a tap on a piece of ground.
        let home = world.claim(for: player.team)?
            .contains(GridPoint(containing: player.feet)) == true

        let arrivedHome = home && !wasHome
        wasHome = home

        if arrivedHome, !hasBuilt, buildHintsLeft > 0, !Prefs.taughtBuilding,
           blueprint.hasSlots, world.canBuild(player.team) {
            buildHintsLeft -= 1

            // The words name what the ghosts are doing; they do not end the lesson.
            // Building three walls does that - see tapMap - because the lesson is
            // over when the player can do the thing, not when they have been told
            // about it.
            hint.show("TAP THE WALLS TO BUILD", seconds: 1.6)
            return
        }

        guard stepped, !hasUsedHold, holdHintsLeft > 0, !hint.isShowing,
              !Prefs.taughtSelling else { return }

        // Shown, not learned. The lesson ends when a slot is actually held and
        // sold - see resolveHold - on the same principle the build lesson follows:
        // being told something is not the same as being able to do it.
        holdHintsLeft -= 1
        hint.show(GameScene.holdSells ? "HOLD AN ITEM TO SELL IT"
                                      : "HOLD AN ITEM TO DROP IT")
    }

    /// Points the camera at whoever it should be watching.
    ///
    /// You while you are alive, and while you are dead, whoever killed you - which
    /// is the only interesting thing on the map at that moment and is usually what
    /// you most want to see. It answers the question every death asks and none of
    /// them used to: where did that come from.
    ///
    /// Falls back to your own body if the killer is gone by the time you look. They
    /// can be killed themselves inside your three second wait, and a camera that
    /// insisted on following a corpse would spend the rest of it watching an empty
    /// patch of grass.
    private func aimCamera(in world: World) {
        guard let player = world.localPlayer else { return }

        if player.isAlive { killedBy = nil }

        if !player.isAlive,
           let id = killedBy,
           let killer = world.actors[id],
           killer.isAlive {
            cameraController.follow(killer.position, subject: id, dt: frameDelta)
            return
        }

        cameraController.follow(player.position,
                                subject: world.localPlayerID,
                                dt: frameDelta)
    }

    /// Takes everything the world announced this frame and hands it to whoever
    /// draws it.
    ///
    /// ONE drain, in one place. Every kind of event has to be taken off the world
    /// every frame whether or not anything is currently listening - a sale made
    /// behind a closed shop, an explosion off the edge of the screen - or they pile
    /// up and arrive together the next time somebody looks. One loop that always
    /// runs cannot forget; three renderers that each drain their own kind can.
    ///
    /// Note what is NOT here: the money. The token counter animates on any change
    /// it sees, so the price leaving your purse is already drawn.
    /// A ring of tiles put into the order light should travel round them.
    ///
    /// By angle from the middle, which is the one ordering that works for a shape
    /// nobody specified: a rectangle, an L, a room with a tree for one side. Sorted
    /// rather than walked, so a wall that is two tiles thick somewhere - or that has
    /// an awkward spur - still sweeps once round instead of stalling where the
    /// walk would have had to choose a direction.
    private static func sweptRound(_ ring: Set<GridPoint>) -> [GridPoint] {
        let count = Double(ring.count)
        let mid = ring.reduce(Vec2.zero) { running, tile in
            Vec2(x: running.x + Double(tile.col) / count,
                 y: running.y + Double(tile.row) / count)
        }

        return ring.sorted {
            atan2(Double($0.row) - mid.y, Double($0.col) - mid.x)
                < atan2(Double($1.row) - mid.y, Double($1.col) - mid.x)
        }
    }

    private func dispatch(_ events: [WorldEvent], in world: World) {
        for event in events {
            switch event {
            case .blast(let position):
                bombRenderer.flash(at: position)

            case .jackpot(let position):
                effectsRenderer.jackpot(at: position)

            case .perkStarted(_, let user):
                // The steady rainbow trail comes off the world state a frame later;
                // this is only the switch being thrown, which nothing about the
                // state a second afterwards can show.
                //
                // WHICH perk is thrown away here rather than never sent. The event
                // still carries it because the world knows it and events are how
                // the world says things, and the day there are two perks again this
                // is a one-word change rather than a plumbing job.
                guard let actor = world.actors[user] else { break }
                effectsRenderer.charge(at: actor.position)
                actorRenderer.charge(user)

            case .gas(let position):
                // The cloud itself is drawn from the world every frame; this is the
                // burst that says it arrived, which state alone cannot show.
                effectsRenderer.burst(at: position)

            case .chestCracked(let position, let items):
                // The same burst a crate gets, scaled by what came out of it.
                effectsRenderer.jackpot(at: position)
                bombRenderer.flash(at: position)
                _ = items   // the pile that lands says how much better than this

            case .machineHit(let position):
                // Sparks off the casing rather than a hit marker: a machine being
                // shot has to read differently from a person being shot, or the
                // screen says somebody is in there taking it.
                bombRenderer.flash(at: position)

            case .sealed(let team, let chests):
                // Everybody's, not only yours. Eight bases close over a match and
                // each one is a place that has just become worth breaking into -
                // seeing somebody else's light go round is the game telling you
                // where to take your next bomb, which is information rather than
                // noise. It is off-camera most of the time anyway.
                // The wall AS BUILT, swept round in ring order rather than in the
                // order a plan would have had it laid - because with any shape
                // allowed there may not have been a plan involved at all.
                let ring = world.enclosure(of: team).wall
                guard !ring.isEmpty else { break }
                effectsRenderer.seal(GameScene.sweptRound(ring), chests: chests)

            case .vault(let points, let team, let position):
                // Only your own base, and only when you can see it. Somebody else's
                // wall paying out is a number over a base you are not standing in,
                // and eight of those every twelve seconds is a screen full of
                // arithmetic nobody asked for.
                guard team == world.localPlayer?.team else { break }

                effectsRenderer.earned(at: position, points: points)

                // And once, ever, the sentence that explains what the number is.
                if !Prefs.taughtHolding {
                    Prefs.taughtHolding = true
                    hint.show("YOUR BASE EARNS WHILE IT HOLDS", seconds: 2.0)
                }

            case .sold(let slot, let tokens, let seller):
                guard seller == world.localPlayerID else { break }
                hotbar.reward(slot: slot, tokens: tokens)

            case .purchase(let bought, let buyer):
                guard buyer == world.localPlayerID else { break }

                // A heal you just bought is a heal you are about to want.
                //
                // Buying one and then having to find it in the bar and pick it out
                // before the button appears is two steps of admin between deciding
                // to patch yourself up and doing it - and the second step is
                // invisible, because nothing on screen says the corner button
                // belongs to whichever slot is selected. Bought while hurt, in a
                // shop you opened because you are hurt: arm it.
                if bought.isHealing,
                   let slot = world.localPlayer?.inventory.slots
                       .firstIndex(where: { $0?.type == bought }) {
                    selectedSlot = slot
                }

                // Whichever of the two asked for it answers. The panel's confirm
                // does nothing unless a card was pressed, and the prompt's does
                // nothing unless it is waiting, so neither has to know about the
                // other.
                if quickBuy.awaiting { quickBuy.confirm() }

                // Where the thing you just bought should appear to land: your own
                // bar, converted into the panel's coordinates, because the panel is
                // what animates it. The scene is the only thing that knows where
                // both of those are.
                shopPanel.confirm(
                    flyingTo: shopPanel.convert(.zero, from: hotbar)
                )

            case .kill(let victim, let killer, let position, let points, _):
                // Remembered so the camera can go and watch them - see aimCamera.
                // Taken from the EVENT rather than worked out later, because by the
                // time anything is drawn the body has been stripped and moved home,
                // and nothing left in the world says who did it.
                if victim == world.localPlayerID { killedBy = killer }

                effectsRenderer.mark(killAt: position,
                                     points: points,
                                     mine: killer == world.localPlayerID)
            }
        }
    }

    /// Keeps the placement outline honest.
    ///
    /// Re-asked every frame rather than only when the finger moves, because the
    /// answer changes while standing still: walk two tiles and the spot that was
    /// out of your claim is inside it, and the spot under your own feet stops being
    /// blocked the moment you step off it. An outline that went green at press time
    /// and stayed green would be the same lie the old blind tap told, just prettier.
    private func updatePlacementGhost(with world: World) {
        guard !world.isOver,
              chestPanel.openChest == nil,
              !shopPanel.isOpen,
              let type = placingType,
              let player = world.localPlayer else {
            ghostType = nil
            ghostOrigin = nil
            placementGhost.hide()
            return
        }

        // A fresh selection starts on a spot that works, so picking a machine out
        // shows you where it could go instead of a red rectangle over your feet.
        // Only the FIRST frame - after that it is yours to aim.
        if ghostType != type {
            ghostType = type
            ghostOrigin = PlacementSystem.suggestion(for: type, by: player, in: world)
                ?? PlacementSystem.origin(of: type, tappedAt: player.feet)
        }

        guard let origin = ghostOrigin else {
            placementGhost.hide()
            return
        }

        placementGhost.show(type, at: origin,
                            valid: PlacementSystem.canPlace(type, at: origin,
                                                            by: player, in: world))
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
            hint.hide()
            moveStick.isHidden = true
            moveStick.end()
            aimStick.isHidden = true
            aimStick.end()
            openButton.isHidden = true
            shopButton.isHidden = shopPanel.isOpen

            // The bar stays up for a CHEST, where it is half the transaction - what
            // you can store is what is in it - and goes away for the SHOP, where it
            // is nothing but clutter behind a panel. That difference is the whole
            // reason the shop stopped being two interfaces at once.
            hotbar.isHidden = shopPanel.isOpen

            // And the standings go with it. The panel is as wide as a small phone
            // allows, so its top-right corner and the leaderboard's bottom-left
            // corner want the same points - and of the two, a table of scores is
            // the one nobody is reading while they shop.
            leaderboard.isHidden = shopPanel.isOpen
            return
        }

        shopButton.isHidden = false
        hotbar.isHidden = false
        leaderboard.isHidden = false


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
            // Yours is storage; anybody else's is a crate with a lid on it. Two
            // different verbs from one button, decided by whose base you are
            // standing in - which is the only thing a player needs to know about
            // the difference.
            wanted = chest.owner == player.team ? .chest(chest.id) : .raid(chest.id)
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
            // The crate glyph, not the chest one, because the ACT is opening a
            // crate. A button that looks like storage and behaves like a crowbar
            // would be the interface lying about the only irreversible thing on
            // this screen.
            case .raid:    openButton.setGlyph(Glyphs.lootbox)
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

        // The first thing this game has ever remembered about how a match WENT.
        // A high-water mark and a count, so a bad match can never take anything
        // away - see Prefs, and the menu, which reads both.
        if let team = world.localPlayer?.team {
            Prefs.finishedMatch(scoring: world.score(for: team))
        }

        // Everything you could press goes, including the chest panel if you happened
        // to have your head in one when the whistle went.
        chestPanel.close()
        shopPanel.close()

        // Put the standings back if the shop had them hidden when the whistle
        // went. The results panel covers them either way, but leaving a control's
        // visibility owned by a screen that no longer exists is how the aim stick
        // once went missing for a whole match.
        leaderboard.isHidden = false
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

    /// Puts a heal in your hand the moment somebody shoots you, if your hand was
    /// empty.
    ///
    /// On the HIT, not on being hurt. The difference matters: "hurt with nothing
    /// selected" is a state that lasts until you patch up, so arming from it would
    /// override the player every time they tried to put the heal away. Being shot
    /// is an instant, it happens exactly when the answer to "what do I want in my
    /// hand" changes, and it leaves anybody who deselects on purpose alone until
    /// the next bullet.
    ///
    /// It never overrides a choice - a bomb you had ready stays ready - and WHICH
    /// heal is ConsumableSystem's answer, the same one the bots get, so the game
    /// cannot arm one thing and recommend another.
    private func armHealingIfHit(in world: World) {
        guard let player = world.localPlayer, player.isAlive else {
            lastLocalHealth = nil
            return
        }

        defer { lastLocalHealth = player.health }

        guard let previous = lastLocalHealth, player.health < previous,
              selectedSlot == nil,
              chestPanel.openChest == nil, !shopPanel.isOpen,
              let heal = ConsumableSystem.bestHeal(for: player) else { return }

        selectedSlot = heal
    }

    /// Puts a heal in your hand the moment you pick one up, if your hand was empty.
    ///
    /// The other half of arming on a hit, and the same rule: fill an empty hand,
    /// never override a choice. Walking over a bandage and having it land silently
    /// in a slot you then have to find is the same two-step problem tapping solved
    /// at low health - except this one happens when you are fine, which is exactly
    /// when you would rather it was already sorted.
    ///
    /// Noticed rather than announced. Nothing in Core has to send a "you picked up
    /// a bandage" message: a slot that holds more healing than it did last frame IS
    /// the event, which is the same trick every renderer in this project uses.
    private func armHealingWhenFound(in world: World) {
        guard let player = world.localPlayer, player.isAlive else {
            lastHealingPerSlot = []
            return
        }

        let healing = player.inventory.slots.map { slot -> Int in
            guard let stack = slot, stack.type.isHealing else { return 0 }
            return stack.count
        }

        defer { lastHealingPerSlot = healing }

        guard lastHealingPerSlot.count == healing.count,
              selectedSlot == nil,
              chestPanel.openChest == nil, !shopPanel.isOpen else { return }

        // The slot that GAINED, so a bandage picked up while a medkit sits two
        // slots along arms the bandage - the thing that just happened rather than
        // whichever heal happens to be best.
        for slot in healing.indices where healing[slot] > lastHealingPerSlot[slot] {
            selectedSlot = slot
            return
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
        // Once the whistle has gone there are two things left to press.
        if world != nil, world.isOver {
            for touch in touches {
                let point = touch.location(in: results)

                // Play again first: it is the bigger target and the common answer,
                // and asking about it first means an overlap can only ever resolve
                // towards another match rather than out of the game.
                if results.isPlayAgain(atLocalPoint: point) {
                    restart()
                    return
                }

                if results.isMenu(atLocalPoint: point) {
                    openMenu()
                    return
                }
            }
            return
        }

        for touch in touches {
            // BEFORE the move stick, which otherwise swallows it: the prompt sits
            // under the health panel, and on a small phone the stick's grab circle
            // reaches that far up the left-hand side. Same trade the item button
            // makes against the aim stick - a small target that is only there for a
            // few seconds beats a large forgiving one that is always there, and the
            // stick loses nothing it needs.
            if quickBuy.isPressed(atLocalPoint: touch.location(in: quickBuy)),
               let type = quickBuy.offer {
                guard let player = world.localPlayer,
                      ShopSystem.canBuy(type, actor: player, in: world) else {
                    // Cannot afford it, or nowhere to put it. Say so and leave the
                    // offer up: both of those can change in a few seconds.
                    quickBuy.refuse()
                    continue
                }

                // Sent, not spent. The prompt waits for the purchase to come back
                // as an event before it celebrates - it used to vanish on the tap,
                // which meant the one moment worth showing happened to a node that
                // was already fading out.
                queuedCommands.append(.buyItem(type))
                quickBuy.arm()
                continue
            }

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
                case .raid(let id):
                    // No panel and no choosing. It bursts, a couple of things land
                    // on the grass, and picking them up is the ordinary business of
                    // walking over loot while somebody shoots at you.
                    queuedCommands.append(.raidChest(chest: id))

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

            // Something out of the bag wants a tile, so a finger on the map is
            // aiming it rather than tapping. It places on release, and only if the
            // outline is green - which is why it can be dragged around first.
            //
            // One finger owns the aim, like every other control on this screen, and
            // any others are swallowed rather than passed on. Taking a second one
            // would orphan the first, whose release would then go nowhere; letting
            // it through to the map would arm a HOLD, and a second thumb quietly
            // demolishing a wall while you line up a machine is not a gesture
            // anybody would go looking for.
            if placingType != nil {
                if placingTouch == nil {
                    placingTouch = touch
                    aimPlacement(at: touch.location(in: worldLayer))
                }
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

        if let active = placingTouch, touches.contains(active) {
            aimPlacement(at: active.location(in: worldLayer))
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

        if let active = placingTouch, touches.contains(active) {
            placingTouch = nil
            commitPlacement()
        }

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

        // A cancelled placing finger leaves the outline where it was and places
        // nothing. The item is still picked out, so it can be aimed again - a call
        // arriving mid-gesture should not cost you a machine, and it should not
        // spend one either. Note this is NOT done in releaseControls: that runs
        // first on release too, and clearing the finger there would unset it before
        // the release could act on it.
        if let active = placingTouch, touches.contains(active) {
            placingTouch = nil
        }

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

    /// What a long press on a hotbar slot does.
    ///
    /// Both answers are built and only one is wired up, which is deliberate. This
    /// gesture used to throw the item on the floor, and dropping is still the
    /// honest reading of it - you can pick the thing back up, you can hand it to
    /// somebody, and nothing about it is irreversible. Selling is the more USEFUL
    /// reading: what a full bag is actually full of is junk, and a bandage on the
    /// grass helps nobody while three tokens do.
    ///
    /// Which of those feels better is not a question anybody can answer by
    /// thinking about it, so the drop path stays exactly where it is - Command,
    /// LootSystem and all - and this one line decides which of them a hold means.
    private static let holdSells = true

    /// Turns a finger that has stayed put into the second meaning of that gesture:
    /// take your own wall back down, or turn the item into tokens.
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
            queuedCommands.append(GameScene.holdSells ? .sellItem(slot: slot)
                                                      : .dropItem(slot: slot))
            hotbar.endHold()

            // Somebody who has done it once knows how to do it - this match, and
            // every match after it.
            hasUsedHold = true
            Prefs.taughtSelling = true
            hint.hide()
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
        view.presentScene(GameScene.newGameScene(),
                          transition: .fade(withDuration: 0.25))
    }

    /// Back to the title screen.
    ///
    /// The other half of having a menu at all: a way in is only a way in if there
    /// is also a way back, and PLAY AGAIN on its own made the results screen a
    /// door that only opened one way.
    private func openMenu() {
        guard let view else { return }
        view.presentScene(MenuScene.newMenuScene(),
                          transition: .fade(withDuration: 0.35))
    }

    /// Picks a slot out, or puts it back.
    ///
    /// Nothing is spent by a tap on the hotbar any more - what acts on the picked
    /// item is either the button or a tap on the map, and which of those belongs to
    /// the item rather than to this screen (ItemType.use). Tapping the same slot
    /// again puts it back, because changing your mind should not cost you the item.
    private func tapHotbar(_ slot: Int) {
        guard let player = world.localPlayer,
              let stack = player.inventory.stack(at: slot) else {
            selectedSlot = nil
            return
        }

        // Hurt, and holding a bandage: the tap IS the heal.
        //
        // Two presses and an invisible rule stood between deciding to patch up and
        // patching up - pick the slot, then find the button above the corner, which
        // nothing on screen connects to the slot you picked. Below the threshold
        // there is exactly one reason anybody touches a bandage, so the game stops
        // asking. ConsumableSystem answers whether it can actually be spent, the
        // same way it answers for the button and for a bot.
        if stack.type.isHealing,
           Double(player.health) < Double(player.maxHealth) * GameConfig.Player.tapHealBelow,
           ConsumableSystem.canUse(slot: slot, actor: player) {
            queuedCommands.append(.useItem(slot: slot))
            hotbar.acknowledge(slot)
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
        // Nothing about the bar here any more. It used to be the sell counter while
        // the shop was up, which made this screen two interfaces with two rules
        // stacked on each other; selling is a hold on the bar during play now, and
        // the bar itself is hidden behind the panel. Every tap on this screen is
        // either a card, the way out, or outside.
        let point = touch.location(in: shopPanel)

        // Anywhere off the panel shuts it, the same way tapping off a menu does
        // everywhere else. The BACK button stays - it is the obvious way out, and
        // the one somebody looks for before they think to try the background.
        guard shopPanel.contains(localPoint: point) else {
            shopPanel.close()
            return
        }

        if shopPanel.isBackButton(atLocalPoint: point) {
            shopPanel.close()
            return
        }

        if let item = shopPanel.item(atLocalPoint: point) {
            // Asked HERE as well as by the simulation, because the card no longer
            // greys out for a bag with no room in it - so a tap can now be refused
            // by something the shop never showed you. Same answer either way; this
            // one just gets to say no out loud instead of the command quietly
            // going nowhere.
            guard let player = world.localPlayer,
                  ShopSystem.canBuy(item, actor: player, in: world) else {
                shopPanel.refuse()
                return
            }

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

        // And anywhere else shuts it, the way the shop does.
        //
        // This used to be ignored on the grounds that a stray thumb should not
        // throw you out of a chest you are halfway through - which was the right
        // instinct and the wrong conclusion. The two panels behaving differently
        // is worse than either behaviour: having learned that tapping the map
        // closes the shop, you try it on a chest and nothing happens, so you go
        // looking for the button you had stopped needing. And the cost of being
        // wrong here is one tap to reopen, since the chest is standing right there.
        if !chestPanel.contains(localPoint: touch.location(in: chestPanel)) {
            chestPanel.close()
        }
    }

    /// Asks for a block. Whether one appears is BuildSystem's call, not the
    /// scene's, and bombs are thrown from the hotbar like everything else you carry.
    ///
    /// Placing a chest or a machine no longer arrives here. It used to: a tap was
    /// read straight into a placement, which is why putting a machine down felt
    /// like a coin flip - the footprint went up and to the right of the finger,
    /// nothing showed you where it would land, and a refusal looked exactly like
    /// the game ignoring you. That is a drag with an outline on it now, below.
    /// How far outside a crate a tap still counts as being on it, in tiles.
    ///
    /// A crate is under a tile across and a fingertip is wider than that, so the
    /// hitbox alone would refuse taps that visibly landed on the thing. Generous
    /// enough to forgive a finger, small enough that it cannot swallow a tap meant
    /// for a wall a tile away.
    private static let tapSlop: Double = 0.35

    private func tapMap(at pointInWorld: CGPoint) {
        // A crate you are standing at opens when you tap IT, not only when you find
        // the button in the corner.
        //
        // The button is not going anywhere - it is faster once you know it is
        // there, it works while your thumb is on the stick, and it is the only way
        // to open something you cannot see. But "walk up to the thing and touch the
        // thing" is what a person tries first, and until now that did nothing at
        // all, which reads as the game ignoring the tap rather than as a control
        // waiting to be discovered elsewhere.
        //
        // Checked before the build command below rather than after, because this
        // function's first act is to queue one, and a crate standing on your own
        // claim would otherwise eat the tap as a wall.
        if let player = world.localPlayer, player.isAlive,
           let box = world.reachableLootbox(for: player),
           box.hitbox.expanded(by: GameScene.tapSlop)
               .contains(GridGeometry.position(for: pointInWorld)) {
            queuedCommands.append(.openLootbox)
            return
        }

        let tile = GridGeometry.gridPoint(for: pointInWorld)
        queuedCommands.append(.placeBlock(tile))

        // And then say what will happen to it, which the map never used to. The
        // answer comes from BuildSystem rather than from a copy of its rules kept
        // here, so the outline that lights up, the brick that pops and the wall
        // that appears are all one decision seen three times.
        guard let player = world.localPlayer else { return }

        if BuildSystem.canPlace(at: tile, by: player, in: world) {
            blueprint.fill(at: tile)
            hasBuilt = true
            wallsBuilt += 1

            // The ghosts themselves no longer stand down - see BlueprintRenderer,
            // which shows where the wall goes for the whole match rather than for
            // the first three taps. What is still learned once is the TEXT hint
            // above them, which is a sentence and only worth reading once.
            if wallsBuilt >= GameScene.wallsToLearn { Prefs.taughtBuilding = true }
            return
        }

        // Only inside your own ground. A red flash out on the open map would be the
        // game telling you off for tapping the scenery.
        guard world.claim(for: player.team)?.contains(tile) == true else { return }

        blueprint.refuse(at: tile)

        // One refusal has a reason worth spelling out, because it is temporary and
        // nothing else on screen mentions it: the quiet after a raid, which exists
        // so a raider can still get back out through the hole they made.
        if !world.canBuild(player.team) {
            hint.show("WALLS ARE DOWN FOR A MOMENT")
        }
    }

    // MARK: - Aiming something onto the map

    /// Points the outline at a spot on the map.
    ///
    /// Where the footprint goes is PlacementSystem's answer, not this file's, so
    /// what is drawn under the finger is the same rectangle the placement will use.
    private func aimPlacement(at pointInWorld: CGPoint) {
        guard let type = placingType else { return }
        ghostOrigin = PlacementSystem.origin(
            of: type, tappedAt: GridGeometry.position(for: pointInWorld))
    }

    /// Lets go of it.
    ///
    /// A refusal keeps both the item and the aim. The outline was already red, so
    /// nothing is being explained after the fact - and having to pick the machine
    /// back out of the bag to try one tile further left would be a punishment for
    /// the screen's own vagueness.
    private func commitPlacement() {
        // A panel that opened under the finger takes the gesture with it. Placing
        // something you can no longer see the map for would be the same class of
        // fault as the corner button that stayed hidden: an input outliving the
        // state it was made in.
        guard chestPanel.openChest == nil, !shopPanel.isOpen, !world.isOver else { return }

        guard let type = placingType,
              let origin = ghostOrigin,
              let player = world.localPlayer,
              PlacementSystem.canPlace(type, at: origin, by: player, in: world),
              let command = PlacementSystem.command(for: type, at: origin) else { return }

        queuedCommands.append(command)
        selectedSlot = nil
        ghostOrigin = nil
    }
}

private func - (a: CGPoint, b: CGPoint) -> CGPoint {
    CGPoint(x: a.x - b.x, y: a.y - b.y)
}
#endif
