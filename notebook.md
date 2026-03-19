# Floppy Duck — AI Agent Context Notebook

> Context document for AI agents working on this codebase. Designed to port
> knowledge between sessions without re-reading every file.

---

## Architecture Overview

### Project Structure
```
FloppyDuck/
├── App/                    # App entry point, AppDelegate
├── Game/
│   ├── GameScene.swift     # Main SpriteKit scene (~1300 lines, refactored)
│   ├── GameConstants.swift # All magic numbers live here (GK enum)
│   ├── DifficultyManager   # Logarithmic difficulty curve, no discrete jumps
│   ├── PowerUp.swift       # PowerUpKind enum + ActivePowerUp struct + PowerUpSpawnManager
│   └── Controllers/
│       ├── ParallaxManager  # Sky, clouds, hills, trees, ground tiles, details, stars
│       ├── BotController    # Bot AI: sprite, per-frame update, scoring, death
│       └── PowerUpController# Power-up lifecycle: spawn, collect, activate, visuals, modifiers
├── Models/
│   └── GameModels.swift    # GameMode, PlayerStats, Medal, Auth, Multiplayer types
├── Views/                  # SwiftUI views (menus, overlays, shop, stats, etc.)
├── Services/               # Networking, auth, sound, haptics, persistence
└── Textures/               # PixelIconFactory, TextureFactory (procedural pixel art)
```

### Key Design Pattern: Controller Extraction
GameScene was 1778 lines. We've extracted three controllers that own their
respective domain logic:

| Controller | Owns | GameScene reads via |
|-----------|------|-------------------|
| `ParallaxManager` | All scrolling background layers | `parallax.update(dt:)` |
| `BotController` | Bot sprite, AI, score HUD | `botController?.update(...)`, `botController?.score` |
| `PowerUpController` | Power-up spawn/collect/activate/visuals | `powerUpCtrl.effectiveGravity`, `.effectivePipeSpeed`, etc. |

Controllers receive unowned/weak references to scene nodes (worldNode, pipeLayer,
duck, hudLayer). GameScene creates them in `didMove(to:)` and calls their update
methods each frame.

### Data Flow
```
GameScene.update()
  ├─ powerUpCtrl.update(dt, currentTime)   // tick expirations + speed modifier
  ├─ Read: powerUpCtrl.effectiveGravity     // apply to physicsWorld
  ├─ Read: powerUpCtrl.effectivePipeSpeed   // drive pipe movement
  ├─ powerUpCtrl.applyGhostAlpha()          // visual effect
  ├─ powerUpCtrl.applyBreadMagnetEffect()   // attract bread if active
  ├─ parallax.update(dt)                    // scroll decorative layers
  └─ botController?.update(dt, pipeNodes, activePowerUps, effectivePipeGap)
```

### Collision Flow
```
didBegin(contact:)
  ├─ Bread → collectBread() (stays in GameScene — bread is game mechanic)
  ├─ Score trigger → difficulty.update(), powerUpCtrl.onPipeScored()
  ├─ Power-up → powerUpCtrl.collectPowerUp()
  ├─ Ghost active? → count ghostPipesPhased, skip
  ├─ Shield active? → powerUpCtrl.consumeShield()
  └─ Otherwise → die()
```

---

## Design Decisions & Why

### Why controllers instead of ECS or protocol composition?
Trey is a solo dev. Controllers with clear ownership boundaries are the simplest
pattern that scales to this codebase size. Each controller is one file, one
responsibility, easy to test in isolation. No framework overhead.

### Why `unowned` for node references?
The scene owns all nodes. Controllers never outlive the scene. `unowned` avoids
retain cycles without the overhead of `weak` optionals for nodes we know exist.
`weak` is used only for `duck` (which gets reparented during death).

### Why no SKActions for pipe movement?
Pipes, bread, and all pipeLayer children move via direct position updates in
`update()` (`child.position.x -= dx`). This means speed changes from difficulty
ramp or power-ups apply instantly to ALL nodes. SKActions would bake a fixed speed
at spawn time.

### Why seeded PRNG for gap positions?
Multiplayer fairness. Both players in head-to-head get the same seed → same gap
positions. Gaps are pre-generated (200 positions) to avoid mid-game divergence.

