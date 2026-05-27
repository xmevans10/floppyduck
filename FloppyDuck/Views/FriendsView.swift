import SwiftUI

enum FriendsTab: String, CaseIterable {
    case friends = "FRIENDS"
    case pending = "REQUESTS"
    case search  = "ADD"

    var systemIcon: String {
        switch self {
        case .friends: return "person.2.fill"
        case .pending: return "envelope.fill"
        case .search:  return "magnifyingglass"
        }
    }

    var accent: Color {
        switch self {
        case .friends: return GK.Colors.buttonBlue
        case .pending: return GK.Colors.buttonGreen
        case .search:  return Color(red: 0.55, green: 0.40, blue: 0.75) // purple
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

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            // Background
            GeometryReader { geo in
                Image(uiImage: UIImage(named: "floppy_theme") ?? UIImage())
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar
                tabPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                // Content panel — dark translucent card
                contentPanel
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 16)
            }

            // Toast
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
                        )
                        .padding(.bottom, 50)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarHidden(true)
        .task { await loadData() }
    }

    // MARK: - Header

    private var headerBar: some View {
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
                    .background(PixelButtonBackground(style: .dark, size: 44))
            }
            .accessibilityLabel("Back")

            Spacer()

            Text("FRIENDS")
                .font(.custom(GK.pixelFontName, size: 22))
                .foregroundColor(.white)
                .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

            Spacer()

            // Pending badge (visible from any tab)
            if !pendingRequests.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(pendingRequests.count)")
                        .font(.custom(GK.pixelFontName, size: 9))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(GK.Colors.buttonRed.opacity(0.85))
                )
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Tab Picker (matches ShopView pattern)

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.25))
        )
    }

    private func tabButton(_ tab: FriendsTab) -> some View {
        let isActive = selectedTab == tab
        return Button {
            SoundManager.shared.play(.button)
            Haptic.light()
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
            Task { await loadData() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tab.systemIcon)
                    .font(.system(size: 9, weight: .bold))
                Text(tab.rawValue)
                    .font(.custom(GK.pixelFontName, size: 8))
                    .lineLimit(1)
                    .fixedSize()

                // Badge on requests tab
                if tab == .pending && !pendingRequests.isEmpty {
                    Text("\(pendingRequests.count)")
                        .font(.custom(GK.pixelFontName, size: 6))
                        .foregroundColor(.white)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(GK.Colors.buttonRed))
                }
            }
            .foregroundColor(isActive ? .white : .white.opacity(0.5))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? tab.accent : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Panel

    private var contentPanel: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingPanel
            } else if let error = errorMessage {
                errorPanel(error)
            } else {
                switch selectedTab {
                case .friends: friendsContent
                case .pending: pendingContent
                case .search:  searchContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Loading

    private var loadingPanel: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView().tint(.white)
            Text("LOADING...")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
    }

    // MARK: - Error

    private func errorPanel(_ error: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(GK.Colors.scoreYellow)
            Text("SOMETHING WENT WRONG")
                .font(.custom(GK.pixelFontName, size: 9))
                .foregroundColor(.white)
            Text(error)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Button {
                Task { await loadData() }
            } label: {
                Text("RETRY")
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            Spacer()
        }
    }

    // MARK: - Friends Content

    private var friendsContent: some View {
        Group {
            if friends.isEmpty {
                emptyState(
                    icon: "person.2.slash",
                    title: "NO FRIENDS YET",
                    subtitle: "ADD FRIENDS TO CHALLENGE THEM!"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    // Count bar
                    HStack {
                        Text("\(friends.count) FRIEND\(friends.count == 1 ? "" : "S")")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(.white.opacity(0.3))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    LazyVStack(spacing: 8) {
                        ForEach(friends) { friend in
                            friendRow(friend)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func friendRow(_ friend: PublicPlayerProfile) -> some View {
        HStack(spacing: 10) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(GK.Colors.buttonBlue.opacity(0.25))
                    .frame(width: 40, height: 40)
                Text(String(friend.username.prefix(1)).uppercased())
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.username)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label {
                        Text("\(friend.stats.elo)")
                            .font(.custom(GK.pixelFontName, size: 6))
                    } icon: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(GK.Colors.scoreYellow.opacity(0.7))

                    Label {
                        Text("\(friend.stats.gamesPlayed) GAMES")
                            .font(.custom(GK.pixelFontName, size: 6))
                    } icon: {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(.white.opacity(0.35))
                }
            }

            Spacer()

            // Actions
            Button {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                manager.navigate(to: .publicProfile(friend.userId))
            } label: {
                Text("VIEW")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(GK.Colors.buttonBlue)
                    )
            }
            .buttonStyle(.plain)

            Button {
                SoundManager.shared.play(.button)
                Task { await removeFriend(friend.userId) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(GK.Colors.buttonRed.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Pending Content

    private var pendingContent: some View {
        Group {
            if pendingRequests.isEmpty {
                emptyState(
                    icon: "envelope.open",
                    title: "NO REQUESTS",
                    subtitle: "FRIEND REQUESTS WILL SHOW UP HERE"
                )
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingRequests) { request in
                            pendingRow(request)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private func pendingRow(_ request: PublicPlayerProfile) -> some View {
        HStack(spacing: 10) {
            // Avatar with green ring
            ZStack {
                Circle()
                    .fill(GK.Colors.buttonGreen.opacity(0.2))
                    .frame(width: 40, height: 40)
                Circle()
                    .stroke(GK.Colors.buttonGreen.opacity(0.5), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Text(String(request.username.prefix(1)).uppercased())
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(request.username)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("WANTS TO BE FRIENDS")
                    .font(.custom(GK.pixelFontName, size: 6))
                    .foregroundColor(GK.Colors.buttonGreen.opacity(0.8))
            }

            Spacer()

            // Accept
            Button {
                SoundManager.shared.play(.button)
                Haptic.medium()
                Task { await acceptRequest(request.userId) }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                    Text("ACCEPT")
                        .font(.custom(GK.pixelFontName, size: 7))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(GK.Colors.buttonGreen)
                )
            }
            .buttonStyle(.plain)

            // Decline
            Button {
                SoundManager.shared.play(.button)
                Task { await removeFriend(request.userId) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(GK.Colors.buttonRed.opacity(0.7))
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.white.opacity(0.08))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(GK.Colors.buttonGreen.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Search Content

    private var searchContent: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    TextField("", text: $searchQuery, prompt:
                        Text("SEARCH USERNAME...")
                            .font(.custom(GK.pixelFontName, size: 9))
                            .foregroundColor(.white.opacity(0.3))
                    )
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .autocapitalization(.none)
                    .onSubmit { Task { await performSearch() } }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )

                Button {
                    SoundManager.shared.play(.button)
                    Task { await performSearch() }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(FriendsTab.search.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).count < 2)
                .opacity(searchQuery.trimmingCharacters(in: .whitespaces).count < 2 ? 0.4 : 1.0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 14)

            // Results
            if isSearching {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView().tint(.white)
                    Text("SEARCHING...")
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                emptyState(
                    icon: "person.fill.questionmark",
                    title: "NO PLAYERS FOUND",
                    subtitle: "TRY A DIFFERENT USERNAME"
                )
            } else if !searchResults.isEmpty {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { result in
                            searchRow(result)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
            } else {
                emptyState(
                    icon: "magnifyingglass",
                    title: "FIND PLAYERS",
                    subtitle: "TYPE A USERNAME ABOVE"
                )
            }
        }
    }

    private func searchRow(_ result: PublicPlayerProfile) -> some View {
        HStack(spacing: 10) {
            // Avatar
            ZStack {
                Circle()
                    .fill(FriendsTab.search.accent.opacity(0.2))
                    .frame(width: 40, height: 40)
                Text(String(result.username.prefix(1)).uppercased())
                    .font(.custom(GK.pixelFontName, size: 14))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(result.username)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label {
                        Text("\(result.stats.elo)")
                            .font(.custom(GK.pixelFontName, size: 6))
                    } icon: {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(GK.Colors.scoreYellow.opacity(0.7))

                    Label {
                        Text("\(result.stats.gamesPlayed)")
                            .font(.custom(GK.pixelFontName, size: 6))
                    } icon: {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(.white.opacity(0.35))
                }
            }

            Spacer()

            Button {
                SoundManager.shared.play(.button)
                Haptic.buttonTap()
                manager.navigate(to: .publicProfile(result.userId))
            } label: {
                Text("VIEW")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)

            Button {
                SoundManager.shared.play(.button)
                Haptic.medium()
                Task { await addFriend(result.userId) }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                    Text("ADD")
                        .font(.custom(GK.pixelFontName, size: 7))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(GK.Colors.buttonGreen)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 10) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.2))
            }
            Text(title)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white.opacity(0.4))
            Text(subtitle)
                .font(.custom(GK.pixelFontName, size: 7))
                .foregroundColor(.white.opacity(0.2))
            Spacer()
        }
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            pendingRequests = try await ConvexClient.shared.getPendingFriendRequests()
            switch selectedTab {
            case .friends:
                friends = try await ConvexClient.shared.getFriends()
            case .pending, .search:
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
            showToast("FAILED TO SEND")
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
