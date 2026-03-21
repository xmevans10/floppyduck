# Floppy Duck — Launch Checklist

> Battle-tested checklist based on real App Store rejection patterns for indie
> games like Flappy Bird, Crossy Road, and similar casual iOS titles.
>
> **#1 rejection reason**: Guideline 2.1 (App Completeness) — crashes, placeholder
> content, broken features. **#2**: Guideline 5.1 (Privacy). **#3**: Guideline 3.1
> (IAP/Payments). This checklist is ordered by rejection risk.

Legend: `[x]` = done · `[ ]` = to do · `🚨` = known rejection risk · `🔧` = needs Xcode/device/portal

---

## Phase 1 — Rejection Blockers (fix these first)

These will get you instantly rejected. No exceptions.

### 1.1 Account Deletion (Guideline 5.1.1(v)) 🚨

Apple requires any app that supports account creation to offer in-app account
deletion. Floppy Duck supports Sign in with Apple → this is mandatory.

- [x] Add DELETE ACCOUNT button in Settings (visible when signed in with Apple)
- [x] Button calls `auth:deleteAccount` mutation on Convex backend
- [x] After deletion: clear local Keychain + UserDefaults, reset to guest state
- [x] Confirmation dialog warns this is permanent
- [x] 🔧 Implement `auth:deleteAccount` Convex mutation server-side (deletes user doc, stats, sessions)
- [ ] 🔧 Verify deletion works end-to-end on device

> **Why this matters**: Apps have been rejected for hiding account deletion behind
> "email us" — it must be self-service and take ≤ a few taps.

### 1.2 App Completeness (Guideline 2.1)

Over 40% of all unresolved rejections are this guideline.

- [x] No placeholder text in any user-facing screen (verified: grep found zero)
- [x] No TODO/FIXME visible to users (only `GK.appStoreID` which safely returns nil)
- [x] Version string reads from bundle (not hardcoded "1.0.0")
- [x] Tutorial overlay exists for first-time players
- [x] Auth onboarding screen handles first launch
- [ ] 🔧 Fresh install → play through every screen (home, classic, VS bot, H2H queue, shop, closet, stats, settings)
- [ ] 🔧 Test on airplane mode — offline paths must not crash
- [ ] 🔧 Test on oldest supported iOS version (check deployment target)
- [ ] 🔧 Test on smallest screen (iPhone SE) and largest (Pro Max) — no clipping

### 1.3 In-App Purchases (Guideline 3.1)

IAP rejections come from two places: technical StoreKit failures and missing
App Store Connect setup. Both must be right.

