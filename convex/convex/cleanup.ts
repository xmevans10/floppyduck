import { internalMutation } from "./_generated/server";
import { v } from "convex/values";
import type { Doc } from "./_generated/dataModel";
import { cleanupBattleRoyale } from "./battleRoyale";
import { scoreBreadReward } from "./lib/stats";

const STALE_QUEUE_MS = 30 * 1000;
const ABANDONED_MATCH_MS = 5 * 60 * 1000;

export const run = internalMutation({
  handler: async (ctx) => {
    const now = Date.now();

    // Purge matchmaking queue entries that have been "searching" for >2 min.
    // Players who force-quit never call leaveQueue, leaving zombie entries.
    const queueEntries = await ctx.db
      .query("matchmakingQueue")
      .collect();

    for (const entry of queueEntries) {
      const lastActivity = entry.lastSeenAt ?? entry.createdAt;
      // Purge stale "searching" entries (player force-quit)
      if (entry.status === "searching" && now - lastActivity > STALE_QUEUE_MS) {
        await ctx.db.delete(entry._id);
      }
      // Purge "matched" entries older than the abandoned-match window —
      // these were never cleaned up after match resolution.
      if (entry.status === "matched" && now - lastActivity > ABANDONED_MATCH_MS) {
        await ctx.db.delete(entry._id);
      }
    }

    // Purge stale rooms that have been "waiting" for >2 min (host left without cancelling).
    const rooms = await ctx.db.query("rooms").collect();
    for (const room of rooms) {
      if (room.status === "waiting" && now - room.createdAt > STALE_QUEUE_MS) {
        await ctx.db.delete(room._id);
      }
    }

    // Purge expired or revoked sessions.  Sessions expire after 30 days
    // but accumulate indefinitely otherwise.
    const sessions = await ctx.db
      .query("sessions")
      .collect();

    for (const session of sessions) {
      if (session.revokedAt || session.expiresAt < now) {
        await ctx.db.delete(session._id);
      }
    }

    // Auto-resolve matches that have been "active" with no update for >5 min.
    // This handles players who disconnect or crash before calling finishMatch.
    const activeMatches = await ctx.db
      .query("matches")
      .withIndex("by_status_createdAt", (q) => q.eq("status", "active"))
      .collect();

    for (const match of activeMatches) {
      if (now - match.updatedAt <= ABANDONED_MATCH_MS) continue;

      // If one player finished, give them the win — the other forfeits.
      // If neither finished, 0-0 draw with no rating or bread change.
      const shouldPatchBoth =
        (match.p1Finished && !match.p2Finished) ||
        (match.p2Finished && !match.p1Finished);

      if (shouldPatchBoth) {
        await ctx.db.patch(match._id, {
          p1Finished: true,
          p2Finished: true,
          updatedAt: now,
        });
      } else if (!match.p1Finished && !match.p2Finished) {
        // Abandoned with no activity from either side — no rating impact.
        await ctx.db.patch(match._id, {
          status: "finished",
          p1Finished: true,
          p2Finished: true,
          finishedAt: now,
          updatedAt: now,
        });
        continue;
      }

      // Re-read and resolve if both are now finished.
      const updated = await ctx.db.get(match._id);
      if (
        updated &&
        updated.status !== "finished" &&
        updated.p1Finished &&
        updated.p2Finished
      ) {
        await resolveMatchAndRatings(ctx, updated);
      }
    }

    await cleanupBattleRoyale(ctx, now);
  },
});

// Duplicated from matches.ts to avoid circular imports.
// This is the matched resolution — Elo, bread, finishedAt.
async function resolveMatchAndRatings(
  ctx: any,
  match: Doc<"matches">,
): Promise<void> {
  const now = Date.now();

  const p1 = await ctx.db.get(match.p1UserId);
  const p2 = await ctx.db.get(match.p2UserId);

  if (!p1 && !p2) {
    await ctx.db.patch(match._id, {
      status: "finished",
      finishedAt: now,
      updatedAt: now,
    });
    return;
  }

  const p1Rating = p1?.rating ?? 1200;
  const p2Rating = p2?.rating ?? 1200;

  let ratingDeltaP1 = 0;
  let ratingDeltaP2 = 0;

  if (match.mode === "ranked") {
    const K = 32;
    const p1Expected = 1 / (1 + Math.pow(10, (p2Rating - p1Rating) / 400));
    const p2Expected = 1 / (1 + Math.pow(10, (p1Rating - p2Rating) / 400));
    const p1ScoreValue =
      match.p1Score === match.p2Score ? 0.5 : match.p1Score > match.p2Score ? 1 : 0;
    const p2ScoreValue =
      match.p1Score === match.p2Score ? 0.5 : match.p2Score > match.p1Score ? 1 : 0;
    ratingDeltaP1 = Math.round(K * (p1ScoreValue - p1Expected));
    ratingDeltaP2 = Math.round(K * (p2ScoreValue - p2Expected));
  }

  if (p1) {
    const breadGain = scoreBreadReward(
      match.p1Score,
      match.p1Score > match.p2Score,
      match.p1Score === match.p2Score,
    );

    await ctx.db.patch(p1._id, {
      gamesPlayed: p1.gamesPlayed + 1,
      wins: match.p1Score === match.p2Score ? p1.wins : p1.wins + (match.p1Score > match.p2Score ? 1 : 0),
      losses: match.p1Score === match.p2Score ? p1.losses : p1.losses + (match.p1Score > match.p2Score ? 0 : 1),
      bestScore: Math.max(p1.bestScore, match.p1Score),
      totalScore: p1.totalScore + match.p1Score,
      bread: p1.bread + breadGain,
      totalBreadCollected: (p1.totalBreadCollected ?? 0) + breadGain,
      rating: p1Rating + ratingDeltaP1,
      recentScores: [...p1.recentScores, match.p1Score].slice(-20),
      updatedAt: now,
    });
  }

  if (p2) {
    const breadGain = scoreBreadReward(
      match.p2Score,
      match.p2Score > match.p1Score,
      match.p1Score === match.p2Score,
    );

    await ctx.db.patch(p2._id, {
      gamesPlayed: p2.gamesPlayed + 1,
      wins: match.p1Score === match.p2Score ? p2.wins : p2.wins + (match.p2Score > match.p1Score ? 1 : 0),
      losses: match.p1Score === match.p2Score ? p2.losses : p2.losses + (match.p2Score > match.p1Score ? 0 : 1),
      bestScore: Math.max(p2.bestScore, match.p2Score),
      totalScore: p2.totalScore + match.p2Score,
      bread: p2.bread + breadGain,
      totalBreadCollected: (p2.totalBreadCollected ?? 0) + breadGain,
      rating: p2Rating + ratingDeltaP2,
      recentScores: [...p2.recentScores, match.p2Score].slice(-20),
      updatedAt: now,
    });
  }

  let winnerUserId = undefined;
  if (match.p1Score > match.p2Score) {
    winnerUserId = p1?._id ?? match.p1UserId;
  } else if (match.p2Score > match.p1Score) {
    winnerUserId = p2?._id ?? match.p2UserId;
  }

  await ctx.db.patch(match._id, {
    status: "finished",
    winnerUserId,
    ratingDeltaP1,
    ratingDeltaP2,
    finishedAt: now,
    updatedAt: now,
  });
}
