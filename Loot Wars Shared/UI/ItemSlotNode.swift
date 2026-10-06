//
//  ItemSlotNode.swift
//  Loot Wars
//
//  One square holding one stack: the panel, the item, and the count badge.
//
//  Extracted when the chest panel arrived and turned out to need exactly what the
//  hotbar already drew. Two copies of this would have looked identical on the day
//  they were written and drifted apart by the second time either was touched -
//  and a chest whose slots do not look like your own slots is a chest nobody
//  believes they can move things into.
//
//  Every measurement is a fraction of the slot's side, so a big slot in a chest
//  panel and a small one in the hotbar are the same drawing at two sizes. At the
//  hotbar's 66pt these reproduce the numbers originally taken off the reference
//  art - a 10pt inset, an 11.5pt badge radius, a 3pt outline.
//

import SpriteKit

final class ItemSlotNode: SKNode {

    /// How much bigger a picked-out slot sits than its neighbours, and how far a
    /// held one is squeezed. Both are scales on the whole slot rather than badges
    /// added to it, so they compose: a selected slot being held squeezes from its
    /// larger size and springs back to it.
    private static let selectedScale: CGFloat = 1.14
    private static let heldScale: CGFloat = 0.8

    private let side: CGFloat
    private var selected = false

    private let panel: SKShapeNode

    /// A red wash over the whole slot, for a tap that was refused.
    ///
    /// Its own node rather than a colour on the panel, which is the lesson the
    /// shop's card learned: the panel is redrawn whenever the slot's contents
    /// change, and a fill being animated on it would be overwritten mid-fade.
    private let flash: SKShapeNode

    /// A pool of the item's rarity colour, BEHIND the item.
    ///
    /// Behind, and not a coloured plate, which was the first attempt: filling the
    /// slot with the colour turned a row of four into a row of flat swatches, and
    /// the item - the thing you are actually reading - had to compete with its own
    /// label. A glow sits under the artwork the way it sits under a dropped item on
    /// the map, so the two read as the same language, and the slot stays a slot.
    private let glow = SKSpriteNode(texture: GlowArt.pool)

    private let icon = SKSpriteNode()

    /// Sparkles, shown only on a power-up. Built once and hidden, rather than made
    /// and thrown away as the slot's contents change: a hotbar slot is rewritten
    /// every time anything at all happens to your inventory, and a node built that
    /// often would restart its own twinkle constantly and never finish one.
    private let enchant: EnchantNode

    /// Shown when tapping this slot will spend what is in it rather than pick it
    /// out - see GameScene.tapHotbar. A ring rather than a colour on the slot
    /// itself, because every other thing a slot can say about its contents is
    /// already said in colour: the rarity pool, the sell tab, the dimming.
    private let urgentRing: SKShapeNode

    // The slot's own background in the item's rarity colour, with a matching border.
    private let rarityPlate: SKShapeNode

    private let badge = SKNode()
    private let count = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// The SELL button, shown only while the shop is open.
    ///
    /// A green tab in the top-right corner - opposite the count badge - carrying a
    /// plus, a number and a token.
    ///
    /// Third attempt at this, and the two failures are worth keeping. A plain price
    /// in the corner said what a thing was worth without ever saying it could be
    /// sold, so it read as a caption. A green bar across the FOOT of the slot said
    /// it loudly and covered the bottom third of the item doing it - and an item
    /// you cannot see is a poor thing to be deciding about. The corner is the only
    /// place on a 66-point square that is both obvious and empty, and the badge
    /// already proves it works: nobody has ever failed to notice a stack count.
    private let sellButton = SKNode()
    private let price = SKLabelNode(fontNamed: "AvenirNext-Bold")

