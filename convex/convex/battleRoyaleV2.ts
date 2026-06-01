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
const JOIN_WAIT_MS = 45 * 1000;
const BOT_TRICKLE_START_MS = 2 * 1000;
const BOT_TRICKLE_INTERVAL_MS = 450;
const ACTIVE_HUMAN_WINDOW_MS = 60 * 1000;
const BOT_FILL_ACTIVE_HUMAN_WEIGHT = 0.02;
const BOT_FILL_MIN_COEFFICIENT = 0.30;
const STALE_AFTER_MS = 30 * 1000;
const FINISHED_RETENTION_MS = 5 * 60 * 1000;
const EMPTY_OPEN_RETENTION_MS = 60 * 1000;
const ALIVE_SNAPSHOT_LOG_LIMIT = 260;
const PAYOUTS = [0.40, 0.25, 0.15, 0.12, 0.08];
const ROOM_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const ROOM_CODE_LENGTH = 5;

const BOT_NAMES = [
  "Quackers", "Webby", "Beaker", "Sir Flaps", "Duck Norris",
  "Puddle Jumper", "Wingman", "Drake", "Mallard Fillmore", "Daffy",
  "Waddles", "Splashy", "Bill Nye", "Flipper", "Quack Sparrow",
  "Pond Hopper", "Feathers", "Breadwinner", "Chirpy", "Divington",
];
const BOT_SKINS = [undefined, "robot", "ninja", "cowboy", "pirate", "astronaut"];

type Ctx = any;
type Lobby = Doc<"battleRoyaleLobbiesV2">;
type Entrant = Doc<"battleRoyaleEntrantsV2">;
type BotTimelineEntry = Lobby["botTimeline"][number];

function randomSeed() {
  return Math.floor(Math.random() * 999_999) + 1;
}

function randomSalt(now: number) {
  return `${now.toString(36)}-${randomSeed().toString(36)}-${Math.random().toString(36).slice(2, 12)}`;
}

function safeInt(value: number) {
  return Math.max(0, Math.floor(value));
}

export const joinLobby = mutation({
  args: identityArgs,
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args);
    const now = Date.now();

    const existing = await activeOpenEntrantForUser(ctx, user._id);
    if (existing) {
      return await buildAssignment(ctx, existing.lobbyId, existing._id, user.bread);
    }

    if (user.bread < BUY_IN) {
      throw new ConvexError("Insufficient bread.");
    }

    let lobby = await findOpenLobby(ctx, now);
    if (!lobby) {
      const reserved = await reserveRoomCode(ctx, now);
      const lobbyId = await ctx.db.insert("battleRoyaleLobbiesV2", {
        status: "open",
        roomCode: reserved.code,
        seed: randomSeed(),
        botSalt: randomSalt(now),
        buyIn: BUY_IN,
        maxPlayers: MAX_PLAYERS,
        humanCount: 0,
        humanAliveCount: 0,
        botCount: 0,
        botTimeline: [],
        joinDeadlineAt: now + JOIN_WAIT_MS,
        createdAt: now,
        updatedAt: now,
      });
      await ctx.db.patch(reserved.id, { lobbyId });
      lobby = await ctx.db.get(lobbyId);
    }

    if (!lobby || lobby.status !== "open") {
      throw new Error("Unable to create battle royale lobby.");
    }

    await ctx.db.patch(user._id, {
      bread: user.bread - BUY_IN,
      updatedAt: now,
    });

    const entrantId = await ctx.db.insert("battleRoyaleEntrantsV2", {
      lobbyId: lobby._id,
      userId: user._id,
      isBot: false,
      username: user.username,
      skinId: user.selectedSkin,
      score: 0,
      alive: true,
      joinedAt: now,
      lastSeenAt: now,
    });

    await ctx.db.patch(lobby._id, {
      humanCount: lobby.humanCount + 1,
      humanAliveCount: lobby.humanAliveCount + 1,
      updatedAt: now,
    });

    await maybeStartLobby(ctx, lobby._id, now);
    return await buildAssignment(ctx, lobby._id, entrantId, user.bread - BUY_IN);
  },
});

export const leaveLobby = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
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

    await ctx.db.patch(lobby._id, {
      humanCount: Math.max(0, lobby.humanCount - 1),
      humanAliveCount: Math.max(0, lobby.humanAliveCount - 1),
      updatedAt: now,
    });

    return { ok: true, refunded: true, bread: user.bread + lobby.buyIn };
  },
});

export const startIfReady = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant) {
      throw new ConvexError("You are not in this battle royale.");
    }

    const now = Date.now();
    await ctx.db.patch(entrant._id, { lastSeenAt: now });
    await maybeStartLobby(ctx, args.lobbyId, now);
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

export const reportScore = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    score: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby || lobby.status !== "active") {
      return { ok: false };
    }

    const entrant = await entrantForUser(ctx, args.lobbyId, user._id);
    if (!entrant || !entrant.alive || entrant.placement) {
      return { ok: false };
    }

    const now = Date.now();
    await ctx.db.patch(entrant._id, {
      score: Math.max(entrant.score, safeInt(args.score)),
      lastSeenAt: now,
    });
    await syncBotRowsForLobby(ctx, lobby, now, { source: "reportScore", userId: user._id });
    return { ok: true };
  },
});

