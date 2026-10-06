//
//  ActorID.swift
//  Loot Wars
//
//  Everything in the world is addressed by ID, never by a direct reference and
//  never by "the player". That is what lets one of these actors become a remote
//  player later without touching any of the systems.
//

struct ActorID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }
}
