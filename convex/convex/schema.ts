import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    deviceId: v.optional(v.string()),
    appleUserId: v.optional(v.string()),
    gameCenterPlayerId: v.optional(v.string()),
    username: v.string(),
    usernameKey: v.optional(v.string()),
    selectedSkin: v.optional(v.string()),
    provider: v.union(v.literal("guest"), v.literal("apple"), v.literal("gameCenter")),

    rating: v.number(),
    gamesPlayed: v.number(),
    wins: v.number(),
    losses: v.number(),
    bestScore: v.number(),
    totalScore: v.number(),
    bread: v.number(),
    totalBreadCollected: v.optional(v.number()),
    recentScores: v.array(v.number()),
    beatenBots: v.array(v.string()),

    createdAt: v.number(),
    updatedAt: v.number(),
  })
    .index("by_deviceId", ["deviceId"])
    .index("by_appleUserId", ["appleUserId"])
    .index("by_gameCenterPlayerId", ["gameCenterPlayerId"])
    .index("by_username", ["username"])
    .index("by_usernameKey", ["usernameKey"])
    .index("by_bestScore", ["bestScore"]),

  sessions: defineTable({
    userId: v.id("users"),
    token: v.string(),
    createdAt: v.number(),
    expiresAt: v.number(),
    revokedAt: v.optional(v.number()),
  })
    .index("by_token", ["token"])
    .index("by_userId", ["userId"]),

  matchmakingQueue: defineTable({
    userId: v.id("users"),
    mode: v.union(v.literal("quick"), v.literal("ranked")),
    status: v.union(v.literal("searching"), v.literal("matched")),
    ticketId: v.string(),
    createdAt: v.number(),
    lastSeenAt: v.number(),
    matchId: v.optional(v.id("matches")),
  })
    .index("by_ticketId", ["ticketId"])
    .index("by_userId", ["userId"])
    .index("by_mode_status_createdAt", ["mode", "status", "createdAt"]),

  rooms: defineTable({
    code: v.string(),
    hostUserId: v.id("users"),
    guestUserId: v.optional(v.id("users")),
    status: v.union(v.literal("waiting"), v.literal("matched")),
    createdAt: v.number(),
    matchId: v.optional(v.id("matches")),
  })
    .index("by_code", ["code"])
    .index("by_hostUserId", ["hostUserId"])
    .index("by_guestUserId", ["guestUserId"]),

  matches: defineTable({
    mode: v.union(v.literal("quick"), v.literal("ranked"), v.literal("private")),
    seed: v.number(),
    p1UserId: v.id("users"),
    p2UserId: v.id("users"),
    p1Score: v.number(),
    p2Score: v.number(),
    p1Finished: v.boolean(),
    p2Finished: v.boolean(),
    status: v.union(v.literal("active"), v.literal("finished")),
    winnerUserId: v.optional(v.id("users")),
    ratingDeltaP1: v.optional(v.number()),
    ratingDeltaP2: v.optional(v.number()),
    roomCode: v.optional(v.string()),
    gameKitSessionCode: v.optional(v.string()),
    p1Ready: v.optional(v.number()),
    p2Ready: v.optional(v.number()),
    startAtMs: v.optional(v.number()),
    createdAt: v.number(),
    updatedAt: v.number(),
    finishedAt: v.optional(v.number()),
  })
    .index("by_p1UserId", ["p1UserId"])
    .index("by_p2UserId", ["p2UserId"])
    .index("by_roomCode", ["roomCode"])
    .index("by_status_createdAt", ["status", "createdAt"]),

  battleRoyaleLobbies: defineTable({
    status: v.union(v.literal("open"), v.literal("active"), v.literal("finished"), v.literal("cancelled")),
    seed: v.number(),
    buyIn: v.number(),
    maxPlayers: v.number(),
    createdAt: v.number(),
    updatedAt: v.number(),
    startedAt: v.optional(v.number()),
    finishedAt: v.optional(v.number()),
  })
    .index("by_status_createdAt", ["status", "createdAt"]),

  battleRoyaleEntrants: defineTable({
    lobbyId: v.id("battleRoyaleLobbies"),
    userId: v.id("users"),
    username: v.string(),
    skinId: v.optional(v.string()),
    score: v.number(),
    y: v.number(),
    rotation: v.number(),
    wingPhase: v.number(),
    alive: v.boolean(),
    placement: v.optional(v.number()),
    prize: v.optional(v.number()),
    joinedAt: v.number(),
    lastSeenAt: v.number(),
    finishedAt: v.optional(v.number()),
  })
    .index("by_lobbyId", ["lobbyId"])
    .index("by_lobby_alive", ["lobbyId", "alive"])
    .index("by_userId", ["userId"]),

  battleRoyalePayouts: defineTable({
    lobbyId: v.id("battleRoyaleLobbies"),
    userId: v.id("users"),
    placement: v.number(),
    amount: v.number(),
    paidAt: v.number(),
  })
    .index("by_lobbyId", ["lobbyId"])
    .index("by_userId", ["userId"]),

  ratings: defineTable({
    userId: v.id("users"),
    rating: v.number(),
    updatedAt: v.number(),
  })
    .index("by_userId", ["userId"])
    .index("by_rating", ["rating"]),

  announcements: defineTable({
    title: v.string(),
    body: v.array(v.string()),
    color: v.optional(v.string()),
    active: v.boolean(),
    createdAt: v.number(),
  })
    .index("by_active_createdAt", ["active", "createdAt"]),

  diagnosticEvents: defineTable({
    userId: v.optional(v.id("users")),
    deviceId: v.optional(v.string()),
    category: v.string(),
    event: v.string(),
    level: v.union(v.literal("debug"), v.literal("info"), v.literal("warning"), v.literal("error")),
    message: v.optional(v.string()),
    matchId: v.optional(v.string()),
    sessionCode: v.optional(v.string()),
    playerGroup: v.optional(v.number()),
    mode: v.optional(v.string()),
    metadata: v.optional(v.array(v.object({
      key: v.string(),
      value: v.string(),
    }))),
    createdAt: v.number(),
  })
    .index("by_createdAt", ["createdAt"])
    .index("by_matchId_createdAt", ["matchId", "createdAt"])
    .index("by_sessionCode_createdAt", ["sessionCode", "createdAt"])
    .index("by_category_createdAt", ["category", "createdAt"]),
});