export const finishRun = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    score: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    await maybeStartLobby(ctx, args.lobbyId, Date.now());

    let lobby = await ctx.db.get(args.lobbyId);
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
    if (lobby.status !== "active") {
      throw new ConvexError("Battle royale is not active.");
    }

    const now = Date.now();
    await syncBotRowsForLobby(ctx, lobby, now, { source: "finishRun", userId: user._id });
    lobby = await ctx.db.get(args.lobbyId);
    if (!lobby) {
      throw new Error("Battle royale lobby not found.");
    }

    const entrants = await entrantsForLobby(ctx, args.lobbyId);
    const aliveBefore = computeAlive(lobby, entrants, now).aliveCount;
    const placement = Math.max(1, aliveBefore);
    const finalScore = Math.max(entrant.score, safeInt(args.score));

    await ctx.db.patch(entrant._id, {
      score: finalScore,
      alive: false,
      placement,
      lastSeenAt: now,
      finishedAt: now,
    });

    const aliveAfter = await updateAliveCache(ctx, lobby, await entrantsForLobby(ctx, args.lobbyId), now);
    await recordBattleRoyaleEvent(ctx, {
      event: "human_row_flipped_dead",
      level: "info",
      message: "Battle Royale human entrant row flipped from alive to dead.",
      lobby,
      userId: user._id,
      metadata: {
        source: "finishRun",
        username: entrant.username,
        score: finalScore,
        placement,
        aliveBefore,
        aliveAfter: aliveAfter.aliveCount,
        humanAliveRows: aliveAfter.humanAliveCount,
        botAliveRows: aliveAfter.botAliveCount,
        totalRows: aliveAfter.debug.totalRows,
      },
    });

    const updatedEntrant = await ctx.db.get(entrant._id);
    if (updatedEntrant) {
      await payEntrantIfWinner(ctx, lobby, updatedEntrant, now);
    }

    await maybeFinalizeLobby(ctx, args.lobbyId, now);
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

export const getState = query({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    return await buildState(ctx, args.lobbyId, user._id);
  },
});

export const getAliveCount = query({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const lobby = await ctx.db.get(args.lobbyId);
    if (!lobby) {
      throw new Error("Battle royale lobby not found.");
    }

    const entrants = await entrantsForLobby(ctx, args.lobbyId);
    if (!entrants.some((entrant: Entrant) => entrant.userId === user._id)) {
      throw new ConvexError("You are not in this battle royale.");
    }

    const now = Date.now();
    const alive = computeAlive(lobby, entrants, now, { projectPendingDead: true });
    return {
      lobbyId: lobby._id,
      roomCode: lobby.roomCode,
      status: effectiveStatus(lobby, alive.aliveCount),
      playerCount: await playerCount(ctx, lobby, now),
      aliveCount: alive.aliveCount,
      startedAt: lobby.startedAt,
      finishedAt: lobby.finishedAt,
      debug: alive.debug,
    };
  },
});

export const syncAliveCount = mutation({
  args: {
    lobbyId: v.id("battleRoyaleLobbiesV2"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    let lobby = await ctx.db.get(args.lobbyId);
    if (!lobby) {
      throw new Error("Battle royale lobby not found.");
    }

    let entrants = await entrantsForLobby(ctx, args.lobbyId);
    if (!entrants.some((entrant: Entrant) => entrant.userId === user._id)) {
      throw new ConvexError("You are not in this battle royale.");
    }

    const now = Date.now();
    const sync = await syncBotRowsForLobby(ctx, lobby, now, { source: "syncAliveCount", userId: user._id });
    lobby = sync.lobby;
    entrants = sync.entrants;
    const alive = sync.alive;
    await maybeFinalizeLobby(ctx, args.lobbyId, now);
    lobby = await ctx.db.get(args.lobbyId) ?? lobby;

    await recordAliveSnapshot(ctx, lobby, alive, now, {
      source: "syncAliveCount",
      userId: user._id,
      flippedRows: sync.flippedRows,
    });

    return {
      lobbyId: lobby._id,
      roomCode: lobby.roomCode,
      status: effectiveStatus(lobby, alive.aliveCount),
      playerCount: await playerCount(ctx, lobby, now),
      aliveCount: alive.aliveCount,
      startedAt: lobby.startedAt,
      finishedAt: lobby.finishedAt,
      debug: alive.debug,
    };
  },
});

async function reserveRoomCode(ctx: Ctx, now: number) {
  for (let attempt = 0; attempt < 24; attempt++) {
    const code = randomRoomCode();
    const existing = await ctx.db
      .query("battleRoyaleRoomCodesV2")
      .withIndex("by_code", (q: any) => q.eq("code", code))
      .first();
    if (existing) continue;

    const id = await ctx.db.insert("battleRoyaleRoomCodesV2", {
      code,
      status: "reserved",
      createdAt: now,
    });
    return { id, code };
  }
  throw new Error("Unable to reserve battle royale room code.");
}

function randomRoomCode() {
  let code = "";
  for (let i = 0; i < ROOM_CODE_LENGTH; i++) {
    code += ROOM_ALPHABET[Math.floor(Math.random() * ROOM_ALPHABET.length)];
  }
  return code;
}

async function findOpenLobby(ctx: Ctx, now: number): Promise<Lobby | null> {
  const lobbies = await ctx.db
    .query("battleRoyaleLobbiesV2")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "open"))
    .order("asc")
    .collect();

  for (const lobby of lobbies) {
    if (lobby.humanCount < lobby.maxPlayers && now < lobby.joinDeadlineAt) {
      return lobby;
    }
  }
  return null;
}

async function activeOpenEntrantForUser(ctx: Ctx, userId: Id<"users">) {
  const entrants = await ctx.db
    .query("battleRoyaleEntrantsV2")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .collect();

  for (const entrant of entrants) {
    if (!entrant.alive || entrant.placement) continue;
    const lobby = await ctx.db.get(entrant.lobbyId);
    if (lobby && lobby.status === "open") {
      return entrant;
    }
  }
  return null;
}

