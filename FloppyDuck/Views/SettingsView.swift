import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var showResetConfirm = false
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
                // Header
                HStack {
                    backButton
                    Spacer()
                    Text("SETTINGS")
                        .font(.custom(GK.pixelFontName, size: 18))
                        .foregroundColor(.white)
                        .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                ScrollView {
                    VStack(spacing: 16) {
                        // Player name
                        settingsPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("PLAYER NAME")
                                    .font(.custom(GK.pixelFontName, size: 8))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                                TextField("", text: $manager.playerName)
                                    .font(.custom(GK.pixelFontName, size: 14))
                                    .foregroundColor(GK.Colors.panelBorder)
                                    .padding(10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(GK.Colors.panelBorder.opacity(0.2), lineWidth: 2)
                                            )
                                    )
                            }
                        }

                        settingsPanel {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("ACCOUNT")
                                        .font(.custom(GK.pixelFontName, size: 10))
                                        .foregroundColor(GK.Colors.panelBorder)
                                    Spacer()
                                    Text(auth.accountBadgeText)
                                        .font(.custom(GK.pixelFontName, size: 7))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(auth.isAppleLinked ? GK.Colors.buttonGreen : GK.Colors.buttonOrange))
                                }

                                if let statusMessage = auth.statusMessage {
                                    Text(statusMessage)
                                        .font(.custom(GK.pixelFontName, size: 7))
                                        .foregroundColor(GK.Colors.panelBorder.opacity(0.75))
                                }

                                Text(auth.syncStatusText)
                                    .font(.custom(GK.pixelFontName, size: 7))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.65))

                                if auth.isAppleLinked {
                                    Button {
                                        Task { await auth.signOut() }
                                    } label: {
                                        Text("SIGN OUT")
                                            .font(.custom(GK.pixelFontName, size: 8))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonRed))
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    Button {
                                        Task { await auth.signInWithApple() }
                                    } label: {
                                        Text("SIGN IN WITH APPLE")
                                            .font(.custom(GK.pixelFontName, size: 8))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(auth.isBusy)
                                    .opacity(auth.isBusy ? 0.6 : 1)

                                    if auth.needsCloudRestore {
                                        Button {
                                            Task { await auth.signInWithApple() }
                                        } label: {
                                            Text("RESTORE CLOUD PROFILE")
                                                .font(.custom(GK.pixelFontName, size: 8))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonGreen))
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(auth.isBusy)
                                        .opacity(auth.isBusy ? 0.6 : 1)
                                    }
                                }
                            }
                        }

                        // Sound toggle
                        settingsPanel {
                            HStack {
                                Text("SOUND")
                                    .font(.custom(GK.pixelFontName, size: 10))
                                    .foregroundColor(GK.Colors.panelBorder)
                                Spacer()
                                Toggle("", isOn: $manager.soundEnabled)
                                    .tint(GK.Colors.buttonGreen)
                                    .labelsHidden()
                            }
                        }

                        // Haptics toggle
                        settingsPanel {
                            HStack {
                                Text("HAPTICS")
                                    .font(.custom(GK.pixelFontName, size: 10))
                                    .foregroundColor(GK.Colors.panelBorder)
                                Spacer()
                                Toggle("", isOn: $manager.hapticsEnabled)
                                    .tint(GK.Colors.buttonGreen)
                                    .labelsHidden()
                            }
                        }

                        // Version info
                        settingsPanel {
                            HStack {
                                Text("VERSION")
                                    .font(.custom(GK.pixelFontName, size: 8))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                                Spacer()
                                Text("1.0.0")
                                    .font(.custom(GK.pixelFontName, size: 8))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                            }
                        }

                        // Reset stats
                        Button {
                            showResetConfirm = true
                        } label: {
                            HStack(spacing: 8) {
                                pixelIcon(.cancel, size: 16)
                                Text("RESET ALL STATS")
                                    .font(.custom(GK.pixelFontName, size: 9))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(GK.Colors.buttonRed)
                                    .shadow(color: GK.Colors.buttonRed.opacity(0.4), radius: 0, x: 0, y: 3)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.black.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarHidden(true)
        .alert("RESET STATS?", isPresented: $showResetConfirm) {
            Button("CANCEL", role: .cancel) {}
            Button("RESET", role: .destructive) {
                manager.resetStats()
            }
        } message: {
            Text("This will erase all your scores, bread, and ELO. This cannot be undone.")
        }
        .onChange(of: manager.soundEnabled) { _, _ in
            SoundManager.shared.refreshAudioPreference()
        }
    }

    // MARK: - Settings Panel

    private func settingsPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GK.Colors.panelCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(GK.Colors.panelBorder, lineWidth: 2)
                    )
            )
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
            SoundManager.shared.play(.button)
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
