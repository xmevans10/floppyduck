import SwiftUI
import PostHog
import Sentry
import GameKit

@main
struct FloppyDuckApp: App {
    @StateObject private var gameManager: GameManager
    @StateObject private var authManager: AuthManager
    /// Skip splash entirely when launched in UI-test mode so screenshots
    /// don't waste time waiting 4+ seconds for the splash animation.
    @State private var splashFinished: Bool

    init() {
        let isUITest = ProcessInfo.processInfo.arguments.contains("-UITestMode")
            || ProcessInfo.processInfo.environment["UITEST_MODE"] == "1"
        _splashFinished = State(initialValue: isUITest)

        // In UI-test mode, skip ALL third-party SDK init (Sentry, PostHog,
        // SoundManager) to avoid network calls and main-thread blocking in CI.
        if !isUITest {
            let sentryVerbose = ProcessInfo.processInfo.environment["SENTRY_VERBOSE"] != nil

            SentrySDK.start { options in
                options.dsn = "https://e7671e36f866d70b8620cf0d6ba9d847@o4510732962037760.ingest.us.sentry.io/4511135319719936"
                options.enableAutoSessionTracking = true

                #if DEBUG
                options.environment = "development"
                options.debug = sentryVerbose
                options.tracesSampleRate = 0.2
                options.attachScreenshot = false
                options.enableUserInteractionTracing = false
                #else
                options.environment = "production"
                options.debug = false
                options.tracesSampleRate = 0.1
                options.attachScreenshot = true
                options.enableUserInteractionTracing = true
                #endif
            }

            AnalyticsManager.configure()
            AnalyticsManager.shared.trackAppOpen()
            SoundManager.shared.prepare()

            GKLocalPlayer.local.authenticateHandler = { _, error in
                if let error = error {
                    print("[GameKit] Auth error: \(error.localizedDescription)")
                }
            }
        }

        let manager = GameManager()
        let auth = AuthManager(gameManager: manager)
        manager.authManager = auth

        _gameManager = StateObject(wrappedValue: manager)
        _authManager = StateObject(wrappedValue: auth)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()

                if splashFinished {
                    ContentView()
                        .environmentObject(gameManager)
                        .environmentObject(authManager)
                        .preferredColorScheme(.light)
                        .transition(.opacity)
                }

                if !splashFinished {
                    SplashView(isFinished: $splashFinished)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.2), value: splashFinished)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
        }
    }
}