async function entrantForUser(ctx: Ctx, lobbyId: Id<"battleRoyaleLobbiesV2">, userId: Id<"users">) {
  const entrants = await ctx.db
    .query("battleRoyaleEntrantsV2")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .collect();
  return entrants.find((entrant: Entrant) => entrant.lobbyId === lobbyId) ?? null;
}

async function entrantsForLobby(ctx: Ctx, lobbyId: Id<"battleRoyaleLobbiesV2">) {
  return await ctx.db
    .query("battleRoyaleEntrantsV2")
    .withIndex("by_lobbyId", (q: any) => q.eq("lobbyId", lobbyId))
    .collect();
}

async function maybeStartLobby(ctx: Ctx, lobbyId: Id<"battleRoyaleLobbiesV2">, now: number) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby || lobby.status !== "open") return;

  const entrants = await entrantsForLobby(ctx, lobbyId);
  if (entrants.length === 0) {
    if (now - lobby.createdAt >= EMPTY_OPEN_RETENTION_MS) {
      await closeAndDeleteOpenLobby(ctx, lobby, now);
    }
    return;
  }

  const fill = await botFillTarget(ctx, lobby, now, entrants.length);
  const visibleBots = visibleOpenBotCount(lobby, now, entrants.length, fill.targetTotal);
  if (now < lobby.joinDeadlineAt && entrants.length + visibleBots < fill.targetTotal) return;

  const botCount = Math.min(Math.max(0, lobby.maxPlayers - entrants.length), Math.max(0, fill.targetTotal - entrants.length));
  const botTimeline = generateBotTimeline(lobby, botCount);
  await createBotEntrantRows(ctx, lobby._id, botTimeline, now);
  await ctx.db.patch(lobbyId, {
    status: "active",
    humanCount: entrants.length,
    humanAliveCount: entrants.filter((entrant: Entrant) => entrant.alive).length,
    botCount,
    botAliveCount: botCount,
    aliveCount: entrants.filter((entrant: Entrant) => entrant.alive).length + botCount,
    botTimeline,
    startedAt: now,
    lastAliveSyncAt: now,
    lastAliveCountLogged: entrants.filter((entrant: Entrant) => entrant.alive).length + botCount,
    updatedAt: now,
  });

  await recordBattleRoyaleEvent(ctx, {
    event: "lobby_rows_materialized",
    level: "info",
    message: "Battle Royale lobby started with one persisted entrant row per player.",
    lobby: { ...lobby, status: "active", botCount, startedAt: now },
    metadata: {
      source: "maybeStartLobby",
      humanRows: entrants.length,
      botRows: botCount,
      totalRows: entrants.length + botCount,
      aliveRows: entrants.filter((entrant: Entrant) => entrant.alive).length + botCount,
      activeHumanRows: fill.activeHumanCount,
      botFillCoefficient: fill.coefficient,
      targetTotalRows: fill.targetTotal,
      firstBotDeathMs: botTimeline[0] ? botCrashAtMs(botTimeline[0]) : undefined,
      lastBotDeathMs: botTimeline[botTimeline.length - 1] ? botCrashAtMs(botTimeline[botTimeline.length - 1]) : undefined,
    },
  });
}

async function createBotEntrantRows(ctx: Ctx,
                                    lobbyId: Id<"battleRoyaleLobbiesV2">,
                                    timeline: BotTimelineEntry[],
                                    now: number) {
  for (const bot of timeline) {
    await ctx.db.insert("battleRoyaleEntrantsV2", {
      lobbyId,
      isBot: true,
      botId: bot.botId,
      username: bot.username,
      skinId: bot.skinId,
      score: 0,
      alive: true,
      botDeathElapsedMs: botCrashAtMs(bot),
      botScoreEvents: bot.scoreEvents,
      botSkill: bot.skill,
      botRisk: bot.risk,
      botConsistency: bot.consistency,
      joinedAt: now,
      lastSeenAt: now,
    });
  }
}

async function ensureBotRowsForLobby(ctx: Ctx, lobby: Lobby, entrants: Entrant[], now: number) {
  if (lobby.status !== "active" || lobby.botCount <= 0) return entrants;

  const existingBotIds = new Set(
    entrants
      .filter((entrant: Entrant) => entrant.isBot && entrant.botId)
      .map((entrant: Entrant) => entrant.botId)
  );
  const missingBots = lobby.botTimeline.filter((bot: BotTimelineEntry) => !existingBotIds.has(bot.botId));
  if (missingBots.length === 0) return entrants;

  await createBotEntrantRows(ctx, lobby._id, missingBots, now);
  await recordBattleRoyaleEvent(ctx, {
    event: "bot_rows_backfilled",
    level: "warning",
    message: "Backfilled missing Battle Royale bot entrant rows for an active lobby.",
    lobby,
    metadata: {
      source: "ensureBotRowsForLobby",
      missingBotRows: missingBots.length,
      existingRows: entrants.length,
      expectedBotRows: lobby.botCount,
    },
  });
  return await entrantsForLobby(ctx, lobby._id);
}

