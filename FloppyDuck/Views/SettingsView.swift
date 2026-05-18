import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager
    @State private var showResetConfirm = false
    @State private var showDeleteAccountConfirm = false
    private let icons = PixelIconFactory.shared

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
                        // Account
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
                                        Task { await auth.signInWithGameCenter() }
                                    } label: {
                                        Text("SIGN IN WITH GAME CENTER")
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
                                            Task { await auth.signInWithGameCenter() }
                                        } label: {
                                            Text("RESTORE GAME CENTER PROFILE")
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

                        // Audio & Haptics — combined panel
                        settingsPanel {
                            VStack(spacing: 14) {
                                // Sound toggle
                                HStack {
                                    Text("SOUND")
                                        .font(.custom(GK.pixelFontName, size: 10))
                                        .foregroundColor(GK.Colors.panelBorder)
                                    Spacer()
                                    Toggle("Sound", isOn: $manager.soundEnabled)
                                        .tint(GK.Colors.buttonGreen)
                                        .labelsHidden()
                                        .accessibilityLabel("Sound toggle")
                                }

                                if manager.soundEnabled {
                                    // Music volume
                                    HStack(spacing: 8) {
                                        Text("MUSIC")
                                            .font(.custom(GK.pixelFontName, size: 8))
                                            .foregroundColor(GK.Colors.panelBorder.opacity(0.8))
                                            .lineLimit(1)
                                            .fixedSize()
                                            .frame(width: 50, alignment: .leading)
                                        Slider(value: $manager.musicVolume, in: 0...1)
                                            .tint(GK.Colors.buttonBlue)
                                    }

                                    // SFX volume
                                    HStack(spacing: 8) {
                                        Text("SFX")
                                            .font(.custom(GK.pixelFontName, size: 8))
                                            .foregroundColor(GK.Colors.panelBorder.opacity(0.8))
                                            .lineLimit(1)
                                            .fixedSize()
                                            .frame(width: 50, alignment: .leading)
                                        Slider(value: $manager.sfxVolume, in: 0...1)
                                            .tint(GK.Colors.buttonOrange)
                                    }
                                }

                                Divider()
                                    .background(GK.Colors.panelBorder.opacity(0.15))

                                // Haptics toggle
                                HStack {
                                    Text("HAPTICS")
                                        .font(.custom(GK.pixelFontName, size: 10))
                                        .foregroundColor(GK.Colors.panelBorder)
                                    Spacer()
                                    Toggle("Haptics", isOn: $manager.hapticsEnabled)
                                        .tint(GK.Colors.buttonGreen)
                                        .labelsHidden()
                                        .accessibilityLabel("Haptics toggle")
                                }
                            }
                        }

                        // Purchases + Restore
                        settingsPanel {
                            VStack(alignment: .leading, spacing: 8) {
                                Button {
                                    Task {
                                        await SkinManager.shared.restorePurchases()
                                        await ThemeManager.shared.restorePurchases()
                                        await BannerManager.shared.restorePurchases()
                                    }
                                } label: {
                                    Text("RESTORE PURCHASES")
                                        .font(.custom(GK.pixelFontName, size: 8))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonBlue))
                                }
                                .buttonStyle(.plain)

                                Text("Restores any previously purchased skins or backgrounds.")
                                    .font(.custom(GK.pixelFontName, size: 6))
                                    .foregroundColor(GK.Colors.panelBorder.opacity(0.5))
                            }
                        }

                        // Delete account (Apple requirement 5.1.1(v))
                        if auth.isAppleLinked {
                            settingsPanel {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("DELETE ACCOUNT")
                                        .font(.custom(GK.pixelFontName, size: 10))
                                        .foregroundColor(GK.Colors.buttonRed)

                                    Text("Permanently deletes your account, stats, and all data from our servers. This cannot be undone.")
                                        .font(.custom(GK.pixelFontName, size: 6))
                                        .foregroundColor(GK.Colors.panelBorder.opacity(0.6))

                                    Button {
                                        showDeleteAccountConfirm = true
                                    } label: {
                                        Text("DELETE MY ACCOUNT")
                                            .font(.custom(GK.pixelFontName, size: 8))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(RoundedRectangle(cornerRadius: 8).fill(GK.Colors.buttonRed))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(auth.isBusy)
                                    .opacity(auth.isBusy ? 0.6 : 1)
                                }
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

                        // Version info (compact, not a full panel)
                        Text("v\(Self.versionString)")
                            .font(.custom(GK.pixelFontName, size: 7))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.top, 4)
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
        .alert("DELETE ACCOUNT?", isPresented: $showDeleteAccountConfirm) {
            Button("CANCEL", role: .cancel) {}
            Button("DELETE EVERYTHING", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
        } message: {
            Text("This will permanently delete your account, all stats, purchase history, and cloud data. You will need Game Center to sign in again. This cannot be undone.")
        }
        .onChange(of: manager.soundEnabled) { _, _ in
            SoundManager.shared.refreshAudioPreference()
        }
        .onChange(of: manager.musicVolume) { _, _ in
            SoundManager.shared.refreshAudioPreference()
        }
        .onChange(of: manager.sfxVolume) { _, _ in
            SoundManager.shared.refreshAudioPreference()
        }
        .onChange(of: manager.hapticsEnabled) { _, _ in
            Haptic.refreshPreference()
        }
    }

    // MARK: - Version

    private static var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(version) (\(build))"
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
                .background(PixelButtonBackground(style: .light, size: 44))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }
}
