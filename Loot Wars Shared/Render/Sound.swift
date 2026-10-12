//
//  Sound.swift
//  Loot Wars
//
//  Every noise the game makes, and what each one is for.
//
//  One enum rather than filenames scattered through the scene, for the same reason
//  RenderPalette exists: a string typed at the call site is a sound that silently
//  stops playing the day somebody renames the file, and nothing anywhere lists what
//  the game is supposed to sound like.
//
//  TWO KINDS, and the difference is the whole design. An interface sound belongs to
//  the person holding the phone - a tap, a purchase, the shop opening - and plays
//  dead centre at full volume because it did not happen anywhere, it happened to
//  YOU. A world sound happened at a place, and is heard from where you are standing:
//  quieter with distance, and off to whichever ear it is on. That is why a bomb
//  three bases away is worth hearing at all, and why it should not be as loud as the
//  one at your feet.
//

import Foundation

enum Sound: CaseIterable {

    // MARK: - Things you did

    /// The match starting, off the menu's play button.
    case play
    /// Something bought with tokens that is not gear.
    case purchase
    /// Gear going on - bought, or picked up off the grass and worn.
    case upgrade
    /// Something going into the bag.
    case collect
    /// Opening the shop, or somebody's chest.
    case select
    /// Moving along the hotbar.
    case tap
    /// A supply spent patching yourself up.
    case heal
    /// Backing out of a panel.
    case exit
    /// Something the game refused to do.
    case error
    /// A line of text arriving to tell you something.
    case notification

    // MARK: - Things that happened

    /// A blaster firing, anybody's.
    case pop
    /// A bomb going off, anywhere on the map.
    case bomb
    /// A wall closing for the first time, anybody's.
    case complete
    /// A foot landing on grass: the plains and the forest. Played on the beat
    /// the figure lands on - see ActorRenderer.footfall.
    case stepGrass
    /// A foot landing on snow.
    case stepSnow
    /// A wall going up, anybody's. The last one in a base also plays complete.
    case block
    /// An arcade machine smashed, anybody's.
    case arcadeBreak
    /// A thrown bomb's fuse sparkling on its way through the air. About as long
    /// as the longest throw, so it runs out as the bomb lands and goes off.
    case fuse
    /// A stink bomb going off: a pop, a fart, then the hiss of the cloud fading
    /// out. One file, mixed from the Stink Bomb, Fart and Fume recordings.
    case stinkGas
    /// A crate on the map opened, anybody's. Not supply drops, which have their own.
    case lootbox
    /// Tokens picked up off the ground. Yours only.
    case token
    /// A turret firing. Its own sound, lower and heavier than a blaster's pop,
    /// so you can tell a turret has opened up on you without looking.
    case turretShot
    /// Somebody knocked out. Full volume for your own kill, heard from where it
    /// happened for everybody else's.
    case elimination
    /// An item sold back for tokens.
    case sell
    /// An arcade hitting the jackpot, anybody's.
    case jackpot
    /// Your shot landed on somebody. Nine takes cut from Hitmarkers.mp3, pitched
    /// down about three semitones and softened on top, each trimmed to start on
    /// its first sound so it lands on the same frame as the
    /// hit, and a different one each time so a burst does not sound like a loop.
    case hitMarker
    /// You took damage. Yours only. The classic hit marker sounds, as recorded:
    /// nine takes cut from Hitmarkers.mp3, not pitched or softened (the hit
    /// markers for YOUR shots are the pitched-down, softened versions).
    case damage
    /// A shot striking an arcade, a chest, a turret or a wall: a dull thunk,
    /// so hitting furniture sounds different from hitting a person. Four takes:
    /// the hit marker recordings pitched well down and muffled.
    case objectHit
    /// A chest broken open in a raid, anybody's.
    case chestBreak
    /// A turret destroyed, anybody's.
    case turretBreak
    /// You were knocked out. Two takes.
    case playerElimination
    /// A supply drop hitting the ground, timed to the moment it lands.
    case supplyDrop
    /// The clock in the last ten seconds, alternating tick and tock. Both cut
    /// from Time.mp3.
    case tick
    case tock
    /// You came first: the fanfare on the results screen as the gold trophy
    /// pops up.
    case victory