async function syncBotRowsForLobby(ctx: Ctx,
                                   lobby: Lobby,
                                   now: number,
                                   options: { source: string; userId?: Id<"users"> }) {
  let entrants = await entrantsForLobby(ctx, lobby._id);
  entrants = await ensureBotRowsForLobby(ctx, lobby, entrants, now);

  if (lobby.status !== "active") {
    const alive = computeAlive(lobby, entrants, now);
    return { lobby, entrants, alive, flippedRows: 0 };
  }

  const elapsedMs = lobby.startedAt ? Math.max(0, now - lobby.startedAt) : 0;
  const aliveBefore = computeAlive(lobby, entrants, now);
  const dueBots = entrants
    .filter((entrant: Entrant) => {
      if (!entrant.isBot || !entrant.alive || entrant.placement) return false;
      return entrant.botDeathElapsedMs !== undefined && elapsedMs >= entrant.botDeathElapsedMs;
    })
    .sort((a: Entrant, b: Entrant) => {
      const aDeath = a.botDeathElapsedMs ?? Number.MAX_SAFE_INTEGER;
      const bDeath = b.botDeathElapsedMs ?? Number.MAX_SAFE_INTEGER;
      if (aDeath !== bDeath) return aDeath - bDeath;
      return String(a._id).localeCompare(String(b._id));
    });

  for (const bot of dueBots) {
    const deathElapsedMs = bot.botDeathElapsedMs ?? elapsedMs;
    await ctx.db.patch(bot._id, {
      alive: false,
      placement: placementAtElapsed(lobby, entrants, deathElapsedMs),
      score: Math.max(bot.score, botRowScoreAt(bot, deathElapsedMs)),
      lastSeenAt: now,
      finishedAt: (lobby.startedAt ?? now) + deathElapsedMs,
      deathReason: "bot_sim",
    });
  }

  if (dueBots.length > 0) {
    entrants = await entrantsForLobby(ctx, lobby._id);
  }

  const aliveAfter = await updateAliveCache(ctx, lobby, entrants, now);
  const refreshedLobby = await ctx.db.get(lobby._id) ?? lobby;

  if (dueBots.length > 0) {
    await recordBattleRoyaleEvent(ctx, {
      event: "bot_rows_flipped_dead",
      level: "info",
      message: "Battle Royale bot entrant rows flipped from alive to dead.",
      lobby: refreshedLobby,
      userId: options.userId,
      metadata: {
        source: options.source,
        elapsedMs,
        flippedRows: dueBots.length,
        aliveBefore: aliveBefore.aliveCount,
        aliveAfter: aliveAfter.aliveCount,
        humanAlive: aliveAfter.humanAliveCount,
        botAlive: aliveAfter.botAliveCount,
        totalRows: entrants.length,
        nextBotDeathMs: aliveAfter.nextBotDeathInMs,
        botIds: dueBots.slice(0, 8).map((bot: Entrant) => bot.botId ?? String(bot._id)).join(","),
      },
    });
  }

  return { lobby: refreshedLobby, entrants, alive: aliveAfter, flippedRows: dueBots.length };
}

async function updateAliveCache(ctx: Ctx, lobby: Lobby, entrants: Entrant[], now: number) {
  const alive = computeAlive(lobby, entrants, now);
  const shouldPatch = lobby.humanAliveCount !== alive.humanAliveCount
    || lobby.botAliveCount !== alive.botAliveCount
    || lobby.aliveCount !== alive.aliveCount
    || lobby.lastAliveSyncAt === undefined;

  if (shouldPatch) {
    await ctx.db.patch(lobby._id, {
      humanAliveCount: alive.humanAliveCount,
      botAliveCount: alive.botAliveCount,
      aliveCount: alive.aliveCount,
      lastAliveSyncAt: now,
      updatedAt: now,
    });
  }
  return alive;
}

function generateBotTimeline(lobby: Lobby, botCount: number): BotTimelineEntry[] {
  const rng = mulberry32(hashString(`${lobby.botSalt}:${lobby._id}:${lobby.seed}`));
  const timeline: BotTimelineEntry[] = [];

  for (let i = 0; i < botCount; i++) {
    const nameIndex = Math.floor(rng() * BOT_NAMES.length);
    const suffix = 1 + Math.floor(i / BOT_NAMES.length);
    const username = `${BOT_NAMES[nameIndex]} ${suffix}`;
    const skinId = BOT_SKINS[Math.floor(rng() * BOT_SKINS.length)];
    const skill = 0.18 + rng() * 0.78;
    const risk = rng();
    const consistency = 0.35 + rng() * 0.62;
    const scoreEvents: number[] = [];
    let elapsedMs = 2_600 + Math.floor(rng() * 1_800);
    let finalScore = 0;

    for (let pipe = 0; pipe < 80; pipe++) {
      const pressure = Math.min(0.46, Math.max(0, pipe - 3) * (0.0065 + risk * 0.0035));
      const wobble = (rng() - 0.5) * (1 - consistency) * 0.22;
      const earlyProtection = pipe < 3 ? 0.995 : pipe < 6 ? 0.965 : 0.0;
      const rawSurviveChance = pipe < 6
        ? earlyProtection - risk * 0.012 + wobble * 0.25
        : 0.965 + skill * 0.025 - pressure - risk * 0.035 + wobble;
      const surviveChance = clamp(rawSurviveChance, 0.08, 0.995);
      if (rng() > surviveChance) {
        break;
      }

      scoreEvents.push(elapsedMs);
      finalScore += 1;

      const basePipeMs = 2_050 - skill * 420 + risk * 260;
      const jitterMs = (rng() - 0.5) * (900 - consistency * 520);
      elapsedMs += Math.max(1_350, Math.floor(basePipeMs + jitterMs));
    }

    const crashDelayMs = 650 + Math.floor(rng() * 1_200);

    timeline.push({
      botId: `bot-${i + 1}-${Math.floor(rng() * 1_000_000).toString(36)}`,
      username,
      skinId,
      finalScore,
      scoreEvents,
      crashDelayMs,
      skill,
      risk,
      consistency,
    });
  }

  return timeline.sort((a, b) => botCrashAtMs(a) - botCrashAtMs(b));
}

