import SwiftUI

struct AuthOnboardingView: View {
    @EnvironmentObject var manager: GameManager
    @EnvironmentObject var auth: AuthManager

    /// Tracks which auth button is actively loading (fix: dual-spinner bug)
    @State private var busyAction: AuthAction?

    private let icons = PixelIconFactory.shared

    private enum AuthAction {
        case guest, apple
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
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

                Text("Choose how to play.")
                    .font(.custom(GK.pixelFontName, size: 8))
                    .foregroundColor(.white.opacity(0.85))

                VStack(spacing: 10) {
                    authButton(
                        icon: .classic,
                        title: "CONTINUE AS GUEST",
                        subtitle: "Quick setup, local + device identity",
                        action: .guest
                    ) {
                        busyAction = .guest
                        Task {
                            await auth.continueAsGuest()
                            busyAction = nil
                        }
                    }

                    authButton(
                        icon: .trophy,
                        title: "SIGN IN WITH APPLE",
                        subtitle: "Required for ranked multiplayer",
                        action: .apple
                    ) {
                        busyAction = .apple
                        Task {
                            await auth.signInWithApple()
                            busyAction = nil
                        }
                    }
                }
                .padding(.horizontal, 26)

                Text("Ranked requires Sign in with Apple. Quick Play and Private Room work as guest.")
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

    private func authButton(icon: PixelIcon,
                            title: String,
                            subtitle: String,
                            action: AuthAction,
                            onTap: @escaping () -> Void) -> some View {
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
                    ProgressView()
                        .tint(.white)
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
        .disabled(anyBusy)
        .opacity(anyBusy && !isThisBusy ? 0.5 : (anyBusy ? 0.8 : 1))
        .accessibilityLabel(title)
    }
}
