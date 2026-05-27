import SwiftUI

enum FriendsTab: String, CaseIterable {
    case friends = "FRIENDS"
    case pending = "REQUESTS"
    case search = "ADD"

    var icon: PixelIcon {
        switch self {
        case .friends: return .headToHead
        case .pending: return .chick
        case .search: return .play
        }
    }
}

struct FriendsView: View {
    @EnvironmentObject var manager: GameManager

    @State private var selectedTab: FriendsTab = .friends
    @State private var friends: [PublicPlayerProfile] = []
    @State private var pendingRequests: [PublicPlayerProfile] = []
    @State private var searchQuery: String = ""
    @State private var searchResults: [PublicPlayerProfile] = []
    @State private var isLoading = true
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var confirmRemoveUserId: String?

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                headerView
                customTabBar
                    .padding(.top, 10)
                contentView
            }

            // Toast overlay
            if let toast = toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.85))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                        )
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3), value: toast)
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadData()
        }
    }

    // MARK: - Background

    private var backgroundView: some View {
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

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Button {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                manager.goHome()
            } label: {
                Image(uiImage: icons.image(for: .back, pixelScale: 3.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .padding(8)
                    .background(PixelButtonBackground(style: .light, size: 44))
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("FRIENDS")
                .font(.custom(GK.pixelFontName, size: 18))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
            Spacer()
            // Badge count for pending requests
            if !pendingRequests.isEmpty && selectedTab != .pending {
                Text("\(pendingRequests.count)")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(GK.Colors.buttonRed))
                    .padding(.trailing, 4)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                let isActive = selectedTab == tab
                Button {
                    SoundManager.shared.play(.button)
                    Haptic.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = tab
                    }
                    Task { await loadData() }
                } label: {
                    VStack(spacing: 4) {
                        Image(uiImage: icons.image(for: tab.icon, pixelScale: 2.0))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .colorMultiply(isActive ? .white : .white.opacity(0.5))

                        Text(tab.rawValue)
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(isActive ? .white : .white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        Group {
                            if isActive {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GK.Colors.buttonBlue)
                                    .shadow(color: GK.Colors.buttonBlue.opacity(0.4), radius: 6, x: 0, y: 2)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.black.opacity(0.15))
                            }
                        }
                    )
                    .overlay(
                        // Pending badge on requests tab
                        Group {
                            if tab == .pending && !pendingRequests.isEmpty {
                                Text("\(pendingRequests.count)")
                                    .font(.custom(GK.pixelFontName, size: 6))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(GK.Colors.buttonRed))
                                    .offset(x: 8, y: -8)
                            }
                        },
                        alignment: .topTrailing
                    )
                }
                .buttonStyle(.plain)

                if tab != FriendsTab.allCases.last {
                    Spacer().frame(width: 6)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("LOADING...")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
        } else if let error = errorMessage {
            Spacer()
            errorPanel(error)
            Spacer()
        } else {
            switch selectedTab {
            case .friends:
                friendsList
            case .pending:
                pendingList
            case .search:
                searchView
            }
        }
    }

    private func errorPanel(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(uiImage: icons.image(for: .warning, pixelScale: 4.0))
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 36, height: 36)
            Text("ERROR")
                .font(.custom(GK.pixelFontName, size: 9))
                .foregroundColor(.white)
            Text(error)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button {
                Task { await loadData() }
            } label: {
                Text("RETRY")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }

    // MARK: - Friends List

    private var friendsList: some View {
        Group {
            if friends.isEmpty {
                emptyView(icon: .headToHead, message: "NO FRIENDS YET",
                           subtitle: "TAP THE ADD TAB TO FIND PLAYERS")
            } else {
                ScrollView(showsIndicators: false) {
                    // Friend count header
                    HStack {
                        Text("\(friends.count) FRIEND\(friends.count == 1 ? "" : "S")")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(.white.opacity(0.4))
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                    LazyVStack(spacing: 10) {
                        ForEach(friends) { friend in
                            friendCard(friend)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Pending Requests

    private var pendingList: some View {
        Group {
            if pendingRequests.isEmpty {
                emptyView(icon: .chick, message: "NO REQUESTS",
                           subtitle: "FRIEND REQUESTS WILL SHOW UP HERE")
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(pendingRequests) { request in
                            pendingCard(request)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Search

    private var searchView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(uiImage: icons.image(for: .questionMark, pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 12, height: 12)
                        .opacity(0.4)

                    TextField("SEARCH USERNAME...", text: $searchQuery)
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(GK.Colors.panelBorder)
                        .autocapitalization(.none)
                        .onSubmit {
                            Task { await performSearch() }
                        }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(GK.Colors.panelCream)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(GK.Colors.panelBorder.opacity(0.3), lineWidth: 2)
                        )
                )

                Button {
                    SoundManager.shared.play(.button)
                    Task { await performSearch() }
                } label: {
                    Text("GO")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(GK.Colors.buttonBlue)
                                .shadow(color: GK.Colors.buttonBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).count < 2)
                .opacity(searchQuery.trimmingCharacters(in: .whitespaces).count < 2 ? 0.5 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            if isSearching {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("SEARCHING...")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                emptyView(icon: .questionMark, message: "NO PLAYERS FOUND",
                           subtitle: "TRY A DIFFERENT USERNAME")
            } else if !searchResults.isEmpty {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(searchResults) { result in
                            searchCard(result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 30)
                }
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(uiImage: icons.image(for: .headToHead, pixelScale: 4.0))
                        .interpolation(.none)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .opacity(0.25)
                    Text("SEARCH FOR PLAYERS")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white.opacity(0.35))
                    Text("TYPE A USERNAME ABOVE")
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(.white.opacity(0.2))
                }
                Spacer()
            }
        }
    }

    // MARK: - Card Views

    private func friendCard(_ friend: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar area
            ZStack {
                Circle()
                    .fill(GK.Colors.buttonBlue.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(uiImage: icons.image(for: .headToHead, pixelScale: 3.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(friend.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(uiImage: icons.image(for: .trophy, pixelScale: 1.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 8, height: 8)
                        Text("\(friend.stats.elo)")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.45))
                    }

                    Text("·")
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.25))

                    HStack(spacing: 3) {
                        Image(uiImage: icons.image(for: .stats, pixelScale: 1.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 8, height: 8)
                        Text("\(friend.stats.gamesPlayed)")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.45))
                    }
                }
            }

            Spacer()

            // View profile button
            Button {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                manager.navigate(to: .publicProfile(friend.userId))
            } label: {
                Text("VIEW")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(GK.Colors.buttonBlue)
                            .shadow(color: GK.Colors.buttonBlue.opacity(0.25), radius: 3, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)

            // Remove button
            Button {
                SoundManager.shared.play(.button)
                Task { await removeFriend(friend.userId) }
            } label: {
                Image(uiImage: icons.image(for: .cancel, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(GK.Colors.buttonRed.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(friend.username)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GK.Colors.panelCream)
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GK.Colors.panelBorder.opacity(0.12), lineWidth: 2)
        )
    }

    private func pendingCard(_ request: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar area with green pulse
            ZStack {
                Circle()
                    .fill(GK.Colors.buttonGreen.opacity(0.15))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(GK.Colors.buttonGreen.opacity(0.3), lineWidth: 2)
                    .frame(width: 44, height: 44)
                Image(uiImage: icons.image(for: .chick, pixelScale: 3.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(request.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)
                Text("WANTS TO BE FRIENDS")
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.buttonGreen)
            }

            Spacer()

            // Accept button
            Button {
                SoundManager.shared.play(.button)
                Haptic.medium()
                Task { await acceptRequest(request.userId) }
            } label: {
                HStack(spacing: 4) {
                    Image(uiImage: icons.image(for: .checkmark, pixelScale: 2.0))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 10, height: 10)
                    Text("ACCEPT")
                        .font(.custom(GK.pixelFontName, size: 6))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(GK.Colors.buttonGreen)
                        .shadow(color: GK.Colors.buttonGreen.opacity(0.3), radius: 3, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept \(request.username)")

            // Decline button
            Button {
                SoundManager.shared.play(.button)
                Task { await removeFriend(request.userId) }
            } label: {
                Image(uiImage: icons.image(for: .cancel, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 12, height: 12)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(GK.Colors.buttonRed.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decline \(request.username)")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GK.Colors.panelCream)
                .shadow(color: GK.Colors.buttonGreen.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GK.Colors.buttonGreen.opacity(0.25), lineWidth: 2)
        )
    }

    private func searchCard(_ result: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(GK.Colors.panelBorder.opacity(0.08))
                    .frame(width: 44, height: 44)
                Image(uiImage: icons.image(for: .duck, pixelScale: 3.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(result.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(uiImage: icons.image(for: .trophy, pixelScale: 1.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 8, height: 8)
                        Text("\(result.stats.elo)")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.45))
                    }

                    Text("·")
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(GK.Colors.panelBorder.opacity(0.25))

                    HStack(spacing: 3) {
                        Image(uiImage: icons.image(for: .stats, pixelScale: 1.5))
                            .interpolation(.none)
                            .resizable()
                            .frame(width: 8, height: 8)
                        Text("\(result.stats.gamesPlayed)")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.panelBorder.opacity(0.45))
                    }
                }
            }

            Spacer()

            // View profile
            Button {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                manager.navigate(to: .publicProfile(result.userId))
            } label: {
                Text("VIEW")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(GK.Colors.buttonBlue)
                    )
            }
            .buttonStyle(.plain)

            // Add friend
            Button {
                SoundManager.shared.play(.button)
                Haptic.medium()
                Task { await addFriend(result.userId) }
            } label: {
                HStack(spacing: 4) {
                    Text("+")
                        .font(.custom(GK.pixelFontName, size: 9))
                    Text("ADD")
                        .font(.custom(GK.pixelFontName, size: 7))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(GK.Colors.buttonGreen)
                        .shadow(color: GK.Colors.buttonGreen.opacity(0.25), radius: 3, x: 0, y: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(GK.Colors.panelCream)
                .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GK.Colors.panelBorder.opacity(0.12), lineWidth: 2)
        )
    }

    // MARK: - Empty View

    private func emptyView(icon: PixelIcon, message: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 64, height: 64)
                Image(uiImage: icons.image(for: icon, pixelScale: 4.0))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .opacity(0.3)
            }
            Text(message)
                .font(.custom(GK.pixelFontName, size: 9))
                .foregroundColor(.white.opacity(0.45))
            Text(subtitle)
                .font(.custom(GK.pixelFontName, size: 6))
                .foregroundColor(.white.opacity(0.25))
            Spacer()
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            // Always load pending count for badge regardless of tab
            pendingRequests = try await ConvexClient.shared.getPendingFriendRequests()
            switch selectedTab {
            case .friends:
                friends = try await ConvexClient.shared.getFriends()
            case .pending:
                break // already loaded above
            case .search:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func performSearch() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else { return }
        isSearching = true
        do {
            searchResults = try await ConvexClient.shared.searchUsers(query: query)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func addFriend(_ userId: String) async {
        do {
            try await ConvexClient.shared.sendFriendRequest(toUserId: userId)
            searchResults.removeAll { $0.userId == userId }
            showToast("REQUEST SENT!")
        } catch {
            showToast("FAILED TO SEND REQUEST")
        }
    }

    private func acceptRequest(_ userId: String) async {
        do {
            try await ConvexClient.shared.acceptFriendRequest(fromUserId: userId)
            pendingRequests.removeAll { $0.userId == userId }
            friends = try await ConvexClient.shared.getFriends()
            showToast("FRIEND ADDED!")
        } catch {
            showToast("FAILED TO ACCEPT")
        }
    }

    private func removeFriend(_ userId: String) async {
        do {
            try await ConvexClient.shared.removeFriend(otherUserId: userId)
            friends.removeAll { $0.userId == userId }
            pendingRequests.removeAll { $0.userId == userId }
            showToast("REMOVED")
        } catch {
            showToast("FAILED TO REMOVE")
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if toastMessage == message { toastMessage = nil }
        }
    }
}
