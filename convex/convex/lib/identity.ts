import { ConvexError } from "convex/values";
import type { Doc, Id } from "../_generated/dataModel";
import { defaultUserStats, upsertRating } from "./stats";

const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const DEFAULT_APPLE_AUDIENCE = "com.xmevans10.FloppyDuck";
const APPLE_KEY_CACHE_TTL_MS = 1000 * 60 * 60;

export type IdentityArgs = {
  deviceId?: string;
  sessionToken?: string;
};

type AppleClaimsPayload = {
  sub: string;
  email?: string;
  nonce?: string;
  iss?: string;
  aud?: string | string[];
  exp?: number;
};

type AppleJwtHeader = {
  alg?: string;
  kid?: string;
};

type AppleJwk = JsonWebKey & {
  kid?: string;
};

type AppleClaims = {
  sub: string;
  email?: string;
  nonce?: string;
  iss?: string;
  aud?: string | string[];
};

let cachedAppleKeys:
  | {
    expiresAt: number;
    keysByKid: Map<string, AppleJwk>;
  }
  | null = null;

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
        if (options.requireLinked && user.provider !== "apple" && user.provider !== "gameCenter") {
          throw new ConvexError("Ranked requires Game Center sign in.");
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

export async function findUserByGameCenterPlayerId(ctx: any, gameCenterPlayerId: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_gameCenterPlayerId", (q: any) => q.eq("gameCenterPlayerId", gameCenterPlayerId))
    .first();
}

export async function findUserByDeviceId(ctx: any, deviceId: string) {
  return await ctx.db
    .query("users")
    .withIndex("by_deviceId", (q: any) => q.eq("deviceId", deviceId))
    .first();
}

export async function verifyAppleIdentityToken(identityToken: string, rawNonce: string): Promise<AppleClaims> {
  if (!rawNonce.trim()) {
    throw new ConvexError("Missing Apple nonce.");
  }

  const { header, payload, signatureInput, signatureBytes } = parseJwt(identityToken);

  const kid = typeof header.kid === "string" ? header.kid : "";
  const alg = typeof header.alg === "string" ? header.alg : "";
  if (!kid || alg !== "RS256") {
    throw new ConvexError("Invalid Apple identity token.");
  }

  const key = await getAppleSigningKey(kid);
  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    key,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"],
  );
  const signatureIsValid = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    signatureBytes,
    signatureInput,
  );
  if (!signatureIsValid) {
    throw new ConvexError("Invalid Apple identity token signature.");
  }

  const sub = typeof payload.sub === "string" ? payload.sub : undefined;
  if (!sub) {
    throw new ConvexError("Apple token missing subject.");
  }

  if (typeof payload.exp === "number") {
    const expiresAtMs = payload.exp * 1000;
    if (expiresAtMs <= Date.now()) {
      throw new ConvexError("Apple identity token expired.");
    }
  }

  if (typeof payload.iss !== "string" || payload.iss !== APPLE_ISSUER) {
    throw new ConvexError("Invalid Apple token issuer.");
  }

  const expectedAudiences = getExpectedAppleAudiences();
  const tokenAudiences = normalizeAudiences(payload.aud);
  if (!tokenAudiences.some((audience) => expectedAudiences.has(audience))) {
    throw new ConvexError("Invalid Apple token audience.");
  }

  if (typeof payload.nonce !== "string" || !payload.nonce) {
    throw new ConvexError("Apple token missing nonce.");
  }

  const expectedNonceHash = await sha256Hex(rawNonce.trim());
  if (payload.nonce.toLowerCase() != expectedNonceHash) {
    throw new ConvexError("Apple nonce mismatch.");
  }

  return {
    sub,
    email: typeof payload.email === "string" ? payload.email : undefined,
    nonce: typeof payload.nonce === "string" ? payload.nonce : undefined,
    iss: typeof payload.iss === "string" ? payload.iss : undefined,
    aud: typeof payload.aud === "string" || Array.isArray(payload.aud) ? payload.aud : undefined,
  };
}

