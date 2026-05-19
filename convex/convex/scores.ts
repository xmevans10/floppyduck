import { query } from "./_generated/server";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";

type HighScoreEntry = {
  userId: string;
  username: string;
  bestScore: number;
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

    const users = await ctx.db
      .query("users")
      .withIndex("by_bestScore")
      .order("desc")
      .collect();

    const entries: HighScoreEntry[] = [];
    const seenIdentityIds = new Set<string>();

    for (const user of users) {
      if (entries.length >= topN) break;
      const identityId = scoreIdentityId(user);
      if (!identityId) continue;
      if (seenIdentityIds.has(identityId)) continue;
      if (!user.bestScore || user.bestScore <= 0) continue;
      seenIdentityIds.add(identityId);

      entries.push({
        userId: user._id,
        username: user.username,
        bestScore: user.bestScore,
        rank: entries.length + 1,
      });
    }

    const requestUser = await resolveRequestUser(ctx, args);

    let ownEntry: HighScoreEntry | null = null;
    if (requestUser && scoreIdentityId(requestUser) && requestUser.bestScore > 0) {
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
): Promise<HighScoreEntry | null> {
  let rank = 1;
  const seenIdentityIds = new Set<string>();
  let cursor: string | null = null;

  while (true) {
    const batch = await ctx.db
      .query("users")
      .withIndex("by_bestScore")
      .order("desc")
      .paginate({ numItems: 100, cursor });

    let foundSelf = false;

    for (const user of batch.page) {
      if (user._id === requestUser._id) {
        foundSelf = true;
        break;
      }

      const identityId = scoreIdentityId(user);
      if (!identityId) continue;
      if (seenIdentityIds.has(identityId)) continue;
      if (!user.bestScore || user.bestScore <= 0) continue;
      seenIdentityIds.add(identityId);
      rank++;
    }

    if (foundSelf) {
      return {
        userId: requestUser._id,
        username: requestUser.username,
        bestScore: requestUser.bestScore,
        rank,
      };
    }

    if (batch.isDone) break;
    cursor = batch.continueCursor;
  }

  return null;
}

function scoreIdentityId(user: Doc<"users">): string | null {
  if (user.provider === "gameCenter" && user.gameCenterPlayerId) {
    return `gc:${user.gameCenterPlayerId}`;
  }
  if (user.provider === "apple" && user.appleUserId) {
    return `apple:${user.appleUserId}`;
  }
  return null;
}
