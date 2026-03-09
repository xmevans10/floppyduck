# Convex Backend

This directory contains the Floppy Duck backend contracts used by the iOS client.

## Setup

1. Install dependencies:
   npm install
2. Authenticate and run dev backend:
   npx convex dev
3. Deploy:
   npx convex deploy

## Endpoints implemented

- `auth:bootstrapGuest`
- `auth:linkApple`
- `auth:getProfile`
- `auth:signOutSession`
- `matchmaking:joinQueue`
- `matchmaking:leaveQueue`
- `matchmaking:checkQueue`
- `matchmaking:createRoom`
- `matchmaking:joinRoom`
- `matchmaking:leaveRoom`
- `matchmaking:checkRoom`
- `matches:reportScore`
- `matches:getState`
- `matches:finishMatch`
- `ratings:leaderboard`

## Notes

- Ranked access is restricted to Apple-linked users.
- ELO updates use K=32.
- Apple token verification validates token shape and claims. Add cryptographic signature verification before production launch.
