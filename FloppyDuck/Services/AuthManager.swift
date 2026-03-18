import AuthenticationServices
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var authState: AuthState = .bootstrapping
    @Published private(set) var identity: PlayerIdentity?
    @Published private(set) var profile: RemotePlayerProfile?

    @Published var statusMessage: String?
    @Published var showRankedSignInPrompt: Bool = false
    @Published private(set) var isBusy: Bool = false
    @Published private(set) var lastCloudSyncAt: Date?
    @Published private(set) var needsCloudRestore: Bool = false

    private let gameManager: GameManager
    private let identityStore: any IdentityStoring
    private let client: any MultiplayerBackendClient
    private var didAttemptBootstrap = false
    private var isBootstrapping = false

    /// Retained coordinator — prevents deallocation while Apple Sign In sheet is open.
    private var activeCoordinator: AppleSignInCoordinator?

    init(gameManager: GameManager,
         identityStore: any IdentityStoring = IdentityStore.shared,
         client: any MultiplayerBackendClient = ConvexClient.shared) {
        self.gameManager = gameManager
        self.identityStore = identityStore
        self.client = client
    }

    var isAppleLinked: Bool {
        identity?.provider == .apple
    }

    var isGuest: Bool {
        !isAppleLinked
    }

    var accountBadgeText: String {
        isAppleLinked ? "APPLE LINKED" : "GUEST"
    }

    var syncStatusText: String {
        if isAppleLinked {
            if let lastCloudSyncAt {
                return "Using cloud profile • Synced \(Self.syncFormatter.string(from: lastCloudSyncAt))"
            }
            return "Using cloud profile"
        }
        if needsCloudRestore {
            return "Cloud profile available. Sign in with Apple to restore."
        }
        return "Using guest profile"
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

        didAttemptBootstrap = true
        isBootstrapping = true
        authState = .bootstrapping
        statusMessage = nil
        defer { isBootstrapping = false }

        let deviceId = identityStore.getOrCreateDeviceId()
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
                applyAuthenticatedState(
                    provider: .apple,
                    userId: remoteProfile.userId,
                    deviceId: deviceId,
                    appleUserId: identityStore.appleUserId,
                    sessionToken: token,
                    sessionExpiresAt: nil,
                    profile: remoteProfile
                )
                authState = .authenticated(.apple)
                statusMessage = nil
                needsCloudRestore = false
            } catch let error as ConvexError where error.isAuthError {
                // 401/403 → session is definitively invalid; clear it.
                print("[AuthManager] Session auth error: \(error). Clearing session.")
                identityStore.sessionToken = nil
                identityStore.appleUserId = nil
                await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
                needsCloudRestore = true
                statusMessage = "Session expired. Sign in with Apple to restore cloud profile."
            } catch {
                // Network / transient error — keep session for next attempt.
                // Fall back to guest for this launch but don't destroy the token.
                print("[AuthManager] Bootstrap profile fetch failed (non-auth): \(error)")
                await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
                needsCloudRestore = true
                statusMessage = "Could not reach server. Sign in with Apple to reconnect."
            }
        } else {
            await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
            needsCloudRestore = false
        }
    }

    func retryBootstrap() async {
        didAttemptBootstrap = false
        await bootstrapIdentityIfNeeded(force: true)
    }

    func continueAsGuest() async {
        await continueAsGuest(markOnboardingComplete: true, silentFailure: false)
    }

    func signInWithApple() async {
        isBusy = true
        defer { isBusy = false }

        // Pre-flight: if we have a previous Apple User ID, check if the
        // credential is still valid (user may have revoked in Settings).
        if let previousAppleId = identityStore.appleUserId {
            let state = await Self.appleCredentialState(for: previousAppleId)
            print("[AuthManager] Apple credential state for \(previousAppleId.prefix(8))…: \(state)")
            if state == .revoked {
                identityStore.sessionToken = nil
                identityStore.appleUserId = nil
                print("[AuthManager] Apple credential revoked — cleared stored identity.")
            }
        }

        do {
            let coordinator = AppleSignInCoordinator()
            activeCoordinator = coordinator  // retain until complete
            let applePayload = try await coordinator.signIn()
            activeCoordinator = nil

            print("[AuthManager] Apple sign-in payload received. appleUserId=\(applePayload.appleUserId.prefix(8))… tokenLength=\(applePayload.identityToken.count)")

            let deviceId = identityStore.getOrCreateDeviceId()

            await client.setAuthContext(deviceId: deviceId, sessionToken: nil)

            let displayName = applePayload.displayName ?? gameManager.playerName
            let linkResponse = try await client.linkApple(
                identityToken: applePayload.identityToken,
                nonce: applePayload.nonce,
                deviceId: deviceId,
                displayName: displayName
            )

            print("[AuthManager] linkApple succeeded. sessionToken length=\(linkResponse.sessionToken.count)")

            identityStore.sessionToken = linkResponse.sessionToken
            identityStore.appleUserId = linkResponse.appleUserId ?? applePayload.appleUserId
            identityStore.didCompleteAuthOnboarding = true
            if !identityStore.didMergeLocalStats || linkResponse.didMergeStats {
                identityStore.didMergeLocalStats = true
            }

            // Verify the session token was actually persisted to Keychain.
            let readBack = identityStore.sessionToken
            if readBack == nil || readBack != linkResponse.sessionToken {
                print("[AuthManager] ⚠️ Keychain write verification FAILED — token not persisted!")
            }

            await client.setAuthContext(deviceId: deviceId, sessionToken: linkResponse.sessionToken)

            applyAuthenticatedState(
                provider: .apple,
                userId: linkResponse.profile.userId,
                deviceId: deviceId,
                appleUserId: identityStore.appleUserId,
                sessionToken: linkResponse.sessionToken,
                sessionExpiresAt: linkResponse.sessionExpiresAt,
                profile: linkResponse.profile
            )

            authState = .authenticated(.apple)
            statusMessage = nil
            showRankedSignInPrompt = false
            needsCloudRestore = false
        } catch {
            activeCoordinator = nil
            if let authError = error as? AuthError,
               case .canceled = authError {
                statusMessage = "Sign in canceled."
                return
            }

            if shouldShowOnboarding {
                authState = .onboardingRequired
            }
            // Include underlying error type so backend issues are diagnosable
            let detail: String
            if let convexErr = error as? ConvexError {
                detail = "Sign in failed: \(convexErr.localizedDescription)"
            } else if let authErr = error as? AuthError {
                detail = "Sign in failed: \(authErr.localizedDescription)"
            } else {
                detail = "Sign in failed: \(error.localizedDescription)"
            }
            statusMessage = detail
            print("[AuthManager] signInWithApple error: \(error)")
            needsCloudRestore = true
        }
    }

    /// Checks the Apple ID credential state for a given user ID.
    private static func appleCredentialState(for appleUserId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        await withCheckedContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: appleUserId) { state, _ in
                continuation.resume(returning: state)
            }
        }
    }

    func signOut() async {
        if identity?.sessionToken != nil {
            do {
                try await client.signOutSession()
            } catch {
                // Best effort on sign-out.
            }
        }

        identityStore.sessionToken = nil
        identityStore.appleUserId = nil

        await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
        statusMessage = "Signed out."
        needsCloudRestore = false
    }

    func ensureRankedAccess() -> Bool {
        if isAppleLinked {
            return true
        }
        showRankedSignInPrompt = true
        return false
    }

    private func continueAsGuest(markOnboardingComplete: Bool,
                                 silentFailure: Bool) async {
        isBusy = true
        defer { isBusy = false }

        let deviceId = identityStore.getOrCreateDeviceId()

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

            authState = .failed("Guest bootstrap failed")
            if !silentFailure {
                statusMessage = "Guest sign-in failed. Using offline profile."
            }
        }
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

        if provider == .apple {
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

    private static let syncFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
