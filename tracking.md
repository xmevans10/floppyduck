# Floppy Duck Tracking Plan

## Objective

Measure activation, retention, monetization, and feature adoption while preserving the game’s current privacy-first stance.

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

## Recommended Event Taxonomy

- `app_open`
- `onboarding_completed`
- `guest_bootstrap_succeeded`
- `apple_sign_in_started`
- `apple_sign_in_succeeded`
- `game_started`
- `game_completed`
- `mode_selected`
- `bot_match_started`
- `bot_match_completed`
- `multiplayer_queue_started`
- `multiplayer_match_found`
- `multiplayer_match_finished`
- `shop_viewed`
- `item_viewed`
- `iap_purchase_started`
- `iap_purchase_completed`
- `iap_restore_completed`
- `skin_equipped`
- `theme_equipped`
- `banner_equipped`
- `stats_viewed`
- `leaderboard_viewed`
- `share_sheet_opened`

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

## Outputs

- weekly KPI snapshot
- funnel analysis
- instrumentation gap log
- recommendation memo

## First Actions

1. Decide which of the recommended events are required for launch versus post-launch.
2. Define the dashboard view needed for first-session retention and purchase conversion.
3. Treat ad attribution as out of scope until core retention and IAP conversion are healthy.

