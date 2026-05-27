import { mutation, query } from "./_generated/server";
import { v, ConvexError } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { resolveUser } from "./lib/identity";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const MAX_FRIENDS = 200;
const MAX_PENDING_REQUESTS = 100;

// ─────────────────────────────────────────────────────────────────────────────
// Public Profile
// ─────────────────────────────────────────────────────────────────────────────

export const getPublicProfile = query({
  args: {
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) {
      throw new ConvexError("Player not found.");
    }

    return toPublicProfile(user);
  },
});

export const searchUsers = query({
  args: {
    query: v.string(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const requestUser = await resolveUser(ctx, args, { allowGuestFallback: false });
    const normalized = args.query.trim().toLowerCase();
    if (normalized.length < 2) {
      return [];
    }

    // Check exact usernameKey match first, then prefix match by scanning
    const exact = await ctx.db
      .query("users")
      .withIndex("by_usernameKey", (q: any) => q.eq("usernameKey", normalized))
      .first();

    const results: any[] = [];
    const seen = new Set<string>();

    if (exact && exact._id !== requestUser._id) {
      seen.add(exact._id as string);
      results.push(toPublicProfile(exact));
    }

    // Prefix scan: iterate usernameKey index, first page
    const scanned = await ctx.db
      .query("users")
      .withIndex("by_usernameKey")
      .paginate({ numItems: 200 });

    for (const user of scanned.page) {
      if (results.length >= 10) break;
      if (seen.has(user._id)) continue;
      if (user._id === requestUser._id) continue;
      const key = user.usernameKey ?? "";
      if (key.toLowerCase().startsWith(normalized)) {
        seen.add(user._id as string);
        results.push(toPublicProfile(user));
      }
    }

    return results;
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// Friends
// ─────────────────────────────────────────────────────────────────────────────

export const sendRequest = mutation({
  args: {
    toUserId: v.id("users"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const requester = await resolveUser(ctx, args, { allowGuestFallback: false });
    const now = Date.now();

    if (args.toUserId === requester._id) {
      throw new ConvexError("You cannot add yourself as a friend.");
    }

    const target = await ctx.db.get(args.toUserId);
    if (!target) {
      throw new ConvexError("Player not found.");
    }

    // Check if already friends or request exists
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", requester._id).eq("toUserId", args.toUserId))
      .first();

    if (existing) {
      if (existing.status === "accepted") {
        throw new ConvexError("Already friends.");
      }
      if (existing.status === "pending") {
        throw new ConvexError("Friend request already sent.");
      }
      if (existing.status === "blocked") {
        throw new ConvexError("Cannot send request.");
      }
    }

    // Check if target blocked requester
    const blockedBy = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", args.toUserId).eq("toUserId", requester._id))
      .first();

    if (blockedBy && blockedBy.status === "blocked") {
      throw new ConvexError("Cannot send friend request to this player.");
    }

    // Check pending requests limit
    const pendingCount = await countFriendships(ctx, requester._id, "from", "pending");
    if (pendingCount >= MAX_PENDING_REQUESTS) {
      throw new ConvexError("Too many pending requests.");
    }

    // Check outgoing friend count
    const friendCount = await countFriendships(ctx, requester._id, "either", "accepted");
    if (friendCount >= MAX_FRIENDS) {
      throw new ConvexError("Friend list is full.");
    }

    await ctx.db.insert("friendships", {
      fromUserId: requester._id,
      toUserId: args.toUserId,
      status: "pending",
      createdAt: now,
      updatedAt: now,
    });

    return { success: true };
  },
});

export const acceptRequest = mutation({
  args: {
    fromUserId: v.id("users"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const now = Date.now();

    const request = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", args.fromUserId).eq("toUserId", user._id))
      .first();

    if (!request || request.status !== "pending") {
      throw new ConvexError("Friend request not found.");
    }

    // Check friend count for both sides
    const userFriendCount = await countFriendships(ctx, user._id, "either", "accepted");
    if (userFriendCount >= MAX_FRIENDS) {
      throw new ConvexError("Your friend list is full.");
    }

    const otherFriendCount = await countFriendships(ctx, args.fromUserId, "either", "accepted");
    if (otherFriendCount >= MAX_FRIENDS) {
      throw new ConvexError("Their friend list is full.");
    }

    await ctx.db.patch(request._id, {
      status: "accepted",
      updatedAt: now,
    });

    return { success: true };
  },
});

export const removeFriendship = mutation({
  args: {
    otherUserId: v.id("users"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    // Find friendship in either direction
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", user._id).eq("toUserId", args.otherUserId))
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
      return { success: true };
    }

    // Check reverse direction (they initiated)
    const reverse = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", args.otherUserId).eq("toUserId", user._id))
      .first();

    if (reverse) {
      await ctx.db.delete(reverse._id);
      return { success: true };
    }

    throw new ConvexError("Friendship not found.");
  },
});

export const blockUser = mutation({
  args: {
    toUserId: v.id("users"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const now = Date.now();

    if (args.toUserId === user._id) {
      throw new ConvexError("You cannot block yourself.");
    }

    // Remove any existing friendship
    const existing = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", user._id).eq("toUserId", args.toUserId))
      .first();

    if (existing) {
      await ctx.db.patch(existing._id, {
        status: "blocked",
        updatedAt: now,
      });
    } else {
      await ctx.db.insert("friendships", {
        fromUserId: user._id,
        toUserId: args.toUserId,
        status: "blocked",
        createdAt: now,
        updatedAt: now,
      });
    }

    // Also remove any pending request from the blocked user
    const reverse = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", args.toUserId).eq("toUserId", user._id))
      .first();

    if (reverse && (reverse.status === "pending" || reverse.status === "accepted")) {
      await ctx.db.delete(reverse._id);
    }

    return { success: true };
  },
});

export const unblockUser = mutation({
  args: {
    toUserId: v.id("users"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    const block = await ctx.db
      .query("friendships")
      .withIndex("by_from_to", (q: any) =>
        q.eq("fromUserId", user._id).eq("toUserId", args.toUserId))
      .first();

    if (block && block.status === "blocked") {
      await ctx.db.delete(block._id);
    }

    return { success: true };
  },
});

export const getFriends = query({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    // Friends are accepted friendships in either direction
    const sent = await ctx.db
      .query("friendships")
      .withIndex("by_fromUserId", (q: any) => q.eq("fromUserId", user._id))
      .collect();

    const received = await ctx.db
      .query("friendships")
      .withIndex("by_toUserId", (q: any) => q.eq("toUserId", user._id))
      .collect();

    const friendIds = new Set<Id<"users">>();
    const friendProfiles: any[] = [];

    for (const f of sent) {
      if (f.status === "accepted") {
        friendIds.add(f.toUserId);
      }
    }

    for (const f of received) {
      if (f.status === "accepted" && !friendIds.has(f.fromUserId)) {
        friendIds.add(f.fromUserId);
      }
    }

    for (const id of friendIds) {
      const friendUser = await ctx.db.get(id);
      if (friendUser) {
        friendProfiles.push(toPublicProfile(friendUser));
      }
    }

    friendProfiles.sort((a, b) => a.username.localeCompare(b.username));
    return friendProfiles;
  },
});

export const getPendingRequests = query({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    const pending = await ctx.db
      .query("friendships")
      .withIndex("by_to_status", (q: any) =>
        q.eq("toUserId", user._id).eq("status", "pending"))
      .collect();

    const profiles: any[] = [];
    for (const p of pending) {
      const requester = await ctx.db.get(p.fromUserId);
      if (requester) {
        profiles.push(toPublicProfile(requester));
      }
    }

    profiles.sort((a, b) => a.username.localeCompare(b.username));
    return profiles;
  },
});

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function toPublicProfile(user: Doc<"users">) {
  return {
    userId: user._id,
    username: user.username,
    provider: user.provider,
    stats: {
      gamesPlayed: user.gamesPlayed,
      wins: user.wins,
      losses: user.losses,
      bestScore: user.bestScore,
      totalScore: user.totalScore,
      elo: user.rating,
      peakElo: user.rating,
      winStreak: 0,
      bestWinStreak: 0,
      beatenBotsCount: (user.beatenBots ?? []).length,
      recentScores: user.recentScores,
      selectedSkin: user.selectedSkin ?? null,
    },
  };
}

async function countFriendships(
  ctx: any,
  userId: Id<"users">,
  direction: "from" | "to" | "either",
  status: "pending" | "accepted" | "blocked",
): Promise<number> {
  if (direction === "from") {
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_fromUserId", (q: any) => q.eq("fromUserId", userId))
      .collect();
    return rows.filter((r: any) => r.status === status).length;
  }

  if (direction === "to") {
    const rows = await ctx.db
      .query("friendships")
      .withIndex("by_toUserId", (q: any) => q.eq("toUserId", userId))
      .collect();
    return rows.filter((r: any) => r.status === status).length;
  }

  // "either" — from and to queries are mutually exclusive
  const from = await ctx.db
    .query("friendships")
    .withIndex("by_fromUserId", (q: any) => q.eq("fromUserId", userId))
    .collect();
  const to = await ctx.db
    .query("friendships")
    .withIndex("by_toUserId", (q: any) => q.eq("toUserId", userId))
    .collect();

  return from.filter((r: any) => r.status === status).length
       + to.filter((r: any) => r.status === status).length;
}
