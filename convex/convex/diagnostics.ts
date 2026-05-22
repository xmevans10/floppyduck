import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import type { Id } from "./_generated/dataModel";

const identityArgs = {
  deviceId: v.optional(v.string()),
  sessionToken: v.optional(v.string()),
};

const metadataArg = v.optional(v.array(v.object({
  key: v.string(),
  value: v.string(),
})));

const MAX_MESSAGE_LENGTH = 2_000;
const MAX_METADATA_ITEMS = 40;
const MAX_METADATA_KEY_LENGTH = 80;
const MAX_METADATA_VALUE_LENGTH = 500;

export const recordEvent = mutation({
  args: {
    category: v.string(),
    event: v.string(),
    level: v.union(v.literal("debug"), v.literal("info"), v.literal("warning"), v.literal("error")),
    message: v.optional(v.string()),
    matchId: v.optional(v.string()),
    sessionCode: v.optional(v.string()),
    playerGroup: v.optional(v.number()),
    mode: v.optional(v.string()),
    metadata: metadataArg,
    ...identityArgs,
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const userId = await resolveOptionalUserId(ctx, args);

    await ctx.db.insert("diagnosticEvents", {
      userId,
      deviceId: trimOptional(args.deviceId, 128),
      category: trimRequired(args.category, 80, "client"),
      event: trimRequired(args.event, 120, "event"),
      level: args.level,
      message: trimOptional(args.message, MAX_MESSAGE_LENGTH),
      matchId: trimOptional(args.matchId, 128),
      sessionCode: trimOptional(args.sessionCode, 128),
      playerGroup: args.playerGroup,
      mode: trimOptional(args.mode, 40),
      metadata: sanitizeMetadata(args.metadata),
      createdAt: now,
    });

    return { ok: true };
  },
});

export const recent = query({
  args: {
    limit: v.optional(v.number()),
    category: v.optional(v.string()),
    matchId: v.optional(v.string()),
    sessionCode: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(200, Math.floor(args.limit ?? 100)));

    if (args.matchId) {
      return await ctx.db
        .query("diagnosticEvents")
        .withIndex("by_matchId_createdAt", (q) => q.eq("matchId", args.matchId))
        .order("desc")
        .take(limit);
    }

    if (args.sessionCode) {
      return await ctx.db
        .query("diagnosticEvents")
        .withIndex("by_sessionCode_createdAt", (q) => q.eq("sessionCode", args.sessionCode))
        .order("desc")
        .take(limit);
    }

    if (args.category) {
      return await ctx.db
        .query("diagnosticEvents")
        .withIndex("by_category_createdAt", (q) => q.eq("category", args.category))
        .order("desc")
        .take(limit);
    }

    return await ctx.db
      .query("diagnosticEvents")
      .withIndex("by_createdAt")
      .order("desc")
      .take(limit);
  },
});

async function resolveOptionalUserId(
  ctx: any,
  args: { deviceId?: string; sessionToken?: string },
): Promise<Id<"users"> | undefined> {
  const token = args.sessionToken?.trim();
  if (token) {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q: any) => q.eq("token", token))
      .first();

    if (session && !session.revokedAt && session.expiresAt > Date.now()) {
      return session.userId;
    }
  }

  const deviceId = args.deviceId?.trim();
  if (deviceId) {
    const user = await ctx.db
      .query("users")
      .withIndex("by_deviceId", (q: any) => q.eq("deviceId", deviceId))
      .first();
    return user?._id;
  }

  return undefined;
}

function sanitizeMetadata(metadata: Array<{ key: string; value: string }> | undefined) {
  if (!metadata || metadata.length === 0) {
    return undefined;
  }

  return metadata
    .slice(0, MAX_METADATA_ITEMS)
    .map((item) => ({
      key: trimRequired(item.key, MAX_METADATA_KEY_LENGTH, "key"),
      value: trimRequired(item.value, MAX_METADATA_VALUE_LENGTH, ""),
    }));
}

function trimRequired(value: string, maxLength: number, fallback: string) {
  const trimmed = value.trim();
  const safe = trimmed.length > 0 ? trimmed : fallback;
  return safe.slice(0, maxLength);
}

function trimOptional(value: string | undefined, maxLength: number) {
  const trimmed = value?.trim();
  if (!trimmed) {
    return undefined;
  }
  return trimmed.slice(0, maxLength);
}
