import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        Group {
            switch auth.authState {
            case .bootstrapping:
                bootstrappingView
            case .onboardingRequired:
                AuthOnboardingView()
            case .authenticated:
                appNavigation
            case .failed(let message):
                authFailedView(message: message)
            }
        }
        .task {
            await auth.bootstrapIdentityIfNeeded()
        }
    }

    private var appNavigation: some View {
        NavigationStack(path: $manager.path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                        // Solid opaque background covers previous-view bleed during push/pop
                        .background(
                            Color(red: 0.35, green: 0.65, blue: 0.90)
                                .ignoresSafeArea()
                        )
                }
        }
        // Overall stack background so nothing peeks through during any transition
        .background(
            Color(red: 0.35, green: 0.65, blue: 0.90)
                .ignoresSafeArea()
        )
        .onAppear {
            SoundManager.shared.startMenuMusic()
        }
        .onChange(of: manager.activeGameConfig) { oldValue, newValue in
            if newValue != nil {
                // Game started — stop menu music (gameplay music starts via bridge onStart)
                SoundManager.shared.stopMenuMusic()
            } else if oldValue != nil {
                // Game ended — resume menu music
                SoundManager.shared.startMenuMusic()
            }
        }
        .fullScreenCover(item: $manager.activeGameConfig) { config in
            GameContainerView(config: config)
                .environmentObject(manager)
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .multiplayerModes:
            MultiplayerModesView()
        case .matchmaking(let mode):
            MatchmakingView(mode: mode)
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        case .shop:
            ShopView()
        case .botLadder:
            BotLadderView()
        case .collection:
            CollectionView()
        case .leaderboard:
            LeaderboardView()
        }
    }

    private func authFailedView(message: String) -> some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("⚠️")
                    .font(.system(size: 48))

                Text("OOPS!")
                    .font(.custom(GK.pixelFontName, size: 22))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

                Text(message)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    Task { await auth.bootstrapIdentityIfNeeded() }
                } label: {
                    Text("RETRY")
                        .font(.custom(GK.pixelFontName, size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(GK.Colors.buttonGreen)
                                .shadow(color: GK.Colors.buttonGreen.opacity(0.5), radius: 0, x: 0, y: 3)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.3), lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    manager.continueAsGuest()
                } label: {
                    Text("CONTINUE AS GUEST")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var bootstrappingView: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                Text("LOADING PROFILE...")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
            }
        }
    }
}
