# Floppy Duck Tracking Plan

## Objective

Measure activation, retention, monetization, and feature adoption while preserving the game's current privacy-first stance.

## Constraints

- Do not assume ATT, ad attribution, or tracking domains.
- Keep any future event plan aligned with the current privacy manifest.
- Only add data collection that improves product decisions enough to justify the compliance surface area.

## Core KPIs

- installs to first launch
- first launch to first game started
- first game started to first game completed
- session count per user
- day-1, day-7, day-30 retention
- shop visit rate
- purchase tap rate
- purchase completion rate
- purchase restore rate
- multiplayer participation rate
- bot ladder participation and completion rate

## Event Taxonomy — Prioritized

### Launch-Critical (12 events) — Wired in v1

These events are needed to understand first-session retention and IAP conversion from day one.

| Event | Properties | Where Fired |
|-------|-----------|-------------|
| `app_open` | — | `FloppyDuckApp.init()` |
| `onboarding_completed` | `method` (guest/apple) | `AuthManager` — first auth choice only |
| `guest_bootstrap_succeeded` | — | `AuthManager.continueAsGuest()` |
| `apple_sign_in_started` | — | `AuthManager.signInWithApple()` |
| `apple_sign_in_succeeded` | — | `AuthManager.signInWithApple()` success |
| `game_started` | `mode`, `seed`, `is_ranked` | `GameManager.startGame()` |
| `game_completed` | `mode`, `score`, `won` | `GameManager.recordGame()` |
| `mode_selected` | `mode` | `GameManager.navigate()` |
| `shop_viewed` | — | `GameManager.navigate(.shop)` |
| `iap_purchase_started` | `product_id`, `item_type` | `SkinManager/ThemeManager/BannerManager` |
| `iap_purchase_completed` | `product_id`, `item_type` | `SkinManager/ThemeManager/BannerManager` |
| `iap_restore_completed` | `item_type`, `items_restored` | `SkinManager/ThemeManager/BannerManager` |

### Post-Launch (12 events) — Also Wired in v1

These provide deeper insight into competitive and cosmetic engagement. All wired up but lower priority for dashboard focus.

| Event | Properties | Where Fired |
|-------|-----------|-------------|
| `bot_match_started` | `bot_id`, `bot_name`, `target_score` | `GameManager.startBotLadderMatch()` |
| `bot_match_completed` | `bot_id`, `won`, `score` | `GameManager.beatBot()` |
| `multiplayer_queue_started` | `mode` | `GameManager.startMatchmaking()` |
| `multiplayer_match_found` | `mode` | `GameManager.startHeadToHead()` |
| `multiplayer_match_finished` | `mode`, `won`, `score`, `opponent_score` | `GameManager.applyMatchResult()` |
| `item_viewed` | `item_type`, `item_id` | Not yet wired — no detail screen exists |
| `skin_equipped` | `skin_id` | `SkinManager.select()` |
| `theme_equipped` | `theme_id` | `ThemeManager.select()` |
| `banner_equipped` | `banner_id` | `BannerManager.select()` |
| `stats_viewed` | — | `GameManager.navigate(.stats)` |
| `leaderboard_viewed` | — | `GameManager.navigate(.leaderboard)` |
| `share_sheet_opened` | `mode`, `score` | Not yet wired — needs ShareCardView hook |

## Implementation Details

### SDK Integration
- **PostHog iOS SDK** v3.x via Swift Package Manager
- Initialized in `FloppyDuckApp.init()` after Sentry
- API key: project "Default project" (id: 252715)
- Host: `https://us.i.posthog.com`
- Debug mode enabled for DEBUG builds

### Architecture
- `AnalyticsManager.swift` in `FloppyDuck/Services/` — singleton wrapper
- All events use `PostHogSDK.shared.capture()` under the hood
- User identification via `PostHogSDK.shared.identify()` on Apple sign-in
- Most events fire from `GameManager` (central coordinator) to minimize view-level changes
- IAP events fire from the three StoreKit managers (Skin/Theme/Banner)

### Privacy
- `PrivacyInfo.xcprivacy` updated with `NSPrivacyCollectedDataTypeProductInteraction` (Analytics purpose)
- No ATT required — all events are behavioral analytics
- NSPrivacyTracking remains `false`
- No tracking domains added

## Funnel Model

- Acquisition funnel: listing view -> install -> first launch
- Activation funnel: first launch -> first game -> second game -> same-day return
- Monetization funnel: shop view -> product tap -> purchase start -> purchase complete
- Competitive funnel: multiplayer entry -> queue start -> match found -> match finish -> ranked repeat

## Dashboard Requirements

- daily active users
- new users versus returning users
- conversion by mode
- IAP conversion by product family
- retention cohort view
- failure dashboard for auth, matchmaking, and purchase flows

## If You Are an AI Agent

### Weekly

- report the top movement in activation, retention, and monetization
- identify one broken funnel and one healthy funnel
- recommend one instrumentation change only if it unlocks a real decision

### Before launch

- verify the proposed event list does not require ATT or contradict the privacy manifest
- flag any gaps that would block understanding first-session retention or IAP conversion

### After launch

- publish a one-page weekly metrics memo with anomalies, hypotheses, and next actions

### Maintaining This Integration

- All analytics calls go through `AnalyticsManager.shared` — never call `PostHogSDK` directly
- To add a new event: add a typed method to `AnalyticsManager.swift`, call it from the appropriate coordinator
- The two unwired events (`item_viewed`, `share_sheet_opened`) need view-level hooks when those UIs are built
- PostHog project: org "Forked", project "Default project" (id: 252715)
- MCP tools for querying: `sdk/tools/mcp_posthog.py` (trends, funnels, retention queries)

## Outputs

- weekly KPI snapshot
- funnel analysis
- instrumentation gap log
- recommendation memo

## First Actions

1. ~~Decide which of the recommended events are required for launch versus post-launch.~~ ✅ Done — see tables above
2. Define the dashboard view needed for first-session retention and purchase conversion.
3. Treat ad attribution as out of scope until core retention and IAP conversion are healthy.
