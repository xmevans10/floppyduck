import { query } from "./_generated/server";
import { v } from "convex/values";

export const leaderboard = query({
  args: {
    limit: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(100, Math.floor(args.limit ?? 20)));

    const rows = await ctx.db
      .query("ratings")
      .withIndex("by_rating")
      .order("desc")
      .take(limit);

    const result: Array<{ userId: string; username: string; rating: number; rank: number }> = [];

    for (let index = 0; index < rows.length; index += 1) {
      const row = rows[index];
      const user = await ctx.db.get(row.userId);
      if (!user) {
        continue;
      }

      result.push({
        userId: user._id,
        username: user.username,
        rating: row.rating,
        rank: index + 1,
      });
    }

    return result;
  },
});
