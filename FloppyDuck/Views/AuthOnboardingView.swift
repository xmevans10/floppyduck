import SwiftUI

struct AuthOnboardingView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    @State private var busyAction: AuthAction?
    @State private var username: String = ""

    private let icons = PixelIconFactory.shared

    private enum AuthAction { case guest, apple }

    private var isUsernameValid: Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 16
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Image(uiImage: TextureFactory.shared.duckUIImage(pixelScale: 5.0))
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 90, height: 68)

                Text("WELCOME")
                    .font(.custom(GK.pixelFontName, size: 20))
                    .foregroundColor(.white)
                    .shadow(color: GK.Colors.pipeBorder, radius: 0, x: 2, y: 2)

                // Username input
                VStack(spacing: 6) {
                    Text("CHOOSE YOUR NAME")
                        .font(.custom(GK.pixelFontName, size: 8))
                        .foregroundColor(.white.opacity(0.85))

                    PixelTextField(text: $username, pixelFontName: GK.pixelFontName,
                                   fontSize: 14, maxLength: 16)
                        .frame(height: 44)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(GK.Colors.panelBorder.opacity(0.2), lineWidth: 2)
                                )
                        )

                    if !username.isEmpty && !isUsernameValid {
                        Text("2–16 characters")
                            .font(.custom(GK.pixelFontName, size: 6))
                            .foregroundColor(GK.Colors.buttonRed.opacity(0.8))
                    }
                }
                .padding(.horizontal, 26)

                // Auth buttons
                VStack(spacing: 10) {
                    authButton(
                        icon: .classic,
                        title: "CONTINUE AS GUEST",
                        subtitle: "Classic + Quick Play only",
                        action: .guest
                    ) {
                        commitUsername()
                        busyAction = .guest
                        Task {
                            await auth.continueAsGuest()
                            busyAction = nil
                        }
                    }

                    authButton(
                        icon: .trophy,
                        title: "SIGN IN WITH APPLE",
                        subtitle: "Unlock all modes + cloud sync",
                        action: .apple
                    ) {
                        commitUsername()
                        busyAction = .apple
                        Task {
                            await auth.signInWithApple()
                            busyAction = nil
                        }
                    }
                }
                .padding(.horizontal, 26)
                .opacity(isUsernameValid ? 1 : 0.45)

                Text("Classic and Quick Play are free.\nSign in to unlock all features.")
                    .font(.custom(GK.pixelFontName, size: 7))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if let statusMessage = auth.statusMessage {
                    Text(statusMessage)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(GK.Colors.scoreYellow)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                }

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private func commitUsername() {
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.count >= 2 {
            manager.playerName = trimmed
        }
    }

    private func authButton(icon: PixelIcon, title: String, subtitle: String,
                            action: AuthAction, onTap: @escaping () -> Void) -> some View {
        let isThisBusy = busyAction == action
        let anyBusy = busyAction != nil

        return Button(action: onTap) {
            HStack(spacing: 12) {
                Image(uiImage: icons.image(for: icon))
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom(GK.pixelFontName, size: 9))
                        .foregroundColor(.white)
                    Text(subtitle)
                        .font(.custom(GK.pixelFontName, size: 7))
                        .foregroundColor(.white.opacity(0.75))
                }

                Spacer()

                if isThisBusy {
                    ProgressView().tint(.white)
                } else {
                    Image(uiImage: icons.image(for: .play))
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 14, height: 14)
                }
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
        .disabled(anyBusy || !isUsernameValid)
        .opacity(anyBusy && !isThisBusy ? 0.5 : (anyBusy ? 0.8 : 1))
        .accessibilityLabel(title)
    }
}
