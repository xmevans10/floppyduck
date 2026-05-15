import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { resolveUser } from "./lib/identity";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

function randomSeed() {
  return Math.floor(Math.random() * 999_999) + 1;
}

function randomSessionCode() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

function randomRoomCode() {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  let code = "";
  for (let i = 0; i < 5; i += 1) {
    code += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return code;
}

export const joinQueue = mutation({
  args: {
    mode: v.union(v.literal("quick"), v.literal("ranked")),
    ticketId: v.optional(v.string()),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, {
      requireLinked: args.mode === "ranked",
    });

    const existing = await ctx.db
      .query("matchmakingQueue")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .collect();

    const active = existing.find((entry) => entry.status === "searching" && entry.mode === args.mode);
    if (active) {
      return { ticketId: active.ticketId };
    }

    const ticketId = args.ticketId ?? crypto.randomUUID();
    const now = Date.now();

    const queueId: Id<"matchmakingQueue"> = await ctx.db.insert("matchmakingQueue", {
      userId: user._id,
      mode: args.mode,
      status: "searching",
      ticketId,
      createdAt: now,
    });

    const opponent = await ctx.db
      .query("matchmakingQueue")
      .withIndex("by_mode_status_createdAt", (q) => q.eq("mode", args.mode).eq("status", "searching"))
      .order("asc")
      .filter((q) => q.neq(q.field("userId"), user._id))
      .first();

    if (opponent) {
      const gameKitCode = randomSessionCode();
      const matchId: Id<"matches"> = await ctx.db.insert("matches", {
        mode: args.mode,
        seed: randomSeed(),
        gameKitSessionCode: gameKitCode,
        p1UserId: opponent.userId,
        p2UserId: user._id,
        p1Score: 0,
        p2Score: 0,
        p1Finished: false,
        p2Finished: false,
        status: "active",
        createdAt: now,
        updatedAt: now,
      });

      await ctx.db.patch(opponent._id, { status: "matched", matchId });
      await ctx.db.patch(queueId, { status: "matched", matchId });
    }

    return { ticketId };
  },
});

export const leaveQueue = mutation({
  args: {
    ticketId: v.optional(v.string()),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    if (args.ticketId) {
      const byTicket = await ctx.db
        .query("matchmakingQueue")
        .withIndex("by_ticketId", (q) => q.eq("ticketId", args.ticketId!))
        .first();
      if (byTicket && byTicket.status === "searching") {
        await ctx.db.delete(byTicket._id);
      }
      return { success: true };
    }

    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const entries = await ctx.db
      .query("matchmakingQueue")
      .withIndex("by_userId", (q) => q.eq("userId", user._id))
      .collect();

    await Promise.all(
      entries
        .filter((entry) => entry.status === "searching")
        .map((entry) => ctx.db.delete(entry._id)),
    );

    return { success: true };
  },
});

export const checkQueue = query({
  args: {
    ticketId: v.optional(v.string()),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    let queueEntry: Doc<"matchmakingQueue"> | null = null;
    let currentUserId: Id<"users"> | null = null;

    if (args.ticketId) {
      queueEntry = await ctx.db
        .query("matchmakingQueue")
        .withIndex("by_ticketId", (q) => q.eq("ticketId", args.ticketId!))
        .first();
      if (queueEntry) {
        currentUserId = queueEntry.userId;
      }
    }

    if (!queueEntry) {
      const user = await resolveUser(ctx, args, { allowGuestFallback: false });
      currentUserId = user._id;

      const entries = await ctx.db
        .query("matchmakingQueue")
        .withIndex("by_userId", (q) => q.eq("userId", user._id))
        .collect();
      queueEntry = entries.find((entry) => entry.status === "matched") ?? null;
    }

    if (!queueEntry || !queueEntry.matchId || !currentUserId) {
      return { found: false };
    }

    const match = await ctx.db.get(queueEntry.matchId);
    if (!match) {
      return { found: false };
    }

    const opponentId = match.p1UserId === currentUserId ? match.p2UserId : match.p1UserId;
    const opponent = await ctx.db.get(opponentId);

    return {
      found: true,
      assignment: {
        matchId: match._id,
        seed: match.seed,
        opponentName: opponent?.username ?? "OPPONENT",
        opponentSkinId: opponent?.selectedSkin ?? undefined,
        gameKitSessionCode: match.gameKitSessionCode ?? undefined,
        mode: match.mode,
        isRanked: match.mode === "ranked",
      },
    };
  },
});