    /// The file, split because they are not all the same format.
    var file: (name: String, kind: String) {
        switch self {
        case .play:     return ("Play", "mp3")
        case .purchase: return ("Purchase", "mp3")
        case .upgrade:  return ("Upgrade", "wav")
        case .collect:  return ("Collect", "wav")
        case .select:   return ("Select", "mp3")
        case .tap:      return ("Tap", "wav")
        case .heal:     return ("Heal", "wav")
        case .exit:     return ("Exit", "mp3")
        case .error:    return ("Error", "mp3")
        case .notification: return ("Notification", "mp3")
        case .pop:      return ("Pop", "mp3")
        case .bomb:     return ("Bomb", "wav")
        case .complete: return ("Complete", "mp3")
        case .stepGrass: return ("Step Grass 1", "wav")
        case .stepSnow:  return ("Step Snow 1", "wav")
        case .block:     return ("Block", "mp3")
        case .arcadeBreak: return ("Arcade Break", "wav")
        case .fuse:      return ("Fuse 1", "wav")
        case .stinkGas:  return ("Stink Gas", "wav")
        case .lootbox:   return ("Lootbox", "mp3")
        case .token:     return ("Token", "wav")
        case .turretShot: return ("Turret Shot", "wav")
        case .elimination: return ("Elimination", "wav")
        case .sell:      return ("Sell", "wav")
        case .jackpot:   return ("Jackpot", "mp3")
        case .hitMarker: return ("Hit Marker 1", "wav")
        case .damage:    return ("Damage 1", "wav")
        case .objectHit: return ("Object Hit 1", "wav")
        case .chestBreak: return ("Chest Break", "mp3")
        case .turretBreak: return ("Turret Break", "wav")
        case .playerElimination: return ("Player Elimination", "wav")
        case .supplyDrop: return ("Supply Drop", "mp3")
        case .tick:      return ("Tick", "wav")
        case .tock:      return ("Tock", "wav")
        case .victory:   return ("Victory", "wav")
        }
    }

    /// Every take of it. Footsteps have six each, cut from one recording, and a
    /// different one plays each step so a walk never sounds like a loop. All the
    /// takes of one sound must share a format.
    var files: [(name: String, kind: String)] {
        switch self {
        case .stepGrass: return (1...6).map { ("Step Grass \($0)", "wav") }
        case .stepSnow:  return (1...6).map { ("Step Snow \($0)", "wav") }
        case .fuse:      return (1...4).map { ("Fuse \($0)", "wav") }
        case .hitMarker: return (1...9).map { ("Hit Marker \($0)", "wav") }
        case .damage:    return (1...9).map { ("Damage \($0)", "wav") }
        case .objectHit: return (1...4).map { ("Object Hit \($0)", "wav") }
        case .playerElimination: return [("Player Elimination", "wav"),
                                         ("Player Elimination 3", "wav")]
        default:         return [file]
        }
    }

