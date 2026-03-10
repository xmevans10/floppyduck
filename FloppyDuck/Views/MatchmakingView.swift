import SwiftUI
import UIKit

struct MultiplayerModesView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer().frame(height: 30)

                HStack {
                    backButton
                    Spacer()
                    Text("HEAD TO HEAD")
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
                               subtitle: "Fast matchmaking") {
                        manager.startMatchmaking(mode: .quickPlay)
                    }

                    modeButton(icon: .trophy,
                               title: "RANKED",
                               subtitle: auth.isAppleLinked ? "Competitive ELO" : "Sign in required") {
                        if manager.startMatchmaking(mode: .ranked) {
                            return
                        }
                        auth.showRankedSignInPrompt = true
                    }
                    .overlay(alignment: .topTrailing) {
                        if !auth.isAppleLinked {
                            Text("LOCKED")
                                .font(.custom(GK.pixelFontName, size: 6))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(GK.Colors.buttonRed))
                                .offset(x: -6, y: 6)
                        }
                    }

                    modeButton(icon: .lock,
                               title: "PRIVATE ROOM",
                               subtitle: "Create or join by code") {
                        manager.startMatchmaking(mode: .privateRoom)
                    }
                }
                .padding(.horizontal, 28)

                VStack(spacing: 6) {
                    Text(auth.isAppleLinked ? "CURRENT ELO" : "GUEST MODE")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.65))

                    Text(auth.isAppleLinked ? "\(manager.stats.elo)" : "SIGN IN FOR RANKED")
                        .font(.custom(GK.pixelFontName, size: 16))
                        .foregroundColor(GK.Colors.scoreYellow)
                }
                .padding(.top, 6)

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .alert("Ranked Requires Sign In", isPresented: $auth.showRankedSignInPrompt) {
            Button("NOT NOW", role: .cancel) {}
            Button("SIGN IN WITH APPLE") {
                Task {
                    await auth.signInWithApple()
                }
            }
        } message: {
            Text("Ranked requires Sign in with Apple. Quick Play and Private Room work as guest.")
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
                .background(Circle().fill(Color.white.opacity(0.2)))
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

    private let icons = PixelIconFactory.shared
    private let dotTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
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
            Task { await manager.cancelMatchmaking() }
        }
    }

    // MARK: - Views

    private var modeTitle: String {
        switch mode {
        case .quickPlay: return "HEAD TO HEAD"
        case .ranked: return "RANKED"
        case .privateRoom: return "PRIVATE ROOM"
        }
    }

    private var searchingContent: some View {
        VStack(spacing: 12) {
            Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 3.0))
                .interpolation(.none)
                .resizable()
                .frame(width: 50, height: 38)

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
            return mode == .privateRoom
                ? "Create a room or join one with a 5-character code."
                : "Searching for an opponent..."
        case .searching:
            return mode == .privateRoom
                ? "Searching\(dots)"
                : "Matchmaking in progress\(dots)"
        case .waitingRoom(let code):
            return "Share code \(code). Waiting for opponent\(dots)"
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
                }
            }
        }
    }

    private func createRoomAndWait() {
        cancelPendingSearch()
        createdRoomCode = nil
        state = .searching
        isWorking = true

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
                }
            }
        }
    }

    private func joinRoomAndWait() {
        cancelPendingSearch()
        state = .searching
        isWorking = true
        let code = roomCode

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
                }
            }
        }
    }

    private func cancelAndReturnHome() {
        cancelPendingSearch()
        Task {
            await manager.cancelMatchmaking()
            await MainActor.run {
                manager.goHome()
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
            return .failed("Sign in with Apple is required for ranked matchmaking.")
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
