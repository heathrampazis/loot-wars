//
//  GasSystem.swift
//  Loot Wars
//
//  Clouds thinning, and doses handed to whoever stayed in one.
//
//  Damage arrives in PORTIONS rather than as a trickle, which is the same lesson
//  the healing at home taught: the screen reacts to every point of damage - a
//  flinch, a darkening, stars coming off - and sixty of those a second is not a
//  cloud of gas, it is a fault. Half a second between doses reads as choking.
//
//  It hurts everybody, including whoever threw it. There are no teammates on this
//  map, so the only person a friendly-fire rule could protect is the thrower, and
//  protecting them would turn the cloud from a piece of ground nobody can use into
//  a piece of ground only one person can use - which is a different and much
//  stronger item than the one intended.
//

enum GasSystem {

    static func update(_ world: World, dt: Double) {
        guard !world.gasClouds.isEmpty else { return }

        // Sorted rather than in dictionary order: this hands out damage, damage can
        // kill, and a kill pays a bounty - so the order has to be the same on every
        // run of the same seed.
        for id in world.gasClouds.keys.sorted(by: { $0.raw < $1.raw }) {
            guard var cloud = world.gasClouds[id] else { continue }

            cloud.timeRemaining -= dt

            guard cloud.timeRemaining > 0 else {
                world.removeGas(id)
                continue
            }

            cloud.doseTimer -= dt

            if cloud.doseTimer <= 0 {
                cloud.doseTimer = GameConfig.Stink.doseInterval
                dose(from: cloud, in: world)
            }

            world.gasClouds[id] = cloud
        }
    }

    /// One dose to everybody standing in it.
    ///
    /// Gated on the cloud being thick enough to see, so what hurts you and what is
    /// drawn are the same thing: gas you can barely make out cannot still be taking
    /// health off you, which is the one way an area effect really does feel unfair.
    private static func dose(from cloud: GasCloud, in world: World) {
        guard cloud.density >= GameConfig.Stink.bitingDensity else { return }

        for id in world.actors.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let actor = world.actors[id], actor.isAlive else { continue }

            // Measured at the FEET rather than at the centre of the figure, for the
            // same reason everything else on this map is: the figure is nearly two
            // tiles tall, and a cloud lying on the ground should catch somebody
            // standing in it rather than somebody whose head is over it.
            guard cloud.contains(actor.feet) else { continue }

            CombatSystem.damage(id,
                                amount: GameConfig.Stink.dose,
                                from: cloud.owner,
                                in: world)
        }
    }
}
