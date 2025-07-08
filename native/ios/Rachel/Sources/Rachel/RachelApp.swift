import SwiftUI
import LiveViewNative
import LiveViewNativeStylesheet

@main
struct RachelApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var coordinator = LiveViewCoordinator(
        URL(string: "http://localhost:4000")!
    )
    
    var body: some View {
        NavigationStack {
            LiveView(coordinator: coordinator)
                .navigationTitle("Rachel")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            // Configure the coordinator with our custom registry
            coordinator.connect()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                try await coordinator.reconnect()
            }
        }
    }
}

// Custom view registry for our game components
struct RachelRegistry: ViewRegistry {
    enum TagName: String {
        case playingCard = "PlayingCard"
        case gameBoard = "GameBoard"
        case playerHand = "PlayerHand"
    }
    
    static func lookup(_ name: String, _ context: Context) -> some View {
        guard let tag = TagName(rawValue: name) else {
            return AnyView(Text("Unknown view: \(name)"))
        }
        
        switch tag {
        case .playingCard:
            return AnyView(PlayingCardView(context: context))
        case .gameBoard:
            return AnyView(GameBoardView(context: context))
        case .playerHand:
            return AnyView(PlayerHandView(context: context))
        }
    }
}

// Placeholder views for custom components
struct PlayingCardView: View {
    let context: Context
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white)
            .frame(width: 80, height: 120)
            .shadow(radius: 4)
    }
}

struct GameBoardView: View {
    let context: Context
    
    var body: some View {
        ZStack {
            Color.green.opacity(0.3)
            Text("Game Board")
        }
    }
}

struct PlayerHandView: View {
    let context: Context
    
    var body: some View {
        HStack {
            ForEach(0..<5) { _ in
                PlayingCardView(context: context)
            }
        }
    }
}