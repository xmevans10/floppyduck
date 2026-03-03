import SwiftUI

struct MatchmakingView: View {
    @EnvironmentObject var gameManager: GameManager
    let mode: MatchmakingMode
    
    @State private var searchTime: Int = 0
    @State private var pulseScale: CGFloat = 1
    @State private var dotCount: Int = 0
    @State private var timer: Timer?
    
    var modeTitle: String {
        mode == .quickPlay ? "Quick Play" : "Ranked"
    }
    
    var modeIcon: String {
        mode == .quickPlay ? "bolt.fill" : "trophy.fill"
    }
    
    var modeColor: Color {
        mode == .quickPlay ? .orange : .yellow
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Pulsing icon
            ZStack {
                Circle()
                    .fill(modeColor.opacity(0.1))
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                
                Circle()
                    .stroke(modeColor.opacity(0.3), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Circle()
                    .fill(modeColor.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: modeIcon)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(modeColor)
            }
            
            VStack(spacing: 8) {
                Text(modeTitle)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Finding opponent" + String(repeating: ".", count: dotCount))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(width: 180, alignment: .leading)
            }
            
            // Timer
            VStack(spacing: 6) {
                Text("TIME")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .tracking(1)
                
                Text(formatTime(searchTime))
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                
                Text("1 player searching")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Cancel button
            Button {
                Haptic.buttonTap()
                gameManager.popToRoot()
            } label: {
                Text("Cancel")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(white: 0.18))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.14),
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarBackButtonHidden(true)
        .onAppear { startSearching() }
        .onDisappear { stopSearching() }
    }
    
    private func startSearching() {
        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.3
        }
        
        // Timer
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            searchTime += 1
            dotCount = (dotCount + 1) % 4
        }
    }
    
    private func stopSearching() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    MatchmakingView(mode: .quickPlay)
        .environmentObject(GameManager())
}
