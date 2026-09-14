//
//  SoundPlayer.swift
//  Loot Wars
//
//  Playing the things in Sound, and placing them.
//
//  AVAudioPlayer rather than SKAction.playSoundFileNamed, and that is not a matter
//  of taste. The SKAction version has no volume and no pan - it plays a file at
//  full blast, centred - so every distance rule below would have been impossible to
//  express. It also ties the sound's lifetime to a node's, which means an explosion
//  stops halfway through if whatever it was attached to is removed, and an
//  explosion is a thing that removes nodes.
//
//  A POOL per sound, because one player cannot play twice at once: asking it to
//  start again cuts off what it was doing. Four bombs in a second is an ordinary
//  thing for eight teams to manage, and one player would render it as one bomb.
//  Round-robin across the voices, so the oldest is the one that gets cut.
//
//  Shared, and this is the one place in the drawing code where that is the right
//  shape. There is one speaker in the phone. Two scenes hand off to each other -
//  the menu plays its button and the match starts a second later - and a per-scene
//  player would decode the same files again on every transition, for no reason
//  other than tidiness.
//

import AVFoundation
import Foundation
import QuartzCore

final class SoundPlayer {

    static let shared = SoundPlayer()

    private var voices: [Sound: [AVAudioPlayer]] = [:]
    private var next: [Sound: Int] = [:]
    private var lastPlayed: [Sound: TimeInterval] = [:]

    /// How far off to the side something has to be to sit fully in one ear.
    ///
    /// A little past the edge of the screen rather than at the map's scale. Panning
    /// over the full earshot would leave everything you can actually SEE nearly
    /// centred, and the useful half of this is telling you which way to turn for
    /// something just out of view.
    private static let fullyOneSide: Double = 13

    /// Never completely one-sided. A sound hard in one ear reads as a fault in the
    /// headphones rather than as a direction.
    private static let widest: Float = 0.85

    /// Close enough that it is you rather than something near you.
    private static let atYourFeet: Double = 2

    private init() {
        #if os(iOS) || os(tvOS)
        // Ambient, so the silent switch means silent and whatever the player had
        // playing keeps playing. A game that stops somebody's music to tell them
        // they picked up a bandage has made a decision that was never its to make.
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        #endif

        for sound in Sound.allCases { load(sound) }
    }

    /// Decoded and primed at launch rather than on first use.
    ///
    /// The first play of an untouched file costs a decode, and it arrives exactly
    /// when something interesting has happened - which is the worst possible moment
    /// for a frame to go long. prepareToPlay does that work now instead.
    private func load(_ sound: Sound) {
        let file = sound.file

        // Both spellings, because where these land in the bundle depends on how the
        // folder was added to the project: a group flattens them to the root, a
        // folder reference keeps the Sounds/ directory. Asking for both costs one
        // failed lookup at launch and saves a silent game.
        let url = Bundle.main.url(forResource: file.name, withExtension: file.kind)
            ?? Bundle.main.url(forResource: file.name,
                               withExtension: file.kind,
                               subdirectory: "Sounds")

        guard let url else {
            print("Loot Wars: missing sound \(file.name).\(file.kind)")
            return
        }

        var made: [AVAudioPlayer] = []
        for _ in 0..<sound.voices {
            guard let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.prepareToPlay()
            made.append(player)
        }

        voices[sound] = made
    }

    /// Builds the shared player, if nothing has yet.
    ///
    /// Everything expensive happens in init - the audio session comes up, nine
    /// files are decoded - and without this the first thing to ask for a sound
    /// pays for all of it. That would be the menu's play button, which is the one
    /// press in the game where a late noise is most obvious, because there is
    /// nothing else happening.
    func warm() {}

    // MARK: - Playing

    /// An interface sound: dead centre, full volume, because it did not happen
    /// anywhere on the map - it happened to you.
    func play(_ sound: Sound) {
        start(sound, volume: sound.gain, pan: 0)
    }

    /// A sound that happened at a place on the map, heard from another.
    ///
    /// Silently does nothing past the sound's earshot, which is most of the point:
    /// eight teams bombing each other across a fifty-six tile map would otherwise
    /// be a continuous rumble that tells you nothing, where a bomb you can only
    /// just hear, off to the left, is somebody opening a base over there.
    func play(_ sound: Sound, at position: Vec2, heardFrom listener: Vec2) {
        guard let earshot = sound.earshot else {
            play(sound)
            return
        }

        let away = position - listener
        let distance = away.length
        guard distance < earshot else { return }

        // Squared falloff rather than linear. Linear keeps a sound at half volume
        // right out to half the earshot, which puts a bomb twelve tiles away almost
        // level with one at your feet; squaring pulls the far half down where it
        // belongs and leaves the near half alone.
        let near = 1 - distance / earshot
        let volume = Float(near * near) * sound.gain

        let sideways = away.x / SoundPlayer.fullyOneSide
        let pan = max(-1, min(1, Float(sideways))) * SoundPlayer.widest

        // Anything happening at your feet skips the rate limit.
        //
        // The limit exists to stop eight people shooting at once flattening the
        // mix, and it does that by dropping whatever asks too soon after something
        // else. That is fine for a gun across the base and wrong for YOURS: a
        // blaster is four and a half shots a second, so in a busy firefight a
        // distant bot firing thirty milliseconds before you would silence your own
        // trigger about one press in five. A gun that intermittently does not go
        // off does not read as a busy mix, it reads as a broken game.
        start(sound, volume: volume, pan: pan, urgent: distance < SoundPlayer.atYourFeet)
    }

    private func start(_ sound: Sound, volume: Float, pan: Float, urgent: Bool = false) {
        guard let pool = voices[sound], !pool.isEmpty else { return }

        // One moment can announce the same thing several times over - a kill
        // scatters a bagful and it is swept up across two frames - and a dozen
        // copies of one chime is not a dozen pickups, it is a fault.
        //
        // Urgent skips the wait but still resets it, so your own shot cannot be
        // dropped and still counts against whoever asks next.
        let now = CACurrentMediaTime()
        if !urgent, let last = lastPlayed[sound], now - last < sound.minimumGap { return }
        lastPlayed[sound] = now

        let index = (next[sound] ?? 0) % pool.count
        next[sound] = index + 1

        let player = pool[index]
        player.volume = max(0, min(1, volume))
        player.pan = pan
        player.currentTime = 0
        player.play()
    }
}
