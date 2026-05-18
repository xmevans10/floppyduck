# Convex Backend Fixes — Implementation Plan

## Files to create/modify (4 files)

---

### 1. NEW: `convex/convex/crons.ts` — Scheduled cleanup job

Creates a cron job that runs every 60 seconds. References `internal.cleanup.run` (defined below).

```typescript
import { cronJobs } from "convex/server";
import { internal } from "./_generated/api";

const crons = cronJobs();

crons.interval("cleanup", { minutes: 1 }, internal.cleanup.run);

export default crons;
```

---

### 2. NEW: `convex/convex/cleanup.ts` — Cleanup internal mutation

Three cleanup operations in one atomic mutation:

**A. Purge stale queue entries** — Deletes `matchmakingQueue` entries where `status === "searching"` AND `createdAt < now - 2 minutes`.

**B. Purge expired/revoked sessions** — Deletes `sessions` where `expiresAt < now` OR `revokedAt` is set.

**C. Auto-resolve abandoned matches** — Finds `matches` where `status === "active"` AND `updatedAt < now - 5 minutes`. For each:
- If one player finished and the other didn't, mark both as finished (the finished player wins by forfeit — their score already reported; the other gets score 0). Call `resolveMatchAndRatings`.
- If NEITHER player finished, mark both as finished with 0-0 draw. Call `resolveMatchAndRatings`.

```typescript
import { internalMutation } from "./_generated/server";
import { resolveMatchAndRatings } from "./matches"; // need to export this
```

Note: `resolveMatchAndRatings` is currently `private async function` in `matches.ts`. It needs to be exported (or the cleanup logic needs to be duplicated/inlined).

**Alternative**: Inline the resolution logic in `cleanup.ts` or extract `resolveMatchAndRatings` into `lib/stats.ts` as a shared utility.

**Alternative 2 (simpler)**: Don't call `resolveMatchAndRatings` — just mark both players as finished and the match as finished with no rating change. This is simpler and avoids the export issue. Rating delta is zero; stats don't change; bread isn't awarded/lost. This is acceptable because a player who abandons shouldn't benefit.

---

### 3. EDIT: `convex/convex/auth.ts` — Add `spendBread` mutation

Add a public mutation that atomically decrements `user.bread`:

```typescript
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
    
    await ctx.db.patch(user._id, {
      bread: user.bread - cost,
      updatedAt: Date.now(),
    });
    
    return { bread: user.bread - cost };
  },
});
```

Also add `import { ConvexError }` if not already imported (it may already be since `auth.ts` uses `ConvexError` — but it doesn't currently import it directly. Check if it's available via `convex/values`).

The Swift client (`ConvexClient.swift`) will need a corresponding method to call this mutation. Add to `SpendableBread` or the appropriate section.

---

### 4. EDIT: `convex/convex/matches.ts` — Fix reportScore monotonicity

Change `reportScore` handler to reject scores lower than the current reported score:

```typescript
const currentScore = side === "p1" ? match.p1Score : match.p2Score;
const newScore = Math.min(MAX_SCORE, Math.max(0, Math.floor(args.score)));

if (newScore < currentScore) {
  throw new ConvexError("Score cannot decrease.");
}

await ctx.db.patch(match._id, {
  [side === "p1" ? "p1Score" : "p2Score"]: newScore,
  updatedAt: Date.now(),
});
```

Also add `import { ConvexError } from "convex/values";` at top if not already present (it is — `matches.ts` uses it in `mustBeParticipant` via `identity.ts`).

---

### 5. EDIT: `convex/convex/ratings.ts` — Fix leaderboard rank numbering

Current issue: deleted users cause `continue` but the rank counter still increments, creating gaps (e.g., rank 1, rank 2, rank 4).

Fix: base rank on the result array length, not loop index:

```typescript
// BEFORE (broken):
result.push({
  rank: result.length + 1,  // technically correct already? let me re-check
});

// Actually, looking at the code:
for (let index = 0; index < rows.length; index += 1) {
  const row = rows[index];
  const user = await ctx.db.get(row.userId);
  if (!user) {
    continue; // skip but index still advances — but rank uses result.length + 1, not index
  }
  result.push({
    rank: result.length + 1, // this is actually correct!
  });
}
```

Wait — looking at the original code more carefully, it uses `result.length + 1` for rank, NOT `index + 1`. So the rank IS already correct for deleted users. The issue described in my audit may be a misreading. Let me re-check:

```typescript
for (let index = 0; index < rows.length; index += 1) {
  const row = rows[index];
  const user = await ctx.db.get(row.userId);
  if (!user) {
    continue;
  }
  result.push({
    rank: result.length + 1, // correct — uses result array length
  });
}
```

This IS correct. The rank numbering works fine even with deleted users because it uses `result.length + 1`. The issue I initially flagged was wrong.

**However**, there's still a problem: if after skipping deleted users, we end up with fewer than `limit` entries, the leaderboard shows fewer players than expected. E.g., if 5 users were deleted in the top 20 ratings, the leaderboard only shows 15 entries.

**Fix**: Keep fetching more entries to fill up to `limit`. Use a loop that continues fetching until we have enough visible users or run out:

```typescript
export const leaderboard = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const target = Math.max(1, Math.min(100, Math.floor(args.limit ?? 20)));
    const result: Array<{ userId: string; username: string; rating: number; rank: number }> = [];
    let cursor: string | undefined;

    while (result.length < target) {
      const batch = await ctx.db
        .query("ratings")
        .withIndex("by_rating")
        .order("desc")
        .paginate({ numItems: target, cursor })
        .take(target);

      for (const row of batch.page) {
        const user = await ctx.db.get(row.userId);
        if (user) {
          result.push({
            userId: user._id,
            username: user.username,
            rating: row.rating,
            rank: result.length + 1,
          });
          if (result.length >= target) break;
        }
      }

      if (batch.isDone || result.length >= target) break;
      cursor = batch.continueCursor;
    }

    return result;
  },
});
```

---

## Swift client updates needed

To support `spendBread`, add a method to `ConvexClient.swift`:

```swift
func spendBread(amount: Int) async throws -> Int {
    let result = try await mutation("auth:spendBread", args: [
        "amount": amount,
        "deviceId": deviceId,
        "sessionToken": sessionToken,
    ])
    guard let bread = result["bread"] as? Int else {
        throw ConvexError.invalidResponse
    }
    return bread
}
```

And call it from `ThemeManager` / `SkinManager` / `ShopView` whenever bread is spent.

---

## Execution order

1. Create `convex/convex/cleanup.ts` — standalone, no deps on other changes
2. Create `convex/convex/crons.ts` — references cleanup
3. Edit `convex/convex/auth.ts` — add `spendBread`
4. Edit `convex/convex/matches.ts` — fix reportScore
5. Edit `convex/convex/ratings.ts` — fix leaderboard pagination
6. Verify: `npx convex dev` to check TypeScript compiles
7. Deploy: `npx convex deploy`
