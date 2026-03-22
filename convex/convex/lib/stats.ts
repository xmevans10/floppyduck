import type { Doc, Id } from "../_generated/dataModel";

export type LocalStatsSnapshot = {
  username?: string;
  gamesPlayed?: number;
  wins?: number;
  losses?: number;
  bestScore?: number;
  totalScore?: number;
  elo?: number;
  bread?: number;
  totalBreadCollected?: number;
  recentScores?: number[];
  beatenBots?: string[];
};

export function defaultUserStats() {
  return {
    rating: 1200,
    gamesPlayed: 0,
    wins: 0,
    losses: 0,
    bestScore: 0,
    totalScore: 0,
    bread: 0,
    totalBreadCollected: 0,
    recentScores: [] as number[],
    beatenBots: [] as string[],
  };
}

export function buildUserFromSnapshot(snapshot: LocalStatsSnapshot | undefined) {
  const defaults = defaultUserStats();

  return {
    rating: snapshot?.elo ?? defaults.rating,
    gamesPlayed: snapshot?.gamesPlayed ?? defaults.gamesPlayed,
    wins: snapshot?.wins ?? defaults.wins,
    losses: snapshot?.losses ?? defaults.losses,
    bestScore: snapshot?.bestScore ?? defaults.bestScore,
    totalScore: snapshot?.totalScore ?? defaults.totalScore,
    bread: snapshot?.bread ?? defaults.bread,
    totalBreadCollected: snapshot?.totalBreadCollected ?? defaults.totalBreadCollected,
    recentScores: sanitizeRecentScores(snapshot?.recentScores ?? defaults.recentScores),
    beatenBots: Array.isArray(snapshot?.beatenBots) ? snapshot!.beatenBots!.slice(0, 32) : defaults.beatenBots,
  };
}

export function shouldMergeLocalStats(user: Doc<"users">) {
  return user.gamesPlayed === 0 && user.wins === 0 && user.losses === 0;
}

export function applyMatchStatsToUser(user: Doc<"users">,
                                      score: number,
                                      didWin: boolean,
                                      didDraw: boolean,
                                      newRating?: number) {
  const wins = didDraw ? user.wins : user.wins + (didWin ? 1 : 0);
  const losses = didDraw ? user.losses : user.losses + (didWin ? 0 : 1);

  const breadGain = didDraw
    ? Math.max(1, score)
    : didWin
      ? Math.max(3, score)
      : Math.max(1, Math.floor(score / 2));

  const recentScores = [
    ...user.recentScores,
    score,
  ].slice(-20);

  return {
    gamesPlayed: user.gamesPlayed + 1,
    wins,
    losses,
    bestScore: Math.max(user.bestScore, score),
    totalScore: user.totalScore + score,
    bread: user.bread + breadGain,
    totalBreadCollected: user.totalBreadCollected + breadGain,
    recentScores,
    rating: typeof newRating === "number" ? newRating : user.rating,
  };
}

export function toPublicProfile(user: Doc<"users">) {
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
      bread: user.bread,
      totalBreadCollected: user.totalBreadCollected,
      recentScores: user.recentScores,
      beatenBots: user.beatenBots,
    },
  };
}

export async function upsertRating(ctx: any, userId: Id<"users">, rating: number, now: number) {
  const existing = await ctx.db
    .query("ratings")
    .withIndex("by_userId", (q: any) => q.eq("userId", userId))
    .first();

  if (existing) {
    await ctx.db.patch(existing._id, { rating, updatedAt: now });
  } else {
    await ctx.db.insert("ratings", { userId, rating, updatedAt: now });
  }
}

function sanitizeRecentScores(scores: number[]) {
  return scores
    .filter((value) => Number.isFinite(value))
    .map((value) => Math.max(0, Math.floor(value)))
    .slice(-20);
}
