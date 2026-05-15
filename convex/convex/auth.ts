import { action, internalMutation, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { v, ConvexError } from "convex/values";
import type { Id } from "./_generated/dataModel";
import { findUserByAppleId, findUserByDeviceId, resolveUser, verifyAppleIdentityToken } from "./lib/identity";
import {
  buildUserFromSnapshot,
  defaultUserStats,
  shouldMergeLocalStats,
  toPublicProfile,
  upsertRating,
} from "./lib/stats";

// Remove before App Store release
const TESTFLIGHT_STARTING_BREAD = 10000;

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const sessionTokenArg = {
  sessionToken: v.optional(v.string()),
};

const USERNAME_MIN_LENGTH = 2;
const USERNAME_MAX_LENGTH = 16;
const RESERVED_USERNAMES = new Set([
  "admin",
  "administrator",
  "moderator",
  "mod",
  "staff",
  "support",
  "system",
  "floppyduck",
  "floppy duck",
  "player",
]);
const BLOCKED_USERNAME_PARTS = [
  "fuck",
  "shit",
  "bitch",
  "cunt",
  "nigger",
  "nigga",
  "fag",
  "faggot",
  "retard",
  "rape",
  "kike",
  "spic",
  "chink",
  "gook",
  "wetback",
  "nazi",
  "hitler",
];

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

function usernameKey(username: string) {
  return username.toLowerCase();
}

function normalizeUsername(input: string) {
  return input.trim().replace(/\s+/g, " ");
}

function validateUsername(input: string) {
  const username = normalizeUsername(input);
  if (username.length < USERNAME_MIN_LENGTH || username.length > USERNAME_MAX_LENGTH) {
    throw new ConvexError("Username must be 2-16 characters.");
  }

  if (!/^[A-Za-z0-9][A-Za-z0-9 _-]*[A-Za-z0-9]$/.test(username)) {
    throw new ConvexError("Use letters, numbers, spaces, _ or -.");
  }

  const key = usernameKey(username);
  if (RESERVED_USERNAMES.has(key)) {
    throw new ConvexError("Choose a more specific username.");
  }

  const compact = key.replace(/[\s_-]/g, "");
  if (BLOCKED_USERNAME_PARTS.some((blocked) => compact.includes(blocked))) {
    throw new ConvexError("Choose a different username.");
  }

  return { username, usernameKey: key };
}

function safeStoredUsername(input: string | undefined) {
  if (!input) return { username: "Player", usernameKey: "player" };
  try {
    return validateUsername(input);
  } catch {
    return { username: "Player", usernameKey: "player" };
  }
}

async function ensureUsernameAvailable(ctx: any, key: string, selfId?: Id<"users">) {
  const existingKeyMatch = await ctx.db
    .query("users")
    .withIndex("by_usernameKey", (q: any) => q.eq("usernameKey", key))
    .first();
  if (existingKeyMatch && existingKeyMatch._id !== selfId) {
    throw new ConvexError("That username is already taken.");
  }

  const legacyMatches = await ctx.db.query("users").collect();
  for (const user of legacyMatches) {
    if (user._id !== selfId && usernameKey(normalizeUsername(user.username)) === key) {
      throw new ConvexError("That username is already taken.");
    }
  }
}

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
      const storedUsername = safeStoredUsername(args.localStats?.username);
      const userId: Id<"users"> = await ctx.db.insert("users", {
        deviceId: args.deviceId,
        username: storedUsername.username,
        usernameKey: storedUsername.usernameKey,
        provider: "guest",
        ...defaults,
        bread: TESTFLIGHT_STARTING_BREAD,
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
      const storedUsername = safeStoredUsername(args.localStats.username ?? user.username);
      await ctx.db.patch(user._id, {
        username: storedUsername.username,
        usernameKey: storedUsername.usernameKey,
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
    username: v.optional(v.string()),
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
      username: args.username,
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
    username: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const requestedUsername = args.username ? validateUsername(args.username) : undefined;

    let appleUser = await findUserByAppleId(ctx, args.appleUserId);
    const guestUser = await findUserByDeviceId(ctx, args.deviceId);

    let userId: Id<"users">;
    let didMergeStats = false;

    if (appleUser) {
      userId = appleUser._id;
      if (requestedUsername) {
        await ensureUsernameAvailable(ctx, requestedUsername.usernameKey, appleUser._id);
      }

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
          username: requestedUsername?.username ?? appleUser.username,
          usernameKey: requestedUsername?.usernameKey ?? appleUser.usernameKey,
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
          username: requestedUsername?.username ?? appleUser.username,
          usernameKey: requestedUsername?.usernameKey ?? appleUser.usernameKey,
          provider: "apple",
          appleUserId: args.appleUserId,
          deviceId: args.deviceId,
          updatedAt: now,
        });
      }
    } else if (guestUser) {
      userId = guestUser._id;
      if (requestedUsername) {
        await ensureUsernameAvailable(ctx, requestedUsername.usernameKey, userId);
      }
      await ctx.db.patch(userId, {
        username: requestedUsername?.username ?? guestUser.username,
        usernameKey: requestedUsername?.usernameKey ?? guestUser.usernameKey,
        provider: "apple",
        appleUserId: args.appleUserId,
        deviceId: args.deviceId,
        updatedAt: now,
      });
      didMergeStats = true;
    } else {
      const defaults = defaultUserStats();
      if (!requestedUsername) {
        throw new ConvexError("Choose a username before signing in.");
      }
      await ensureUsernameAvailable(ctx, requestedUsername.usernameKey);
      userId = await ctx.db.insert("users", {
        deviceId: args.deviceId,
        appleUserId: args.appleUserId,
        username: requestedUsername.username,
        usernameKey: requestedUsername.usernameKey,
        provider: "apple",
        ...defaults,
        bread: TESTFLIGHT_STARTING_BREAD,
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


export const syncBeatenBots = mutation({
  args: {
    beatenBots: v.array(v.string()),
    ...sessionTokenArg,
    deviceId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const now = Date.now();

    // Merge: keep any server-side bots the client doesn't know about,
    // then add the client's new entries. Cap at 32 for safety.
    const merged = Array.from(
      new Set([...user.beatenBots, ...args.beatenBots]),
    ).slice(0, 32);

    if (merged.length !== user.beatenBots.length) {
      await ctx.db.patch(user._id, {
        beatenBots: merged,
        updatedAt: now,
      });
    }

    return { beatenBots: merged };
  },
});

export const spendBread = mutation({
  args: {
    amount: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const cost = Math.max(1, Math.floor(args.amount));

    if (user.bread < cost) {
      throw new ConvexError("Insufficient bread.");
    }

    const now = Date.now();
    await ctx.db.patch(user._id, {
      bread: user.bread - cost,
      updatedAt: now,
    });

    return { bread: user.bread - cost };
  },
});

export const updateUsername = mutation({
  args: {
    username: v.string(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const name = validateUsername(args.username);
    await ensureUsernameAvailable(ctx, name.usernameKey, user._id);

    await ctx.db.patch(user._id, {
      username: name.username,
      usernameKey: name.usernameKey,
      updatedAt: Date.now(),
    });

    return { username: name.username };
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
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
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
    const hostedRooms = await ctx.db
      .query("rooms")
      .withIndex("by_hostUserId", (q) => q.eq("hostUserId", userId))
      .collect();
    for (const room of hostedRooms) {
      if (room.status === "waiting") {
        await ctx.db.delete(room._id);
      }
    }

    // Also clean up rooms where user joined as guest
    const guestRooms = await ctx.db
      .query("rooms")
      .withIndex("by_guestUserId", (q) => q.eq("guestUserId", userId))
      .collect();
    for (const room of guestRooms) {
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

export const syncStats = mutation({
  args: {
    localStats: localStatsValidator,
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    if (!user) return { merged: false };

    const stats = args.localStats ?? {};
    const patch: Record<string, any> = {};

    if (typeof stats.bestScore === "number" && stats.bestScore > user.bestScore) {
      patch.bestScore = stats.bestScore;
    }
    if (typeof stats.gamesPlayed === "number" && stats.gamesPlayed > user.gamesPlayed) {
      patch.gamesPlayed = stats.gamesPlayed;
    }
    if (typeof stats.wins === "number" && stats.wins > user.wins) {
      patch.wins = stats.wins;
    }
    if (typeof stats.losses === "number" && stats.losses > user.losses) {
      patch.losses = stats.losses;
    }
    if (typeof stats.totalScore === "number" && stats.totalScore > user.totalScore) {
      patch.totalScore = stats.totalScore;
    }
    if (typeof stats.bread === "number" && stats.bread > user.bread) {
      patch.bread = stats.bread;
    }
    if (typeof stats.totalBreadCollected === "number" && stats.totalBreadCollected > (user.totalBreadCollected ?? 0)) {
      patch.totalBreadCollected = stats.totalBreadCollected;
    }
    if (Array.isArray(stats.beatenBots) && stats.beatenBots.length > 0) {
      const existing = new Set(user.beatenBots ?? []);
      for (const id of stats.beatenBots) {
        existing.add(id);
      }
      patch.beatenBots = [...existing].slice(0, 32);
    }

    if (Object.keys(patch).length > 0) {
      patch.updatedAt = Date.now();
      await ctx.db.patch(user._id, patch);
      return { merged: true };
    }

    return { merged: false };
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

export const grantTestflightBread = internalMutation({
  args: {},
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    const now = Date.now();
    let updated = 0;
    for (const user of users) {
      await ctx.db.patch(user._id, {
        bread: user.bread + 10000,
        updatedAt: now,
      });
      updated++;
    }
    return { updated, total: users.length };
  },
});
