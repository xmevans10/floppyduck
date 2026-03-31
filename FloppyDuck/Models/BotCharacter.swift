import SwiftUI

/// Legacy AI difficulty parameters — kept for Codable compatibility.
/// New bot logic uses `HumanBotProfile` instead.
struct BotDifficulty: Hashable, Codable {
    let noiseRange: CGFloat      // ±pixels of aim inaccuracy around gap center
    let flapStrength: CGFloat    // multiplier on flap impulse (0–1)
    let errorRate: CGFloat       // chance of failing to flap when needed (0–1)
}

/// A named bot opponent on the VS Bot ladder.
struct BotCharacter: Identifiable, Hashable {
    let id: String
    let name: String
    let title: String
    let elo: Int
    let difficulty: BotDifficulty       // Legacy — kept for any external references
    let profile: HumanBotProfile        // New human-like AI parameters
    let accentColor: Color
    let targetScore: Int                // bot dies naturally around this score
    let skin: DuckSkin                  // unique skin for this bot
    let taunt: String                   // shown before match

    // Hashable conformance (profile is Hashable via Codable synthesis)
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BotCharacter, rhs: BotCharacter) -> Bool {
        lhs.id == rhs.id
    }

    /// All 8 bots in ladder order (easiest → hardest).
    ///
    /// Human-like profiles based on motor-control research:
    ///   - Reaction time: 150–200 ms (elite) → 350+ ms (beginner)
    ///   - Motor noise σ: ~15 ms (expert) → ~80 ms (beginner)
    ///   - Isaksen et al. used σ = 30 ms for an "average" Flappy Bird player
    ///   - Panic parameters model the human tendency to over-flap near obstacles
    ///   - Fatigue models attention decay over a session
    ///   - Death pressure creates a gradual skill collapse instead of abrupt stop
    static let all: [BotCharacter] = [

        // 1. QUACKERS — Newbie (dies around score 8–12)
        //    Very slow reactions, high motor noise, panics easily, fatigues fast.
        //    Looks like someone playing Flappy Bird for the first time.
        BotCharacter(
            id: "quackers", name: "QUACKERS", title: "Newbie", elo: 100,
            difficulty: BotDifficulty(noiseRange: 45, flapStrength: 0.60, errorRate: 0.30),
            profile: HumanBotProfile(
                reactionBase: 0.38,
                reactionσ: 0.07,
                motorσ: 0.075,
                perceptionRange: 180,
                aimBiasσ: 11,
                panicDistance: 120,
                panicMisalignment: 22,
                panicFlapChance: 0.35,
                fatigueRate: 0.010,
                scoreRecovery: 0.08,
                attentionFloor: 0.45,
                targetScore: 10,
                deathPressureRate: 0.30
            ),
            accentColor: Color(red: 0.95, green: 0.85, blue: 0.30), targetScore: 10,
            skin: .sailor, taunt: "Quack quack! I'm just learning!"),

        // 2. WADDLES — Casual (dies around score 12–16)
        //    Slow but not hopeless. Gets flustered near pipes.
        BotCharacter(
            id: "waddles", name: "WADDLES", title: "Casual", elo: 300,
            difficulty: BotDifficulty(noiseRange: 35, flapStrength: 0.68, errorRate: 0.20),
            profile: HumanBotProfile(
                reactionBase: 0.34,
                reactionσ: 0.06,
                motorσ: 0.065,
                perceptionRange: 200,
                aimBiasσ: 9,
                panicDistance: 110,
                panicMisalignment: 25,
                panicFlapChance: 0.30,
                fatigueRate: 0.008,
                scoreRecovery: 0.07,
                attentionFloor: 0.48,
                targetScore: 14,
                deathPressureRate: 0.27
            ),
            accentColor: Color(red: 0.40, green: 0.80, blue: 0.90), targetScore: 14,
            skin: .cowboy, taunt: "Yeehaw! Bet you can't outfly me, partner!"),

        // 3. PUDDLES — Regular (dies around score 16–20)
        //    Average mobile gamer. Decent reactions, some panic behavior.
        BotCharacter(
            id: "puddles", name: "PUDDLES", title: "Regular", elo: 500,
            difficulty: BotDifficulty(noiseRange: 25, flapStrength: 0.76, errorRate: 0.12),
            profile: HumanBotProfile(
                reactionBase: 0.30,
                reactionσ: 0.05,
                motorσ: 0.050,
                perceptionRange: 230,
                aimBiasσ: 7,
                panicDistance: 95,
                panicMisalignment: 28,
                panicFlapChance: 0.22,
                fatigueRate: 0.006,
                scoreRecovery: 0.06,
                attentionFloor: 0.52,
                targetScore: 18,
                deathPressureRate: 0.24
            ),
            accentColor: Color(red: 0.40, green: 0.75, blue: 0.30), targetScore: 18,
            skin: .pirate, taunt: "Arr! No one passes through MY pipes!"),

        // 4. DRAKE — Competitor (dies around score 20–25)
        //    Good player. Controlled flapping, moderate panic threshold.
        BotCharacter(
            id: "drake", name: "DRAKE", title: "Competitor", elo: 700,
            difficulty: BotDifficulty(noiseRange: 18, flapStrength: 0.82, errorRate: 0.08),
            profile: HumanBotProfile(
                reactionBase: 0.27,
                reactionσ: 0.04,
                motorσ: 0.040,
                perceptionRange: 260,
                aimBiasσ: 5,
                panicDistance: 80,
                panicMisalignment: 32,
                panicFlapChance: 0.15,
                fatigueRate: 0.005,
                scoreRecovery: 0.05,
                attentionFloor: 0.55,
                targetScore: 22,
                deathPressureRate: 0.22
            ),
            accentColor: Color(red: 0.90, green: 0.55, blue: 0.16), targetScore: 22,
            skin: .dinosaur, taunt: "Time to show you how it's done."),

        // 5. FEATHERS — Skilled (dies around score 26–32)
        //    Snappy reactions, low motor noise, rarely panics.
        BotCharacter(
            id: "feathers", name: "FEATHERS", title: "Skilled", elo: 900,
            difficulty: BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0.05),
            profile: HumanBotProfile(
                reactionBase: 0.23,
                reactionσ: 0.035,
                motorσ: 0.032,
                perceptionRange: 290,
                aimBiasσ: 4,
                panicDistance: 65,
                panicMisalignment: 36,
                panicFlapChance: 0.10,
                fatigueRate: 0.004,
                scoreRecovery: 0.04,
                attentionFloor: 0.58,
                targetScore: 28,
                deathPressureRate: 0.20
            ),
            accentColor: Color(red: 0.90, green: 0.45, blue: 0.65), targetScore: 28,
            skin: .alien, taunt: "Your puny Earth skills won't save you."),

        // 6. MALLORY — Expert (dies around score 33–38)
        //    Near-elite reactions (~200 ms). Stays calm under pressure.
        BotCharacter(
            id: "mallory", name: "MALLORY", title: "Expert", elo: 1100,
            difficulty: BotDifficulty(noiseRange: 8, flapStrength: 0.92, errorRate: 0.03),
            profile: HumanBotProfile(
                reactionBase: 0.20,
                reactionσ: 0.025,
                motorσ: 0.025,
                perceptionRange: 310,
                aimBiasσ: 3,
                panicDistance: 55,
                panicMisalignment: 40,
                panicFlapChance: 0.06,
                fatigueRate: 0.003,
                scoreRecovery: 0.03,
                attentionFloor: 0.62,
                targetScore: 35,
                deathPressureRate: 0.18
            ),
            accentColor: Color(red: 0.60, green: 0.35, blue: 0.80), targetScore: 35,
            skin: .wizard, taunt: "I've foreseen your defeat in the stars."),

        // 7. GOOSE — Menace (dies around score 42–48)
        //    Elite gamer. Fast reactions, tiny motor noise, iron nerves.
        BotCharacter(
            id: "goose", name: "GOOSE", title: "Menace", elo: 1300,
            difficulty: BotDifficulty(noiseRange: 5, flapStrength: 0.95, errorRate: 0.01),
            profile: HumanBotProfile(
                reactionBase: 0.17,
                reactionσ: 0.020,
                motorσ: 0.020,
                perceptionRange: 330,
                aimBiasσ: 2.5,
                panicDistance: 50,
                panicMisalignment: 45,
                panicFlapChance: 0.04,
                fatigueRate: 0.002,
                scoreRecovery: 0.025,
                attentionFloor: 0.65,
                targetScore: 45,
                deathPressureRate: 0.16
            ),
            accentColor: Color(red: 0.85, green: 0.25, blue: 0.25), targetScore: 45,
            skin: .devil, taunt: "HONK. You're going DOWN."),

        // 8. THE DUCK — Final Boss (dies around score 55–65)
        //    Closest to perfect human play. Minimal noise, deep focus.
        //    In future: could be replaced with a recorded replay of a real top player.
        BotCharacter(
            id: "the_duck", name: "THE DUCK", title: "Final Boss", elo: 1500,
            difficulty: BotDifficulty(noiseRange: 3, flapStrength: 0.98, errorRate: 0.00),
            profile: HumanBotProfile(
                reactionBase: 0.15,
                reactionσ: 0.015,
                motorσ: 0.015,
                perceptionRange: 350,
                aimBiasσ: 2,
                panicDistance: 45,
                panicMisalignment: 50,
                panicFlapChance: 0.02,
                fatigueRate: 0.001,
                scoreRecovery: 0.020,
                attentionFloor: 0.70,
                targetScore: 60,
                deathPressureRate: 0.14
            ),
            accentColor: Color(red: 0.95, green: 0.80, blue: 0.18), targetScore: 60,
            skin: .golden, taunt: "I am the one true duck. You are not ready."),
    ]

    static func find(_ id: String) -> BotCharacter? {
        all.first { $0.id == id }
    }
}