function hashString(value: string): number {
  let hash = 2_166_136_261;
  for (let i = 0; i < value.length; i++) {
    hash ^= value.charCodeAt(i);
    hash = Math.imul(hash, 16_777_619);
  }
  return hash >>> 0;
}

function mulberry32(seed: number) {
  return function next() {
    let t = seed += 0x6D2B79F5;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4_294_967_296;
  };
}

function clamp(value: number, min: number, max: number) {
  return Math.max(min, Math.min(max, value));
}

async function playerCount(ctx: Ctx, lobby: Lobby, now: number) {
  if (lobby.status === "open") {
    const fill = await botFillTarget(ctx, lobby, now, lobby.humanCount);
    return lobby.humanCount + visibleOpenBotCount(lobby, now, lobby.humanCount, fill.targetTotal);
  }
  return lobby.humanCount + lobby.botCount;
}

function visibleOpenBotCount(lobby: Lobby, now: number, humanCount: number, targetTotal: number) {
  if (lobby.status !== "open") return lobby.botCount;
  const capacity = Math.max(0, lobby.maxPlayers - humanCount);
  const targetBots = Math.max(0, targetTotal - humanCount);
  const elapsed = Math.max(0, now - lobby.createdAt - BOT_TRICKLE_START_MS);
  const trickled = Math.floor(elapsed / BOT_TRICKLE_INTERVAL_MS);
  return Math.min(capacity, targetBots, trickled);
}

async function botFillTarget(ctx: Ctx, lobby: Lobby, now: number, humanCount: number) {
  const activeHumanCount = await activeBattleRoyaleHumanCount(ctx, now);
  const coefficient = clamp(
    1 - activeHumanCount * BOT_FILL_ACTIVE_HUMAN_WEIGHT,
    BOT_FILL_MIN_COEFFICIENT,
    1
  );
  const targetTotal = Math.min(
    lobby.maxPlayers,
    Math.max(humanCount, Math.ceil(lobby.maxPlayers * coefficient))
  );
  return { activeHumanCount, coefficient, targetTotal };
}

async function activeBattleRoyaleHumanCount(ctx: Ctx, now: number) {
  const entrants = await ctx.db
    .query("battleRoyaleEntrantsV2")
    .collect();
  const userIds = new Set<string>();
  for (const entrant of entrants) {
    if (entrant.isBot || !entrant.userId) continue;
    if (now - entrant.lastSeenAt > ACTIVE_HUMAN_WINDOW_MS) continue;
    const lobby = await ctx.db.get(entrant.lobbyId);
    if (!lobby || (lobby.status !== "open" && lobby.status !== "active")) continue;
    userIds.add(String(entrant.userId));
  }
  return userIds.size;
}

function computeAlive(lobby: Lobby,
                      entrants: Entrant[],
                      now: number,
                      options: { projectPendingDead?: boolean } = {}) {
  const elapsedMs = lobby.startedAt ? Math.max(0, now - lobby.startedAt) : 0;
  const humanRows = entrants.filter((entrant: Entrant) => !entrant.isBot);
  const botRows = entrants.filter((entrant: Entrant) => entrant.isBot);
  const aliveRows = entrants.filter((entrant: Entrant) => entrant.alive && !entrant.placement);
  const humanAliveCount = aliveRows.filter((entrant: Entrant) => !entrant.isBot).length;
  const aliveBotRows = aliveRows.filter((entrant: Entrant) => entrant.isBot);
  const pendingDeadBots = aliveBotRows.filter((entrant: Entrant) => {
    if (!entrant.alive || entrant.placement) return false;
    const deathElapsedMs = entrant.botDeathElapsedMs;
    return deathElapsedMs !== undefined && elapsedMs >= deathElapsedMs;
  });
  const botAliveCount = options.projectPendingDead
    ? Math.max(0, aliveBotRows.length - pendingDeadBots.length)
    : aliveBotRows.length;
  const persistedAliveRowCount = humanAliveCount + aliveBotRows.length;
  const nextBotDeathInMs = botRows
    .filter((entrant: Entrant) => entrant.alive && !entrant.placement && entrant.botDeathElapsedMs !== undefined)
    .map((entrant: Entrant) => Math.max(0, (entrant.botDeathElapsedMs ?? 0) - elapsedMs))
    .sort((a: number, b: number) => a - b)[0];

  if (lobby.status === "finished" || lobby.status === "cancelled") {
    return {
      aliveCount: 0,
      humanAliveCount: 0,
      botAliveCount: 0,
      elapsedMs: Math.max(0, (lobby.finishedAt ?? now) - (lobby.startedAt ?? now)),
      nextBotDeathInMs: undefined,
      debug: debugAlive({
        elapsedMs,
        aliveCount: 0,
        humanAliveCount: 0,
        botAliveCount: 0,
        nextBotDeathInMs: undefined,
        dbAliveCount: persistedAliveRowCount,
        totalRows: entrants.length,
        humanRows: humanRows.length,
        botRows: botRows.length,
        pendingDeadRows: pendingDeadBots.length,
      }),
    };
  }

  const aliveCount = humanAliveCount + botAliveCount;
  return {
    aliveCount,
    humanAliveCount,
    botAliveCount,
    elapsedMs,
    nextBotDeathInMs,
    debug: debugAlive({
      elapsedMs,
      aliveCount,
      humanAliveCount,
      botAliveCount,
      nextBotDeathInMs,
      dbAliveCount: persistedAliveRowCount,
      totalRows: entrants.length,
      humanRows: humanRows.length,
      botRows: botRows.length,
      pendingDeadRows: pendingDeadBots.length,
    }),
  };
}

