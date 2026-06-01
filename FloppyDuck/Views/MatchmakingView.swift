import SwiftUI
import UIKit

struct MultiplayerModesView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var showFeatureSignInPrompt: Bool = false
    private let icons = PixelIconFactory.shared

    private var needsGameCenterAuth: Bool { !auth.hasGameCenterMultiplayerAccess }

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 30)

                HStack {
                    backButton
                    Spacer()
                    Text("MULTIPLAYER")
                        .font(.custom(GK.pixelFontName, size: 16))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)

                VStack(spacing: 12) {
                    modeButton(icon: .play,
                               title: "QUICK PLAY",
                               subtitle: needsGameCenterAuth ? "Game Center required" : "Fast matchmaking") {
                        Task { await startHeadToHeadMode(.quickPlay) }
                    }
                    .overlay(alignment: .topTrailing) {
                        if needsGameCenterAuth {
                            lockedBadge
                        }
                    }
                    .opacity(needsGameCenterAuth ? 0.5 : 1.0)

                    modeButton(icon: .trophy,
                               title: "RANKED",
                               subtitle: needsGameCenterAuth ? "Game Center required" : "Competitive ELO") {
                        Task { await startHeadToHeadMode(.ranked) }
                    }
                    .overlay(alignment: .topTrailing) {
                        if needsGameCenterAuth {
                            lockedBadge
                        }
                    }
                    .opacity(needsGameCenterAuth ? 0.5 : 1.0)

                    modeButton(icon: .lock,
                               title: "PRIVATE ROOM",
                               subtitle: needsGameCenterAuth ? "Game Center required" : "Create or join by code") {
                        Task { await startHeadToHeadMode(.privateRoom) }
                    }
                    .overlay(alignment: .topTrailing) {
                        if needsGameCenterAuth {
                            lockedBadge
                        }
                    }
                    .opacity(needsGameCenterAuth ? 0.5 : 1.0)

                    modeButton(icon: .trophy,
                               title: "BATTLE ROYALE",
                               subtitle: "25 bread buy-in - payouts shown") {
                        manager.startMatchmaking(mode: .battleRoyale)
                    }
                    .opacity(manager.stats.bread >= 25 ? 1.0 : 0.55)
                }
                .padding(.horizontal, 28)

                multiplayerEloBadge
                .padding(.top, 6)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            auth.refreshGameCenterAuthenticationState(reason: "multiplayer_modes_appear")
        }
        .alert("Game Center Required", isPresented: $showFeatureSignInPrompt) {
            Button("NOT NOW", role: .cancel) {}
            if auth.needsGameCenterSettingsRecovery {
                Button("OPEN SETTINGS") {
                    openSettings()
                }
            }
            Button("SIGN IN WITH GAME CENTER") {
                Task { await auth.signInWithGameCenter() }
            }
        } message: {
            Text(auth.statusMessage ?? "Quick Play, Ranked, and Private Room require Game Center for realtime head-to-head.")
        }
        .alert("Game Center Required", isPresented: $auth.showRankedSignInPrompt) {
            Button("NOT NOW", role: .cancel) {}
            if auth.needsGameCenterSettingsRecovery {
                Button("OPEN SETTINGS") {
                    openSettings()
                }
            }
            Button("SIGN IN WITH GAME CENTER") {
                Task {
                    await auth.signInWithGameCenter()
                }
            }
        } message: {
            Text(auth.statusMessage ?? "Quick Play, Ranked, and Private Room require Game Center for realtime head-to-head.")
        }
    }

    private var multiplayerEloBadge: some View {
        VStack(spacing: 5) {
            Text(auth.hasGameCenterMultiplayerAccess ? "CURRENT ELO" : "GAME CENTER")
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.72))

            Text(auth.hasGameCenterMultiplayerAccess ? "\(manager.stats.elo)" : "SIGN IN FOR HEAD-TO-HEAD")
                .font(.custom(GK.pixelFontName, size: needsGameCenterAuth ? 8 : 16))
                .foregroundColor(GK.Colors.scoreYellow)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.scoreYellow.opacity(0.28), lineWidth: 2)
                )
        )
        .accessibilityLabel(auth.hasGameCenterMultiplayerAccess ? "Current ELO: \(manager.stats.elo)" : "Game Center sign in required for head-to-head")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private var lockedBadge: some View {
        Text("LOCKED")
            .font(.custom(GK.pixelFontName, size: 6))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(GK.Colors.buttonRed))
            .offset(x: -6, y: 6)
    }

    @MainActor
    private func startHeadToHeadMode(_ mode: MatchmakingMode) async {
        print("[MultiplayerModesView] head-to-head mode tapped:\(mode.rawValue) needsGameCenterAuth:\(needsGameCenterAuth)")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "head_to_head_mode_tapped",
            message: "User tapped a head-to-head mode.",
            mode: mode.rawValue,
            metadata: ["needsGameCenterAuth": String(needsGameCenterAuth)]
        )
        guard await auth.ensureGameCenterAuthenticated() else {
            MultiplayerDiagnostics.record(
                category: "auth",
                event: "head_to_head_auth_failed",
                level: "error",
                message: auth.statusMessage ?? "Game Center authentication failed.",
                mode: mode.rawValue
            )
            showFeatureSignInPrompt = true
            return
        }

        if !manager.startMatchmaking(mode: mode) {
            MultiplayerDiagnostics.record(
                category: "matchmaking",
                event: "head_to_head_route_failed",
                level: "error",
                message: "GameManager refused to open matchmaking route.",
                mode: mode.rawValue
            )
            showFeatureSignInPrompt = true
        }
    }

    private func modeButton(icon: PixelIcon,
                            title: String,
                            subtitle: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                pixelIcon(icon, size: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                pixelIcon(.play, size: 14)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(GK.Colors.buttonBlue)
                    .shadow(color: GK.Colors.buttonBlue.opacity(0.45), radius: 0, x: 0, y: 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    private var backButton: some View {
        Button {
            manager.goHome()
        } label: {
            Image(uiImage: icons.image(for: .back))
                .interpolation(.none)
                .resizable()
                .frame(width: 28, height: 28)
                .padding(8)
                .background(PixelButtonBackground(style: .light, size: 44))
        }
        .buttonStyle(.plain)
    }
}

struct MatchmakingView: View {
    let mode: MatchmakingMode

    @EnvironmentObject var manager: GameManager

    @State private var dots = ""
    @State private var roomCode = ""
    @State private var createdRoomCode: String?
    @State private var copiedCode: Bool = false
    @State private var state: MatchmakingState = .idle
    @State private var roomAction: PrivateRoomAction = .create
    @State private var isWorking: Bool = false
    @State private var searchTask: Task<Void, Never>?
    @State private var battleRoyaleAssignment: BattleRoyaleAssignment?
    @State private var battleRoyaleState: BattleRoyaleState?
    @State private var brCountdown: Int = 45
    private let brCountdownTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let icons = PixelIconFactory.shared
    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            GeometryReader { geo in
                Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                pixelIcon(headerIcon, size: 44)

                Text(modeTitle)
                    .font(.custom(GK.pixelFontName, size: 18))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

                VStack(spacing: 16) {
                    switch mode {
                    case .quickPlay, .ranked:
                        searchingContent
                    case .privateRoom:
                        privateRoomContent
                    case .battleRoyale:
                        battleRoyaleContent
                    }
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(GK.Colors.panelCream)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GK.Colors.panelBorder, lineWidth: 3)
                )
                .padding(.horizontal, 28)

                Spacer()

                Button {
                    cancelAndReturnHome()
                } label: {
                    HStack(spacing: 8) {
                        pixelIcon(.cancel, size: 16)
                        Text("CANCEL")
                            .font(.custom(GK.pixelFontName, size: 10))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(GK.Colors.buttonRed)
                            .shadow(color: GK.Colors.buttonRed.opacity(0.4), radius: 0, x: 0, y: 3)
                    )
                    .overlay(Capsule().stroke(Color.black.opacity(0.3), lineWidth: 2))
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 30)
            }
        }
        .navigationBarHidden(true)
        .onAppear(perform: onAppear)
        .onDisappear(perform: onDisappear)
        .onReceive(dotTimer) { _ in
            dots = dots.count >= 3 ? "" : dots + "."
        }
    }

    // MARK: - State

    private enum MatchmakingState: Equatable {
        case idle
        case searching
        case waitingRoom(String)
        case timedOut
        case failed(String)
        case matched
    }

    private enum PrivateRoomAction {
        case create
        case join
    }

    // MARK: - Lifecycle

    private func onAppear() {
        if mode == .quickPlay || mode == .ranked {
            startQueueSearch()
        }
    }

    private func onDisappear() {
        if isWorking {
            searchTask?.cancel()
            if let lobbyId = battleRoyaleAssignment?.lobbyId {
                Task { await manager.leaveBattleRoyaleLobby(lobbyId: lobbyId) }
            } else {
                Task { await manager.cancelMatchmaking() }
            }
        }
    }

    // MARK: - Views

    private var modeTitle: String {
        switch mode {
        case .quickPlay: return "MULTIPLAYER"
        case .ranked: return "RANKED"
        case .privateRoom: return "PRIVATE ROOM"
        case .battleRoyale: return "BATTLE ROYALE"
        }
    }

    private var searchingContent: some View {
        VStack(spacing: 12) {
            Image(uiImage: TextureFactory.shared.skinDuckUIImage(skin: SkinManager.shared.selectedSkin, pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)

            Text("SEARCHING\(dots)")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.panelBorder)
                .frame(width: 200, alignment: .center)

            if mode == .ranked {
                HStack(spacing: 6) {
                    pixelIcon(.trophy, size: 14)
                    Text("ELO: \(manager.stats.elo)")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))
                }
            }

            statusText
            retryButton
        }
    }

    private var privateRoomContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                roomActionButton(title: "CREATE", selected: roomAction == .create) {
                    roomAction = .create
                    state = .idle
                }
                roomActionButton(title: "JOIN", selected: roomAction == .join) {
                    roomAction = .join
                    state = .idle
                }
            }

            if roomAction == .create {
                VStack(spacing: 10) {
                    Text("ROOM CODE")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                    Button {
                        if let code = createdRoomCode {
                            UIPasteboard.general.string = code
                            SoundManager.shared.play(.button)
                            copiedCode = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedCode = false
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(createdRoomCode ?? "-----")
                                .font(.custom(GK.pixelFontName, size: 20))
                                .foregroundColor(GK.Colors.panelBorder)
                            if createdRoomCode != nil {
                                Text(copiedCode ? "COPIED!" : "TAP TO COPY")
                                    .font(.custom(GK.pixelFontName, size: 6))
                                    .foregroundColor(copiedCode ? GK.Colors.buttonGreen : GK.Colors.panelBorder.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(createdRoomCode != nil ? GK.Colors.panelBorder.opacity(0.5) : GK.Colors.panelBorder.opacity(0.3), lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(createdRoomCode == nil)
                    .accessibilityLabel(createdRoomCode != nil ? "Room code \(createdRoomCode!). Tap to copy" : "Room code pending")

                    actionButton(title: createdRoomCode == nil ? "CREATE ROOM" : "RETRY") {
                        createRoomAndWait()
                    }
                }
            } else {
                VStack(spacing: 10) {
                    Text("ROOM CODE")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                    TextField("", text: $roomCode)
                        .font(.custom(GK.pixelFontName, size: 20))
                        .foregroundColor(GK.Colors.panelBorder)
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.characters)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(GK.Colors.panelBorder.opacity(0.3), lineWidth: 2)
                                )
                        )
                        .onChange(of: roomCode) { _, value in
                            roomCode = String(value.prefix(GK.roomCodeLength)).uppercased()
                        }

                    actionButton(title: "JOIN ROOM") {
                        joinRoomAndWait()
                    }
                    .disabled(roomCode.count != GK.roomCodeLength)
                    .opacity(roomCode.count == GK.roomCodeLength ? 1 : 0.5)
                }
            }

            statusText
            retryButton
        }
    }

    private var battleRoyaleContent: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                pixelIcon(.trophy, size: 20)
                VStack(alignment: .leading, spacing: 4) {
                    Text("25 BREAD BUY-IN")
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(GK.Colors.panelBorder)
                    Text(battleRoyalePayoutPreviewText)
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.55))
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                }
                Spacer()
                Text("\(manager.stats.bread)")
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(GK.Colors.scoreYellow)
            }

            if let state = battleRoyaleState {
                battleRoyaleLobbyCount(players: state.playerCount,
                                       maxPlayers: state.maxPlayers,
                                       detail: state.status == .active ? "\(state.aliveCount) ALIVE" : "FILLING TO 100")
            } else if let assignment = battleRoyaleAssignment {
                battleRoyaleLobbyCount(players: assignment.playerCount,
                                       maxPlayers: assignment.maxPlayers,
                                       detail: "WAITING FOR LOBBY\(dots)")
            }

            actionButton(title: battleRoyaleAssignment == nil ? "JOIN - 25 BREAD" : "WAITING") {
                joinBattleRoyaleAndWait()
            }
            .disabled(isWorking || battleRoyaleAssignment != nil || manager.stats.bread < 25)
            .opacity((!isWorking && battleRoyaleAssignment == nil && manager.stats.bread >= 25) ? 1 : 0.5)

            statusText
            retryButton
        }
    }

    private var battleRoyalePayoutPreviewText: String {
        let buyIn = battleRoyaleState?.buyIn ?? battleRoyaleAssignment?.buyIn ?? 25
        let maxPlayers = battleRoyaleState?.maxPlayers ?? battleRoyaleAssignment?.maxPlayers ?? 100
        let poolAfterSink = Int(Double(maxPlayers * buyIn) * 0.95)
        let payouts = [0.40, 0.25, 0.15, 0.12, 0.08].map { Int(Double(poolAfterSink) * $0) }
        let preview = payouts.enumerated()
            .map { "#\($0.offset + 1) \($0.element)" }
            .joined(separator: "  ")
        return "TOP 5 PAID: \(preview)"
    }

    private func battleRoyaleLobbyCount(players: Int, maxPlayers: Int, detail: String) -> some View {
        VStack(spacing: 6) {
            Text("\(players)/\(maxPlayers) DUCKS")
                .font(.custom(GK.pixelFontName, size: 12))
                .foregroundColor(GK.Colors.panelBorder)
            Text(detail)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(GK.Colors.panelBorder.opacity(0.55))
                .multilineTextAlignment(.center)
            if let assignment = battleRoyaleAssignment, assignment.status == .open {
                Text("STARTS IN \(brCountdown)S")
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.scoreYellow)
            }
        }
        .onReceive(brCountdownTimer) { _ in
            if let assignment = battleRoyaleAssignment, assignment.status == .open {
                let now = Int(Date().timeIntervalSince1970 * 1000)
                let deadline = assignment.joinDeadlineAt ?? (assignment.createdAt + 45_000)
                brCountdown = max(0, Int(ceil(Double(deadline - now) / 1000.0)))
            } else {
                brCountdown = 45
            }
        }
    }

    private var statusText: some View {
        Text(statusMessage)
            .font(.custom(GK.pixelFontName, size: 7))
            .foregroundColor(statusColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
    }

    private var statusMessage: String {
        switch state {
        case .idle:
            if mode == .privateRoom {
                return "Create a room or join one with a 5-character code."
            }
            if mode == .battleRoyale {
                return manager.stats.bread >= 25
                    ? "Join the pool. Last duck standing wins."
                    : "You need 25 bread to join."
            }
            return "Searching for an opponent..."
        case .searching:
            return mode == .privateRoom
                ? "Searching\(dots)"
                : "Matchmaking in progress\(dots)"
        case .waitingRoom(let code):
            return mode == .battleRoyale
                ? "Lobby \(code). Waiting for ducks\(dots)"
                : "Share code \(code). Waiting for opponent\(dots)"
        case .timedOut:
            return "Matchmaking timed out. Retry to keep searching."
        case .failed(let msg):
            return msg
        case .matched:
            return "Match found. Launching..."
        }
    }

    private var statusColor: Color {
        switch state {
        case .failed:
            return GK.Colors.buttonRed
        case .timedOut:
            return GK.Colors.buttonOrange
        default:
            return GK.Colors.panelBorder.opacity(0.5)
        }
    }

    private var shouldShowRetry: Bool {
        switch state {
        case .failed, .timedOut:
            return true
        default:
            return false
        }
    }

    @ViewBuilder
    private var retryButton: some View {
        if shouldShowRetry {
            Button {
                retryCurrentFlow()
            } label: {
                HStack(spacing: 6) {
                    pixelIcon(.retry, size: 13)
                    Text("RETRY")
                        .font(.custom(GK.pixelFontName, size: 8))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(GK.Colors.buttonBlue)
                        .shadow(color: GK.Colors.buttonBlue.opacity(0.45), radius: 0, x: 0, y: 2)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func startQueueSearch() {
        cancelPendingSearch()
        state = .searching
        isWorking = true
        print("[MatchmakingView] startQueueSearch mode:\(mode.rawValue)")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "queue_search_started",
            message: "User started queue search.",
            mode: mode.rawValue
        )

        searchTask = Task {
            do {
                let assignment = try await manager.queueForMatch(mode: mode)
                await MainActor.run {
                    isWorking = false
                    state = .matched
                    manager.startHeadToHead(matchAssignment: assignment)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    isWorking = false
                    state = errorToState(error)
                    MultiplayerDiagnostics.record(
                        category: "matchmaking",
                        event: "queue_search_failed",
                        level: "error",
                        message: error.localizedDescription,
                        mode: mode.rawValue
                    )
                }
            }
        }
    }

    private func createRoomAndWait() {
        cancelPendingSearch()
        createdRoomCode = nil
        state = .searching
        isWorking = true
        print("[MatchmakingView] createRoomAndWait")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "private_room_create_started",
            message: "User started private room creation.",
            mode: mode.rawValue
        )

        searchTask = Task {
            do {
                let code = try await manager.createPrivateRoom()
                await MainActor.run {
                    createdRoomCode = code
                    state = .waitingRoom(code)
                }

                let assignment = try await manager.waitForPrivateRoomMatch()
                await MainActor.run {
                    isWorking = false
                    state = .matched
                    manager.startHeadToHead(matchAssignment: assignment)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    isWorking = false
                    state = errorToState(error)
                    MultiplayerDiagnostics.record(
                        category: "matchmaking",
                        event: "private_room_create_failed",
                        level: "error",
                        message: error.localizedDescription,
                        mode: mode.rawValue
                    )
                }
            }
        }
    }

    private func joinRoomAndWait() {
        cancelPendingSearch()
        state = .searching
        isWorking = true
        let code = roomCode
        print("[MatchmakingView] joinRoomAndWait code:\(code)")
        MultiplayerDiagnostics.record(
            category: "matchmaking",
            event: "private_room_join_started",
            message: "User started private room join.",
            mode: mode.rawValue,
            metadata: ["roomCode": code]
        )

        searchTask = Task {
            do {
                try await manager.joinPrivateRoom(code: code)
                await MainActor.run {
                    createdRoomCode = code
                    state = .waitingRoom(code)
                }

                let assignment = try await manager.waitForPrivateRoomMatch()
                await MainActor.run {
                    isWorking = false
                    state = .matched
                    manager.startHeadToHead(matchAssignment: assignment)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    isWorking = false
                    state = errorToState(error)
                    MultiplayerDiagnostics.record(
                        category: "matchmaking",
                        event: "private_room_join_failed",
                        level: "error",
                        message: error.localizedDescription,
                        mode: mode.rawValue,
                        metadata: ["roomCode": code]
                    )
                }
            }
        }
    }

    private func joinBattleRoyaleAndWait() {
        cancelPendingSearch()
        state = .searching
        isWorking = true
        battleRoyaleAssignment = nil
        battleRoyaleState = nil

        searchTask = Task {
            do {
                let assignment = try await manager.joinBattleRoyaleLobby()
                await MainActor.run {
                    battleRoyaleAssignment = assignment
                    state = .waitingRoom(assignment.roomCode ?? String(assignment.lobbyId.prefix(5)).uppercased())
                }

                while !Task.isCancelled {
                    let latest = try await manager.startBattleRoyaleIfReady(lobbyId: assignment.lobbyId)
                    await MainActor.run {
                        battleRoyaleState = latest
                    }

                    if latest.status == .active {
                        await MainActor.run {
                            isWorking = false
                            state = .matched
                            manager.startBattleRoyale(assignment: BattleRoyaleAssignment(
                                lobbyId: latest.lobbyId,
                                entrantId: latest.entrantId,
                                roomCode: latest.roomCode ?? battleRoyaleAssignment?.roomCode,
                                seed: latest.seed,
                                status: latest.status,
                                playerCount: latest.playerCount,
                                aliveCount: latest.aliveCount,
                                buyIn: latest.buyIn,
                                maxPlayers: latest.maxPlayers,
                                bread: manager.stats.bread,
                                createdAt: battleRoyaleAssignment?.createdAt ?? Int(Date().timeIntervalSince1970 * 1000),
                                joinDeadlineAt: battleRoyaleAssignment?.joinDeadlineAt
                            ))
                        }
                        return
                    }

                    if latest.status == .cancelled || latest.status == .finished {
                        await MainActor.run {
                            isWorking = false
                            state = .failed("Lobby closed. Your buy-in was refunded if it had not started.")
                        }
                        return
                    }

                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    isWorking = false
                    state = errorToState(error)
                }
            }
        }
    }

    private func cancelAndReturnHome() {
        cancelPendingSearch()
        Task {
            if let lobbyId = battleRoyaleAssignment?.lobbyId {
                await manager.leaveBattleRoyaleLobby(lobbyId: lobbyId)
            } else {
                await manager.cancelMatchmaking()
            }
            await MainActor.run {
                if !manager.path.isEmpty {
                    manager.path.removeLast()
                }
            }
        }
    }

    private func cancelPendingSearch() {
        if isWorking {
            searchTask?.cancel()
            searchTask = nil
            isWorking = false
        }
    }

    private func errorToState(_ error: Error) -> MatchmakingState {
        if let sessionError = error as? MultiplayerSessionError,
           case .timeout = sessionError {
            return .timedOut
        }

        let raw = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return .failed("Could not connect to matchmaking. Check connection and retry.")
        }
        let lowered = raw.lowercased()

        if lowered.contains("network") || lowered.contains("offline") ||
            lowered.contains("timed out") || lowered.contains("request failed") {
            return .failed("Connection issue. Check internet and tap retry.")
        }

        if lowered.contains("sign in") {
            return .failed(mode == .battleRoyale ? "Could not join Battle Royale." : "Game Center sign in is required for ranked matchmaking.")
        }

        if lowered.contains("insufficient") || lowered.contains("bread") {
            return .failed("You need 25 bread to join Battle Royale.")
        }

        if lowered.contains("resolve user identity") || lowered.contains("device identity") {
            return .failed("Profile sync issue. Tap retry.")
        }

        if raw.count <= 96 {
            return .failed(raw)
        }

        return .failed("Matchmaking failed. Tap retry.")
    }

    private var headerIcon: PixelIcon {
        switch mode {
        case .quickPlay:
            return .play
        case .ranked:
            return .trophy
        case .privateRoom:
            return .lock
        case .battleRoyale:
            return .trophy
        }
    }

    private func retryCurrentFlow() {
        switch mode {
        case .quickPlay, .ranked:
            startQueueSearch()
        case .privateRoom:
            if roomAction == .create {
                createRoomAndWait()
            } else {
                joinRoomAndWait()
            }
        case .battleRoyale:
            joinBattleRoyaleAndWait()
        }
    }

    // MARK: - Components

    private func roomActionButton(title: String,
                                  selected: Bool,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(selected ? .white : GK.Colors.panelBorder)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? GK.Colors.buttonBlue : Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(GK.Colors.panelBorder.opacity(0.35), lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(GK.Colors.buttonGreen)
                        .shadow(color: GK.Colors.pipeDarkGreen, radius: 0, x: 0, y: 3)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.pipeBorder, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
