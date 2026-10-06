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
        case .bomb, .complete, .play, .purchase, .upgrade, .select,
             .heal, .exit, .error, .notification: return 0.02
        }
    }

    /// Per-sound trim, so the mix can be balanced without re-exporting anything.
    var gain: Float {
        switch self {
        // The quietest thing in the game, because it is the commonest by an order
        // of magnitude. A pop at the same level as a purchase, four and a half
        // times a second, is the only sound here capable of making somebody turn
        // the volume off.
        case .pop:      return 0.42
        case .tap:      return 0.55
        case .collect:  return 0.7
        case .bomb:     return 0.9
        // Quieter than the things you chose to do. A refusal and a line of text
        // are the game interrupting you, and an interruption that is as loud as
        // your own actions stops reading as a footnote and starts reading as a
        // telling-off.
        case .error:        return 0.6
        case .notification: return 0.6
        case .exit:         return 0.8
        case .play, .purchase, .upgrade, .select, .complete, .heal: return 1
        }
    }
}
