//
//  Haptics.swift
//  Loot Wars
//
//  Vibration for the moments that are about YOU: your shots landing, being
//  hit, a kill, dying, a bomb going off close by, building, buying, and the
//  game refusing something. Not healing, which happens often and should feel
//  calm. Never for what happens to somebody else across the
//  map - a buzz in the hand is a fact about you or it is noise.
//
//  Every one goes through here, and here asks Prefs.vibrationOn, the same way
//  every sound asks Prefs.soundOn. Each kind also has a shortest gap, because
//  a held trigger lands four hits a second and auto-build lays a wall every
//  fifth of one, and a motor buzzing nonstop stops meaning anything.
//
//  Does nothing on a device without a Taptic Engine, which is every iPad.
//

import QuartzCore
#if os(iOS)
import UIKit
#endif

enum Haptic: Hashable {
    /// Your shot landed on somebody.
    case hit
    /// You were hit.
    case hurt
    /// You knocked somebody out.
    case kill
    /// You were knocked out.
    case died
    /// A bomb went off near you; nearer is harder.
    case blast(near: Double)
    /// A wall of yours went up.
    case build
    /// Something bought.
    case success
    /// Your base is being raided.
    case warning
    /// The game said no.
    case error

    /// The shortest gap between two of the same kind, in seconds.
    fileprivate var minimumGap: CFTimeInterval {
        switch self {
        case .hit:     return 0.09
        case .hurt:    return 0.15
        case .build:   return 0.08
        case .blast:   return 0.12
        case .kill, .died, .success, .warning, .error: return 0.05
        }
    }

    /// Kinds that share a rate limit, so two bombs are one kind.
    fileprivate var family: Int {
        switch self {
        case .hit: return 0
        case .hurt: return 1
        case .kill: return 2
        case .died: return 3
        case .blast: return 4
        case .build: return 5
        case .success: return 6
        case .warning: return 7
        case .error: return 8
        }
    }
}

final class Haptics {

    static let shared = Haptics()

    private var lastPlayed: [Int: CFTimeInterval] = [:]

    #if os(iOS)
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notice = UINotificationFeedbackGenerator()
    #endif

    private init() {
        #if os(iOS)
        // Woken once, so the first buzz of a match is not late.
        [light, medium, heavy, rigid, soft].forEach { $0.prepare() }
        notice.prepare()
        #endif
    }

    func play(_ haptic: Haptic) {
        guard Prefs.vibrationOn else { return }

        let now = CACurrentMediaTime()
        if let last = lastPlayed[haptic.family], now - last < haptic.minimumGap { return }
        lastPlayed[haptic.family] = now

        #if os(iOS)
        switch haptic {
        case .hit:
            rigid.impactOccurred(intensity: 0.45)
        case .hurt:
            medium.impactOccurred(intensity: 0.8)
        case .kill:
            heavy.impactOccurred()
            notice.notificationOccurred(.success)
        case .died:
            heavy.impactOccurred()
            notice.notificationOccurred(.error)
        case .blast(let near):
            heavy.impactOccurred(intensity: CGFloat(max(0.3, min(1, near))))
        case .build:
            soft.impactOccurred(intensity: 0.6)
        case .success:
            notice.notificationOccurred(.success)
        case .warning:
            notice.notificationOccurred(.warning)
        case .error:
            notice.notificationOccurred(.error)
        }
        #endif
    }
}
