import SwiftUI

/// AI difficulty parameters for a bot opponent.
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
    let difficulty: BotDifficulty
    let accentColor: Color
    let targetScore: Int         // bot dies deterministically at this score — player wins by surviving
    let skin: DuckSkin           // unique skin for this bot
    let taunt: String            // shown before match

    /// All 8 bots in ladder order (easiest → hardest).
    static let all: [BotCharacter] = [
        BotCharacter(
            id: "quackers", name: "QUACKERS", title: "Newbie", elo: 100,
            difficulty: BotDifficulty(noiseRange: 45, flapStrength: 0.60, errorRate: 0.30),
            accentColor: Color(red: 0.95, green: 0.85, blue: 0.30), targetScore: 10,
            skin: .sailor, taunt: "Quack quack! I'm just learning!"),
        BotCharacter(
            id: "waddles", name: "WADDLES", title: "Casual", elo: 300,
            difficulty: BotDifficulty(noiseRange: 35, flapStrength: 0.68, errorRate: 0.20),
            accentColor: Color(red: 0.40, green: 0.80, blue: 0.90), targetScore: 14,
            skin: .cowboy, taunt: "Yeehaw! Bet you can't outfly me, partner!"),
        BotCharacter(
            id: "puddles", name: "PUDDLES", title: "Regular", elo: 500,
            difficulty: BotDifficulty(noiseRange: 25, flapStrength: 0.76, errorRate: 0.12),
            accentColor: Color(red: 0.40, green: 0.75, blue: 0.30), targetScore: 18,
            skin: .pirate, taunt: "Arr! No one passes through MY pipes!"),
        BotCharacter(
            id: "drake", name: "DRAKE", title: "Competitor", elo: 700,
            difficulty: BotDifficulty(noiseRange: 18, flapStrength: 0.82, errorRate: 0.08),
            accentColor: Color(red: 0.90, green: 0.55, blue: 0.16), targetScore: 22,
            skin: .dinosaur, taunt: "Time to show you how it's done."),
        BotCharacter(
            id: "feathers", name: "FEATHERS", title: "Skilled", elo: 900,
            difficulty: BotDifficulty(noiseRange: 12, flapStrength: 0.88, errorRate: 0.05),
            accentColor: Color(red: 0.90, green: 0.45, blue: 0.65), targetScore: 28,
            skin: .alien, taunt: "Your puny Earth skills won't save you."),
        BotCharacter(
            id: "mallory", name: "MALLORY", title: "Expert", elo: 1100,
            difficulty: BotDifficulty(noiseRange: 8, flapStrength: 0.92, errorRate: 0.03),
            accentColor: Color(red: 0.60, green: 0.35, blue: 0.80), targetScore: 35,
            skin: .wizard, taunt: "I've foreseen your defeat in the stars."),
        BotCharacter(
            id: "goose", name: "GOOSE", title: "Menace", elo: 1300,
            difficulty: BotDifficulty(noiseRange: 5, flapStrength: 0.95, errorRate: 0.01),
            accentColor: Color(red: 0.85, green: 0.25, blue: 0.25), targetScore: 45,
            skin: .devil, taunt: "HONK. You're going DOWN."),
        BotCharacter(
            id: "the_duck", name: "THE DUCK", title: "Final Boss", elo: 1500,
            difficulty: BotDifficulty(noiseRange: 3, flapStrength: 0.98, errorRate: 0.00),
            accentColor: Color(red: 0.95, green: 0.80, blue: 0.18), targetScore: 60,
            skin: .golden, taunt: "I am the one true duck. You are not ready."),
    ]

    static func find(_ id: String) -> BotCharacter? {
        all.first { $0.id == id }
    }
}
