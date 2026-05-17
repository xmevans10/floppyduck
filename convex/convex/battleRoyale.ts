import { mutation, query } from "./_generated/server";
import { v, ConvexError } from "convex/values";
import type { Doc, Id } from "./_generated/dataModel";
import { resolveUser } from "./lib/identity";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const BUY_IN = 25;
const MAX_PLAYERS = 100;
const MIN_PLAYERS_TO_START = 10;
const START_AFTER_MS = 60 * 1000;
const CANCEL_AFTER_MS = 5 * 60 * 1000;
const STALE_AFTER_MS = 30 * 1000;
const PAYOUTS = [0.40, 0.25, 0.15, 0.10, 0.05];

function randomSeed() {
  return Math.floor(Math.random() * 999_999) + 1;
}

export const joinLobby = mutation({
  args: identityArgs,
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args);
    const now = Date.now();

    const existing = await activeEntrantForUser(ctx, user._id);
    if (existing) {
      return await buildAssignment(ctx, existing.lobbyId, existing._id, user.bread);
    }

    if (user.bread < BUY_IN) {
      throw new ConvexError("Insufficient bread.");
    }

    let lobby = await findOpenLobby(ctx);
    if (!lobby) {
      const lobbyId = await ctx.db.insert("battleRoyaleLobbies", {
        status: "open",
        seed: randomSeed(),
        buyIn: BUY_IN,
        maxPlayers: MAX_PLAYERS,
        createdAt: now,
        updatedAt: now,
      });
      lobby = await ctx.db.get(lobbyId);
    }

    if (!lobby) {
      throw new Error("Unable to create battle royale lobby.");
    }

    await ctx.db.patch(user._id, {
      bread: user.bread - BUY_IN,
      updatedAt: now,
    });

    const entrantId = await ctx.db.insert("battleRoyaleEntrants", {
      lobbyId: lobby._id,
      userId: user._id,
      username: user.username,
      skinId: user.selectedSkin,
      score: 0,
      y: 0,
      rotation: 0,
      wingPhase: 1,
      alive: true,
      joinedAt: now,
      lastSeenAt: now,
    });

    await maybeStartLobby(ctx, lobby._id, now);
    return await buildAssignment(ctx, lobby._id, entrantId, user.bread - BUY_IN);
  },
});

export const leaveLobby = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby || lobby.status !== "open") {
      return { ok: true, refunded: false, bread: user.bread };
    }

    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant) {
      return { ok: true, refunded: false, bread: user.bread };
    }

    const now = Date.now();
    await ctx.db.delete(entrant._id);
    await ctx.db.patch(user._id, {
      bread: user.bread + lobby.buyIn,
      updatedAt: now,
    });
    return { ok: true, refunded: true, bread: user.bread + lobby.buyIn };
  },
});

export const startIfReady = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant) {
      throw new ConvexError("You are not in this battle royale.");
    }
    await maybeStartLobby(ctx, args.lobbyId, Date.now());
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

export const reportState = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    score: v.number(),
    y: v.number(),
    rotation: v.number(),
    wingPhase: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby || lobby.status !== "active") {
      return { ok: false };
    }
    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant || !entrant.alive) {
      return { ok: false };
    }

    await ctx.db.patch(entrant._id, {
      score: Math.max(entrant.score, safeInt(args.score)),
      y: args.y,
      rotation: args.rotation,
      wingPhase: safeInt(args.wingPhase),
      lastSeenAt: Date.now(),
    });
    return { ok: true };
  },
});

export const finishRun = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    score: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby) {
      throw new Error("Battle royale lobby not found.");
    }

    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant) {
      throw new ConvexError("You are not in this battle royale.");
    }

    if (entrant.placement) {
      return await buildState(ctx, args.lobbyId, user._id);
    }

    const now = Date.now();
    const placement = await nextPlacement(ctx, args.lobbyId);
    await ctx.db.patch(entrant._id, {
      score: Math.max(entrant.score, safeInt(args.score)),
      alive: false,
      placement,
      lastSeenAt: now,
      finishedAt: now,
    });

    await finalizeIfComplete(ctx, args.lobbyId, now);
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

export const getState = query({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

async function findOpenLobby(ctx: any): Promise<Doc<"battleRoyaleLobbies"> | null> {
  const open = await ctx.db
    .query("battleRoyaleLobbies")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "open"))
    .order("asc")
    .collect();

  for (const lobby of open) {
    const entrants = await entrantsForLobby(ctx, lobby._id);
    if (entrants.length < lobby.maxPlayers) return lobby;
  }
  return null;
}