function debugAlive(args: {
  elapsedMs: number;
  aliveCount: number;
  humanAliveCount: number;
  botAliveCount: number;
  nextBotDeathInMs: number | undefined;
  dbAliveCount: number;
  totalRows: number;
  humanRows: number;
  botRows: number;
  pendingDeadRows: number;
}) {
  return {
    elapsedMs: args.elapsedMs,
    aliveCount: args.aliveCount,
    humanAliveCount: args.humanAliveCount,
    botAliveCount: args.botAliveCount,
    dbAliveCount: args.dbAliveCount,
    virtualDeadPendingCount: args.pendingDeadRows,
    nextBotDeathInMs: args.nextBotDeathInMs,
    totalRows: args.totalRows,
    humanRows: args.humanRows,
    botRows: args.botRows,
    aliveRows: args.aliveCount,
    deadRows: Math.max(0, args.totalRows - args.aliveCount),
  };
}

function effectiveStatus(lobby: Lobby, aliveCount: number) {
  if (lobby.status === "active" && aliveCount <= 0) return "finished";
  return lobby.status;
}

async function maybeFinalizeLobby(ctx: Ctx, lobbyId: Id<"battleRoyaleLobbiesV2">, now: number) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby || lobby.status !== "active") return;

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const alive = computeAlive(lobby, entrants, now);
  if (alive.aliveCount > 0) return;

  await ctx.db.patch(lobbyId, {
    status: "finished",
    finishedAt: lobby.finishedAt ?? now,
    cleanupAfter: now + FINISHED_RETENTION_MS,
    updatedAt: now,
  });
  await closeRoomCode(ctx, lobby, now);
}

async function markHumanDead(ctx: Ctx,
                             lobby: Lobby,
                             entrant: Entrant,
                             placement: number,
                             score: number,
                             now: number) {
  await ctx.db.patch(entrant._id, {
    alive: false,
    placement,
    score: Math.max(entrant.score, score),
    finishedAt: now,
    lastSeenAt: now,
  });
  const updated = await ctx.db.get(entrant._id);
  if (updated) {
    await payEntrantIfWinner(ctx, lobby, updated, now);
  }
}

async function payEntrantIfWinner(ctx: Ctx, lobby: Lobby, entrant: Entrant, now: number) {
  if (!entrant.userId) return;
  const placement = entrant.placement;
  if (!placement || placement < 1 || placement > PAYOUTS.length) return;

  const amount = Math.floor(lobby.maxPlayers * lobby.buyIn * 0.95 * PAYOUTS[placement - 1]);
  if (amount <= 0) return;

  const existing = await ctx.db
    .query("battleRoyalePayoutsV2")
    .withIndex("by_lobbyId", (q: any) => q.eq("lobbyId", lobby._id))
    .filter((q: any) => q.eq(q.field("userId"), entrant.userId))
    .first();
  if (existing) return;

  const user = await ctx.db.get(entrant.userId);
  if (user) {
    await ctx.db.patch(user._id, {
      bread: user.bread + amount,
      totalBreadCollected: (user.totalBreadCollected ?? 0) + amount,
      updatedAt: now,
    });
  }

  await ctx.db.patch(entrant._id, { prize: amount });
  await ctx.db.insert("battleRoyalePayoutsV2", {
    lobbyId: lobby._id,
    userId: entrant.userId,
    placement,
    amount,
    paidAt: now,
  });
}

async function buildAssignment(ctx: Ctx,
                               lobbyId: Id<"battleRoyaleLobbiesV2">,
                               entrantId: Id<"battleRoyaleEntrantsV2">,
                               bread: number) {
  const lobby = await ctx.db.get(lobbyId);
  const entrant = await ctx.db.get(entrantId);
  if (!lobby || !entrant) throw new Error("Battle royale lobby not found.");

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const alive = computeAlive(lobby, entrants, Date.now());
  return {
    lobbyId: lobby._id,
    entrantId: entrant._id,
    roomCode: lobby.roomCode,
    seed: lobby.seed,
    status: effectiveStatus(lobby, alive.aliveCount),
    playerCount: await playerCount(ctx, lobby, Date.now()),
    aliveCount: alive.aliveCount,
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    bread,
    createdAt: lobby.createdAt,
    joinDeadlineAt: lobby.joinDeadlineAt,
  };
}

async function buildState(ctx: Ctx, lobbyId: Id<"battleRoyaleLobbiesV2">, userId: Id<"users">) {
  const lobby = await ctx.db.get(lobbyId);
  if (!lobby) {
    throw new Error("Battle royale lobby not found.");
  }

  const entrants = await entrantsForLobby(ctx, lobbyId);
  const local = entrants.find((entrant: Entrant) => entrant.userId === userId);
  if (!local) {
    throw new ConvexError("You are not in this battle royale.");
  }

  const now = Date.now();
  const alive = computeAlive(lobby, entrants, now);
  const elapsedMs = lobby.startedAt ? Math.max(0, now - lobby.startedAt) : 0;
  const leaderboard = buildLeaderboard(lobby, entrants, elapsedMs);

  return {
    lobbyId: lobby._id,
    entrantId: local._id,
    roomCode: lobby.roomCode,
    seed: lobby.seed,
    status: effectiveStatus(lobby, alive.aliveCount),
    buyIn: lobby.buyIn,
    maxPlayers: lobby.maxPlayers,
    playerCount: await playerCount(ctx, lobby, now),
    aliveCount: alive.aliveCount,
    local: publicHuman(local),
    leaderboard,
    debug: alive.debug,
  };
}