    /// How far away it can still be heard, in tiles, or nil for a sound that did
    /// not happen anywhere.
    ///
    /// Both of these reach well past the edge of the screen, and that is the point.
    /// A map is fifty-six tiles across and you can see about twenty-two of them, so
    /// a bomb at twenty-eight is somebody raiding a base you cannot see - which is
    /// the single most useful thing the game could tell you without drawing
    /// anything. Cut to the screen's edge it would only ever confirm what you were
    /// already looking at.
    ///
    /// A wall closing carries less far than a bomb, because it should: one is an
    /// attack and the other is somebody quietly finishing a job.
    var earshot: Double? {
        switch self {
        case .bomb:     return 34
        case .complete: return 24

        // Much tighter than either, and on purpose. A bomb is one event a minute
        // and worth hearing from across the map; a blaster is four and a half a
        // second per person and there are eight of them. Eighteen tiles is a
        // little inside what you can see, so gunfire means a fight you could walk
        // to rather than a fight somewhere on this map - which is the difference
        // between atmosphere and a wall of noise.
        case .pop:      return 18
        // Far enough to hear somebody coming before they are on top of you,
        // about half the screen, and no further.
        case .stepGrass, .stepSnow: return 12
        // Your own building and the base next door, not every base on the map.
        case .block: return 14
        // As far as a base closing: somebody losing their arcade is news.
        case .arcadeBreak: return 24
        // As far as gunfire: a bomb on its way is a fight you could walk to.
        case .fuse: return 18
        // Less far than a real bomb. It is a nuisance, not an attack on a base.
        case .stinkGas: return 22
        // Close by: yours, and somebody looting right next to you.
        case .lootbox: return 12
        case .token: return nil
        // A little further than a blaster: a turret is the base telling you it
        // has seen you.
        case .turretShot: return 20
        // A fight you could walk to, the same reach as gunfire.
        case .elimination: return 18
        case .sell: return nil
        // Far enough to hear one go off in the next base along and go for it.
        case .jackpot: return 20
        case .hitMarker: return nil
        case .damage: return nil
        // Your own shooting and the base next to you.
        case .objectHit: return 12
        // A raid next door is worth knowing about.
        case .chestBreak: return 22
        case .turretBreak: return 24
        case .playerElimination: return nil
        // Most of the map: a drop landing is everybody's business, and the pan
        // says which way it came down.
        case .supplyDrop: return 60
        case .tick, .tock: return nil
        case .victory: return nil
        case .play, .purchase, .upgrade, .collect, .select, .tap,
             .heal, .exit, .error, .notification: return nil
        }
    }

    /// How many can overlap before the oldest is cut off.
    ///
    /// One apiece for the interface, because you cannot tap twice at once and two
    /// copies of the same click a frame apart is a stutter rather than two taps.
    /// More for the world, where four bombs in a second is a perfectly ordinary
    /// thing for eight teams to do.
    var voices: Int {
        switch self {
        // The most of anything by a distance. Eight actors at four and a half
        // shots a second will genuinely have six in the air at once during a
        // firefight, and a pool that runs out renders that as one gun.
        case .pop:      return 6
        case .bomb:     return 4
        case .complete: return 3
        case .collect:  return 3
        // A step lasts longer than the gap between two of them, so they overlap,
        // and with others walking nearby there are several at once.
        case .stepGrass, .stepSnow: return 8
        case .block: return 4
        case .arcadeBreak: return 2
        case .fuse: return 3
        case .stinkGas: return 3
        case .lootbox: return 3
        case .token: return 3
        case .turretShot: return 4
        case .elimination: return 3
        case .sell: return 2
        case .jackpot: return 2
        // Shots land four and a half a second; each one gets its own tick.
        case .hitMarker: return 4
        case .damage: return 2
        case .objectHit: return 4
        case .chestBreak, .turretBreak, .playerElimination, .supplyDrop: return 2
        case .tick, .tock: return 2
        case .victory: return 1
        case .play, .purchase, .upgrade, .select, .tap,
             .heal, .exit, .error, .notification: return 2
        }
    }

    /// The shortest gap between two of these, in seconds.
    ///
    /// A guard against one moment producing a dozen of the same noise. Collect is
    /// the one that needs it - a bagful of gear scattered by a kill is picked up in
    /// a couple of frames, and eight copies of the same chime inside a tenth of a
    /// second is not eight pickups, it is a fault.
    var minimumGap: TimeInterval {
        switch self {
        case .collect: return 0.07
        case .tap:     return 0.04

        // Short enough not to touch your own fire - four and a half a second is
        // 222ms apart - and long enough to cap what eight people shooting at once
        // can do to the mix. Your own shots skip it anyway; see SoundPlayer, where
        // anything at your feet is exempt.
        case .pop:     return 0.035
        case .stepGrass, .stepSnow: return 0.02
        case .block: return 0.03
        case .arcadeBreak: return 0.05
        case .fuse: return 0.05
        case .stinkGas: return 0.05
        case .lootbox: return 0.05
        // A kill scatters a pile and it is swept up across a few frames. One
        // jingle for the lot, not one per coin.
        case .token: return 0.08
        case .turretShot: return 0.05
        case .elimination: return 0.05
        case .sell: return 0.05
        case .jackpot: return 0.1
        case .hitMarker: return 0.05
        // Gas hurts in small steps; one thud every so often, not one per step.
        case .damage: return 0.15
        case .objectHit: return 0.06
        case .chestBreak, .turretBreak, .playerElimination, .supplyDrop: return 0.05
        case .tick, .tock: return 0.02
        case .victory: return 0.5
        case .bomb, .complete, .play, .purchase, .upgrade, .select,
             .heal, .exit, .error, .notification: return 0.02
        }
    }

