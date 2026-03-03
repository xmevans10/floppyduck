import SwiftUI

struct HomeView: View {
    @EnvironmentObject var gameManager: GameManager
    @State private var showPrivateRoom = false
    @State private var showJoinRoom = false
    @State private var roomCode = ""
    @State private var duckBounce = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                statsStrip
                modeCards
                privateRoomSection
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 20)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.12),
                    Color(red: 0.10, green: 0.12, blue: 0.20),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationBarHidden(true)
        .sheet(isPresented: $showJoinRoom) {
            JoinRoomSheet(roomCode: $roomCode)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Floppy Duck")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Tap. Flap. Compete.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Duck mascot
            Text("🦆")
                .font(.system(size: 48))
                .offset(y: duckBounce ? -4 : 4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: duckBounce)
                .onAppear { duckBounce = true }
        }
        .padding(.top, 20)
    }
    
    // MARK: - Stats
    
    private var statsStrip: some View {
        HStack(spacing: 0) {
            StatBadge(label: "RATING", value: "\(gameManager.playerRating)")
            Divider().frame(height: 40).background(Color.white.opacity(0.15))
            StatBadge(label: "BEST", value: "\(gameManager.bestScore)")
            Divider().frame(height: 40).background(Color.white.opacity(0.15))
            StatBadge(label: "GAMES", value: "\(gameManager.gamesPlayed)")
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - Mode Cards
    
    private var modeCards: some View {
        VStack(spacing: 14) {
            ModeCard(
                icon: "bolt.fill",
                iconColor: .orange,
                title: "Quick Play",
                subtitle: "Find a match instantly",
                action: { 
                    Haptic.buttonTap()
                    gameManager.startMatchmaking(mode: .quickPlay)
                }
            )
            
            ModeCard(
                icon: "trophy.fill",
                iconColor: .yellow,
                title: "Ranked",
                subtitle: "ELO-based matchmaking",
                action: { 
                    Haptic.buttonTap()
                    gameManager.startMatchmaking(mode: .ranked)
                }
            )
            
            ModeCard(
                icon: "gamecontroller.fill",
                iconColor: .green,
                title: "Single Player",
                subtitle: "Classic flappy gameplay",
                action: { 
                    Haptic.buttonTap()
                    gameManager.startSoloGame()
                }
            )
        }
    }
    
    // MARK: - Private Room
    
    private var privateRoomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRIVATE ROOM")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1)
            
            VStack(spacing: 0) {
                // Create Room
                Button {
                    Haptic.buttonTap()
                    // TODO: Create room via backend
                } label: {
                    HStack {
                        Image(systemName: "link")
                            .foregroundColor(.blue)
                        Text("Create Room")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                
                Divider().padding(.leading, 48)
                
                // Join Room
                Button {
                    Haptic.buttonTap()
                    showJoinRoom = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.and.pencil.and.ellipsis")
                            .foregroundColor(.orange)
                        Text("Join with Code")
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

// MARK: - Join Room Sheet

struct JoinRoomSheet: View {
    @Binding var roomCode: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter Room Code")
                    .font(.title2.weight(.bold))
                
                TextField("CODE", text: $roomCode)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.characters)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color(white: 0.15), in: RoundedRectangle(cornerRadius: 12))
                
                Button {
                    Haptic.buttonTap()
                    // TODO: Join room
                    dismiss()
                } label: {
                    Text("Join")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(roomCode.count < GK.roomCodeLength)
                .opacity(roomCode.count < GK.roomCodeLength ? 0.5 : 1)
                
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    HomeView()
        .environmentObject(GameManager())
}
