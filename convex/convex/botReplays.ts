import { v } from "convex/values";
import { query, mutation } from "./_generated/server";

/**
 * Fetch a random active replay for a given bot ID.
 * Returns null if no replays exist (game falls back to behavioral AI).
 */
export const getRandomReplay = query({
  args: { botId: v.string() },
  handler: async (ctx, { botId }) => {
    const replays = await ctx.db
      .query("botReplays")
      .withIndex("by_botId_active", (q) =>
        q.eq("botId", botId).eq("isActive", true)
      )
      .collect();

    if (replays.length === 0) return null;

    // Pick a random replay
    const idx = Math.floor(Math.random() * replays.length);
    const replay = replays[idx];
    return {
      pipeSeed: replay.pipeSeed,
      flapTimestamps: replay.flapTimestamps,
      finalScore: replay.finalScore,
    };
  },
});

/**
 * Store a new bot replay (from a recorded human session).
 */
export const storeReplay = mutation({
  args: {
    botId: v.string(),
    pipeSeed: v.number(),
    flapTimestamps: v.array(v.float64()),
    finalScore: v.number(),
    recordedBy: v.optional(v.id("users")),
  },
  handler: async (ctx, args) => {
    return await ctx.db.insert("botReplays", {
      botId: args.botId,
      pipeSeed: args.pipeSeed,
      flapTimestamps: args.flapTimestamps,
      finalScore: args.finalScore,
      recordedBy: args.recordedBy,
      createdAt: Date.now(),
      isActive: true,
    });
  },
});

/**
 * Deactivate a replay (soft delete).
 */
export const deactivateReplay = mutation({
  args: { replayId: v.id("botReplays") },
  handler: async (ctx, { replayId }) => {
    await ctx.db.patch(replayId, { isActive: false });
  },
});
