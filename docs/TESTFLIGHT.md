# TestFlight Build Guide

## Prerequisites

### 1. Xcode & Apple Developer Account
- macOS with Xcode installed
- Apple Developer account (paid membership) added to Xcode: **Xcode → Settings → Accounts**
- The account must have the **"iOS Distribution"** certificate in your keychain

### 2. App Store Connect API Key
Fastlane uses a team-scoped API key to upload builds and metadata.

**Secrets needed:**

| Secret | Description | Where to get it |
|--------|-------------|-----------------|
| `ASC_KEY_ID` | App Store Connect API Key ID | [App Store Connect → Users and Access → Keys](https://appstoreconnect.apple.com/access/api) |
| `ASC_ISSUER_ID` | Issuer ID from the API Keys page | Same page as above |
| `ASC_KEY_FILE` | Path to the downloaded `.p8` private key | Download from the API Keys page, place somewhere safe (e.g., `~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8`) |
| `APP_STORE_ID` | Numeric App Store Connect App ID | App Store Connect → App → General → App Information → "Apple ID" |

### 3. GitHub Secrets (for CI/CD)
If using GitHub Actions, add these as repo secrets:

```
ASC_KEY_ID
ASC_ISSUER_ID
ASC_KEY_CONTENT            # base64 of the .p8 file contents
APP_STORE_ID
```

Convex auto-deploys on pushes to `main` via:
```
CONVEX_DEPLOY_KEY          # from Convex dashboard → Settings → Deploy Keys
```

---

## Setup

```bash
# 1. Install Ruby dependencies
bundle install

# 2. Set environment variables
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_FILE="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
export APP_STORE_ID="6768735513"   # Floppy Duck's numeric ID
```

---

## Verify Apple ID Session

Before building, make sure Xcode can sign:

```bash
# Open Xcode → Settings → Accounts and verify your Apple ID shows "iOS Distribution" certificate
# Or check from CLI:
security find-identity -v -p codesigning | grep "Apple Distribution"
```

If you see `"Your session has expired. Please log in."`, re-login in Xcode → Settings → Accounts.

---

## Build & Upload

```bash
# Full pipeline: build archive → update metadata → upload to TestFlight
bundle exec fastlane release

# Individual lanes:
bundle exec fastlane build       # Just build the IPA
bundle exec fastlane upload      # Upload existing IPA to TestFlight
bundle exec fastlane metadata    # Update App Store metadata only
```

The IPA lands at `/tmp/FloppyDuckFastlane/FloppyDuck.ipa` after a successful build.

---

## Troubleshooting

### "No signing certificate 'iOS Distribution' found"
You're missing a distribution certificate. Either:
- Let Xcode auto-manage signing and build from Xcode first (this creates the cert)
- Or manually create one in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/certificates/list)

### "Your session has expired. Please log in."
Your Xcode Apple ID session expired. Open Xcode → Settings → Accounts → re-enter credentials.

### "No Accounts" during export
Xcode isn't logged in. Check Xcode → Settings → Accounts.

### Leaderboard shows "NO RANKINGS YET"
- Verify Convex is deployed: `npx convex deploy -y` (from `convex/` directory)
- Check Convex dashboard logs at https://dashboard.convex.dev
- The `users.by_bestScore` index must be deployed in production
- Check Sentry for client-side errors: https://floppyduck.sentry.io

### Convex deploy fails
```bash
cd convex
npx convex deploy -y
```
If you get a deploy key error, set `CONVEX_DEPLOY_KEY`.

---

## Architecture

```
fastlane release
  ├─ build (gym/xcodebuild)
  │   ├─ Clean + Archive (Release, app-store)
  │   └─ Export IPA to /tmp/FloppyDuckFastlane/
  ├─ metadata (deliver)
  │   └─ Upload metadata/screenshots from fastlane/metadata/
  └─ upload (pilot)
      └─ Upload IPA to App Store Connect → TestFlight
```

App Store Connect API key authentication (not Apple ID password) is used by fastlane for upload. The build/export step still requires Xcode's local Apple ID session for code signing.
