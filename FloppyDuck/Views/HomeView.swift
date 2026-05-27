import SwiftUI

struct HomeView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var titleFlashOffset: CGFloat = -180

    private let icons = PixelIconFactory.shared

    @State private var showSignInPrompt: Bool = false

    @AppStorage("lastPatchNotesVersion") private var lastPatchNotesVersion: String = ""
    @AppStorage("seenAnnouncementIds") private var seenAnnouncementIds: String = ""
    @State private var showPatchNotes = false
    @State private var patchNotesShownThisSession = false
    @State private var activeAnnouncements: [Announcement] = []
    @State private var pendingFriendRequestCount: Int = 0

    private var isGuest: Bool { auth.isGuest }

    var body: some View {
        ZStack {
            // Enhanced 8-bit sky background
            homeBackground
                .ignoresSafeArea()

            cloudLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 54)

                    // Title
                    titleSection
                        .padding(.top, 2)

                    // Bread counter + best score
                    HStack(spacing: 12) {
                        breadCounter
                        bestScoreBadge
                    }
                    .padding(.top, 16)

                    accountBadge
                        .padding(.top, 10)

                    Spacer().frame(height: 22)

                    // Play button (expandable)
                    playSection
                        .padding(.horizontal, 40)

                    Spacer().frame(height: 16)

                    // Bottom row: Shop, Collection, Achievements, Stats, Settings
                    bottomButtons
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 24)
                }
            }

            if showPatchNotes {
                PatchNotesOverlay(
                    isPresented: $showPatchNotes,
                    onDismiss: {
                        lastPatchNotesVersion = currentAppVersion
                        let newSeenIds = Set(seenAnnouncementIds.components(separatedBy: ",").filter { !$0.isEmpty })
                            .union(activeAnnouncements.map { $0.id })
                        seenAnnouncementIds = newSeenIds.sorted().joined(separator: ",")
                    },
                    announcements: activeAnnouncements
                )
                .zIndex(100)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            auth.refreshGameCenterAuthenticationState(reason: "home_appear")
        }
        .task {
            activeAnnouncements = (try? await ConvexClient.shared.fetchAnnouncements()) ?? []

            if !isGuest {
                pendingFriendRequestCount = (try? await ConvexClient.shared.getPendingFriendRequests().count) ?? 0
            }

            guard !patchNotesShownThisSession else { return }

            let seenIds = Set(seenAnnouncementIds.components(separatedBy: ",").filter { !$0.isEmpty })
            let hasNewAnnouncement = activeAnnouncements.contains { !seenIds.contains($0.id) }
            let isNewVersion = lastPatchNotesVersion != currentAppVersion

            if hasNewAnnouncement || isNewVersion {
                patchNotesShownThisSession = true
                showPatchNotes = true
            }
        }
        .alert("Sign In to Unlock", isPresented: $showSignInPrompt) {
            Button("NOT NOW", role: .cancel) {}
            Button("SIGN IN WITH GAME CENTER") {
                Task { await auth.signInWithGameCenter() }
            }
        } message: {
            Text("Sign in with Game Center to access all game features.")
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        // Base text (visible color)
        VStack(spacing: 4) {
            titleLine("FLOPPY", color: .white, size: 30)
            titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
        }
        .overlay {
            // Sheen masked to letter shapes — no bounding box, shaped precisely to text
            VStack(spacing: 4) {
                titleLine("FLOPPY", color: .white, size: 30)
                titleLine("DUCK", color: GK.Colors.scoreYellow, size: 30)
            }
            .mask {
                VStack(spacing: 4) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                }
            }
            .overlay {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.white.opacity(0.15),
                                Color.white.opacity(0.65),
                                Color.white.opacity(0.15),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 50, height: 100)
                    .rotationEffect(.degrees(14))
                    .offset(x: titleFlashOffset)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
            }
            .mask {
                VStack(spacing: 4) {
                    Text("FLOPPY")
                        .font(.custom(GK.pixelFontName, size: 30))
                    Text("DUCK")
                        .font(.custom(GK.pixelFontName, size: 30))
                }
            }
        }
        .onAppear {
            // Item 4: Respect reduce motion accessibility setting
            guard !UIAccessibility.isReduceMotionEnabled else { return }
            withAnimation(.linear(duration: 1.65).repeatForever(autoreverses: false)) {
                titleFlashOffset = 180
            }
        }
    }

    private func titleLine(_ text: String, color: Color, size: CGFloat) -> some View {
        Text(text)
            .font(.custom(GK.pixelFontName, size: size))
            .foregroundColor(color)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: 4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -4, y: 4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 4, y: -4)
            .shadow(color: GK.Colors.pipeBorder, radius: 0, x: -4, y: -4)
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 0, y: 6)
    }

    // MARK: - 8-bit Home Background

    private var homeBackground: some View {
        GeometryReader { geo in
            Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Cloud Layer

    /// Pixel-art clouds (same procedural texture as Day theme) — positioned
    /// at or above the "FLOPPY DUCK" title (y ≤ 54pt from top).
    private var cloudLayer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack {
                PixelCloud(scale: 1.0, yOffset: 12, duration: 22, screenWidth: w)
                PixelCloud(scale: 0.65, yOffset: 0, duration: 29, screenWidth: w)
                PixelCloud(scale: 1.2, yOffset: 24, duration: 25, screenWidth: w)
                PixelCloud(scale: 0.8, yOffset: 40, duration: 32, screenWidth: w)
                PixelCloud(scale: 0.5, yOffset: 30, duration: 27, screenWidth: w)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Bread Counter

    private var breadCounter: some View {
        HStack(spacing: 10) {
            Image(uiImage: TextureFactory.shared.breadUIImage(pixelScale: 4.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 32, height: 26)

            Text("\(manager.stats.bread)")
                .font(.custom(GK.pixelFontName, size: 16))
                .foregroundColor(GK.Colors.breadGold)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.breadGold.opacity(0.3), lineWidth: 2)
                )
        )
        .accessibilityLabel("Bread: \(manager.stats.bread)")
    }

    private var bestScoreBadge: some View {
        HStack(spacing: 6) {
            Image(uiImage: icons.image(for: .trophy, pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 20, height: 20)

            Text("\(manager.stats.bestScore)")
                .font(.custom(GK.pixelFontName, size: 16))
                .foregroundColor(GK.Colors.buttonOrange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.buttonOrange.opacity(0.3), lineWidth: 2)
                )
        )
        .accessibilityLabel("Best score: \(manager.stats.bestScore)")
    }

    private var accountBadge: some View {
        HStack(spacing: 6) {
            pixelIcon(auth.isAppleLinked ? .trophy : .classic, size: 14)
            Text(auth.accountBadgeText)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.3))
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Play Section

    private var playSection: some View {
        VStack(spacing: 10) {
            // Single Player — navigates to sub-screen (Classic / Arcade)
            subModeButton(
                icon: .classic,
                title: "SINGLE PLAYER",
                subtitle: "Classic · Arcade",
                color: GK.Colors.classicTint
            ) {
                SoundManager.shared.play(.button)
                manager.navigate(to: .singlePlayerModes)
            }

            // VS Bot — navigates to bot ladder
            subModeButton(
                icon: .bot,
                title: "VS BOT",
                subtitle: isGuest ? "Sign in to unlock" : "Bot Ladder",
                color: GK.Colors.vsBotTint,
                locked: isGuest
            ) {
                if isGuest {
                    showSignInPrompt = true
                } else {
                    SoundManager.shared.play(.button)
                    manager.navigate(to: .botLadder)
                }
            }

            // Multiplayer — navigates to sub-screen (Quick Play / Ranked / etc.)
            subModeButton(
                icon: .headToHead,
                title: "MULTIPLAYER",
                subtitle: "Quick · Ranked · Room",
                color: GK.Colors.headToHeadTint
            ) {
                SoundManager.shared.play(.button)
                manager.navigate(to: .multiplayerModes)
            }
        }
    }

    private func subModeButton(icon: PixelIcon, title: String, subtitle: String, color: Color, locked: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                pixelIcon(icon, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 11))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                Image(uiImage: PixelIconFactory.shared.image(for: locked ? .lock : .play, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(color)
                    .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.5 : 1.0)
        .accessibilityIdentifier("\(title), \(subtitle)")
        .accessibilityLabel(locked ? "\(title), sign in to unlock" : "\(title), \(subtitle)")
    }

    // MARK: - Bottom Buttons (3×2 grid)

    private let bottomGridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    private var bottomButtons: some View {
        LazyVGrid(columns: bottomGridColumns, spacing: 8) {
            bottomButton(icon: .shop, label: "SHOP", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .shop)
            }

            bottomButton(icon: .collection, label: "COLLECTION", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .collection)
            }

            bottomButton(icon: .trophy, label: "ACHIEVE", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .achievements)
            }

            bottomButton(icon: .ribbon, label: "LEADERBOARD", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .leaderboard)
            }

            bottomButton(icon: .stats, label: "STATS", locked: isGuest) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .stats)
            }

            bottomButton(icon: .star, label: "FRIENDS", locked: isGuest, badge: pendingFriendRequestCount > 0 ? "\(pendingFriendRequestCount)" : nil) {
                if isGuest { showSignInPrompt = true; return }
                SoundManager.shared.play(.button)
                manager.navigate(to: .friends)
            }

            bottomButton(icon: .settings, label: "SETTINGS") {
                SoundManager.shared.play(.button)
                manager.navigate(to: .settings)
            }
        }
    }

    private func bottomButton(icon: PixelIcon, label: String, locked: Bool = false, badge: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                pixelIcon(icon, size: 32)
                Text(label)
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(GK.Colors.panelCream)
                    .shadow(color: Color.black.opacity(0.15), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(GK.Colors.panelBorder, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.red))
                        .offset(x: 6, y: -6)
                }
            }
            .overlay(alignment: .topTrailing) {
                if locked {
                    Image(uiImage: PixelIconFactory.shared.image(for: .lock, pixelScale: 1.5))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 10, height: 10)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .opacity(locked ? 0.45 : 1.0)
        .accessibilityIdentifier(label)
        .accessibilityLabel(locked ? "\(label), sign in to unlock" : label)
    }

    // MARK: - Helpers

    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

// MARK: - Pixel Cloud (procedural, same as Day theme)

private struct PixelCloud: View {
    let scale: CGFloat
    let yOffset: CGFloat
    let duration: Double
    let screenWidth: CGFloat

    @State private var xOffset: CGFloat

    init(scale: CGFloat, yOffset: CGFloat, duration: Double, screenWidth: CGFloat) {
        self.scale = scale
        self.yOffset = yOffset
        self.duration = duration
        self.screenWidth = screenWidth
        let baseW: CGFloat = 90 * scale
        _xOffset = State(initialValue: -baseW)
    }

    var body: some View {
        Image(uiImage: TextureFactory.shared.cloudUIImage())
            .interpolation(.none)
            .resizable()
            .frame(width: 90 * scale, height: 40 * scale)
            .offset(x: xOffset, y: yOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    xOffset = screenWidth + 90 * scale
                }
            }
    }
}
