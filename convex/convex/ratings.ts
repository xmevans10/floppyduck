import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";

export const leaderboard = query({
  args: {
    limit: v.optional(v.number()),
    deviceId: v.optional(v.string()),
    sessionToken: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const target = Math.max(1, Math.min(100, Math.floor(args.limit ?? 20)));
    const result: Array<{ userId: string; username: string; rating: number; rank: number }> = [];
    const seenAppleIds = new Set<string>();
    let cursor: string | null = null;

    while (result.length < target) {
      const batch = await ctx.db
        .query("ratings")
        .withIndex("by_rating")
        .order("desc")
        .paginate({ numItems: target, cursor });

      for (const row of batch.page) {
        const user = await ctx.db.get(row.userId);
        if (!user || user.provider !== "apple" || !user.appleUserId) continue;
        if (seenAppleIds.has(user.appleUserId)) continue;
        seenAppleIds.add(user.appleUserId);

        result.push({
          userId: user._id,
          username: user.username,
          rating: row.rating,
          rank: result.length + 1,
        });
        if (result.length >= target) break;
      }

      if (batch.isDone) break;
      cursor = batch.continueCursor;
    }

    return result;
  },
});

export const pruneNonAppleRatings = internalMutation({
  args: {},
  handler: async (ctx) => {
    const ratings = await ctx.db
      .query("ratings")
      .withIndex("by_rating")
      .order("desc")
      .collect();
    let deleted = 0;
    const seenAppleIds = new Set<string>();

    for (const rating of ratings) {
      const user = await ctx.db.get(rating.userId);
      if (!user || user.provider !== "apple" || !user.appleUserId || seenAppleIds.has(user.appleUserId)) {
        await ctx.db.delete(rating._id);
        deleted += 1;
        continue;
      }

      seenAppleIds.add(user.appleUserId);
    }

    return {
      deleted,
      kept: ratings.length - deleted,
    };
  },
});
