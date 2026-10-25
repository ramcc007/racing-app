import SwiftUI
import EchoLapCore

@main
struct EchoLapApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch app.route {
            case .intro:
                IntroView()
                    .transition(.opacity)
            case .home:
                HomeRoot()
                    .transition(.opacity)
                    .onAppear {
                        // Game Center signs in quietly once the player is past the intro and first race.
                        if app.progress.tutorialDone { GameCenterService.shared.start() }
                    }
            case .race(let request):
                RaceView(request: request)
                    .id(request.id)
                    .transition(.opacity)
            }
            if let toast = app.toast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(Theme.rounded(.callout, .semibold))
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .glassCard(cornerRadius: 18)
                        .padding(.bottom, 40)
                        .accessibilityIdentifier("toast")
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: app.route)
        .animation(.spring(duration: 0.3), value: app.toast)
    }
}

/// The links shown in Settings, on the intro and on the home footer. They must be live before submission
/// (docs/OWNER_STEPS.md): the privacy policy is also entered in App Store Connect.
enum AppLinks {
    static let privacy = URL(string: "https://ramcc007.github.io/racing-app/privacy.html")!
    static let terms = URL(string: "https://ramcc007.github.io/racing-app/terms.html")!
    static let support = URL(string: "https://ramcc007.github.io/racing-app/support.html")!
}
