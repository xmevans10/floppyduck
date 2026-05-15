import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  users: defineTable({
    deviceId: v.optional(v.string()),
    appleUserId: v.optional(v.string()),
    username: v.string(),
    usernameKey: v.optional(v.string()),
    selectedSkin: v.optional(v.string()),
    provider: v.union(v.literal("guest"), v.literal("apple")),

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
    .index("by_username", ["username"])
    .index("by_usernameKey", ["usernameKey"]),

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
    createdAt: v.number(),
    updatedAt: v.number(),
    finishedAt: v.optional(v.number()),
  })
    .index("by_p1UserId", ["p1UserId"])
    .index("by_p2UserId", ["p2UserId"])
    .index("by_roomCode", ["roomCode"])
    .index("by_status_createdAt", ["status", "createdAt"]),

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
});
