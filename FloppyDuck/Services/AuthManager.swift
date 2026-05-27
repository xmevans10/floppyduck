import AuthenticationServices
import Foundation
import GameKit
import Network
import UIKit

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var authState: AuthState = .bootstrapping
    @Published private(set) var identity: PlayerIdentity?
    @Published private(set) var profile: RemotePlayerProfile?

    @Published var statusMessage: String?
    @Published var showRankedSignInPrompt: Bool = false
    @Published private(set) var needsGameCenterSettingsRecovery: Bool = false
    @Published private(set) var isGameCenterAuthenticated: Bool = false
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var lastCloudSyncAt: Date?
    @Published private(set) var needsCloudRestore: Bool = false

    private let gameManager: GameManager
    private let identityStore: any IdentityStoring
    private let client: any MultiplayerBackendClient
    private var didAttemptBootstrap = false
    private var isBootstrapping = false
    private var gameCenterAuthObserver: NSObjectProtocol?

    /// Retained coordinator — prevents deallocation while Apple Sign In sheet is open.
    private var activeCoordinator: AppleSignInCoordinator?

    init(gameManager: GameManager,
         identityStore: any IdentityStoring = IdentityStore.shared,
         client: any MultiplayerBackendClient = ConvexClient.shared) {
        self.gameManager = gameManager
        self.identityStore = identityStore
        self.client = client
        self.isGameCenterAuthenticated = GKLocalPlayer.local.isAuthenticated
        self.gameCenterAuthObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameCenterAuthenticationState(reason: "didBecomeActive")
            }
        }
    }

    deinit {
        if let gameCenterAuthObserver {
            NotificationCenter.default.removeObserver(gameCenterAuthObserver)
        }
    }

    var isAppleLinked: Bool {
        identity?.provider == .gameCenter || identity?.provider == .apple
    }

    var isGuest: Bool {
        !isAppleLinked
    }

    var hasGameCenterMultiplayerAccess: Bool {
        isAppleLinked && isGameCenterAuthenticated
    }

    var accountBadgeText: String {
        isAppleLinked ? "GAME CENTER" : "SIGNED OUT"
    }

    var syncStatusText: String {
        if isAppleLinked {
            if let lastCloudSyncAt {
                return "Using cloud profile • Synced \(Self.syncFormatter.string(from: lastCloudSyncAt))"
            }
            return "Using cloud profile"
        }
        if needsCloudRestore {
            return "Cloud profile available. Sign in with Game Center to restore."
        }
        return "Sign in with Game Center to sync your profile."
    }

    var shouldShowOnboarding: Bool {
        if case .onboardingRequired = authState {
            return true
        }
        return false
    }

    func bootstrapIdentityIfNeeded(force: Bool = false) async {
        guard force || !didAttemptBootstrap else { return }
        guard !isBootstrapping else { return }

        refreshGameCenterAuthenticationState(reason: "bootstrap_start")
        didAttemptBootstrap = true
        isBootstrapping = true
        authState = .bootstrapping
        statusMessage = nil
        defer { isBootstrapping = false }

        let deviceId = identityStore.getOrCreateDeviceId()

        // In UI-test mode, skip ALL network calls and go straight to local
        // guest auth.  This must happen before client.setAuthContext so CI
        // (which has no Convex backend) never blocks on a network timeout.
        if isUITestMode {
            await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
            return
        }

        // Fast airplane-mode detection — if the device has no network path at
        // all, skip the Convex round-trip entirely and go straight to offline
        // guest mode.  This avoids the long "loading profile" hang.
        let hasNetwork = await withCheckedContinuation { cont in
            let monitor = NWPathMonitor()
            monitor.pathUpdateHandler = { path in
                monitor.cancel()
                cont.resume(returning: path.status == .satisfied)
            }
            monitor.start(queue: DispatchQueue(label: "net.check"))
        }
        if !hasNetwork {
            print("[AuthManager] No network — skipping profile fetch (airplane mode)")
            await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
            statusMessage = "Offline mode — connect to sync your profile."
            return
        }

        let token = identityStore.sessionToken
        await client.setAuthContext(deviceId: deviceId, sessionToken: token)

        if !authV1Enabled {
            await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
            return
        }

        guard identityStore.didCompleteAuthOnboarding else {
            authState = .onboardingRequired
            return
        }

        if let token, !token.isEmpty {
            do {
                let remoteProfile = try await client.getProfile()
                let provider = remoteProfile.provider
                applyAuthenticatedState(
                    provider: provider,
                    userId: remoteProfile.userId,
                    deviceId: deviceId,
                    appleUserId: provider == .apple ? identityStore.appleUserId : nil,
                    sessionToken: token,
                    sessionExpiresAt: nil,
                    profile: remoteProfile
                )
                authState = .authenticated(provider)
                statusMessage = nil
                needsCloudRestore = false

                // The restored identity tells us the user previously signed in
                // with Game Center (provider == .gameCenter or .apple, which
                // aliases to Game Center in signInWithApple). Install the
                // GameKit authenticate handler now so iOS can silently log the
                // player back in before they reach the Multiplayer screen —
                // otherwise `isGameCenterAuthenticated` stays false and the
                // modes render as LOCKED on first appearance.
                if provider == .gameCenter || provider == .apple {
                    silentlyAuthenticateGameCenterIfPossible(reason: "bootstrap_restore")
                }
            } catch let error as ConvexError where error.isAuthError {
                // 401/403 → session is definitively invalid; clear it.
                print("[AuthManager] Session auth error: \(error). Clearing session.")
                identityStore.sessionToken = nil
                identityStore.appleUserId = nil
                await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
                needsCloudRestore = true
                statusMessage = "Session expired. Sign in with Game Center to restore cloud profile."
            } catch {
                // Network / transient error — keep session for next attempt.
                // Fall back to guest for this launch but don't destroy the token.
                print("[AuthManager] Bootstrap profile fetch failed (non-auth): \(error)")
                await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
                needsCloudRestore = true
                statusMessage = "Could not reach server. Sign in with Game Center to reconnect."
            }
        } else {
            authState = .onboardingRequired
            needsCloudRestore = false
        }
    }

    func retryBootstrap() async {
        didAttemptBootstrap = false
        await bootstrapIdentityIfNeeded(force: true)
    }

    @discardableResult
    func refreshGameCenterAuthenticationState(reason: String = "manual") -> Bool {
        let current = GKLocalPlayer.local.isAuthenticated
        guard isGameCenterAuthenticated != current else { return current }

        isGameCenterAuthenticated = current
        print("[AuthManager] Game Center auth state changed. authenticated=\(current) reason=\(reason) alias=\(GKLocalPlayer.local.alias)")
        MultiplayerDiagnostics.record(
            category: "auth",
            event: "game_center_auth_state_changed",
            message: "Game Center authentication state changed.",
            metadata: gameCenterDiagnosticMetadata(extra: [
                "reason": reason,
            ])
        )
        return current
    }

    /// Best-effort: install GameKit's `authenticateHandler` at app launch so a
    /// user who previously linked Game Center is silently re-authenticated on
    /// next cold start. Without this, `GKLocalPlayer.local.isAuthenticated`
    /// stays `false` until the user taps Multiplayer (which calls
    /// `signInWithGameCenter()`), causing the modes to appear LOCKED/grayed
    /// even though the user is signed in to Game Center on the device.
    ///
    /// Only call this once we know the user previously chose Game Center
    /// (i.e. their identity was just restored with `.gameCenter`). For guests
    /// we skip it so we never present a Game Center sheet to someone who has
    /// not opted in.
    func silentlyAuthenticateGameCenterIfPossible(reason: String) {
        if GKLocalPlayer.local.isAuthenticated {
            refreshGameCenterAuthenticationState(reason: "\(reason)_fast_path")
            return
        }

        print("[AuthManager] Silent Game Center auth requested reason=\(reason)")
        MultiplayerDiagnostics.record(
            category: "auth",
            event: "game_center_silent_auth_started",
            message: "Silent Game Center authentication kicked off at app launch.",
            metadata: gameCenterDiagnosticMetadata(extra: ["reason": reason])
        )

        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await Self.authenticateGameCenterPlayer()
                await MainActor.run {
                    self.refreshGameCenterAuthenticationState(reason: "\(reason)_success")
                }
            } catch {
                await MainActor.run {
                    self.refreshGameCenterAuthenticationState(reason: "\(reason)_failed")
                    print("[AuthManager] Silent Game Center auth failed reason=\(reason) error=\(error.localizedDescription)")
                    MultiplayerDiagnostics.record(
                        category: "auth",
                        event: "game_center_silent_auth_failed",
                        level: "warning",
                        message: error.localizedDescription,
                        metadata: self.gameCenterDiagnosticMetadata(extra: [
                            "reason": reason,
                            "error": String(describing: error),
                        ])
                    )
                }
            }
        }
    }

    func continueAsGuest() async {
        let isFirstOnboarding = !identityStore.didCompleteAuthOnboarding
        refreshGameCenterAuthenticationState(reason: "continue_as_guest")
        needsGameCenterSettingsRecovery = false
        await continueAsGuest(markOnboardingComplete: true, silentFailure: false)
        if isFirstOnboarding {
            AnalyticsManager.shared.trackOnboardingCompleted(method: "guest")
        }
        AnalyticsManager.shared.trackGuestBootstrapSucceeded()
    }

    func signInWithApple() async {
        await signInWithGameCenter()
    }

    func signInWithGameCenter() async {
        refreshGameCenterAuthenticationState(reason: "sign_in_start")
        isBusy = true
        defer { isBusy = false }
        needsGameCenterSettingsRecovery = false

        print("[AuthManager] Game Center sign-in started. localAuth=\(GKLocalPlayer.local.isAuthenticated) alias=\(GKLocalPlayer.local.alias)")
        MultiplayerDiagnostics.record(
            category: "auth",
            event: "game_center_sign_in_started",
            message: "Game Center sign-in started.",
            metadata: gameCenterDiagnosticMetadata()
        )

        AnalyticsManager.shared.trackAppleSignInStarted()

        do {
            let player = try await Self.authenticateGameCenterPlayer()
            refreshGameCenterAuthenticationState(reason: "authenticate_succeeded")
            let playerId = Self.gameCenterPlayerId(from: player)
            let alias = Self.gameCenterAlias(from: player)
            print("[AuthManager] Game Center authenticate succeeded. alias=\(alias) playerId=\(Self.shortId(playerId))")
            MultiplayerDiagnostics.record(
                category: "auth",
                event: "game_center_authenticate_succeeded",
                message: "Game Center authenticate succeeded.",
                metadata: gameCenterDiagnosticMetadata(extra: [
                    "resolvedAlias": alias,
                    "resolvedPlayerId": Self.shortId(playerId),
                ])
            )

            let deviceId = identityStore.getOrCreateDeviceId()

            await client.setAuthContext(deviceId: deviceId, sessionToken: nil)

            let linkResponse = try await client.linkGameCenter(
                playerId: playerId,
                alias: alias,
                deviceId: deviceId
            )

            print("[AuthManager] linkGameCenter succeeded. sessionToken length=\(linkResponse.sessionToken.count)")

            identityStore.sessionToken = linkResponse.sessionToken
            identityStore.appleUserId = nil
            if !identityStore.didCompleteAuthOnboarding {
                AnalyticsManager.shared.trackOnboardingCompleted(method: "game_center")
            }
            identityStore.didCompleteAuthOnboarding = true
            if !identityStore.didMergeLocalStats || linkResponse.didMergeStats {
                identityStore.didMergeLocalStats = true
            }
            AnalyticsManager.shared.trackAppleSignInSucceeded()
            AnalyticsManager.identify(userId: linkResponse.profile.userId, properties: ["provider": "game_center"])

            // Verify the session token was actually persisted to Keychain.
            let readBack = identityStore.sessionToken
            if readBack == nil || readBack != linkResponse.sessionToken {
                print("[AuthManager] ⚠️ Keychain write verification FAILED — token not persisted!")
            }

            await client.setAuthContext(deviceId: deviceId, sessionToken: linkResponse.sessionToken)

            applyAuthenticatedState(
                provider: .gameCenter,
                userId: linkResponse.profile.userId,
                deviceId: deviceId,
                appleUserId: nil,
                sessionToken: linkResponse.sessionToken,
                sessionExpiresAt: linkResponse.sessionExpiresAt,
                profile: linkResponse.profile
            )

            authState = .authenticated(.gameCenter)
            statusMessage = nil
            showRankedSignInPrompt = false
            needsCloudRestore = false
            needsGameCenterSettingsRecovery = false
        } catch {
            refreshGameCenterAuthenticationState(reason: "sign_in_failed")
            activeCoordinator = nil
            if let authError = error as? AuthError,
               case .canceled = authError {
                statusMessage = "Sign in canceled."
                return
            }

            if shouldShowOnboarding {
                authState = .onboardingRequired
            }
            statusMessage = gameCenterSignInFailureMessage(for: error)
            print("[AuthManager] signInWithGameCenter error: \(error)")
            MultiplayerDiagnostics.record(
                category: "auth",
                event: "game_center_sign_in_failed",
                level: "error",
                message: error.localizedDescription,
                metadata: gameCenterDiagnosticMetadata(extra: [
                    "error": String(describing: error),
                ])
            )
            needsCloudRestore = true
        }
    }

    private static func authenticateGameCenterPlayer() async throws -> GKLocalPlayer {
        // Fast path: if Game Center is already authenticated this session,
        // return immediately. Re-setting authenticateHandler on an already-
        // authenticated player triggers a full Apple server round-trip that
        // can spin for seconds before resolving.
        if GKLocalPlayer.local.isAuthenticated {
            print("[AuthManager] Game Center authenticate fast-path already authenticated.")
            return GKLocalPlayer.local
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            GKLocalPlayer.local.authenticateHandler = { viewController, error in
                print("[AuthManager] Game Center authenticate handler fired. hasViewController=\(viewController != nil) localAuth=\(GKLocalPlayer.local.isAuthenticated) error=\(error?.localizedDescription ?? "nil")")
                if let viewController {
                    Self.presentGameCenterAuthentication(viewController)
                    return
                }

                guard !didResume else { return }

                if let error {
                    // GameKit sometimes fires a stale error before a successful
                    // re-auth completes internally. If the player is actually
                    // authenticated by now, succeed instead of throwing.
                    if GKLocalPlayer.local.isAuthenticated {
                        print("[AuthManager] Game Center authenticate handler had stale error but local player is authenticated.")
                        didResume = true
                        continuation.resume(returning: GKLocalPlayer.local)
                        return
                    }
                    didResume = true
                    continuation.resume(throwing: error)
                } else if GKLocalPlayer.local.isAuthenticated {
                    didResume = true
                    continuation.resume(returning: GKLocalPlayer.local)
                } else {
                    didResume = true
                    continuation.resume(throwing: AuthError.signInFailed("Game Center is not available."))
                }
            }
        }
    }

    private static func presentGameCenterAuthentication(_ viewController: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let root = scenes
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow })?
            .rootViewController else { return }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(viewController, animated: true)
    }

    private func gameCenterSignInFailureMessage(for error: Error) -> String {
        if let gkError = error as? GKError,
           gkError.code == .notAuthenticated {
            needsGameCenterSettingsRecovery = true
            return "Game Center is not signed in on this device. Open Settings > Game Center, sign in, then try again."
        }

        if let authError = error as? AuthError,
           case .signInFailed = authError {
            needsGameCenterSettingsRecovery = true
            return "Game Center is not available right now. Open Settings > Game Center, sign in, then try again."
        }

        if let convexErr = error as? ConvexError {
            return "Game Center sign in failed: \(convexErr.localizedDescription)"
        }
        if let authErr = error as? AuthError {
            return "Game Center sign in failed: \(authErr.localizedDescription)"
        }
        return "Game Center sign in failed: \(error.localizedDescription)"
    }

    private static func gameCenterPlayerId(from player: GKLocalPlayer) -> String {
        if !player.teamPlayerID.isEmpty {
            return player.teamPlayerID
        }
        return player.gamePlayerID
    }

    private static func gameCenterAlias(from player: GKLocalPlayer) -> String {
        let alias = player.alias.trimmingCharacters(in: .whitespacesAndNewlines)
        return alias.isEmpty ? "Player" : String(alias.prefix(16))
    }

    private func gameCenterDiagnosticMetadata(extra: [String: String] = [:]) -> [String: String] {
        var metadata = [
            "localAuthenticated": String(GKLocalPlayer.local.isAuthenticated),
            "publishedGameCenterAuthenticated": String(isGameCenterAuthenticated),
            "localAlias": GKLocalPlayer.local.alias,
            "localGamePlayerId": Self.shortId(GKLocalPlayer.local.gamePlayerID),
            "localTeamPlayerId": Self.shortId(GKLocalPlayer.local.teamPlayerID),
            "identityProvider": identity?.provider.rawValue ?? "nil",
            "authState": String(describing: authState),
        ]
        extra.forEach { metadata[$0.key] = $0.value }
        return metadata
    }

    private static func shortId(_ value: String) -> String {
        guard !value.isEmpty else { return "nil" }
        guard value.count > 8 else { return value }
        return "\(value.prefix(4))...\(value.suffix(4))"
    }

    func signOut() async {
        refreshGameCenterAuthenticationState(reason: "sign_out")
        if identity?.sessionToken != nil {
            do {
                try await client.signOutSession()
            } catch {
                // Best effort on sign-out.
            }
        }

        identityStore.sessionToken = nil
        identityStore.appleUserId = nil

        identity = nil
        profile = nil
        lastCloudSyncAt = nil
        authState = .onboardingRequired
        statusMessage = "Signed out."
        needsCloudRestore = false
        needsGameCenterSettingsRecovery = false
    }

    /// Permanently deletes the user's account and all associated server-side
    /// data. Required by App Store Review Guideline 5.1.1(v) for any app that
    /// supports account creation.
    func deleteAccount() async {
        isBusy = true
        defer { isBusy = false }
        refreshGameCenterAuthenticationState(reason: "delete_account")

        // 1. Ask backend to delete the user record, stats, sessions, etc.
        do {
            try await client.deleteAccount()
        } catch {
            statusMessage = "Account deletion failed: \(error.localizedDescription)"
            return
        }

        // 2. Wipe all local credentials and cached state.
        identityStore.sessionToken = nil
        identityStore.appleUserId = nil
        identityStore.didCompleteAuthOnboarding = false
        identityStore.didMergeLocalStats = false

        // 3. Reset local game state.
        gameManager.resetStats()

        // 4. Clear identity and profile.
        identity = nil
        profile = nil
        lastCloudSyncAt = nil
        needsCloudRestore = false
        needsGameCenterSettingsRecovery = false

        // 5. Return to onboarding (fresh install state).
        authState = .onboardingRequired
        statusMessage = "Account deleted."
    }

    func ensureRankedAccess() -> Bool {
        if isAppleLinked {
            return true
        }
        showRankedSignInPrompt = true
        return false
    }

    func ensureGameCenterAuthenticated() async -> Bool {
        refreshGameCenterAuthenticationState(reason: "ensure_start")
        if hasGameCenterMultiplayerAccess {
            return true
        }

        await signInWithGameCenter()
        refreshGameCenterAuthenticationState(reason: "ensure_finished")
        return hasGameCenterMultiplayerAccess
    }

    private func continueAsGuest(markOnboardingComplete: Bool,
                                 silentFailure: Bool) async {
        isBusy = true
        defer { isBusy = false }

        let deviceId = identityStore.getOrCreateDeviceId()

        if isUITestMode {
            completeLocalGuestBootstrap(
                deviceId: deviceId,
                markOnboardingComplete: markOnboardingComplete,
                userIdPrefix: "uitest"
            )
            authState = .authenticated(.guest)
            if !silentFailure {
                statusMessage = nil
            }
            needsCloudRestore = false
            return
        }

        await client.setAuthContext(deviceId: deviceId, sessionToken: nil)

        let shouldAttemptMerge = !identityStore.didMergeLocalStats
        let localSnapshot = shouldAttemptMerge
            ? LocalStatsSnapshot(username: gameManager.playerName, stats: gameManager.stats)
            : nil

        do {
            let bootstrap = try await client.bootstrapGuest(deviceId: deviceId, localStats: localSnapshot)
            if shouldAttemptMerge || bootstrap.didMergeStats {
                identityStore.didMergeLocalStats = true
            }

            if markOnboardingComplete {
                identityStore.didCompleteAuthOnboarding = true
            }

            identityStore.sessionToken = nil

            applyAuthenticatedState(
                provider: .guest,
                userId: bootstrap.profile.userId,
                deviceId: deviceId,
                appleUserId: nil,
                sessionToken: nil,
                sessionExpiresAt: nil,
                profile: bootstrap.profile
            )
            authState = .authenticated(.guest)
            if !silentFailure {
                statusMessage = nil
            }
            if identityStore.sessionToken == nil {
                needsCloudRestore = false
            }
        } catch {
            let fallbackProfile = RemotePlayerProfile(
                userId: "local-\(deviceId)",
                username: gameManager.playerName,
                provider: .guest,
                stats: gameManager.stats
            )

            applyAuthenticatedState(
                provider: .guest,
                userId: fallbackProfile.userId,
                deviceId: deviceId,
                appleUserId: nil,
                sessionToken: nil,
                sessionExpiresAt: nil,
                profile: fallbackProfile
            )

            authState = .authenticated(.guest)
            if !silentFailure {
                statusMessage = "Could not reach server. Playing offline."
            }
        }
    }

    private func completeLocalGuestBootstrap(deviceId: String,
                                             markOnboardingComplete: Bool,
                                             userIdPrefix: String = "local") {
        if markOnboardingComplete {
            identityStore.didCompleteAuthOnboarding = true
        }

        identityStore.sessionToken = nil

        let fallbackProfile = RemotePlayerProfile(
            userId: "\(userIdPrefix)-\(deviceId)",
            username: gameManager.playerName,
            provider: .guest,
            stats: gameManager.stats
        )

        applyAuthenticatedState(
            provider: .guest,
            userId: fallbackProfile.userId,
            deviceId: deviceId,
            appleUserId: nil,
            sessionToken: nil,
            sessionExpiresAt: nil,
            profile: fallbackProfile
        )
    }

    private func applyAuthenticatedState(provider: AuthProvider,
                                         userId: String,
                                         deviceId: String,
                                         appleUserId: String?,
                                         sessionToken: String?,
                                         sessionExpiresAt: Date?,
                                         profile: RemotePlayerProfile) {
        self.profile = profile
        self.identity = PlayerIdentity(
            userId: userId,
            provider: provider,
            deviceId: deviceId,
            appleUserId: appleUserId,
            sessionToken: sessionToken,
            sessionExpiresAt: sessionExpiresAt
        )

        if provider == .apple || provider == .gameCenter {
            lastCloudSyncAt = Date()
        }

        gameManager.applyRemoteProfile(profile)
    }

    private var authV1Enabled: Bool {
        if let value = Bundle.main.object(forInfoDictionaryKey: "AUTH_V1_ENABLED") as? Bool {
            return value
        }
        return true
    }

    private var isUITestMode: Bool {
        let processInfo = ProcessInfo.processInfo
        return processInfo.environment["UITEST_MODE"] == "1"
            || processInfo.arguments.contains("-UITestMode")
    }

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