async function activeEntrantForUser(ctx: any, userId: Id<"users">) {
  const entrants = await ctx.db
    .query("battleRoyaleEntrants")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .collect();

  for (const entrant of entrants) {
    const lobby = await ctx.db.get(entrant.lobbyId);
    if (lobby && (lobby.status === "open" || lobby.status === "active")) {
      return entrant;
    }
  }
  return null;
}

async function entrantForUser(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, userId: Id<"users">) {
  const entrants = await ctx.db
    .query("battleRoyaleEntrants")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .collect();
  return entrants.find((entrant: Doc<"battleRoyaleEntrants">) => entrant.lobbyId === lobbyId) ?? null;
}

async function entrantsForLobby(ctx: any, lobbyId: Id<"battleRoyaleLobbies">) {
  return await ctx.db
    .query("battleRoyaleEntrants")
    .withIndex("by_lobbyId", (q: any) => q.eq("lobbyId", lobbyId))
    .collect();
}

async function maybeStartLobby(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, now: number) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby || lobby.status !== "open") return;

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const shouldStart =
    entrants.length >= lobby.maxPlayers ||
    (entrants.length >= MIN_PLAYERS_TO_START && now - lobby.createdAt >= START_AFTER_MS);

  if (shouldStart) {
    await ctx.db.patch(lobbyId, {
      status: "active",
      startedAt: now,
      updatedAt: now,
    });
  } else if (now - lobby.createdAt >= CANCEL_AFTER_MS && entrants.length < MIN_PLAYERS_TO_START) {
    await cancelLobby(ctx, lobby, entrants, now);
  }
}

async function cancelLobby(ctx: any,
                           lobby: Doc<"battleRoyaleLobbies">,
                           entrants: Doc<"battleRoyaleEntrants">[],
                           now: number) {
  for (const entrant of entrants) {
    const user = await ctx.db.get(entrant.userId);
    if (user) {
      await ctx.db.patch(user._id, {
        bread: user.bread + lobby.buyIn,
        updatedAt: now,
      });
    }
    await ctx.db.patch(entrant._id, {
      alive: false,
      finishedAt: now,
      lastSeenAt: now,
    });
  }
  await ctx.db.patch(lobby._id, {
    status: "cancelled",
    finishedAt: now,
    updatedAt: now,
  });
}

async function nextPlacement(ctx: any, lobbyId: Id<"battleRoyaleLobbies">) {
  const entrants = await entrantsForLobby(ctx, lobbyId);
  const total = entrants.length;
  const eliminated = entrants.filter((entrant: Doc<"battleRoyaleEntrants">) => !!entrant.placement).length;
  return Math.max(1, total - eliminated);
}

async function finalizeIfComplete(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, now: number) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby || lobby.status === "finished" || lobby.status === "cancelled") return;

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const alive = entrants.filter((entrant: Doc<"battleRoyaleEntrants">) => entrant.alive);
  if (lobby.status === "active" && alive.length === 1) {
    await ctx.db.patch(alive[0]._id, {
      alive: false,
      placement: 1,
      finishedAt: now,
      lastSeenAt: now,
    });
  }

  const updatedEntrants = await entrantsForLobby(ctx, lobbyId);
  if (updatedEntrants.some((entrant: Doc<"battleRoyaleEntrants">) => !entrant.placement)) return;

  await payWinners(ctx, lobby, updatedEntrants, now);
  await ctx.db.patch(lobbyId, {
    status: "finished",
    finishedAt: now,
    updatedAt: now,
  });
}

async function payWinners(ctx: any,
                          lobby: Doc<"battleRoyaleLobbies">,
                          entrants: Doc<"battleRoyaleEntrants">[],
                          now: number) {
  const poolAfterSink = Math.floor(entrants.length * lobby.buyIn * 0.95);
  for (const entrant of entrants) {
    const placement = entrant.placement ?? entrants.length;
    if (placement < 1 || placement > PAYOUTS.length) continue;
    const amount = Math.floor(poolAfterSink * PAYOUTS[placement - 1]);
    if (amount <= 0) continue;

    const existing = await ctx.db
      .query("battleRoyalePayouts")
      .withIndex("by_lobbyId", (q: any) => q.eq("lobbyId", lobby._id))
      .filter((q: any) => q.eq(q.field("userId"), entrant.userId))
      .first();
    if (existing) continue;

    const user = await ctx.db.get(entrant.userId);
    if (user) {
      await ctx.db.patch(user._id, {
        bread: user.bread + amount,
        totalBreadCollected: (user.totalBreadCollected ?? 0) + amount,
        updatedAt: now,
      });
    }
    await ctx.db.patch(entrant._id, { prize: amount });
    await ctx.db.insert("battleRoyalePayouts", {
      lobbyId: lobby._id,
      userId: entrant.userId,
      placement,
      amount,
      paidAt: now,
    });
  }
}

