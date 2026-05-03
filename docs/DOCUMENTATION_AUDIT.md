# Documentation Audit

Audited May 3, 2026. This file tracks current documentation health, stale
claims, and recommended cleanup order.

## Executive Summary

The documentation is useful but fragmented. Launch, product, growth, support,
tracking, and art notes all exist, but several files disagree with the current
codebase and with each other. The highest-risk issue is not missing docs; it is
stale docs that look canonical.

Most urgent cleanup themes:

- choose one canonical art pipeline and mark the older pipeline docs as archived
- reconcile IAP inventory across code, StoreKit config, metadata, and review
  notes
- remove or quarantine narrative docs that describe old capabilities or old agent
  constraints
- add a short top-level docs map so future agents know which files are canonical

## Current Documentation Map

Canonical or close to canonical:

- `README.md` - repo overview and source-of-truth pointers
- `testflight.md` - launch-readiness runbook
- `docs/APPSTORE_METADATA.md` - App Store copy and IAP inventory draft
- `ARTWORK.md` - current intended art direction, though it needs runtime-path
  reconciliation
- `prompts/README.md` and `prompts/*.md` - current hero prompt format
- `tracking.md` - analytics plan and PostHog implementation notes
- `AUTH_SETUP.md` and `convex/README.md` - auth/backend setup notes

Archived:

- `LAUNCH_CHECKLIST.md`
- `RELEASE_CHECKLIST.md`

Useful but strategic/playbook style:

- `product.md`
- `marketing.md`
- `growth.md`
- `monetization.md`
- `support.md`
- `research.md`

Needs cleanup or archival:

- `PROCESS.md`
- `notebook.md`
- `docs/ADDING_THEMES.md`
- `tools/pixel_art_engine/README.md`
- `docs/CI_MULTI_DEVICE_SCREENSHOTS.md`

## Findings

### 1. Art Pipeline Docs Conflict

`ARTWORK.md` says the direction is one generated hero image plus deterministic
runtime overlays. `tools/pixel_art_engine/README.md` describes a separate
GPT Image 2 multi-layer pipeline with nine generated layers per theme.
`docs/ADDING_THEMES.md` describes adding procedural renderers in
`TextureFactory`. Current runtime code is recipe-driven through
`ThemeRecipeCatalog` and `ParallaxManager`.

Impact: theme work can easily happen through the wrong path. This already caused
confusion during QA rendering because filesystem/generated previews did not match
the SpriteKit runtime path.

Recommended action:
- make `ARTWORK.md` explicitly name `ThemeRecipeCatalog` and `ParallaxManager`
  as the current runtime path
- archive `tools/pixel_art_engine/README.md` unless that tool is still active
- rewrite `docs/ADDING_THEMES.md` around `BackgroundTheme`,
  `ThemeRecipeCatalog`, asset catalogs, and SpriteKit QA renders

### 2. IAP Inventory Is Inconsistent

`docs/APPSTORE_METADATA.md` lists 10 products in its table: 3 skins, 2 themes,
3 pipe skins, and 2 banners. The same file later says "IN-APP PURCHASES
(7 Non-Consumable)" and lists only 3 skins, 2 backgrounds, and 2 banners.
`testflight.md` also says all 7 premium products are registered. The local
StoreKit config at `FloppyDuck/Config/FloppyDuckProducts.storekit` contains
7 product IDs and does not include premium pipe skin products.

Impact: App Review notes, App Store Connect setup, and local StoreKit testing can
drift. This is release-blocking if premium pipe skins are visible in-app but not
registered, or if the metadata promises products that are absent from StoreKit.

Recommended action:
- decide whether premium pipe skins ship in the first release
- make StoreKit config, App Store metadata, review notes, and visible shop
  inventory match that decision exactly
- update `monetization.md` after the decision

### 3. App Store Copy Overstates Asset Provenance

