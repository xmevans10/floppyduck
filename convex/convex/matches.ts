import { mutation, query } from "./_generated/server";
import { v, ConvexError } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { mustBeParticipant, resolveUser, userSide } from "./lib/identity";
import { applyMatchStatsToUser, upsertRating } from "./lib/stats";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const K_FACTOR = 32;

// Server-side score cap — expert tier starts at 40, 500 is absurdly generous.
const MAX_SCORE = 500;

export const reportScore = mutation({
  args: {
    matchId: v.id("matches"),
    score: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);
    const side = userSide(match, user._id);

    const newScore = Math.min(MAX_SCORE, Math.max(0, Math.floor(args.score)));
    const currentScore = side === "p1" ? match.p1Score : match.p2Score;

    if (newScore < currentScore) {
      throw new ConvexError("Score cannot decrease.");
    }

    await ctx.db.patch(match._id, {
      [side === "p1" ? "p1Score" : "p2Score"]: newScore,
      updatedAt: Date.now(),
    });

    return { ok: true };
  },
});

export const getState = query({
  args: {
    matchId: v.id("matches"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);
    const p1 = await ctx.db.get(match.p1UserId);
    const p2 = await ctx.db.get(match.p2UserId);

    // Gracefully handle deleted opponents — matches are preserved after
    // account deletion so the remaining player can still query state.
    return buildPublicMatchState(match, user._id, p1, p2);
  },
});

export const finishMatch = mutation({
  args: {
    matchId: v.id("matches"),
    score: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);

    const side = userSide(match, user._id);

    // Guard: prevent a player from re-submitting after they already finished.
    const alreadyFinished = side === "p1" ? match.p1Finished : match.p2Finished;
    if (alreadyFinished) {
      const p1 = await ctx.db.get(match.p1UserId);
      const p2 = await ctx.db.get(match.p2UserId);
      return buildPublicMatchState(match, user._id, p1, p2);
    }

    const now = Date.now();

    const patch = side === "p1"
      ? { p1Score: Math.min(MAX_SCORE, Math.max(0, Math.floor(args.score))), p1Finished: true, updatedAt: now }
      : { p2Score: Math.min(MAX_SCORE, Math.max(0, Math.floor(args.score))), p2Finished: true, updatedAt: now };

    await ctx.db.patch(match._id, patch);

    let updatedMatch = await ctx.db.get(match._id);
    if (!updatedMatch) {
      throw new Error("Match not found after update.");
    }

    if (updatedMatch.status !== "finished" && updatedMatch.p1Finished && updatedMatch.p2Finished) {
      updatedMatch = await resolveMatchAndRatings(ctx, updatedMatch);
    }

    const p1 = await ctx.db.get(updatedMatch.p1UserId);
    const p2 = await ctx.db.get(updatedMatch.p2UserId);

    // Gracefully handle deleted opponents — matches are preserved after
    // account deletion so the remaining player can still finish.
    return buildPublicMatchState(updatedMatch, user._id, p1, p2);
  },
});

export const abandonMatch = mutation({
  args: {
    matchId: v.id("matches"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);

    if (match.status === "finished") {
      const p1 = await ctx.db.get(match.p1UserId);
      const p2 = await ctx.db.get(match.p2UserId);
      return buildPublicMatchState(match, user._id, p1, p2);
    }

    if (match.p1Score > 0 || match.p2Score > 0 || match.p1Finished || match.p2Finished) {
      throw new ConvexError("Cannot abandon a match after gameplay starts.");
    }

    const now = Date.now();
    await ctx.db.patch(match._id, {
      p1Finished: true,
      p2Finished: true,
      status: "finished",
      ratingDeltaP1: 0,
      ratingDeltaP2: 0,
      finishedAt: now,
      updatedAt: now,
    });

    const updated = await ctx.db.get(match._id);
    if (!updated) {
      throw new Error("Match not found after abandon.");
    }

    const p1 = await ctx.db.get(updated.p1UserId);
    const p2 = await ctx.db.get(updated.p2UserId);
    return buildPublicMatchState(updated, user._id, p1, p2);
  },
});

export const markReady = mutation({
  args: {
    matchId: v.id("matches"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);
    const side = userSide(match, user._id);

    if (match.status !== "active") {
      throw new Error("Match is not active.");
    }

    const now = Date.now();
    const field = side === "p1" ? "p1Ready" : "p2Ready";
    await ctx.db.patch(match._id, { [field]: now, updatedAt: now });

    return { ok: true };
  },
});

export const scheduleStart = mutation({
  args: {
    matchId: v.id("matches"),
    startAtMs: v.number(),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);
    const side = userSide(match, user._id);

    // Only the host (p1) may schedule the start.
    if (side !== "p1") {
      throw new Error("Only the host can schedule the match start.");
    }

    if (match.status !== "active") {
      throw new Error("Match is not active.");
    }

    // Both players must have signalled ready.
    if (!match.p1Ready || !match.p2Ready) {
      throw new Error("Both players must be ready before starting.");
    }

    const now = Date.now();
    await ctx.db.patch(match._id, {
      startAtMs: args.startAtMs,
      updatedAt: now,
    });

    return { ok: true };
  },
});

