import { action, internalMutation, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { findUserByAppleId, findUserByDeviceId, resolveUser, verifyAppleIdentityToken } from "./lib/identity";
import {
  buildUserFromSnapshot,
  defaultUserStats,
  shouldMergeLocalStats,
  toPublicProfile,
  upsertRating,
} from "./lib/stats";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const sessionTokenArg = {
  sessionToken: v.optional(v.string()),
};

const localStatsValidator = v.optional(
  v.object({
    username: v.optional(v.string()),
    gamesPlayed: v.optional(v.number()),
    wins: v.optional(v.number()),
    losses: v.optional(v.number()),
    bestScore: v.optional(v.number()),
    totalScore: v.optional(v.number()),
    elo: v.optional(v.number()),
    bread: v.optional(v.number()),
    totalBreadCollected: v.optional(v.number()),
    recentScores: v.optional(v.array(v.number())),
    beatenBots: v.optional(v.array(v.string())),
  }),
);

export const bootstrapGuest = mutation({
  args: {
    deviceId: v.string(),
    localStats: localStatsValidator,
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    let user = await findUserByDeviceId(ctx, args.deviceId);

    if (!user) {
      const defaults = defaultUserStats();
      const userId: Id<"users"> = await ctx.db.insert("users", {
        deviceId: args.deviceId,
        username: args.localStats?.username ?? "Player",
        provider: "guest",
        ...defaults,
        createdAt: now,
        updatedAt: now,
      });
      await upsertRating(ctx, userId, defaults.rating, now);
      user = await ctx.db.get(userId);
    }

    if (!user) {
      throw new Error("Unable to create guest profile.");
    }

    let didMergeStats = false;

    if (args.localStats && shouldMergeLocalStats(user)) {
      const merged = buildUserFromSnapshot(args.localStats);
      await ctx.db.patch(user._id, {
        username: args.localStats.username ?? user.username,
        rating: merged.rating,
        gamesPlayed: merged.gamesPlayed,
        wins: merged.wins,
        losses: merged.losses,
        bestScore: merged.bestScore,
        totalScore: merged.totalScore,
        bread: merged.bread,
        totalBreadCollected: merged.totalBreadCollected,
        recentScores: merged.recentScores,
        beatenBots: merged.beatenBots,
        updatedAt: now,
      });

      await upsertRating(ctx, user._id, merged.rating, now);
      didMergeStats = true;
      user = await ctx.db.get(user._id);
    }

    if (!user) {
      throw new Error("Unable to load guest profile.");
    }

    return {
      profile: toPublicProfile(user),
      didMergeStats,
    };
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// Apple Sign-In
//
// `linkApple` is an ACTION (not a mutation) because Apple JWT verification
// requires fetching Apple's public JWKS from https://appleid.apple.com/auth/keys.
// Convex mutations run as database transactions and cannot call `fetch()`.
//
// Flow: action verifies the Apple identity token → calls internal mutation
// to perform database writes (upsert user, create session).
// ─────────────────────────────────────────────────────────────────────────────

export const linkApple = action({
  args: {
    identityToken: v.string(),
    nonce: v.string(),
    deviceId: v.string(),
    displayName: v.optional(v.string()),
    ...sessionTokenArg,
  },
  handler: async (ctx, args): Promise<any> => {
    // Step 1: Verify the Apple identity token (requires fetch for JWKS).
    const claims = await verifyAppleIdentityToken(args.identityToken, args.nonce);

    // Step 2: Delegate all database work to an internal mutation.
    return await ctx.runMutation(internal.auth.linkAppleWrite, {
      appleUserId: claims.sub,
      email: claims.email,
      deviceId: args.deviceId,
      displayName: args.displayName,
    });
  },
});

/**
 * Internal mutation — performs the database writes for Apple Sign-In.
 * Only callable from other Convex functions (not directly from clients).
 */
export const linkAppleWrite = internalMutation({
  args: {
    appleUserId: v.string(),
    email: v.optional(v.string()),
    deviceId: v.string(),
    displayName: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();

    let appleUser = await findUserByAppleId(ctx, args.appleUserId);
    const guestUser = await findUserByDeviceId(ctx, args.deviceId);

    let userId: Id<"users">;
    let didMergeStats = false;

    if (appleUser) {
      userId = appleUser._id;

      // Apple profile is source of truth. Only merge guest progress into Apple profile
      // when Apple profile is effectively fresh and guest actually has progress.
      const canMergeGuestIntoApple = Boolean(
        guestUser &&
          guestUser._id !== appleUser._id &&
          shouldMergeLocalStats(appleUser) &&
          !shouldMergeLocalStats(guestUser),
      );

      if (canMergeGuestIntoApple && guestUser) {
        await ctx.db.patch(appleUser._id, {
          username: args.displayName ?? appleUser.username,
          rating: guestUser.rating,
          gamesPlayed: guestUser.gamesPlayed,
          wins: guestUser.wins,
          losses: guestUser.losses,
          bestScore: guestUser.bestScore,
          totalScore: guestUser.totalScore,
          bread: guestUser.bread,
          totalBreadCollected: guestUser.totalBreadCollected,
          recentScores: guestUser.recentScores,
          beatenBots: guestUser.beatenBots,
          updatedAt: now,
        });

        didMergeStats = true;
      } else {
        await ctx.db.patch(appleUser._id, {
          username: args.displayName ?? appleUser.username,
          provider: "apple",
          appleUserId: args.appleUserId,
          deviceId: args.deviceId,
          updatedAt: now,
        });
      }
    } else if (guestUser) {
      userId = guestUser._id;
      await ctx.db.patch(userId, {
        username: args.displayName ?? guestUser.username,
        provider: "apple",
        appleUserId: args.appleUserId,
        deviceId: args.deviceId,
        updatedAt: now,
      });
      didMergeStats = true;
    } else {
      const defaults = defaultUserStats();
      userId = await ctx.db.insert("users", {
        deviceId: args.deviceId,
        appleUserId: args.appleUserId,
        username: args.displayName ?? "Player",
        provider: "apple",
        ...defaults,
        createdAt: now,
        updatedAt: now,
      });
      await upsertRating(ctx, userId, defaults.rating, now);
    }

    const sessionToken = crypto.randomUUID();
    const sessionExpiresAt = now + 1000 * 60 * 60 * 24 * 30;

    await ctx.db.insert("sessions", {
      userId,
      token: sessionToken,
      createdAt: now,
      expiresAt: sessionExpiresAt,
    });

    await upsertRating(ctx, userId, (await ctx.db.get(userId))!.rating, now);

    const user = await ctx.db.get(userId);
    if (!user) {
      throw new Error("Unable to load linked account.");
    }

    return {
      profile: toPublicProfile(user),
      sessionToken,
      sessionExpiresAt: Math.floor(sessionExpiresAt / 1000),
      appleUserId: args.appleUserId,
      didMergeStats,
    };
  },
});

export const getProfile = query({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    return toPublicProfile(user);
  },
});

export const deleteAccount = mutation({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { requireLinked: true });
    const userId = user._id;

    // Delete all sessions for this user
    const sessions = await ctx.db
      .query("sessions")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();
    for (const session of sessions) {
      await ctx.db.delete(session._id);
    }

    // Delete matchmaking queue entries
    const queueEntries = await ctx.db
      .query("matchmakingQueue")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .collect();
    for (const entry of queueEntries) {
      await ctx.db.delete(entry._id);
    }

    // Delete rooms where user is host and status is "waiting"
    const rooms = await ctx.db
      .query("rooms")
      .withIndex("by_hostUserId", (q) => q.eq("hostUserId", userId))
      .collect();
    for (const room of rooms) {
      if (room.status === "waiting") {
        await ctx.db.delete(room._id);
      }
    }

    // Delete ratings entry
    const rating = await ctx.db
      .query("ratings")
      .withIndex("by_userId", (q) => q.eq("userId", userId))
      .first();
    if (rating) {
      await ctx.db.delete(rating._id);
    }

    // Delete the user document itself
    await ctx.db.delete(userId);

    // NOTE: Matches are intentionally preserved — they reference two players
    // and deleting would affect data integrity for the other participant.

    return { success: true };
  },
});

export const signOutSession = mutation({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    if (!args.sessionToken) {
      return { success: true };
    }

    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q) => q.eq("token", args.sessionToken!))
      .first();

    if (session && !session.revokedAt) {
      await ctx.db.patch(session._id, {
        revokedAt: Date.now(),
      });
    }

    return { success: true };
  },
});