    /// Local origin is the centre of the slot.
    init(side: CGFloat) {
        self.side = side
        enchant = EnchantArt.overlay(box: side * 0.85)

        // Built before super.init, because it is a constant stored property and
        // Swift wants every one of those settled before the superclass runs. It is
        // only decorated and parented afterwards, where self exists.
        panel = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                         width: side, height: side),
                            cornerRadius: side * 0.182)

        rarityPlate = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                               width: side, height: side),
                                  cornerRadius: side * 0.182)

        urgentRing = SKShapeNode(rect: CGRect(x: -side / 2 - 2, y: -side / 2 - 2,
                                              width: side + 4, height: side + 4),
                                 cornerRadius: side * 0.2)

        flash = SKShapeNode(rect: CGRect(x: -side / 2, y: -side / 2,
                                         width: side, height: side),
                            cornerRadius: side * 0.182)
        super.init()

        panel.fillColor = RenderPalette.hotbarSlot
        panel.strokeColor = .clear
        addChild(panel)

        // Over everything, including the count badge and the urgent ring: a refusal
        // is about the slot as a whole and should not be drawn underneath half of
        // what is in it.
        // Colourless until something happens to it: refuse and confirm each set
        // their own, so the plate is not secretly red between answers.
        flash.alpha = 0
        flash.zPosition = 5
        addChild(flash)

        rarityPlate.lineWidth = 3
        rarityPlate.zPosition = 0.2
        rarityPlate.isHidden = true
        addChild(rarityPlate)

        glow.size = CGSize(width: side * 1.05, height: side * 1.05)
        glow.colorBlendFactor = 1
        glow.zPosition = 0.5
        glow.isHidden = true
        addChild(glow)

        urgentRing.fillColor = .clear
        urgentRing.strokeColor = RenderPalette.placementValid
        urgentRing.lineWidth = 3
        urgentRing.zPosition = 4
        urgentRing.isHidden = true
        addChild(urgentRing)

        icon.zPosition = 1
        icon.isHidden = true
        addChild(icon)

        enchant.zPosition = 1.5
        enchant.isHidden = true
        addChild(enchant)

        let radius = side * 0.174
        let inset = side * 0.076

        badge.position = CGPoint(x: -side / 2 + inset, y: side / 2 - inset)
        badge.zPosition = 2
        badge.isHidden = true
        addChild(badge)

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.fillColor = RenderPalette.countBadge
        circle.strokeColor = .black
        circle.lineWidth = side * 0.045
        badge.addChild(circle)

        count.fontSize = radius * 1.22
        count.fontColor = .white
        count.horizontalAlignmentMode = .center
        count.verticalAlignmentMode = .center
        count.zPosition = 1
        badge.addChild(count)

        // Overhangs its corner slightly, which is what stops it reading as part of
        // the artwork underneath.
        let tabHeight = side * 0.28
        let tabWidth = side * 0.66

        sellButton.position = CGPoint(
            x: side / 2 - tabWidth / 2 + side * 0.04,
            y: side / 2 - tabHeight / 2 + side * 0.04
        )

        sellButton.zPosition = 3
        sellButton.isHidden = true
        addChild(sellButton)

        let pill = SKShapeNode(
            path: CGPath(
                roundedRect: CGRect(
                    x: -tabWidth / 2,
                    y: -tabHeight / 2,
                    width: tabWidth,
                    height: tabHeight
                ),
                cornerWidth: tabHeight / 2,
                cornerHeight: tabHeight / 2,
                transform: nil
            )
        )

        // No outline. A stroke round something this small is most of its width, and
        // four of them in a row read as a fence rather than as four buttons - the
        // green is doing the work and does not need help.
        pill.fillColor = RenderPalette.sellButton
        pill.strokeColor = .clear
        sellButton.addChild(pill)

        price.fontSize = tabHeight * 0.66
        price.fontColor = .white
        price.horizontalAlignmentMode = .center
        price.verticalAlignmentMode = .center
        price.position = CGPoint(x: -tabWidth * 0.16, y: 0)
        price.zPosition = 1
        sellButton.addChild(price)

        let token = SKSpriteNode(texture: ItemArt.texture(for: .token(1)))
        token.size = ItemArt.size(
            of: ItemArt.texture(for: .token(1)),
            fittingInto: tabHeight * 0.8
        )
        token.position = CGPoint(x: tabWidth * 0.26, y: 0)
        token.zPosition = 1
        sellButton.addChild(token)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Where the slot rests: bigger while it is the one picked out.
    private var restingScale: CGFloat {
        selected ? ItemSlotNode.selectedScale : 1
    }

    /// Squeezes over the length of a hold, so the press has somewhere to go while
    /// the finger is down.
    ///
    /// Not decoration. Four tenths of a second with no response at all reads as a
    /// tap that failed to register, and the player lifts off just before the thing
    /// they were waiting for would have happened.
    func beginHold(duration: TimeInterval) {
        removeAction(forKey: "scale")
        run(.scale(to: restingScale * ItemSlotNode.heldScale, duration: duration),
            withKey: "hold")
    }

    func endHold() {
        removeAction(forKey: "hold")
        settle()
    }

    /// The picked-out slot simply sits larger than the others.
    ///
    /// It used to wear a ring. Growing it says the same thing without adding a
    /// second colour to a bar that is already carrying item art and count badges -
    /// and it reads at a glance on a screen held at arm's length, which an outline
    /// four points wide does not.
    func setSelected(_ selected: Bool) {
        guard selected != self.selected else { return }
        self.selected = selected
        removeAction(forKey: "hold")
        settle()
    }

    /// The top two rungs breathe. Nothing else does.
    ///
    /// A hotbar where every slot pulses is a hotbar nobody can read, and this game
    /// has already been through one round of too much animation. But a Mythical
    /// turning up is the best thing that happens to anybody in a match, and a
    /// still gold glow says exactly as much as a still grey one. So the movement is
    /// reserved for the two rarities that have earned it, and it is slow - nearly
    /// three seconds a cycle - so it reads as something alight rather than as a
    /// notification asking to be dismissed.
    ///
    /// Mythical rather than Legendary, and it is the same two rungs it always was.
    /// The ladder lost its two middle rungs and the gear names slid up to meet the
    /// colours, so the top pair is now called Mythical and Cosmic. Left at
    /// Legendary this would have been three rungs plus the stink bomb - which is
    /// the "every slot pulses" failure it exists to prevent.
    private func breathe(for rarity: Rarity) {
        glow.removeAction(forKey: "rare")
        guard rarity >= .mythical else { return }

        glow.run(.repeatForever(.sequence([
            .group([.fadeAlpha(to: 1.0, duration: 1.4), .scale(to: 1.12, duration: 1.4)]),
            .group([.fadeAlpha(to: 0.8, duration: 1.4), .scale(to: 1.0, duration: 1.4)])
        ])), withKey: "rare")
    }

    /// Rings the slot green while what is in it is worth tapping.
    ///
    /// It breathes, which is the same signal the menu's button and the build ghost
    /// use: on a screen where everything else is still, the thing that moves is the
    /// thing to press.
    ///
    /// An INVITATION now rather than a warning. It used to say "a tap here is no
    /// longer free", which was the important half while most taps merely selected;
    /// every tap spends something now, so what is worth saying is which one is
    /// worth spending - see HotbarNode.update.
    func setUrgent(_ urgent: Bool) {
        guard urgent != !urgentRing.isHidden else { return }

        urgentRing.removeAllActions()
        urgentRing.isHidden = !urgent

        guard urgent else { return }

        urgentRing.alpha = 0.35
        urgentRing.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.95, duration: 0.45),
            .fadeAlpha(to: 0.35, duration: 0.55)
        ])))
    }

    /// A quick squeeze that ends back at this slot's own resting size.
    ///
    /// Not a plain scale action from outside: a selected slot rests at 1.14 and a
    /// held one is on its way to 0.8, and anything that ends at a flat 1 would
    /// quietly resize whichever slot you had picked out. It also takes the same
    /// key, so a squeeze and a settle cannot both be running.
    func flinch() {
        removeAction(forKey: "scale")
        zRotation = 0
        run(.sequence([
            .scale(to: restingScale * 0.86, duration: 0.07),
            .scale(to: restingScale, duration: 0.14)
        ]), withKey: "scale")
    }

    /// The tap was refused: wobble, and wash the slot red.
    ///
    /// The same pair the shop answers a card with, and deliberately the same pair
    /// rather than a second language - somebody who has learned that a red shake
    /// means "no" in one place has learned it everywhere.
    ///
    /// A wobble rather than a slide, for the reason the shop's version records: the
    /// bar owns slot POSITION, so a moveBy interrupted by a relayout could leave a
    /// slot parked where it used to be. Rotation and scale are nobody else's.
    ///
    /// It takes the "scale" key, which is what settle, flinch and a hold all use,
    /// so a refusal and a settle can never run together. The zRotation reset in
    /// each of those is what straightens a wobble that one of them cut short.
    func refuse() {
        wobble(washedIn: RenderPalette.placementBlocked, strength: 0.55)
    }

    /// The tap went through: the same wobble, washed green.
    ///
    /// ONE MOVEMENT FOR BOTH ANSWERS and the colour is what tells them apart, which
    /// is the rule the shop's cards already follow and is worth restating here
    /// because it looks like laziness and is not. What the wobble says is "your tap
    /// landed on THIS slot", which is equally true of a yes and a no; the eye reads
    /// a wash of green or red far faster than it reads any difference between two
    /// wobbles, and two motions would mean learning two motions.
    ///
    /// Stronger than the refusal. Taking something out of a chest is the thing you
    /// opened it to do, and the good answer should not be the quieter one - the
    /// same correction the shop's confirm records.
    func confirm() {
        wobble(washedIn: RenderPalette.placementValid, strength: 0.7)
    }

    /// The shake both answers share.
    ///
    /// A wobble rather than a slide, for the reason the shop's version records: the
    /// bar and the chest panel own slot POSITION, so a moveBy interrupted by a
    /// relayout could leave a slot parked where it used to be. Rotation and scale
    /// are nobody else's.
    ///
    /// It takes the "scale" key, which is what settle, flinch and a hold all use,
    /// so an answer and a settle can never run together. The zRotation reset in
    /// each of those is what straightens a wobble that one of them cut short.
    private func wobble(washedIn colour: SKColor, strength: CGFloat) {
        removeAction(forKey: "scale")
        removeAction(forKey: "hold")
        zRotation = 0

        run(.sequence([
            .group([.rotate(toAngle: -0.085, duration: 0.05),
                    .scale(to: restingScale * 0.94, duration: 0.05)]),
            .rotate(toAngle: 0.085, duration: 0.09),
            .rotate(toAngle: -0.05, duration: 0.07),
            .group([.rotate(toAngle: 0, duration: 0.06),
                    .scale(to: restingScale, duration: 0.06)])
        ]), withKey: "scale")

        flash.removeAllActions()
        flash.fillColor = colour
        flash.strokeColor = colour
        flash.alpha = strength
        flash.run(.fadeAlpha(to: 0, duration: 0.42))
    }

    /// What is drawn in this slot right now, so a panel can fly a copy of it
    /// somewhere. Nil for an empty slot.
    var artwork: (texture: SKTexture, size: CGSize)? {
        guard !icon.isHidden, let texture = icon.texture else { return nil }
        return (texture, icon.size)
    }

    private func settle() {
        removeAction(forKey: "scale")
        zRotation = 0
        run(.scale(to: restingScale, duration: 0.12), withKey: "scale")
    }

    /// Shows or hides the sell button, and what it would pay.
    func setPrice(_ tokens: Int?) {
        guard let tokens, tokens > 0 else {
            sellButton.isHidden = true
            return
        }

        sellButton.isHidden = false
        price.text = "+\(tokens)"
    }

    /// Draws what is in the slot, or empties it.
    ///
    /// No dimming, here or anywhere else. A slot you cannot use right now looks
    /// exactly like one you can, and says so when it is tapped - see
    /// Actor.canUse for what a tap is allowed to do, and refuse() above for what a
    /// tap it will not allow gets.
    func show(_ stack: ItemStack?) {
        guard let stack else {
            icon.isHidden = true
            enchant.isHidden = true
            badge.isHidden = true
            sellButton.isHidden = true

            // An empty slot is a hole in the bar, not an item of no value.
            rarityPlate.isHidden = true
            glow.isHidden = true
            glow.removeAllActions()
            return
        }

        // The plate in the interface's dark slate for a common item, the glow in
        // the rarity's own colour - a smoked tile with a soft light in it, rather
        // than a light grey tile or a dark smudge. See RenderPalette.interfaceColour.
        let plate = RenderPalette.interfaceColour(of: stack.type.rarity)
        rarityPlate.isHidden = false
        rarityPlate.fillColor = plate.withAlphaComponent(0.5)
        rarityPlate.strokeColor = plate

        glow.isHidden = false
        glow.color = RenderPalette.colour(of: stack.type.rarity)
        glow.alpha = 0.95
        breathe(for: stack.type.rarity)

        let texture = ItemArt.texture(for: stack.type)
        icon.texture = texture
        icon.size = ItemArt.size(of: texture, fittingInto: side - side * 0.152)
        icon.isHidden = false
        icon.alpha = 1.0

        // A perk shows its sparkles whether or not one is already running. It used
        // to fade them, back when the slot faded with them; a power-up in the bar
        // is a power-up in the bar, and what has changed when you cannot use it is
        // not the item, it is that you are busy being powerful.
        enchant.isHidden = !stack.type.isEnchanted
        enchant.alpha = 1.0

        if stack.type.isEnchanted { enchant.tint(for: stack.type) }

        // A badge on a single item is noise - it only earns its place once there
        // is more than one.
        badge.isHidden = stack.count <= 1
        count.text = "\(stack.count)"
    }
}