### Speed modifier grace period
When slowMotion or speedBurst expires, the game doesn't snap back to 1.0x speed.
Instead, `PowerUpController.speedModifier` lerps back at 0.25/s. This prevents
the jarring "everything just sped up" feeling. Ramping ON is fast (2.0/s) so the
effect feels immediate.

### Power-up spawning: free-floating between pipes
Power-up collectibles are spawned as standalone nodes in pipeLayer, positioned
randomly in the space between pipes. The positioning logic lives in GameScene
(via `spawnPowerUpCollectible` + `makePowerUpCollectible`) because it needs pipe
layout context. PowerUpController owns the lifecycle (activation, effects, expiry)
via `consumePendingKind()` which provides the kind and clears the pending slot.

### DizzyDuck velocity flip
When dizzyDuck activates or deactivates, the duck's velocity is flipped (×0.85,
clamped to ±maxUpSpeed) and its Y position is clamped to safe bounds. This
prevents instant death from being at the wrong screen edge when gravity inverts.
The transition logic lives in PowerUpController.applyDizzyTransition().

### Achievement tracking stays in GameScene
`shieldsUsed`, `ghostPipesPhased`, `magnetBreadCollected`, `debuffScoreAtStart` —
these are game-session metrics that cross controller boundaries. GameScene tracks
them via callbacks (`onPowerUpCollected`, `onShieldConsumed`) rather than coupling
controllers to achievement logic.

### Power-up label parent override
Power-up collected labels (`"SHIELD"`, `"GHOST"`, etc.) are added to the scene
root instead of worldNode. This prevents them from shaking during the death screen
shake animation. The `labelParentOverride` property on PowerUpController enables
this without the controller needing to know about scene hierarchy.

### Death duck reparenting
During death, the duck sprite is moved from worldNode to the scene root. This
ensures the camera zoom and screen shake on worldNode don't move the duck
sideways during its scripted fall. The duck is reparented back in `resetGame()`.

### Reduce-motion accessibility
`ParallaxManager.update()` checks `UIAccessibility.isReduceMotionEnabled`. When
enabled, decorative layers (clouds, hills, trees) stop scrolling. Ground tiles
and details always scroll because they provide gameplay-relevant motion cues.

---

## Gotchas & Pitfalls

### 1. Duck horizontal drift
The duck's collisionBitMask must be `GK.groundCategory` ONLY. If pipe collision
is enabled, SpriteKit's physics resolution pushes the duck leftward over time.
Pipe contacts are detected via `contactTestBitMask` + `didBegin()`, not physical
collision. There's also a position clamp in `update()` as a safety net.

### 2. Ghost duck collision mask
When ghostDuck activates, `PowerUpController.activateGhostDuck()` changes the
duck's `contactTestBitMask` to exclude pipes. When it deactivates, the mask is
restored. If the duck dies while ghost is active, `cleanupDuckVisuals()` restores
alpha but does NOT restore the collision mask — that happens in `resetGame()` when
the entire physics body is rebuilt.

### 3. Shield cooldown window
After a shield absorbs a hit, there's a 0.5s cooldown where `isShieldOnCooldown`
returns true. During this window, additional pipe contacts are ignored. Without
this, the duck would die on the very next frame from the same pipe.

### 4. BotController gap modifiers
`BotController.update()` takes `activePowerUps` and `effectivePipeGap` separately.
It applies gap modifiers (pipeExpander/pipeSqueeze) internally — pass the BASE
`difficulty.effectivePipeGap`, not `powerUpCtrl.effectivePipeGap` (which already
includes modifiers). Passing the modified gap would double-apply the multipliers.

### 5. PowerUpController duck reference
The duck sprite uses a `weak` reference in PowerUpController. After `resetGame()`,
the physics body is rebuilt but the sprite node is reused. Call
`powerUpCtrl.setDuck(duck)` after resetting the physics body to ensure the
reference is fresh (the weak ref should survive, but this is defensive).

### 6. Death particle timing
`spawnDeathParticles()` is called BEFORE the duck is reparented to scene root.
Particles are added to worldNode, so they shake with the screen shake effect.
This is intentional — it looks better when the particles scatter with the shake.