async function buildAssignment(ctx: any,
                               lobbyId: Id<"battleRoyaleLobbies">,
                               entrantId: Id<"battleRoyaleEntrants">,
                               bread: number) {
  const lobby = await ctx.db.get(lobbyId);
  const entrant = await ctx.db.get(entrantId);
  const entrants = await entrantsForLobby(ctx, lobbyId);
  if (!lobby || !entrant) throw new Error("Battle royale lobby not found.");

  return {
    lobbyId: lobby._id,
    entrantId: entrant._id,
    seed: lobby.seed,
    status: lobby.status,
    playerCount: entrants.length,
    aliveCount: entrants.filter((entry: Doc<"battleRoyaleEntrants">) => entry.alive).length,
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    bread,
  };
}

async function buildState(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, userId: Id<"users">) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby) {
    throw new Error("Battle royale lobby not found.");
  }

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const local = entrants.find((entrant: Doc<"battleRoyaleEntrants">) => entrant.userId === userId);
  if (!local) {
    throw new ConvexError("You are not in this battle royale.");
  }

  const sorted = [...entrants].sort((a, b) => {
    if ((a.placement ?? 999) !== (b.placement ?? 999)) return (a.placement ?? 999) - (b.placement ?? 999);
    return b.score - a.score;
  });
  const alive = entrants.filter((entrant: Doc<"battleRoyaleEntrants">) => entrant.alive);
  const ghosts = sampleGhosts(entrants, local);

  return {
    lobbyId: lobby._id,
    entrantId: local._id,
    seed: lobby.seed,
    status: lobby.status,
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    playerCount: entrants.length,
    aliveCount: alive.length,
    local: publicEntrant(local),
    leaderboard: sorted.slice(0, 10).map(publicEntrant),
    ghosts: ghosts.map(publicGhost),
  };
}

function sampleGhosts(entrants: Doc<"battleRoyaleEntrants">[],
                      local: Doc<"battleRoyaleEntrants">) {
  const others = entrants.filter((entrant) => entrant.userId !== local.userId && entrant.alive);
  const byScore = [...others].sort((a, b) => b.score - a.score).slice(0, 5);
  const near = [...others].sort((a, b) => Math.abs(a.score - local.score) - Math.abs(b.score - local.score)).slice(0, 5);
  const recent = [...others].sort((a, b) => b.lastSeenAt - a.lastSeenAt).slice(0, 14);
  const seen = new Set<string>();
  return [...byScore, ...near, ...recent].filter((entrant) => {
    if (seen.has(entrant._id)) return false;
    seen.add(entrant._id);
    return true;
  }).slice(0, 24);
}

function publicEntrant(entrant: Doc<"battleRoyaleEntrants">) {
  return {
    playerId: entrant.userId,
    username: entrant.username,
    skinId: entrant.skinId,
    score: entrant.score,
    alive: entrant.alive,
    placement: entrant.placement,
    prize: entrant.prize ?? 0,
  };
}

function publicGhost(entrant: Doc<"battleRoyaleEntrants">) {
  return {
    playerId: entrant.userId,
    username: entrant.username,
    skinId: entrant.skinId,
    score: entrant.score,
    y: entrant.y,
    rotation: entrant.rotation,
    wingPhase: entrant.wingPhase,
  };
}

function safeInt(value: number) {
  return Math.max(0, Math.floor(value));
}

export async function cleanupBattleRoyale(ctx: any, now: number) {
  const active = await ctx.db
    .query("battleRoyaleLobbies")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "active"))
    .collect();

  for (const lobby of active) {
    const entrants = await entrantsForLobby(ctx, lobby._id);
    for (const entrant of entrants) {
      if (entrant.alive && now - entrant.lastSeenAt > STALE_AFTER_MS) {
        const placement = await nextPlacement(ctx, lobby._id);
        await ctx.db.patch(entrant._id, {
          alive: false,
          placement,
          finishedAt: now,
          lastSeenAt: now,
        });
      }
    }
    await finalizeIfComplete(ctx, lobby._id, now);
  }

  const open = await ctx.db
    .query("battleRoyaleLobbies")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "open"))
    .collect();
  for (const lobby of open) {
    await maybeStartLobby(ctx, lobby._id, now);
  }
}
