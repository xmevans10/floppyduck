import { internalMutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";

type LeaderboardEntry = {
  userId: string;
  username: string;
  rating: number;
  rank: number;
};

export const leaderboard = query({
  args: {
    limit: v.optional(v.number()),
    deviceId: v.optional(v.string()),
    sessionToken: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const topN = Math.max(1, Math.min(100, Math.floor(args.limit ?? 50)));

    const entries: LeaderboardEntry[] = [];
    const seenAppleIds = new Set<string>();
    let cursor: string | null = null;

    while (entries.length < topN) {
      const batch = await ctx.db
        .query("ratings")
        .withIndex("by_rating")
        .order("desc")
        .paginate({ numItems: topN, cursor });

      for (const row of batch.page) {
        const user = await ctx.db.get(row.userId);
        if (!user || user.provider !== "apple" || !user.appleUserId) continue;
        if (seenAppleIds.has(user.appleUserId)) continue;
        seenAppleIds.add(user.appleUserId);

        entries.push({
          userId: user._id,
          username: user.username,
          rating: row.rating,
          rank: entries.length + 1,
        });
        if (entries.length >= topN) break;
      }

      if (batch.isDone) break;
      cursor = batch.continueCursor;
    }

    const requestUser = await resolveRequestUser(ctx, args);

    let ownEntry: LeaderboardEntry | null = null;
    if (requestUser && requestUser.provider === "apple" && requestUser.appleUserId) {
      const alreadyListed = entries.some((e) => e.userId === requestUser._id);
      if (!alreadyListed) {
        ownEntry = await computeUserRank(ctx, requestUser);
      }
    }

    return { entries, ownEntry };
  },
});

async function resolveRequestUser(
  ctx: any,
  args: { deviceId?: string; sessionToken?: string },
): Promise<Doc<"users"> | null> {
  if (args.sessionToken) {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q: any) => q.eq("token", args.sessionToken!))
      .first();
    if (session && !session.revokedAt && session.expiresAt > Date.now()) {
      const user = await ctx.db.get(session.userId);
      if (user) return user;
    }
  }

  if (args.deviceId) {
    const user = await ctx.db
      .query("users")
      .withIndex("by_deviceId", (q: any) => q.eq("deviceId", args.deviceId))
      .first();
    if (user) return user;
  }

  return null;
}

async function computeUserRank(
  ctx: any,
  requestUser: Doc<"users">,
): Promise<LeaderboardEntry | null> {
  let rank = 1;
  const seenAppleIds = new Set<string>();
  let cursor: string | null = null;

  const userRating = await ctx.db
    .query("ratings")
    .withIndex("by_userId", (q: any) => q.eq("userId", requestUser._id))
    .first();

  if (!userRating) return null;

  while (true) {
    const batch = await ctx.db
      .query("ratings")
      .withIndex("by_rating")
      .order("desc")
      .paginate({ numItems: 100, cursor });

    let foundSelf = false;

    for (const row of batch.page) {
      if (row.userId === requestUser._id) {
        foundSelf = true;
        break;
      }

      const user = await ctx.db.get(row.userId);
      if (!user || user.provider !== "apple" || !user.appleUserId) continue;
      if (seenAppleIds.has(user.appleUserId)) continue;
      seenAppleIds.add(user.appleUserId);
      rank++;
    }

    if (foundSelf) {
      return {
        userId: requestUser._id,
        username: requestUser.username,
        rating: userRating.rating,
        rank,
      };
    }

    if (batch.isDone) break;
    cursor = batch.continueCursor;
  }

  return null;
}

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
