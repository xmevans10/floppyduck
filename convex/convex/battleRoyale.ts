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
const FINISHED_RETENTION_MS = 5 * 60 * 1000;
const PAYOUTS = [0.40, 0.25, 0.15, 0.12, 0.08];

const BOT_DESIRED_PLAYERS = 30;
const BOT_TRICKLE_PER_TICK = 12;
const BOT_NAMES = [
  "Quackers", "Webby", "Beaker", "Sir Flaps", "Duck Norris",
  "Puddle Jumper", "Wingman", "Drake", "Mallard Fillmore", "Daffy",
  "Waddles", "Splashy", "Bill Nye", "Flipper", "Quack Sparrow",
  "Pond Hopper", "Feathers", "Breadwinner", "Chirpy", "Divington",
];
const BOT_SKINS = [undefined, "robot", "ninja", "cowboy", "pirate", "astronaut"];

function randomSeed() {
  return Math.floor(Math.random() * 999_999) + 1;
}

// ── Mutations & Queries ──

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
      alive: true,
      joinedAt: now,
      lastSeenAt: now,
    });

    // Trickle in bots on each join so the lobby fills gradually.
    const lobbyEntrants = await entrantsForLobby(ctx, lobby._id);
    const botsToAdd = Math.min(5, BOT_DESIRED_PLAYERS - lobbyEntrants.length);
    if (botsToAdd > 0) {
      await injectBots(ctx, lobby, botsToAdd, now);
    }

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
    y: v.optional(v.number()),
    rotation: v.optional(v.number()),
    wingPhase: v.optional(v.number()),
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
    const elapsedSec = lobby.startedAt ? (now - lobby.startedAt) / 1000 : 0;

    await syncDeadEntrants(ctx, args.lobbyId, now, elapsedSec);

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

export const getAliveCount = query({
  args: {
    lobbyId: v.id("battleRoyaleLobbies"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby) {
      throw new Error("Battle royale lobby not found.");
    }

    const entrants = await entrantsForLobby(ctx, args.lobbyId);
    if (!entrants.some((entrant: Doc<"battleRoyaleEntrants">) => entrant.userId === user._id)) {
      throw new ConvexError("You are not in this battle royale.");
    }

    const elapsedSec = lobby.startedAt ? (Date.now() - lobby.startedAt) / 1000 : 0;
    const aliveDebug = buildAliveDebug(entrants, elapsedSec);
    return {
      lobbyId: lobby._id,
      status: lobby.status,
      playerCount: entrants.length,
      aliveCount: aliveDebug.aliveCount,
      finishedAt: lobby.finishedAt,
      debug: aliveDebug,
    };
  },
});

// ── Helpers ──

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
    if (!entrant.alive || entrant.placement) continue;
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
  await deleteBotUsers(ctx, entrants);
  for (const entrant of entrants) {
    await ctx.db.delete(entrant._id);
  }
  await ctx.db.delete(lobby._id);
}

async function injectBots(ctx: any, lobby: Doc<"battleRoyaleLobbies">, count: number, now: number) {
  for (let i = 0; i < count; i++) {
    const nameIndex = i % BOT_NAMES.length;
    const suffix = Math.floor(i / BOT_NAMES.length) + 1;
    const botName = BOT_NAMES[nameIndex] + " " + suffix;
    const botUserId = await ctx.db.insert("users", {
      username: botName,
      provider: "bot",
      rating: 1000 + Math.floor(Math.random() * 400),
      gamesPlayed: 0,
      wins: 0,
      losses: 0,
      bestScore: 0,
      totalScore: 0,
      bread: 0,
      recentScores: [],
      beatenBots: [],
      createdAt: now,
      updatedAt: now,
    });

    const skinId = BOT_SKINS[Math.floor(Math.random() * BOT_SKINS.length)];
    await ctx.db.insert("battleRoyaleEntrants", {
      lobbyId: lobby._id,
      userId: botUserId,
      username: botName,
      skinId,
      score: Math.floor(Math.random() * 5),
      alive: true,
      isBot: true,
      joinedAt: now,
      lastSeenAt: now,
    });
  }
}

async function nextPlacement(ctx: any, lobbyId: Id<"battleRoyaleLobbies">) {
  const entrants = await entrantsForLobby(ctx, lobbyId);
  const total = entrants.length;
  const eliminated = entrants.filter((entrant: Doc<"battleRoyaleEntrants">) => !!entrant.placement).length;
  return Math.max(1, total - eliminated);
}

// ── Bot Virtual Logic ──

function safeInt(value: number) {
  return Math.max(0, Math.floor(value));
}

function hashInt(str: string, seed: number): number {
  let h = seed;
  for (let i = 0; i < str.length; i++) {
    h = ((h << 5) - h + str.charCodeAt(i)) | 0;
  }
  return h;
}