`docs/APPSTORE_METADATA.md` says every visual/audio asset is generated from code
and that there are no borrowed sprites. Current code references Juhani Junkala
CC0 music packs, `THIRD_PARTY_ASSETS.md` tracks an imported CC0 birds sprite, and
the current art workflow uses generated/imported PNGs in asset catalogs.

Impact: product copy can become inaccurate and potentially risky during review or
public launch.

Recommended action:
- soften the copy to "retro pixel-art style with code-generated effects and
  carefully curated assets"
- keep third-party asset provenance in `THIRD_PARTY_ASSETS.md`
- avoid claims that every visual and sound is code-generated unless the repo
  actually returns to that model

### 4. `PROCESS.md` Is Historical And Stale

`PROCESS.md` describes early development, old constraints, and future plans such
as Supabase/Firebase multiplayer. The current backend is Convex, and the current
environment can run Xcode/simulator commands in many cases. It also presents a
personal narrative rather than current engineering guidance.

Impact: future agents can absorb outdated assumptions.

Recommended action:
- move this under an `archive/` folder or add a strong "historical, not current
  engineering docs" banner at the top
- remove it from any source-of-truth path

### 5. `notebook.md` Mixes Architecture, Reflections, And Old Roadmap

`notebook.md` is valuable for context but too large and mixed-purpose. It includes
architecture notes, gotchas, old "this commit" summaries, and historical
reflections. Some sections are still useful; others duplicate `ROADMAP.md`,
`testflight.md`, and current code comments.

Impact: high chance of stale context being mistaken for current state.

Recommended action:
- split durable architecture/gotchas into `docs/ARCHITECTURE.md`
- move historical reflections to archive
- keep `notebook.md` as a short pointer file or remove it from the main docs map

### 6. CI Screenshot Docs Are Probably Stale

`docs/CI_MULTI_DEVICE_SCREENSHOTS.md` says to manually update CI to a screenshot
matrix. `.github/workflows/ci.yml` still uses a single `iPhone 16 Pro` screenshot
job. The doc may still be a valid proposal, but it should be labeled as pending
and linked from `testflight.md` only if it is still planned.

Impact: screenshot readiness may be overestimated.

Recommended action:
- either implement the matrix or rename the file to make clear it is a proposal
- update `testflight.md` to state the actual screenshot CI state

### 7. README Status Date Is Stale

`README.md` says "Current Status (April 2, 2026)" while `testflight.md` says
Updated April 13, 2026 and the current audit date is May 3, 2026.

Impact: small, but it weakens trust in the top-level overview.

Recommended action:
- replace date-specific status with "Current Status" plus links to canonical
  status files
- keep launch state in `testflight.md`

### 8. Pixelorama Needs Provenance Tracking

Pixelorama is now intentionally tracked as a reference submodule. It is not app
runtime code and should not be treated as an imported asset pack.

Impact: without a usage note, future agents may try to integrate it directly or
commit build outputs.

Recommended action:
- keep `docs/PIXELORAMA.md` as the usage tracker
- if any Pixelorama assets are copied into the app, add them to
  `THIRD_PARTY_ASSETS.md`
- keep Pixelorama out of Xcode until a specific integration is chosen

## Recommended Cleanup Order

1. Fix the IAP inventory mismatch in `docs/APPSTORE_METADATA.md`,
   `testflight.md`, `monetization.md`, StoreKit config, and visible shop state.
2. Rewrite the theme docs around the current recipe-driven SpriteKit render path.
3. Mark `PROCESS.md`, old parts of `notebook.md`, and old pipeline docs as
   historical or archive them.
4. Update `README.md` to point to a canonical docs map instead of restating
   fast-moving launch status.
5. Decide whether to implement or archive the CI screenshot matrix proposal.
6. Add a lightweight `docs/README.md` index after the above cleanup so future
   contributors know what is canonical.

## Verification Notes

This audit used local source inspection only. No App Store Connect, PostHog,
GitHub Actions run history, or Convex deployment state was queried. Treat portal
state and production analytics as unverified until checked directly.