function buildLeaderboard(lobby: Lobby, entrants: Entrant[], elapsedMs: number) {
  const rowEntrants = entrants.map((entrant: Entrant) => publicEntrant(entrant, elapsedMs));
  const hasBotRows = entrants.some((entrant: Entrant) => entrant.isBot);
  const legacyBots = hasBotRows
    ? []
    : lobby.botTimeline.map((bot: BotTimelineEntry) => publicBot(lobby, entrants, bot, elapsedMs));
  return [...rowEntrants, ...legacyBots]
    .sort((a, b) => {
      const ap = a.placement ?? 999;
      const bp = b.placement ?? 999;
      if (ap !== bp) return ap - bp;
      return b.score - a.score;
    })
    .slice(0, 10);
}

function publicHuman(entrant: Entrant) {
  return publicEntrant(entrant, 0);
}

function publicEntrant(entrant: Entrant, elapsedMs: number) {
  const isBot = entrant.isBot === true;
  return {
    playerId: isBot ? `bot:${entrant.botId ?? String(entrant._id)}` : entrant.userId,
    username: entrant.username,
    skinId: entrant.skinId,
    score: isBot && entrant.alive ? botRowScoreAt(entrant, elapsedMs) : entrant.score,
    alive: entrant.alive && !entrant.placement,
    placement: entrant.placement,
    prize: entrant.prize ?? 0,
  };
}

function publicBot(lobby: Lobby, entrants: Entrant[], bot: BotTimelineEntry, elapsedMs: number) {
  const alive = lobby.status === "active" && elapsedMs < botCrashAtMs(bot);
  return {
    playerId: `bot:${bot.botId}`,
    username: bot.username,
    skinId: bot.skinId,
    score: botScoreAt(bot, elapsedMs),
    alive,
    placement: alive ? undefined : botPlacement(lobby, entrants, bot),
    prize: 0,
  };
}

function botScoreAt(bot: BotTimelineEntry, elapsedMs: number) {
  if (bot.scoreEvents && bot.scoreEvents.length > 0) {
    let score = 0;
    for (const scoreAtMs of bot.scoreEvents) {
      if (elapsedMs >= scoreAtMs) {
        score += 1;
      } else {
        break;
      }
    }
    return Math.min(score, bot.finalScore);
  }

  const crashAtMs = botCrashAtMs(bot);
  if (elapsedMs >= crashAtMs) return bot.finalScore;
  return Math.max(0, Math.floor((bot.finalScore * Math.max(0, elapsedMs)) / crashAtMs));
}

function botRowScoreAt(bot: Entrant, elapsedMs: number) {
  const scoreEvents = bot.botScoreEvents ?? [];
  if (scoreEvents.length > 0) {
    let score = 0;
    for (const scoreAtMs of scoreEvents) {
      if (elapsedMs >= scoreAtMs) {
        score += 1;
      } else {
        break;
      }
    }
    return score;
  }

  return bot.score;
}

function placementAtElapsed(lobby: Lobby, entrants: Entrant[], deathElapsedMs: number) {
  const startedAt = lobby.startedAt ?? 0;
  let aliveAtDeath = 0;

  for (const entrant of entrants) {
    if (entrant.isBot) {
      const botDeathElapsedMs = entrant.botDeathElapsedMs ?? Number.MAX_SAFE_INTEGER;
      if (botDeathElapsedMs >= deathElapsedMs) aliveAtDeath += 1;
      continue;
    }

    if (!entrant.finishedAt) {
      if (entrant.alive && !entrant.placement) aliveAtDeath += 1;
      continue;
    }

    if (entrant.finishedAt - startedAt > deathElapsedMs) aliveAtDeath += 1;
  }

  return Math.max(1, aliveAtDeath);
}

function botPlacement(lobby: Lobby, entrants: Entrant[], bot: BotTimelineEntry) {
  const startedAt = lobby.startedAt ?? 0;
  const crashAtMs = botCrashAtMs(bot);
  const aliveHumansAtDeath = entrants.filter((entrant: Entrant) => {
    if (!entrant.finishedAt) return entrant.alive;
    return entrant.finishedAt - startedAt > crashAtMs;
  }).length;
  const botsAliveAtDeath = lobby.botTimeline.filter((entry: BotTimelineEntry) => botCrashAtMs(entry) >= crashAtMs).length;
  return Math.max(1, aliveHumansAtDeath + botsAliveAtDeath);
}

function botCrashAtMs(bot: BotTimelineEntry) {
  if (bot.deathAtMs !== undefined) return bot.deathAtMs;
  const scoreEvents = bot.scoreEvents ?? [];
  const lastScoreAtMs = scoreEvents.length > 0 ? scoreEvents[scoreEvents.length - 1] : 2_500;
  return lastScoreAtMs + (bot.crashDelayMs ?? 900);
}

async function recordAliveSnapshot(ctx: Ctx,
                                   lobby: Lobby,
                                   alive: ReturnType<typeof computeAlive>,
                                   now: number,
                                   options: { source: string; userId?: Id<"users">; flippedRows?: number }) {
  const snapshotLogCount = lobby.aliveSnapshotLogCount ?? 0;
  const countChanged = lobby.lastAliveCountLogged !== alive.aliveCount;
  const flippedRows = options.flippedRows ?? 0;
  const shouldLog = snapshotLogCount < 20 || countChanged || flippedRows > 0;
  if (!shouldLog || snapshotLogCount >= ALIVE_SNAPSHOT_LOG_LIMIT) return;

  await recordBattleRoyaleEvent(ctx, {
    event: "alive_count_row_snapshot",
    level: countChanged && alive.aliveCount > (lobby.lastAliveCountLogged ?? alive.aliveCount) ? "warning" : "debug",
    message: "Battle Royale alive count snapshot derived from persisted entrant rows.",
    lobby,
    userId: options.userId,
    metadata: {
      source: options.source,
      status: lobby.status,
      elapsedMs: alive.elapsedMs,
      countedAliveRows: alive.aliveCount,
      cachedAliveRows: lobby.aliveCount,
      lastLoggedAliveRows: lobby.lastAliveCountLogged,
      humanAliveRows: alive.humanAliveCount,
      botAliveRows: alive.botAliveCount,
      totalRows: alive.debug.totalRows,
      deadRows: alive.debug.deadRows,
      pendingDeadRows: alive.debug.virtualDeadPendingCount,
      flippedRows,
      nextBotDeathMs: alive.nextBotDeathInMs,
      snapshotLogCount: snapshotLogCount + 1,
    },
  });

  await ctx.db.patch(lobby._id, {
    aliveSnapshotLogCount: snapshotLogCount + 1,
    lastAliveCountLogged: alive.aliveCount,
    updatedAt: now,
  });
}