function botParams(entrantId: string): { targetScore: number; deathAtMs: number } {
  const h1 = hashInt(entrantId, 42);
  const h2 = hashInt(entrantId, 137);

  const targetScore = 10 + (Math.abs(h1) % 31);  // 10 – 40, uniform
  const deathAtMs = (15 + (Math.abs(h2) % 76)) * 1000;   // 15 – 90s, uniform

  return { targetScore, deathAtMs };
}

function botVirt(entrantId: string, elapsedSec: number) {
  const { targetScore, deathAtMs } = botParams(entrantId);
  const elapsedMs = Math.max(0, Math.floor(elapsedSec * 1000));
  const score = Math.min(Math.floor((elapsedMs * targetScore) / deathAtMs), targetScore);
  return { score, alive: elapsedMs < deathAtMs };
}

function botScore(entrantId: string, elapsedSec: number): number {
  return botVirt(entrantId, elapsedSec).score;
}

function botIsAlive(entrant: Doc<"battleRoyaleEntrants">, elapsedSec: number): boolean {
  if (!entrant.alive) return false;
  if (!entrant.isBot) return true;
  return botVirt(entrant._id, elapsedSec).alive;
}

function buildAliveDebug(entrants: Doc<"battleRoyaleEntrants">[], elapsedSec: number) {
  const elapsedMs = Math.max(0, Math.floor(elapsedSec * 1000));
  let humanAliveCount = 0;
  let botAliveCount = 0;
  let dbAliveCount = 0;
  let virtualDeadPendingCount = 0;
  let nextBotDeathInMs: number | undefined;

  for (const entrant of entrants) {
    if (entrant.alive) dbAliveCount += 1;

    const alive = botIsAlive(entrant, elapsedSec);
    if (alive && entrant.isBot) botAliveCount += 1;
    if (alive && !entrant.isBot) humanAliveCount += 1;

    if (!entrant.isBot || !entrant.alive) continue;
    const { deathAtMs } = botParams(entrant._id);
    const remainingMs = deathAtMs - elapsedMs;
    if (remainingMs <= 0) {
      virtualDeadPendingCount += 1;
    } else if (nextBotDeathInMs === undefined || remainingMs < nextBotDeathInMs) {
      nextBotDeathInMs = remainingMs;
    }
  }

  return {
    elapsedMs,
    aliveCount: humanAliveCount + botAliveCount,
    humanAliveCount,
    botAliveCount,
    dbAliveCount,
    virtualDeadPendingCount,
    nextBotDeathInMs,
  };
}

// ── Finalization ──

async function syncDeadEntrants(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, now: number, elapsedSec: number) {
  const entrants = await entrantsForLobby(ctx, lobbyId);
  const deadWithoutPlacement: Doc<"battleRoyaleEntrants">[] = [];
  for (const e of entrants) {
    if (!e.alive || e.placement) continue;
    if (!botIsAlive(e, elapsedSec)) {
      deadWithoutPlacement.push(e);
    }
  }
  // Sort ascending by score so the lowest scorer gets the worst placement
  // (processed first), and the highest scorer gets placement 1 (processed last).
  deadWithoutPlacement.sort((a, b) => {
    const sa = a.isBot ? botScore(a._id, elapsedSec) : a.score;
    const sb = b.isBot ? botScore(b._id, elapsedSec) : b.score;
    if (sa !== sb) return sa - sb;
    return String(a._id).localeCompare(String(b._id));
  });
  for (const e of deadWithoutPlacement) {
    const p = await nextPlacement(ctx, lobbyId);
    await ctx.db.patch(e._id, {
      alive: false,
      placement: p,
      score: e.isBot ? botScore(e._id, elapsedSec) : e.score,
      finishedAt: now,
      lastSeenAt: now,
    });
  }
}

async function finalizeIfComplete(ctx: any, lobbyId: Id<"battleRoyaleLobbies">, now: number) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby || lobby.status === "finished" || lobby.status === "cancelled") return;

  const elapsedSec = lobby.startedAt ? (now - lobby.startedAt) / 1000 : 0;

  await syncDeadEntrants(ctx, lobbyId, now, elapsedSec);

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const alive = entrants.filter((e: Doc<"battleRoyaleEntrants">) => botIsAlive(e, elapsedSec));

  if (lobby.status === "active" && alive.length === 1 && alive[0].isBot) {
    await ctx.db.patch(alive[0]._id, { alive: false, placement: 1, finishedAt: now, lastSeenAt: now });
  }

  const updated = await entrantsForLobby(ctx, lobbyId);
  if (updated.some((e: Doc<"battleRoyaleEntrants">) => !e.placement)) return;

  await payWinners(ctx, lobby, updated, now);
  await ctx.db.patch(lobbyId, {
    status: "finished",
    finishedAt: lobby.finishedAt ?? now,
    updatedAt: now,
  });
}