### 7. Score trigger nodes
Score triggers are child nodes of pipe containers, positioned at the gap center.
They're removed from parent on contact (`removeFromParent()`), which prevents
double-scoring. The bot's scoring system uses a `pipesPassed: Set<String>` keyed
on pipe node names instead.

### 8. TextureFactory cache
LRU-bounded to 200 entries (~400KB). Eviction runs on `didReceiveMemoryWarning`.
First-frame stutter can occur if textures aren't pre-warmed — see ROADMAP Phase 3.

---

## What's Been Done

### Controller Wiring (This Commit)
- ✅ BotController wired into GameScene (replaced ~165 lines of inline bot logic)
- ✅ PowerUpController wired into GameScene (replaced ~350 lines of inline power-up logic)
- ✅ Speed modifier grace period moved to PowerUpController
- ✅ DizzyDuck velocity transition moved to PowerUpController
- ✅ Death particle burst (12-15 pixel particles in duck palette colors)
- ✅ Reduce-motion accessibility in ParallaxManager
- ✅ GameScene: 1778 → ~1300 lines (-27%)

### Launch Polish (This Commit)
- ✅ LeaderboardView: pull-to-refresh (`.refreshable`), auto-scroll to current player row (`ScrollViewReader`), smart loading (spinner only on first load)
- ✅ Accessibility labels across 5 views: LeaderboardView, ShopView, BotLadderView, AchievementsView, StatsView
- ✅ Already done (discovered pre-existing): TextureFactory pre-warm (in SplashView), per-skin death sounds (in SoundManager)

### Previous Commits
- Bug fixes (stat timing, head-to-head results, 4 gameplay issues, 5 visual bugs)
- Infrastructure (TextureFactory LRU cache, GK.Animation constants, dead code removal)
- ParallaxManager extraction (7 methods, 6 properties out of GameScene)
- Power-up spawning repositioned (free-floating between pipes instead of on pipes)
- DizzyDuck velocity transitions (smooth activation/deactivation)
- Test coverage (12 test files, ~2000 lines, PRNG + GameConstants tests)

---

## What's Next (from ROADMAP.md)

1. **Dynamic gap difficulty** — PRNG generates static gaps; could vary maxPipeDelta
   per difficulty tier (must preserve multiplayer determinism)
2. **Per-skin death sounds** — SoundManager already has skin awareness
3. **Accessibility** — Dynamic Type for pixel font, VoiceOver labels on all
   interactive elements (reduce-motion is now done)
4. **SpriteKit draw call batching** — texture atlases to reduce GPU state changes
5. **Pre-warm TextureFactory** — generate common textures during splash screen
6. **Multiplayer reconnection** — handle app backgrounding during matches
7. **App Store readiness** — real App Store URL, privacy manifest, app icons

---

## Trey's Preferences & Communication Style

- Solo iOS developer. Writes clean Swift, likes pixel art aesthetic.
- Prefers direct pushes to main (no PR ceremony for a solo project).
- Values thorough commit messages and documentation.
- Appreciates when changes are explained with context (the "why", not just "what").
- Uses ROADMAP.md as the source of truth for priorities.
- Likes controller extraction pattern — clean separation but no over-engineering.
- Tests are important but pragmatic — test behavior, not implementation details.
- Git email: `viktor-ai@users.noreply.github.com` for AI-authored commits.

---

## File Quick Reference

| File | Lines | Key exports |
|------|-------|-------------|
| `GameScene.swift` | ~1300 | `GameScene`, `GamePhase`, `GameSceneDelegate` |
| `GameConstants.swift` | ~110 | `GK` enum (all constants, collision masks, colors) |
| `DifficultyManager.swift` | ~100 | `DifficultyTier`, `DifficultyManager` |
| `PowerUp.swift` | ~220 | `PowerUpKind`, `ActivePowerUp`, `PowerUpSpawnManager` |
| `BotController.swift` | ~316 | `BotController` |
| `PowerUpController.swift` | ~550 | `PowerUpController` |
| `ParallaxManager.swift` | ~345 | `ParallaxManager` |
| `GameModels.swift` | ~350 | `GameMode`, `PlayerStats`, `Medal`, multiplayer types |