function parseJwt(identityToken: string): {
  header: AppleJwtHeader;
  payload: AppleClaimsPayload;
  signatureInput: Uint8Array;
  signatureBytes: Uint8Array;
} {
  const segments = identityToken.split(".");
  if (segments.length !== 3) {
    throw new ConvexError("Invalid Apple identity token.");
  }

  const [headerSegment, payloadSegment, signatureSegment] = segments;
  const header = decodeJwtSegment<AppleJwtHeader>(headerSegment, "header");
  const payload = decodeJwtSegment<AppleClaimsPayload>(payloadSegment, "payload");
  const signatureInput = new TextEncoder().encode(`${headerSegment}.${payloadSegment}`);
  const signatureBytes = decodeBase64Url(signatureSegment, "signature");

  return { header, payload, signatureInput, signatureBytes };
}

function decodeJwtSegment<T>(segment: string, partName: string): T {
  const bytes = decodeBase64Url(segment, partName);
  let json: string;

  try {
    json = new TextDecoder().decode(bytes);
  } catch {
    throw new ConvexError(`Invalid Apple identity token ${partName}.`);
  }

  try {
    return JSON.parse(json) as T;
  } catch {
    throw new ConvexError(`Invalid Apple identity token ${partName}.`);
  }
}

function decodeBase64Url(segment: string, partName: string): Uint8Array {
  const base64 = segment.replace(/-/g, "+").replace(/_/g, "/");
  const padded = base64 + "===".slice((base64.length + 3) % 4);

  try {
    if (typeof atob === "function") {
      const binary = atob(padded);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i += 1) {
        bytes[i] = binary.charCodeAt(i);
      }
      return bytes;
    }
    if ((globalThis as any).Buffer) {
      return (globalThis as any).Buffer.from(padded, "base64");
    }
  } catch {
    throw new ConvexError(`Invalid Apple identity token ${partName}.`);
  }

  throw new ConvexError("Base64 decoding unavailable.");
}

async function getAppleSigningKey(kid: string): Promise<AppleJwk> {
  const now = Date.now();
  if (!cachedAppleKeys || cachedAppleKeys.expiresAt <= now) {
    cachedAppleKeys = await fetchAppleSigningKeys();
  }

  const cached = cachedAppleKeys.keysByKid.get(kid);
  if (cached) {
    return cached;
  }

  // Retry immediately in case Apple rotated keys after cache fill.
  cachedAppleKeys = await fetchAppleSigningKeys();
  const rotated = cachedAppleKeys.keysByKid.get(kid);
  if (rotated) {
    return rotated;
  }

  throw new ConvexError("Unknown Apple signing key.");
}

async function fetchAppleSigningKeys(): Promise<{ expiresAt: number; keysByKid: Map<string, AppleJwk> }> {
  const response = await fetch(APPLE_JWKS_URL);
  if (!response.ok) {
    throw new ConvexError("Failed to load Apple signing keys.");
  }

  const body = (await response.json()) as { keys?: AppleJwk[] };
  const keysByKid = new Map<string, AppleJwk>();

  for (const key of body.keys ?? []) {
    const kid = typeof key.kid === "string" ? key.kid : "";
    if (kid) {
      keysByKid.set(kid, key);
    }
  }

  if (!keysByKid.size) {
    throw new ConvexError("No Apple signing keys available.");
  }

  return {
    expiresAt: Date.now() + APPLE_KEY_CACHE_TTL_MS,
    keysByKid,
  };
}

function getExpectedAppleAudiences(): Set<string> {
  const fromEnv = ((globalThis as any).process?.env?.APPLE_EXPECTED_AUDIENCES as string | undefined) ?? "";
  const audiences = fromEnv
    .split(",")
    .map((value) => value.trim())
    .filter((value) => value.length > 0);

  if (!audiences.length) {
    return new Set([DEFAULT_APPLE_AUDIENCE]);
  }

  return new Set(audiences);
}

function normalizeAudiences(aud: string | string[] | undefined): string[] {
  if (typeof aud === "string") {
    return [aud];
  }
  if (Array.isArray(aud)) {
    return aud.filter((value): value is string => typeof value === "string");
  }
  return [];
}

async function sha256Hex(input: string): Promise<string> {
  const hash = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return Array.from(new Uint8Array(hash))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export function mustBeParticipant(match: Doc<"matches">, userId: Id<"users">) {
  if (match.p1UserId !== userId && match.p2UserId !== userId) {
    throw new ConvexError("You are not part of this match.");
  }
}

export function userSide(match: Doc<"matches">, userId: Id<"users">) {
  return match.p1UserId === userId ? "p1" : "p2";
}