async function payWinners(ctx: any,
                          lobby: Doc<"battleRoyaleLobbies">,
                          entrants: Doc<"battleRoyaleEntrants">[],
                          now: number) {
  const poolAfterSink = Math.floor(entrants.length * lobby.buyIn * 0.95);
  for (const entrant of entrants) {
    if (entrant.isBot) continue;
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

async function deleteBotUsers(ctx: any, entrants: Doc<"battleRoyaleEntrants">[]) {
  for (const entrant of entrants) {
    if (!entrant.isBot) continue;
    const user = await ctx.db.get(entrant.userId);
    if (user && user.provider === "bot") {
      await ctx.db.delete(user._id);
    }
  }
}

// ── Build State (queries) ──

async function buildAssignment(ctx: any,
                               lobbyId: Id<"battleRoyaleLobbies">,
                               entrantId: Id<"battleRoyaleEntrants">,
                               bread: number) {
  const lobby = await ctx.db.get(lobbyId);
  const entrant = await ctx.db.get(entrantId);
  const entrants = await entrantsForLobby(ctx, lobbyId);
  if (!lobby || !entrant) throw new Error("Battle royale lobby not found.");

  const now = Date.now();
  const elapsedSec = lobby.startedAt ? (now - lobby.startedAt) / 1000 : 0;

  return {
    lobbyId: lobby._id,
    entrantId: entrant._id,
    seed: lobby.seed,
    status: lobby.status,
    playerCount: entrants.length,
    aliveCount: entrants.filter((e: Doc<"battleRoyaleEntrants">) => botIsAlive(e, elapsedSec)).length,
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    bread,
    createdAt: lobby.createdAt,
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

  const now = Date.now();
  const elapsedSec = lobby.startedAt ? (now - lobby.startedAt) / 1000 : 0;

  const virtualScore = (entrant: Doc<"battleRoyaleEntrants">): number => {
    if (!entrant.isBot) return entrant.score;
    return botScore(entrant._id, elapsedSec);
  };

  const sorted = [...entrants].sort((a, b) => {
    if ((a.placement ?? 999) !== (b.placement ?? 999)) return (a.placement ?? 999) - (b.placement ?? 999);
    return virtualScore(b) - virtualScore(a);
  });

  const aliveDebug = buildAliveDebug(entrants, elapsedSec);
  const leaderboard = sorted.slice(0, 10).map((e: Doc<"battleRoyaleEntrants">) => ({
    ...publicEntrant(e, elapsedSec),
    alive: botIsAlive(e, elapsedSec),
  }));

  return {
    lobbyId: lobby._id,
    entrantId: local._id,
    seed: lobby.seed,
    status: lobby.status,
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    playerCount: entrants.length,
    aliveCount: aliveDebug.aliveCount,
    local: publicEntrant(local, elapsedSec),
    leaderboard,
    debug: aliveDebug,
  };
}

function publicEntrant(entrant: Doc<"battleRoyaleEntrants">, elapsedSec: number) {
  return {
    playerId: entrant.userId,
    username: entrant.username,
    skinId: entrant.skinId,
    score: entrant.isBot ? botScore(entrant._id, elapsedSec) : entrant.score,
    alive: entrant.alive,
    placement: entrant.placement,
    prize: entrant.prize ?? 0,
  };
}

// ── Cleanup Cron ──

export async function cleanupBattleRoyale(ctx: any, now: number) {
  const active = await ctx.db
    .query("battleRoyaleLobbies")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "active"))
    .collect();

  for (const lobby of active) {
    const entrants = await entrantsForLobby(ctx, lobby._id);
    for (const entrant of entrants) {
      if (entrant.alive && !entrant.isBot && now - entrant.lastSeenAt > STALE_AFTER_MS) {
        await ctx.db.patch(entrant._id, {
          alive: false,
          placement: await nextPlacement(ctx, lobby._id),
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
    const entrants = await entrantsForLobby(ctx, lobby._id);

    if (entrants.length < BOT_DESIRED_PLAYERS && now - lobby.createdAt >= 15_000) {
      const botsNeeded = BOT_DESIRED_PLAYERS - entrants.length;
      await injectBots(ctx, lobby, Math.min(BOT_TRICKLE_PER_TICK, botsNeeded), now);
    }

    await maybeStartLobby(ctx, lobby._id, now);
  }

  const finished = await ctx.db
    .query("battleRoyaleLobbies")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "finished"))
    .collect();

  for (const lobby of finished) {
    const finishedAt = lobby.finishedAt ?? lobby.updatedAt;
    if (now - finishedAt < FINISHED_RETENTION_MS) continue;

    const entrants = await entrantsForLobby(ctx, lobby._id);
    await deleteBotUsers(ctx, entrants);
    for (const entrant of entrants) {
      await ctx.db.delete(entrant._id);
    }
    await ctx.db.delete(lobby._id);
  }
}
