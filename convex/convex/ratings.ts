import { query } from "./_generated/server";
import { v } from "convex/values";

export const leaderboard = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const target = Math.max(1, Math.min(100, Math.floor(args.limit ?? 20)));
    const result: Array<{ userId: string; username: string; rating: number; rank: number }> = [];
    let cursor: string | null = null;

    while (result.length < target) {
      const batch = await ctx.db
        .query("ratings")
        .withIndex("by_rating")
        .order("desc")
        .paginate({ numItems: target, cursor });

      for (const row of batch.page) {
        const user = await ctx.db.get(row.userId);
        if (!user) continue;
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
