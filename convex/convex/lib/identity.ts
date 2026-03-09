import { ConvexError } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import { defaultUserStats, upsertRating } from "./stats";

export type IdentityArgs = {
  deviceId?: string;
  sessionToken?: string;
};

type ResolveOptions = {
  requireLinked?: boolean;
  allowGuestFallback?: boolean;
};

export async function resolveUser(ctx: any,
                                  args: IdentityArgs,
                                  options: ResolveOptions = {}) {
  const now = Date.now();

  const token = args.sessionToken?.trim();
  if (token) {
    const session = await ctx.db
      .query("sessions")
      .withIndex("by_token", (q: any) => q.eq("token", token))
      .first();

    if (session && !session.revokedAt && session.expiresAt > now) {
      const user = await ctx.db.get(session.userId);
      if (user) {
        if (options.requireLinked && user.provider !== "apple") {
          throw new ConvexError("Ranked requires Sign in with Apple.");
        }
        return user;
      }
    }
  }

  if (options.requireLinked) {
    throw new ConvexError("Sign in required.");
  }

  const deviceId = args.deviceId?.trim();
  if (!deviceId) {
    throw new ConvexError("Missing device identity.");
  }

  let user = await ctx.db
    .query("users")
    .withIndex("by_deviceId", (q: any) => q.eq("deviceId", deviceId))
    .first();

  if (!user && options.allowGuestFallback !== false) {
    const stats = defaultUserStats();
    const userId: Id<"users"> = await ctx.db.insert("users", {
      deviceId,
      username: "Player",
      provider: "guest",
      ...stats,
      createdAt: now,
      updatedAt: now,
    });

    await upsertRating(ctx, userId, stats.rating, now);
    user = await ctx.db.get(userId);
  }

  if (!user) {
    throw new ConvexError("Unable to resolve user identity.");
  }

  return user;
}

export async function findUserByAppleId(ctx: any, appleUserId: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_appleUserId", (q: any) => q.eq("appleUserId", appleUserId))
    .first();
}

export async function findUserByDeviceId(ctx: any, deviceId: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_deviceId", (q: any) => q.eq("deviceId", deviceId))
    .first();
}

export function parseAppleClaims(identityToken: string) {
  const segments = identityToken.split(".");
  if (segments.length < 2) {
    throw new ConvexError("Invalid Apple identity token.");
  }

  const payloadSegment = segments[1];
  const base64 = payloadSegment.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "===".slice((base64.length + 3) % 4);

  let json: string;
  try {
    if (typeof atob === "function") {
      json = atob(padded);
    } else if ((globalThis as any).Buffer) {
      json = (globalThis as any).Buffer.from(padded, "base64").toString("utf8");
    } else {
      throw new Error("Base64 decoding unavailable.");
    }
  } catch {
    throw new ConvexError("Invalid Apple identity token payload.");
  }

  let payload: any;
  try {
    payload = JSON.parse(json);
  } catch {
    throw new ConvexError("Invalid Apple identity token payload.");
  }

  const sub = typeof payload.sub === "string" ? payload.sub : undefined;
  if (!sub) {
    throw new ConvexError("Apple token missing subject.");
  }

  if (payload.exp && Number.isFinite(payload.exp)) {
    const expiresAtMs = Number(payload.exp) * 1000;
    if (expiresAtMs <= Date.now()) {
      throw new ConvexError("Apple identity token expired.");
    }
  }

  return {
    sub,
    email: typeof payload.email === "string" ? payload.email : undefined,
    nonce: typeof payload.nonce === "string" ? payload.nonce : undefined,
    iss: typeof payload.iss === "string" ? payload.iss : undefined,
    aud: typeof payload.aud === "string" ? payload.aud : undefined,
  };
}

export function mustBeParticipant(match: Doc<"matches">, userId: Id<"users">) {
  if (match.p1UserId !== userId && match.p2UserId !== userId) {
    throw new ConvexError("You are not part of this match.");
  }
}

export function userSide(match: Doc<"matches">, userId: Id<"users">) {
  return match.p1UserId === userId ? "p1" : "p2";
}