#### Code-side (verified ✅)
- [x] All digital content uses Apple IAP (StoreKit 2) — no external payment
- [x] `SkinManager` has complete purchase/verify/restore/transaction-listener flow
- [x] `ThemeManager` has complete purchase/verify/restore/transaction-listener flow
- [x] `#if DEBUG` fallback auto-grants in debug builds (won't trigger in release)
- [x] RESTORE PURCHASES accessible from Settings (not just Shop)
- [x] RESTORE PURCHASES accessible from Shop premium tab
- [x] RESTORE PURCHASES accessible from Shop backgrounds tab

#### App Store Connect (must be done before submission)
- [ ] 🔧 Accept Paid Applications Agreement in App Store Connect → Agreements
- [ ] 🔧 Set up banking/tax information
- [ ] 🔧 Register IAP: `com.floppyduck.skin.alien` ($0.49, Non-Consumable)
- [ ] 🔧 Register IAP: `com.floppyduck.skin.wizard` ($0.49, Non-Consumable)
- [ ] 🔧 Register IAP: `com.floppyduck.skin.devil` ($0.49, Non-Consumable)
- [ ] 🔧 Register IAP: `com.floppyduck.theme.space` ($0.99, Non-Consumable)
- [ ] 🔧 Register IAP: `com.floppyduck.theme.pixelTokyo` ($0.99, Non-Consumable)
- [ ] 🔧 Each IAP has: display name, description, screenshot, review notes
- [ ] 🔧 Attach IAP products to the app submission (reviewed together)
- [ ] 🔧 Test purchases in StoreKit sandbox (not just #if DEBUG)
- [ ] 🔧 Wire `FloppyDuckProducts.storekit` into Xcode scheme for local testing

> **Common trap**: StoreKit works locally but fails in Apple's sandbox because
> products aren't registered in App Store Connect. Reviewers test in sandbox.

### 1.4 Privacy (Guideline 5.1)

Privacy is now the #1 rejection category overall.

- [x] Privacy manifest (`PrivacyInfo.xcprivacy`) declares UserDefaults API usage
- [x] Privacy manifest declares collected data: UserID, GameplayContent
- [x] No tracking (`NSPrivacyTracking = false`)
- [x] No ATT framework (not needed — no tracking)
- [x] `ITSAppUsesNonExemptEncryption = false` in Info.plist
- [x] Privacy policy URL exists: `https://xmevans10.github.io/floppyduck/privacy.html`
- [ ] 🔧 Enter privacy details in App Store Connect (Privacy Nutrition Label)
- [ ] 🔧 Verify privacy policy page is live and loads correctly

### 1.5 Sign in with Apple (Guideline 4.8)

Required when the app offers any form of third-party login.

- [x] Sign in with Apple is the only social login (no Google/Facebook to worry about)
- [x] Guest mode works without sign-in
- [x] Apple credential state restoration on relaunch
- [ ] 🔧 Enable Sign in with Apple capability in Apple Developer portal → App ID
- [ ] 🔧 Add entitlement to provisioning profile
- [ ] 🔧 Test full Apple Sign In → link → restore → sign out flow on device

---

## Phase 2 — Metadata & App Store Connect

These won't reject you but missing them blocks submission.

### 2.1 Create App Record

- [ ] 🔧 Create new app in App Store Connect
- [ ] 🔧 Platform: iOS
- [ ] 🔧 Bundle ID: match Xcode project
- [ ] 🔧 SKU: `floppyduck` (internal identifier)
- [ ] 🔧 Note the Apple ID → update `GK.appStoreID` from `"000000000"` to real value

### 2.2 Product Page Content

All content is drafted in `docs/APPSTORE_METADATA.md`. Copy into ASC:

- [x] App name: "Floppy Duck"
- [x] Subtitle: "Pixel Flap. Retro Quack." (30 chars max ✓)
- [x] Description written (< 4000 chars ✓)
- [x] Keywords: within 100 chars ✓
- [x] Promotional text written (< 170 chars ✓)
- [x] What's New text written
- [x] Category: Games → Casual (primary), Games → Action (secondary)
- [x] Copyright: © 2026 Floppy Duck
- [ ] 🔧 Enter all of the above into App Store Connect
- [ ] 🔧 Support URL is live: `https://xmevans10.github.io/floppyduck/support.html`
- [ ] 🔧 Marketing URL is live: `https://xmevans10.github.io/floppyduck/`
- [ ] 🔧 Privacy policy URL is live

### 2.3 App Review Information

Reviewers are humans with limited time. Make their job easy.

- [ ] 🔧 Provide contact name, phone, email
- [ ] 🔧 App Review notes explaining:
  - App starts in guest mode (no login needed to play)
  - IAPs are in Shop (DUCKS tab → PREMIUM section, BACKGROUNDS tab)
  - Multiplayer requires 2 devices
  - Bot ladder is single-player
- [ ] 🔧 If auth flow is tricky, provide demo Apple ID credentials
- [ ] 🔧 Add screenshots showing IAP flow (helps reviewer find it)

### 2.4 Age Rating

- [ ] 🔧 Complete age rating questionnaire in App Store Connect
  - No violence (cartoon only, no realistic harm)
  - No gambling
  - No mature themes
  - Expected result: 4+
- [ ] 🔧 Verify in-game content matches declared age rating

### 2.5 Pricing

- [ ] 🔧 Set base price: Free
- [ ] 🔧 Availability: all territories (or specific markets)
- [ ] 🔧 Select "Automatically release this version" or date-based release

---

## Phase 3 — Screenshots & Build

### 3.1 Screenshots

Apple requires screenshots at specific device sizes. Don't stretch — generate natively.

Required sizes for iPhone:
- [ ] 🔧 6.7" (iPhone 16 Pro Max) — 1290 × 2796 px
- [ ] 🔧 6.5" (iPhone 11 Pro Max) — 1242 × 2688 px (optional but recommended)
- [ ] 🔧 5.5" (iPhone 8 Plus) — 1242 × 2208 px (required if supporting these)

Scenes to capture (6 per size):
- [ ] 🔧 Home screen — shows game title, buttons, pixel art
- [ ] 🔧 Classic gameplay — mid-flight through pipes
- [ ] 🔧 VS Bot ladder — showing bot personalities
- [ ] 🔧 Shop — duck skins and backgrounds grid
- [ ] 🔧 Head to Head — multiplayer lobby or in-match
- [ ] 🔧 Stats / Leaderboard — showing progression

UI tests exist in `FloppyDuckUITests/ScreenshotTests.swift` — use these with
different simulators. Reference: `docs/CI_MULTI_DEVICE_SCREENSHOTS.md`.

> **Common mistake**: Stretching iPhone screenshots for iPad → instant rejection.
> If not targeting iPad, just make sure iPhone screenshots look correct.

### 3.2 Build & Archive

- [ ] 🔧 Xcode scheme set to Release (not Debug)
- [ ] 🔧 Archive succeeds without errors
- [ ] 🔧 Upload build to App Store Connect via Xcode or Transporter
- [ ] 🔧 Build passes App Store Connect automated checks (no emails about issues)
- [ ] 🔧 Select build in App Store Connect submission form

### 3.3 App Icon

- [x] 1024×1024 icon present (AppIcon-1024.png)
- [x] All required sizes in AppIcon.appiconset (16 files for iPhone + iPad)
- [x] No transparency, no rounded corners (Apple adds those)
- [ ] 🔧 Verify icon renders correctly on device home screen

### 3.4 Launch Screen

- [x] LaunchScreen.storyboard wires LaunchBackground (full-bleed) and LaunchDuck (centered)
- [x] Auto Layout constraints for all screen sizes
- [ ] 🔧 Verify launch screen renders on SE through Pro Max (no black flash)

---

## Phase 4 — Smoke Testing (2-device where needed)

### 4.1 Core Gameplay

- [ ] 🔧 Classic mode: tap to flap, pipes spawn, score increments, game over works
- [ ] 🔧 VS Bot: select bot → play → win/lose triggers correctly → skin unlocks
- [ ] 🔧 Game Over: score displayed, bread collected, back-to-home works
- [ ] 🔧 Daily streak: first game of day increments streak + awards bonus bread

### 4.2 Auth Flows

- [ ] 🔧 Fresh install → guest bootstrap → can play immediately
- [ ] 🔧 Guest → Sign in with Apple → profile retained
- [ ] 🔧 Kill app → relaunch → session restored (not guest again)
- [ ] 🔧 Sign out → returns to guest mode without crash
- [ ] 🔧 Delete account → clears everything, returns to onboarding
- [ ] 🔧 Airplane mode → app launches, local play works, auth fails gracefully

### 4.3 Multiplayer (requires 2 devices + backend)

- [ ] 🔧 Quick Play: both clients paired, shared pipe seed, results sync
- [ ] 🔧 Ranked: paired, result includes ELO change
- [ ] 🔧 Private Room: create → code shown → join with code → match starts
- [ ] 🔧 Cancel queue: exits cleanly, no orphaned state
- [ ] 🔧 Timeout: queue timeout doesn't crash

### 4.4 IAP Flows (requires StoreKit sandbox or .storekit config)

- [ ] 🔧 Browse Shop → tap premium skin → purchase sheet appears
- [ ] 🔧 Complete purchase → skin granted + OWNED badge shown
- [ ] 🔧 Browse backgrounds tab → tap premium theme → purchase works
- [ ] 🔧 Restore purchases from Settings → previously purchased items restored
- [ ] 🔧 Cancel purchase → no error, state unchanged
- [ ] 🔧 Transaction listener: purchase on device A → launch on device B → item appears

### 4.5 Backend Security

- [ ] 🔧 Convex backend validates Apple identity token signature (JWKS)
- [ ] 🔧 Token claim checks: `iss`, `aud`, `exp`, `nonce` all enforced
- [ ] 🔧 `APPLE_EXPECTED_AUDIENCES` env var set in Convex dashboard
- [ ] 🔧 `auth:deleteAccount` mutation deletes user data completely

---

## Phase 5 — TestFlight

### 5.1 Internal Testing

- [ ] 🔧 Upload build to TestFlight
- [ ] 🔧 Add internal testers (up to 100)
- [ ] 🔧 Testers install and play through core flows
- [ ] 🔧 Check for crash reports in App Store Connect
- [ ] 🔧 Fix any issues → re-upload

### 5.2 External Testing (optional but recommended)

- [ ] 🔧 Submit TestFlight build for Beta App Review (lighter review)
- [ ] 🔧 Add external testers (up to 10,000)
- [ ] 🔧 Collect feedback for 3-7 days minimum
- [ ] 🔧 Address critical feedback before App Store submission

---

## Phase 6 — Submit for Review

### 6.1 Final Preflight

- [ ] All Phase 1 rejection blockers resolved
- [ ] All Phase 2 metadata entered in App Store Connect
- [ ] Screenshots uploaded for all required sizes
- [ ] Build uploaded and selected
- [ ] App Review notes written
- [ ] IAP products submitted with app
- [ ] Privacy nutrition label completed
- [ ] Age rating questionnaire completed

### 6.2 Submit

- [ ] 🔧 Click "Add for Review" in App Store Connect
- [ ] 🔧 Expected review time: 24-48 hours (can be up to 7 days)
- [ ] 🔧 Monitor for rejection emails — respond promptly

### 6.3 If Rejected

- [ ] Read the rejection reason carefully (usually cites specific guideline)
- [ ] Fix the issue
- [ ] Resubmit with clear notes explaining what changed
- [ ] If you disagree, use the Resolution Center to appeal

---

## Phase 7 — Post-Launch (after approval)

### 7.1 Monitor

- [ ] Watch App Store Connect analytics (impressions, downloads, conversion)
- [ ] Monitor crash reports (Xcode Organizer + App Store Connect)
- [ ] Respond to App Store reviews within 24 hours
- [ ] Check IAP revenue reports

### 7.2 Quick Follow-Up Update

Ship within 1-2 weeks of launch:

- [ ] Fix any issues reported by early users
- [ ] Improve onboarding if conversion data suggests drop-off
- [ ] Update "What's New" text with genuine improvements

### 7.3 App Store Optimization

- [ ] Review keyword performance (are users finding the app?)
- [ ] A/B test screenshots if Apple supports it for your plan
- [ ] Consider localization for top markets

---

## Current Status Summary

| Phase | Items | Done | Remaining |
|-------|-------|------|-----------|
| 1. Rejection Blockers | 36 | 22 | 14 (mostly 🔧) |
| 2. Metadata & ASC | 22 | 10 | 12 (all 🔧) |
| 3. Screenshots & Build | 18 | 5 | 13 (all 🔧) |
| 4. Smoke Testing | 23 | 0 | 23 (all 🔧) |
| 5. TestFlight | 7 | 0 | 7 (all 🔧) |
| 6. Submit | 10 | 0 | 10 |
| 7. Post-Launch | 9 | 0 | 9 |

**Code-side items complete: 37 of 125 total**
**Next action: Account deletion is the critical path** — everything else is
Xcode/portal work, but this is a code change that blocks submission.
