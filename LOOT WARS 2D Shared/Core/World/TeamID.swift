//
//  TeamID.swift
//  Loot Wars
//
//  Eight teams, one actor each for now. Ownership of anything in the world - walls
//  today, base claims and score tomorrow - is expressed as a TeamID, never as
//  "mine" versus "theirs". There is no privileged team.
//

struct TeamID: Hashable {
    let raw: Int

    init(_ raw: Int) {
        self.raw = raw
    }

    static let count = 8
}
