import SwiftUI

@main
struct FloppyDuckApp: App {
    @StateObject private var gameManager = GameManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameManager)
                .preferredColorScheme(.light)
        }
    }
}
