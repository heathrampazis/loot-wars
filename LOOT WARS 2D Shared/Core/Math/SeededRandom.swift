//
//  SeededRandom.swift
//  Loot Wars
//
//  All randomness in the game comes from here, never from Int.random or friends.
//
//  Why it matters: the same seed always produces the same map, which means a bug
//  you can see is a bug you can reproduce. It is also what would let a host and a
//  client generate an identical world from a single number instead of shipping the
//  whole map over the wire.
//
//  SplitMix64 - small, fast, and good enough for a game.
//

struct SeededRandom: RandomNumberGenerator {

    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
