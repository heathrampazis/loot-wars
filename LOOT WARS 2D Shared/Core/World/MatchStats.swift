//
//  MatchStats.swift
//  Loot Wars
//
//  What one player did this match, for the results screen: fights, loot and
//  money. Written as things happen and never read by the simulation, so it
//  cannot change how a match plays out - see World.tally.
//

struct MatchStats {
    var kills = 0
    var deaths = 0

    /// Shots from your own blaster - not your turret's - and how many of them
    /// hit somebody.
    var shotsFired = 0
    var shotsHit = 0
    /// Health taken off other teams, by anything of yours.
    var damageDealt = 0

    /// Other teams' chests broken open with something inside.
    var chestsRaided = 0
    /// Every token that came your way: kills, crates, raids and pickups.
    var tokensEarned = 0

    /// Share of shots that hit, 0...1, or nil before the first shot.
    var accuracy: Double? {
        shotsFired > 0 ? Double(shotsHit) / Double(shotsFired) : nil
    }
}
