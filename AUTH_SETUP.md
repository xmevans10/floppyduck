# Auth Setup (Sign in with Apple)

## iOS Project

1. Open `FloppyDuck.xcodeproj` in Xcode.
2. Select the `FloppyDuck` target.
3. In **Signing & Capabilities**, add **Sign in with Apple**.
4. Confirm `FloppyDuck/FloppyDuck.entitlements` includes:
   - `com.apple.developer.applesignin` -> `Default`

## Convex Backend

1. `cd convex`
2. `npm install`
3. `npx convex dev`
4. `npx convex deploy`

## Runtime Config

- Set `CONVEX_BASE_URL` in `FloppyDuck/Info.plist`.
- Keep `AUTH_V1_ENABLED` as `true` for identity/auth rollout.

## Security Notes

- Do not place deploy keys in the iOS app bundle.
- Do not commit sensitive tokens.
- Rotate any accidentally exposed keys immediately.
