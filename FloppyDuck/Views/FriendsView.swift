import SwiftUI

enum FriendsTab: String, CaseIterable {
    case friends = "FRIENDS"
    case pending = "REQUESTS"
    case search = "ADD"
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

    private let icons = PixelIconFactory.shared

    var body: some View {
        ZStack {
            backgroundView

            VStack(spacing: 0) {
                headerView
                tabPicker
                contentView
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
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(FriendsTab.allCases, id: \.self) { tab in
                Text(tab.rawValue)
                    .font(.custom(GK.pixelFontName, size: 9))
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 30)
        .padding(.top, 8)
        .onChange(of: selectedTab) { _, _ in
            Task { await loadData() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            Spacer()
            ProgressView().tint(.white)
            Text("LOADING...")
                .font(.custom(GK.pixelFontName, size: 8))
                .foregroundColor(.white.opacity(0.7))
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
                emptyView(message: "NO FRIENDS YET")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(friends) { friend in
                            friendRow(friend)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Pending Requests

    private var pendingList: some View {
        Group {
            if pendingRequests.isEmpty {
                emptyView(message: "NO PENDING REQUESTS")
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(pendingRequests) { request in
                            pendingRow(request)
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
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 8) {
                TextField("SEARCH USERNAME...", text: $searchQuery)
                    .font(.custom(GK.pixelFontName, size: 12))
                    .foregroundColor(GK.Colors.panelBorder)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(GK.Colors.panelCream)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(GK.Colors.panelBorder, lineWidth: 2)
                            )
                    )
                    .autocapitalization(.none)
                    .onSubmit {
                        Task { await performSearch() }
                    }

                Button {
                    Task { await performSearch() }
                } label: {
                    Text("GO")
                        .font(.custom(GK.pixelFontName, size: 10))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(GK.Colors.buttonBlue)
                        )
                }
                .buttonStyle(.plain)
                .disabled(searchQuery.trimmingCharacters(in: .whitespaces).count < 2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            if isSearching {
                Spacer()
                ProgressView().tint(.white)
                Spacer()
            } else if searchResults.isEmpty && !searchQuery.isEmpty {
                emptyView(message: "NO PLAYERS FOUND")
            } else if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults) { result in
                            searchResultRow(result)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }

    // MARK: - Row Views

    private func friendRow(_ friend: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            pixelIcon(.headToHead, size: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(friend.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Text("ELO \(friend.stats.elo) · \(friend.stats.gamesPlayed) GAMES")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
            }

            Spacer()

            // View profile
            Button {
                SoundManager.shared.play(.button)
                manager.navigate(to: .publicProfile(friend.userId))
            } label: {
                Text("VIEW")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GK.Colors.buttonBlue))
            }
            .buttonStyle(.plain)

            // Remove
            Button {
                Task { await removeFriend(friend.userId) }
            } label: {
                Image(uiImage: icons.image(for: .cancel, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(friend.username)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func pendingRow(_ request: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            pixelIcon(.headToHead, size: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(request.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Text("WANTS TO BE FRIENDS")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.buttonGreen)
            }

            Spacer()

            // Accept
            Button {
                Task { await acceptRequest(request.userId) }
            } label: {
                Image(uiImage: icons.image(for: .checkmark, pixelScale: 2.5))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .padding(6)
                    .background(Circle().fill(GK.Colors.buttonGreen))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Accept \(request.username)")

            // Decline/Remove
            Button {
                Task { await removeFriend(request.userId) }
            } label: {
                Image(uiImage: icons.image(for: .cancel, pixelScale: 2.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .padding(6)
                    .background(Circle().fill(GK.Colors.buttonRed))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Decline \(request.username)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.buttonGreen, lineWidth: 2)
                )
        )
    }

    private func searchResultRow(_ result: PublicPlayerProfile) -> some View {
        HStack(spacing: 12) {
            pixelIcon(.classic, size: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.username)
                    .font(.custom(GK.pixelFontName, size: 10))
                    .foregroundColor(GK.Colors.panelBorder)
                Text("ELO \(result.stats.elo) · \(result.stats.gamesPlayed) GAMES")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
            }

            Spacer()

            // View profile
            Button {
                SoundManager.shared.play(.button)
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

            // Add friend
            Button {
                Task { await addFriend(result.userId) }
            } label: {
                Text("ADD")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(GK.Colors.buttonGreen))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GK.Colors.panelCream)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(GK.Colors.panelBorder, lineWidth: 2)
                )
        )
    }

    private func emptyView(message: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            pixelIcon(.duck, size: 40)
                .opacity(0.4)
            Text(message)
                .font(.custom(GK.pixelFontName, size: 10))
                .foregroundColor(.white.opacity(0.5))
            if selectedTab == .friends {
                Text("ADD FRIENDS FROM THE ADD TAB")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white.opacity(0.35))
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private func pixelIcon(_ icon: PixelIcon, size: CGFloat) -> some View {
        Image(uiImage: icons.image(for: icon, pixelScale: 3.0))
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }

    // MARK: - Data

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            switch selectedTab {
            case .friends:
                friends = try await ConvexClient.shared.getFriends()
            case .pending:
                pendingRequests = try await ConvexClient.shared.getPendingFriendRequests()
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
            // Remove from search results or reload
            searchResults.removeAll { $0.userId == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func acceptRequest(_ userId: String) async {
        do {
            try await ConvexClient.shared.acceptFriendRequest(fromUserId: userId)
            pendingRequests.removeAll { $0.userId == userId }
            // Reload friends
            friends = try await ConvexClient.shared.getFriends()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeFriend(_ userId: String) async {
        do {
            try await ConvexClient.shared.removeFriend(otherUserId: userId)
            friends.removeAll { $0.userId == userId }
            pendingRequests.removeAll { $0.userId == userId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