async function recordBattleRoyaleEvent(ctx: Ctx, args: {
  event: string;
  level: "debug" | "info" | "warning" | "error";
  message?: string;
  lobby: any;
  userId?: Id<"users">;
  metadata?: Record<string, unknown>;
}) {
  const metadata = Object.entries(args.metadata ?? {})
    .filter(([, value]) => value !== undefined)
    .slice(0, 40)
    .map(([key, value]) => ({
      key: String(key).slice(0, 80),
      value: String(value).slice(0, 500),
    }));

  await ctx.db.insert("diagnosticEvents", {
    userId: args.userId,
    category: "battle_royale",
    event: args.event.slice(0, 120),
    level: args.level,
    message: args.message?.slice(0, 2_000),
    matchId: String(args.lobby._id).slice(0, 128),
    sessionCode: args.lobby.roomCode ? String(args.lobby.roomCode).slice(0, 128) : undefined,
    mode: "battleRoyale",
    metadata,
    createdAt: Date.now(),
  });
}

async function closeRoomCode(ctx: Ctx, lobby: Lobby, now: number) {
  const code = await ctx.db
    .query("battleRoyaleRoomCodesV2")
    .withIndex("by_code", (q: any) => q.eq("code", lobby.roomCode))
    .first();
  if (code && code.status !== "closed") {
    await ctx.db.patch(code._id, {
      status: "closed",
      closedAt: now,
    });
  }
}

async function closeAndDeleteOpenLobby(ctx: Ctx, lobby: Lobby, now: number) {
  await closeRoomCode(ctx, lobby, now);
  const entrants = await entrantsForLobby(ctx, lobby._id);
  for (const entrant of entrants) {
    await ctx.db.delete(entrant._id);
  }
  await ctx.db.delete(lobby._id);
}

async function deleteFinishedLobby(ctx: Ctx, lobby: Lobby) {
  const entrants = await entrantsForLobby(ctx, lobby._id);
  for (const entrant of entrants) {
    await ctx.db.delete(entrant._id);
  }

  const payouts = await ctx.db
    .query("battleRoyalePayoutsV2")
    .withIndex("by_lobbyId", (q: any) => q.eq("lobbyId", lobby._id))
    .collect();
  for (const payout of payouts) {
    await ctx.db.delete(payout._id);
  }

  await ctx.db.delete(lobby._id);
}

export async function cleanupBattleRoyaleV2(ctx: Ctx, now: number) {
  const open = await ctx.db
    .query("battleRoyaleLobbiesV2")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "open"))
    .collect();

  for (const lobby of open) {
    const entrants = await entrantsForLobby(ctx, lobby._id);
    if (entrants.length === 0 && now - lobby.createdAt >= EMPTY_OPEN_RETENTION_MS) {
      await closeAndDeleteOpenLobby(ctx, lobby, now);
      continue;
    }
    if (now >= lobby.joinDeadlineAt) {
      await maybeStartLobby(ctx, lobby._id, now);
    }
  }

  const active = await ctx.db
    .query("battleRoyaleLobbiesV2")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "active"))
    .collect();

  for (const lobby of active) {
    const sync = await syncBotRowsForLobby(ctx, lobby, now, { source: "cleanup" });
    let latestLobby = sync.lobby;
    const entrants = sync.entrants;
    const stale = entrants
      .filter((entrant: Entrant) => !entrant.isBot && entrant.alive && !entrant.placement && now - entrant.lastSeenAt > STALE_AFTER_MS)
      .sort((a: Entrant, b: Entrant) => {
        if (a.score !== b.score) return a.score - b.score;
        return String(a._id).localeCompare(String(b._id));
      });

    for (const entrant of stale) {
      const latestEntrants = await entrantsForLobby(ctx, latestLobby._id);
      const aliveBefore = computeAlive(latestLobby, latestEntrants, now).aliveCount;
      await markHumanDead(ctx, latestLobby, entrant, Math.max(1, aliveBefore), entrant.score, now);
      const refreshed = await ctx.db.get(latestLobby._id);
      if (!refreshed) break;
      await updateAliveCache(ctx, refreshed, await entrantsForLobby(ctx, refreshed._id), now);
      latestLobby = await ctx.db.get(refreshed._id) ?? refreshed;
    }

    await maybeFinalizeLobby(ctx, lobby._id, now);
  }

  const finished = await ctx.db
    .query("battleRoyaleLobbiesV2")
    .withIndex("by_status_createdAt", (q: any) => q.eq("status", "finished"))
    .collect();

  for (const lobby of finished) {
    const cleanupAfter = lobby.cleanupAfter ?? ((lobby.finishedAt ?? lobby.updatedAt) + FINISHED_RETENTION_MS);
    if (now < cleanupAfter) continue;
    await closeRoomCode(ctx, lobby, now);
    await deleteFinishedLobby(ctx, lobby);
  }
}
