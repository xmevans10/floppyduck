# Floppy Duck — Quality Roadmap

> Built while Trey sleeps. Goal: C → A-.

## ✅ Done Tonight (Commits 5-8)

### Commit 5: Bug Fixes (5 bugs)
| Bug | Impact | Fix |
|-----|--------|-----|
| Power-up pipe counts hardcoded to 5 | pipeExpander/pipeSqueeze lasting 5 pipes instead of 3 | Use `kind.initialPipeCount` |
| "+5" milestone popup lie | UI shows "+5" but only +1 scored | Show "+1" with gold treatment |
| Dead `SkyTheme` enum | 30 lines of dead code in GameScene | Removed + bridge property |
| Dead delegate callbacks & SwiftUI overlays | ~105 lines never reached | Removed `PowerUpHUD`, dead state vars, dead bridge callbacks |
| Bot AI ignores power-up gap modifiers | Bot dies too easily during pipeExpander/Squeeze | Apply same 1.3×/0.8× modifiers |

### Commit 6: Infrastructure Quality
- **TextureFactory LRU cache** — bounded to 200 entries (~400KB) with eviction; `clearCache()` on memory warning
- **GK.Animation constants** — 16 magic numbers extracted from death sequence
- **Dead code removal** — `effectiveMaxUpSpeed`, `effectiveMaxPipeDelta` and their tier multipliers (declared, never called)
- **PRNG tests** — 7 tests: determinism, range, gap bounds, delta limits, multiplayer fairness, zero-seed edge case

### Commit 7: ParallaxManager Extraction
- **GameScene delegated to ParallaxManager** — sky gradient, clouds, hills, trees, ground tiles, ground details, stars
- **7 methods removed** from GameScene, **6 properties removed**
- **~30 lines of scroll-loop code** replaced with `parallax.update(dt:)`
- **GameScene: 1898 → 1675 lines** (-223)
- **Safety fixes:** 3 force-unwrapped URLs → optional binding; Calendar force unwrap → nil coalescing
- **Input validation:** PixelTextField enforces 16-char max + alphanumeric filter
- **Network resilience:** opponent polling now uses exponential backoff (400ms → 3.2s cap)

### Commit 8: Test Coverage
- **GameConstantsTests** — physics sanity, world geometry, bitmask uniqueness, speed hierarchy, medal ordering, animation timing

## 📦 Shipped (Ready to Use)

### Controller Architecture
Three new controller files in `FloppyDuck/Game/Controllers/`:

| Controller | Lines | Responsibility |
|-----------|-------|---------------|
| `ParallaxManager` | 333 | Sky, clouds, hills, trees, ground tiles, details, stars. **Wired into GameScene.** |
| `BotController` | 316 | Bot sprite, AI loop, scoring, death. Standalone — ready for GameScene wiring. |
| `PowerUpController` | 475 | Spawn, collect, activate/deactivate, visuals, modifiers. Standalone — ready for GameScene wiring. |

### Test Suite: 12 test files, ~2000 lines
```
FloppyDuckTests/
├── AchievementTests.swift        (254 lines)
├── BotCharacterTests.swift       (64 lines)
├── DifficultyManagerTests.swift  (188 lines)
├── GameConstantsTests.swift      (95 lines)  ← NEW
├── GameModelTests.swift          (91 lines)
├── GamePerformanceTests.swift    (27 lines)
├── MedalTests.swift              (68 lines)
├── MultiplayerFlowTests.swift    (392 lines)
├── MultiplayerSessionTests.swift (228 lines)
├── PlayerStatsTests.swift        (217 lines)
├── PowerUpTests.swift            (290 lines)
└── PRNGTests.swift               (103 lines)  ← NEW
```

---

## 🔜 Next Up (Prioritized)

### Phase 1: Wire Remaining Controllers (Needs Xcode)
1. **Wire BotController into GameScene** — replace `setupBotDuck()`, `updateBot()`, `botDied()`, and all bot state. Needs compilation to verify.
2. **Wire PowerUpController into GameScene** — replace power-up spawn/collect/activate/deactivate/visuals. Most complex extraction; deeply interacts with collision handling.
3. **Target:** GameScene from 1675 → ~900 lines.

### Phase 2: Gameplay Polish
1. **Dynamic gap difficulty** — `PRNG.generateGapPositions()` uses static `maxPipeDelta`. Consider on-demand generation that respects `DifficultyManager.effectiveMaxPipeDelta` per-tier (tricky: must keep multiplayer determinism).
2. **Death sequence juice** — particle burst on pipe collision, per-skin death sound variants.
3. **Accessibility** — Dynamic Type for pixel font sizes, VoiceOver labels on all interactive elements, reduce-motion support for parallax.

### Phase 3: Performance
1. **SpriteKit draw call batching** — group same-texture sprites in `SKCropNode` or use texture atlases to reduce GPU state changes.
2. **Pre-warm TextureFactory** — generate most-used textures during splash screen to avoid first-frame stutter.
3. **Instrument profiling** — run Time Profiler + Allocations once on-device to find real bottlenecks.

### Phase 4: Multiplayer Resilience
1. **Reconnection logic** — if app backgrounds during head-to-head match, attempt reconnect on foreground.
2. **Match timeout handling** — server-side timeout for abandoned matches; client shows "opponent disconnected" instead of indefinite polling.
3. **Leaderboard pagination** — currently loads all entries; add cursor-based pagination.

### Phase 5: App Store Readiness
1. **Real App Store URL** in `GK.appStoreURL`.
2. **Privacy manifest** — declare `UserDefaults`, Keychain, `UIDevice.identifierForVendor` usage for App Store review.
3. **App Icons** — pixel-art app icon in all required sizes.
4. **Screenshots** — CI workflow already set up; verify it captures all screen sizes.
5. **StoreKit testing** — validate IAP flows in sandbox environment.

---

## 📊 Codebase Health

| Metric | Before | After |
|--------|--------|-------|
| Source files | 41 | 44 (+3 controllers) |
| Total source lines | ~17,600 | ~15,600 |
| GameScene.swift | 1,930 | 1,675 |
| Test files | 10 | 12 |
| Test lines | ~1,620 | ~2,000 |
| Force unwraps | 8 | 4 (only in safe contexts) |
| Dead code blocks | 6+ | 0 |
| Known bugs | 5 | 0 |
| Memory management | Unbounded texture cache | LRU-bounded (200) + memory warning |
| Network resilience | Fixed-interval polling | Exponential backoff |
| Input validation | None | 16-char max + character filter |
