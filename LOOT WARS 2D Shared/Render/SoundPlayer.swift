//
//  SoundPlayer.swift
//  Loot Wars
//
//  Playing the things in Sound, and placing them.
//
//  AVAudioEngine with the files decoded into memory up front, NOT AVAudioPlayer -
//  and that is a rewrite rather than a preference. AVAudioPlayer is built for
//  playing a track: every call to play() re-primes the thing, seeking currentTime
//  back to zero is a real seek, and Apple's own guidance is to call prepareToPlay
//  again after each stop. None of that matters for a menu click. All of it matters
//  for the blaster, which fires four and a half times a second per person with
//  eight people on the map, every one of those calls landing on the thread that is
//  trying to draw the frame. That is where the stutter came from.
//
//  An engine does the expensive half once. A file is decoded to a PCM buffer at
//  launch and never touched again; playing it is scheduleBuffer, which hands a
//  pointer to the audio thread and returns. The mixing happens on the audio
//  thread, where it belongs, and nothing about firing a gun reaches the renderer.
//
//  A POOL of player nodes per sound, because one node plays one thing at a time.
//  Round-robin, so the oldest is the one that gets interrupted - four bombs in a
//  second is ordinary for eight teams, and one voice would render it as one bomb.
//
//  Shared, and this is the one place in the drawing code where that is right.
//  There is one speaker in the phone. Two scenes hand off to each other and a
//  per-scene player would decode thirteen files again on every transition.
//

import AVFoundation
import Foundation
import QuartzCore

final class SoundPlayer {

    static let shared = SoundPlayer()

    private let engine = AVAudioEngine()

    /// Decoded once, at launch, and then never again.
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var nodes: [Sound: [AVAudioPlayerNode]] = [:]

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

        // Touched before anything is attached, because asking for it is what builds
        // it - and building the mixer half way through wiring nodes into it is how
        // an engine ends up with a connection to something that did not exist yet.
        let mixer = engine.mainMixerNode

        for sound in Sound.allCases { load(sound, into: mixer) }

        resume()
    }

    /// Decoded, wired up, and left running.
    ///
    /// All of it at launch rather than on first use. The decode is the expensive
    /// part and it would otherwise land on whichever frame first fired a gun -
    /// which is to say, on the first interesting thing that happens in a match.
    private func load(_ sound: Sound, into mixer: AVAudioMixerNode) {
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

        guard let audio = try? AVAudioFile(forReading: url) else {
            print("Loot Wars: unreadable sound \(file.name).\(file.kind)")
            return
        }

        let frames = AVAudioFrameCount(audio.length)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: audio.processingFormat,
                                            frameCapacity: frames) else {
            print("Loot Wars: undecodable sound \(file.name).\(file.kind)")
            return
        }

        do { try audio.read(into: buffer) } catch {
            print("Loot Wars: unreadable sound \(file.name).\(file.kind) - \(error)")
            return
        }

        buffers[sound] = buffer

        // Connected at the FILE's own format rather than at one house format. The
        // mixer converts, which is its job, and the alternative is resampling
        // thirteen files by hand to agree with each other.
        var pool: [AVAudioPlayerNode] = []
        for _ in 0..<sound.voices {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: mixer, format: buffer.format)
            pool.append(node)
        }

        nodes[sound] = pool
    }

    /// Starts the engine, and every node in it, if they are not already going.
    ///
    /// A player node has to be told to play once before anything scheduled into it
    /// is heard, and it stays playing forever afterwards - scheduling is what makes
    /// a noise, not starting. The engine itself can be stopped out from under all
    /// of this by the system: a phone call, headphones going in or out. So this is
    /// idempotent and is asked again cheaply on the way into every sound.
    @discardableResult
    private func resume() -> Bool {
        if engine.isRunning { return true }

        do { try engine.start() } catch {
            print("Loot Wars: audio engine would not start - \(error)")
            return false
        }

        for pool in nodes.values {
            for node in pool { node.play() }
        }
        return true
    }

    /// Builds the shared player, if nothing has yet.
    ///
    /// Everything expensive happens in init - the session comes up, thirteen files
    /// are decoded, thirty-odd nodes are wired into the mixer - and without this
    /// the first thing to ask for a sound pays for all of it. That would be the
    /// menu's play button, which is the press in the game where a late noise is
    /// most obvious, because nothing else is happening.
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
    /// eight teams shooting at each other across a fifty-six tile map would
    /// otherwise be a continuous rumble that tells you nothing, where a shot you
    /// can only just hear, off to the left, is a fight you could walk to.
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
        // else. Fine for a gun across the base, wrong for YOURS: a blaster is four
        // and a half shots a second, so in a busy firefight a distant bot firing
        // thirty milliseconds before you would silence your own trigger about one
        // press in five. A gun that intermittently does not go off does not read as
        // a busy mix, it reads as a broken game.
        start(sound, volume: volume, pan: pan, urgent: distance < SoundPlayer.atYourFeet)
    }

    private func start(_ sound: Sound, volume: Float, pan: Float, urgent: Bool = false) {
        guard let buffer = buffers[sound],
              let pool = nodes[sound], !pool.isEmpty else { return }

        // One moment can announce the same thing several times over - a kill
        // scatters a bagful and it is swept up across two frames - and a dozen
        // copies of one chime is not a dozen pickups, it is a fault.
        //
        // Urgent skips the wait but still resets it, so your own shot cannot be
        // dropped and cannot be used to jump the queue twice either.
        let now = CACurrentMediaTime()
        if !urgent, let last = lastPlayed[sound], now - last < sound.minimumGap { return }
        lastPlayed[sound] = now

        guard resume() else { return }

        let index = (next[sound] ?? 0) % pool.count
        next[sound] = index + 1

        let node = pool[index]
        node.volume = max(0, min(1, volume))
        node.pan = pan

        // interrupts, so a voice that is still busy is taken over rather than
        // queued behind itself. Queued is the wrong answer for every sound here:
        // a second gunshot belongs now or not at all, never in two seconds' time.
        node.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
    }
}