    /// Whether it fades in a straight line with distance rather than squared.
    /// Footsteps do: they are quiet to begin with, and squared they were gone
    /// before anyone was close enough to matter.
    var fadesEvenly: Bool {
        switch self {
        case .stepGrass, .stepSnow: return true
        default: return false
        }
    }

    /// Per-sound trim, so the mix can be balanced without re-exporting anything.
    ///
    /// Balanced by measurement, not by ear one sound at a time. Every file was
    /// measured at its loudest tenth of a second (weighted the way hearing is),
    /// and each gain here brings it to a level for its kind of sound:
    ///
    ///   big moments (bomb, arcade breaking, a kill)     loudest
    ///   rewards (play, buying, selling, tokens, crates) a step under
    ///   the interface (taps, back, refusals)            under that
    ///   the constant stuff (gunfire, building, fuses)   quiet, it never stops
    ///   footsteps and hit markers                       barely there, by request
    ///
    /// Above 1 is allowed for a file recorded too quietly: SoundPlayer boosts
    /// the samples once when it loads them, since a player's volume stops at 1.
    var gain: Float {
        switch self {
        // Big moments.
        case .bomb:        return 1.15
        case .arcadeBreak: return 1.05
        case .elimination: return 1.0
        case .jackpot:     return 1.45
        case .stinkGas:    return 0.5
        case .complete:    return 1.6

        // Rewards.
        case .play:     return 1.2
        case .upgrade:  return 0.64
        case .purchase: return 0.98
        case .sell:     return 1.9
        case .token:    return 1.3
        case .lootbox:  return 0.75
        case .collect:  return 1.7
        case .heal:     return 0.76

        // The interface. A refusal and a line of text are the game interrupting
        // you, so they sit with the taps rather than above them.
        case .select:       return 0.9
        case .tap:          return 1.1
        case .exit:         return 0.94
        case .error:        return 0.7
        case .notification: return 1.15

        // The constant stuff. Gunfire was the loudest thing in the game by a
        // distance and is also the commonest; the turret's shot more so.
        case .pop:        return 0.2
        case .turretShot: return 0.26
        case .block:      return 0.5
        case .fuse:       return 0.32
        // Under your own hit markers: landing a hit should always be the
        // louder of the two, so in a trade you hear yourself winning it.
        // You also feel this one and see the flinch.
        case .damage:     return 0.43
        // About as loud as your hit markers: hitting something either way.
        case .objectHit:  return 0.78

        // Big moments, alongside the bomb and the arcade breaking.
        case .chestBreak:        return 0.66
        case .turretBreak:       return 0.74
        case .playerElimination: return 2.7
        case .supplyDrop:        return 1.08

        // The clock: with the interface, clear but not urgent-loud. The two
        // recordings differ, so each has its own trim to sound even.
        case .tick: return 1.3
        case .tock: return 0.76

        // The biggest moment there is, and nothing else is playing over it.
        case .victory: return 1.2

        // Tuned by ear already and kept: these are meant to be barely there.
        case .stepGrass, .stepSnow: return 0.1

        // Your hits: soft, but clearly over the damage you take - about 4 dB
        // above it, and a touch under the gunfire around them.
        case .hitMarker:            return 0.73
        }
    }

    /// Whether this sound cuts through everything else: when it plays, every
    /// other sound dips for a moment so it is heard clearly. See SoundPlayer.duck.
    var takesPrecedence: Bool {
        self == .elimination || self == .playerElimination
    }

    /// What the player node is set to: the gain, up to 1. Anything above that
    /// is applied to the samples at load - see `boost`.
    var playGain: Float { min(gain, 1) }

    /// How much the samples themselves are raised when loaded, for a gain
    /// above 1. One for everything else.
    var boost: Float { max(gain, 1) }
}