export const getReadyState = query({
  args: {
    matchId: v.id("matches"),
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const user = await resolveUser(ctx, args, { allowGuestFallback: false });
    const match = await ctx.db.get(args.matchId);

    if (!match) {
      throw new Error("Match not found.");
    }

    mustBeParticipant(match, user._id);

    return {
      p1Ready: match.p1Ready ?? null,
      p2Ready: match.p2Ready ?? null,
      startAtMs: match.startAtMs ?? null,
      status: match.status,
    };
  },
});

function buildPublicMatchState(match: Doc<"matches">,
                               userId: Doc<"users">["_id"],
                               p1: Doc<"users"> | null,
                               p2: Doc<"users"> | null) {
  const isP1 = match.p1UserId === userId;
  const localScore = isP1 ? match.p1Score : match.p2Score;
  const opponentScore = isP1 ? match.p2Score : match.p1Score;
  const localUser = isP1 ? p1 : p2;
  const opponent = isP1 ? p2 : p1;
  const isFinalized = match.status === "finished";

  return {
    matchId: match._id,
    mode: match.mode,
    opponentName: opponent?.username ?? "OPPONENT",
    opponentSkinId: opponent?.selectedSkin ?? undefined,
    localScore,
    opponentScore,
    isFinished: isFinalized,
    isFinalized,
    didWin: isFinalized ? localScore > opponentScore : undefined,
    didDraw: isFinalized ? localScore === opponentScore : undefined,
    ratingDelta: isFinalized ? (isP1 ? match.ratingDeltaP1 : match.ratingDeltaP2) : undefined,
    newRating: isFinalized ? (localUser?.rating ?? undefined) : undefined,
    isRanked: match.mode === "ranked",
  };
}

async function resolveMatchAndRatings(ctx: any, match: Doc<"matches">): Promise<Doc<"matches">> {
  const now = Date.now();

  const p1 = await ctx.db.get(match.p1UserId);
  const p2 = await ctx.db.get(match.p2UserId);

  // At least one participant must still exist to finalize the match.
  if (!p1 && !p2) {
    // Both deleted — just mark the match finished with no rating changes.
    await ctx.db.patch(match._id, {
      status: "finished",
      finishedAt: now,
      updatedAt: now,
    });
    const updatedMatch = await ctx.db.get(match._id);
    if (!updatedMatch) {
      throw new Error("Unable to read resolved match.");
    }
    return updatedMatch;
  }

  const p1Score = match.p1Score;
  const p2Score = match.p2Score;

  let winnerUserId = undefined;
  if (p1Score > p2Score) {
    winnerUserId = p1?._id;
  } else if (p2Score > p1Score) {
    winnerUserId = p2?._id;
  }

  let ratingDeltaP1 = 0;
  let ratingDeltaP2 = 0;

  // Use actual rating or default 1200 for deleted opponents.
  const p1Rating = p1?.rating ?? 1200;
  const p2Rating = p2?.rating ?? 1200;

  let p1NewRating = p1Rating;
  let p2NewRating = p2Rating;

  if (match.mode === "ranked") {
    const p1Expected = 1 / (1 + Math.pow(10, (p2Rating - p1Rating) / 400));
    const p2Expected = 1 / (1 + Math.pow(10, (p1Rating - p2Rating) / 400));

    const p1ScoreValue = p1Score === p2Score ? 0.5 : p1Score > p2Score ? 1 : 0;
    const p2ScoreValue = p1Score === p2Score ? 0.5 : p2Score > p1Score ? 1 : 0;

    ratingDeltaP1 = Math.round(K_FACTOR * (p1ScoreValue - p1Expected));
    ratingDeltaP2 = Math.round(K_FACTOR * (p2ScoreValue - p2Expected));

    p1NewRating = p1Rating + ratingDeltaP1;
    p2NewRating = p2Rating + ratingDeltaP2;
  }

  // Only update stats for users that still exist.
  if (p1) {
    const p1StatsPatch = applyMatchStatsToUser(
      p1,
      p1Score,
      p1Score > p2Score,
      p1Score === p2Score,
      p1NewRating,
    );
    await ctx.db.patch(p1._id, {
      ...p1StatsPatch,
      updatedAt: now,
    });
    await upsertRating(ctx, p1._id, p1NewRating, now);
  }

  if (p2) {
    const p2StatsPatch = applyMatchStatsToUser(
      p2,
      p2Score,
      p2Score > p1Score,
      p1Score === p2Score,
      p2NewRating,
    );
    await ctx.db.patch(p2._id, {
      ...p2StatsPatch,
      updatedAt: now,
    });
    await upsertRating(ctx, p2._id, p2NewRating, now);
  }

  await ctx.db.patch(match._id, {
    status: "finished",
    winnerUserId,
    ratingDeltaP1,
    ratingDeltaP2,
    finishedAt: now,
    updatedAt: now,
  });

  const updatedMatch = await ctx.db.get(match._id);
  if (!updatedMatch) {
    throw new Error("Unable to read resolved match.");
  }

  return updatedMatch;
}