export const createRoom = mutation({
  args: {
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args);

    const now = Date.now();
    let code = randomRoomCode();

    for (let i = 0; i < 6; i += 1) {
      const existing = await ctx.db
        .query("rooms")
        .withIndex("by_code", (q) => q.eq("code", code))
        .first();
      if (!existing || existing.status !== "waiting") {
        break;
      }
      code = randomRoomCode();
    }

    const roomId = await ctx.db.insert("rooms", {
      code,
      hostUserId: user._id,
      status: "waiting",
      createdAt: now,
    });

    return {
      roomCode: code,
      ticketId: roomId,
    };
  },
});

export const joinRoom = mutation({
  args: {
    code: v.string(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args);

    const code = args.code.trim().toUpperCase();
    const room = await ctx.db
      .query("rooms")
      .withIndex("by_code", (q) => q.eq("code", code))
      .first();

    if (!room || room.status !== "waiting") {
      throw new Error("Room not found or already matched.");
    }

    if (room.hostUserId === user._id) {
      throw new Error("Cannot join your own room.");
    }

    const now = Date.now();
    const matchId: Id<"matches"> = await ctx.db.insert("matches", {
      mode: "private",
      seed: randomSeed(),
      gameKitSessionCode: room.code,
      p1UserId: room.hostUserId,
      p2UserId: user._id,
      p1Score: 0,
      p2Score: 0,
      p1Finished: false,
      p2Finished: false,
      status: "active",
      roomCode: room.code,
      createdAt: now,
      updatedAt: now,
    });

    await ctx.db.patch(room._id, {
      guestUserId: user._id,
      status: "matched",
      matchId,
    });

    return {
      roomCode: room.code,
      ticketId: room._id,
    };
  },
});

export const leaveRoom = mutation({
  args: {
    code: v.string(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    const code = args.code.trim().toUpperCase();
    const room = await ctx.db
      .query("rooms")
      .withIndex("by_code", (q) => q.eq("code", code))
      .first();

    if (!room) {
      return { success: true };
    }

    if (room.status === "waiting") {
      if (room.hostUserId === user._id) {
        await ctx.db.delete(room._id);
      }
    }

    return { success: true };
  },
});

export const checkRoom = query({
  args: {
    code: v.string(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });

    const code = args.code.trim().toUpperCase();
    const room = await ctx.db
      .query("rooms")
      .withIndex("by_code", (q) => q.eq("code", code))
      .first();

    if (!room) {
      return { found: false };
    }

    if (room.hostUserId !== user._id && room.guestUserId !== user._id) {
      return { found: false };
    }

    if (!room.matchId) {
      return { found: false };
    }

    const match = await ctx.db.get(room.matchId);
    if (!match) {
      return { found: false };
    }

    const opponentId = match.p1UserId === user._id ? match.p2UserId : match.p1UserId;
    const opponent = await ctx.db.get(opponentId);

    return {
      found: true,
      assignment: {
        matchId: match._id,
        seed: match.seed,
        opponentName: opponent?.username ?? "OPPONENT",
        opponentSkinId: opponent?.selectedSkin ?? undefined,
        gameKitSessionCode: match.gameKitSessionCode ?? undefined,
        mode: "private",
        isRanked: false,
        roomCode: code,
      },
    };
  },
});
