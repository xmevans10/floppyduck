import SwiftUI

/// Matchmaking waiting screen — retro styled.
struct MatchmakingView: View {
    @EnvironmentObject var gameManager: GameManager
    let mode: MatchmakingMode

    @State private var dotCount = 0
    @State private var elapsed = 0
    @State private var duckBounce: CGFloat = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Sky background
            LinearGradient(
                colors: [GK.Colors.skyTop, GK.Colors.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Bouncing duck
                Group {
                    if let img = TextureFactory.shared.duckUIImage().cgImage {
                        Image(uiImage: UIImage(cgImage: img, scale: 0.5, orientation: .up))
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 70, height: 50)
                    }
                }
                .offset(y: duckBounce)

                // Title
                ZStack {
                    Text(mode == .quickPlay ? "Finding Match" : "Ranked Queue")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(GK.Colors.panelBorder)
                        .offset(x: 2, y: 2)
                    Text(mode == .quickPlay ? "Finding Match" : "Ranked Queue")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Animated dots
                Text("Searching" + String(repeating: ".", count: dotCount))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(width: 160, alignment: .leading)

                // Timer
                Text(timeString)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))

                Spacer()

                // Cancel button
                Button {
                    Haptic.buttonTap()
                    gameManager.popToRoot()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 160, height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.red.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.black.opacity(0.3), lineWidth: 3)
                                )
                                .shadow(color: .black.opacity(0.25), radius: 0, x: 2, y: 3)
                        )
                }
                .buttonStyle(RetroPress())
                .padding(.bottom, 60)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onReceive(timer) { _ in
            elapsed += 1
            dotCount = (dotCount + 1) % 4
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                duckBounce = -10
            }
        }
    }

    private var timeString: String {
        let m = elapsed / 60
        let s = elapsed % 60
        return String(format: "%d:%02d", m, s)
    }
}
