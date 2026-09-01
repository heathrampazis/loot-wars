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

    /// Every team, in a fixed order. For anything that has to show all of them - a
    /// leaderboard, say - without reaching into a dictionary whose order is not
    /// stable between runs.
    static let all: [TeamID] = (0..<count).map(TeamID.init)
}
