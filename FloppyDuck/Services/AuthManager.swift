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
    private let identityStore: IdentityStore
    private let client: ConvexClient
    private var didAttemptBootstrap = false

    init(gameManager: GameManager,
         identityStore: IdentityStore = .shared,
         client: ConvexClient = .shared) {
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

    func bootstrapIdentityIfNeeded() async {
        guard !didAttemptBootstrap else { return }
        didAttemptBootstrap = true

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
            } catch {
                identityStore.sessionToken = nil
                identityStore.appleUserId = nil
                await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
                needsCloudRestore = true
                statusMessage = "Session expired. Sign in with Apple to restore cloud profile."
            }
        } else {
            await continueAsGuest(markOnboardingComplete: true, silentFailure: true)
            needsCloudRestore = false
        }
    }

    func continueAsGuest() async {
        await continueAsGuest(markOnboardingComplete: true, silentFailure: false)
    }

    func signInWithApple() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let applePayload = try await AppleSignInCoordinator().signIn()
            let deviceId = identityStore.getOrCreateDeviceId()

            await client.setAuthContext(deviceId: deviceId, sessionToken: nil)

            let displayName = applePayload.displayName ?? gameManager.playerName
            let linkResponse = try await client.linkApple(
                identityToken: applePayload.identityToken,
                nonce: applePayload.nonce,
                deviceId: deviceId,
                displayName: displayName
            )

            identityStore.sessionToken = linkResponse.sessionToken
            identityStore.appleUserId = linkResponse.appleUserId ?? applePayload.appleUserId
            identityStore.didCompleteAuthOnboarding = true
            if !identityStore.didMergeLocalStats || linkResponse.didMergeStats {
                identityStore.didMergeLocalStats = true
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
            if let authError = error as? AuthError,
               case .canceled = authError {
                statusMessage = "Sign in canceled."
                return
            }

            if shouldShowOnboarding {
                authState = .onboardingRequired
            }
            statusMessage = "Sign in failed. Please retry."
            needsCloudRestore = true
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
