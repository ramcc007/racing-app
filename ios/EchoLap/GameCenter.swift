import GameKit
import UIKit
import EchoLapCore

/// Game Center: sign-in, achievements and four leaderboards. Entirely optional: without Game Center the game works
/// exactly the same, and nothing is sent anywhere except to Apple's own Game Center (the developer receives no data).
/// The identifiers below must exist in App Store Connect (docs/GAME_CENTER_SETUP.md) and be submitted with version 1.0.
@MainActor
final class GameCenterService: ObservableObject {
    static let shared = GameCenterService()

    enum Board: String, CaseIterable {
        /// Total career stars (higher is better).
        case stars = "echolap.lb.stars"
        /// Today's daily track, recurring every day (time in hundredths, lower is better).
        case daily = "echolap.lb.daily"
        /// This week's gauntlet total (hundredths, lower is better), recurring weekly.
        case weekly = "echolap.lb.weekly"
        /// Echo Survival laps (higher is better).
        case survival = "echolap.lb.survival"
    }

    @Published private(set) var signedIn = false
    private var started = false
    private var accessPointWanted = false
    private var latest: PlayerProgress?
    private let defaults = UserDefaults.standard
    private let reportedKey = "echolap.gc.reported"
    private let bestKeyPrefix = "echolap.gc.best."

    /// Starts sign-in silently. Called after the player's first race, never over the intro or a race.
    func start() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-EchoScene") || ProcessInfo.processInfo.arguments.contains("-EchoUITest") { return }
        #endif
        guard !started else { return }
        started = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor in
                if let viewController { Self.present(viewController) }
                guard let self else { return }
                self.signedIn = GKLocalPlayer.local.isAuthenticated
                if self.signedIn { self.showAccessPoint(self.accessPointWanted) }
                if self.signedIn, let progress = self.latest { self.sync(progress) }
            }
        }
    }

    /// Shows or hides the Game Center access point (menus only: never during races, the intro or the tutorial).
    func showAccessPoint(_ visible: Bool) {
        accessPointWanted = visible
        guard signedIn else { return }
        GKAccessPoint.shared.location = .topLeading
        GKAccessPoint.shared.isActive = visible
    }

    /// Reports new achievements and a better star total. Cheap to call after every save.
    func sync(_ progress: PlayerProgress) {
        latest = progress
        guard signedIn else { return }
        var reported = Set(defaults.stringArray(forKey: reportedKey) ?? [])
        let fresh = Achievement.unlocked(in: progress).filter { !reported.contains($0.id) }
        if !fresh.isEmpty {
            let list = fresh.map { a -> GKAchievement in
                let item = GKAchievement(identifier: a.gameCenterID)
                item.percentComplete = 100
                item.showsCompletionBanner = true
                return item
            }
            Task {
                if (try? await GKAchievement.report(list)) != nil {
                    reported.formUnion(fresh.map(\.id))
                    defaults.set(Array(reported), forKey: reportedKey)
                }
            }
        }
        submit(.stars, score: progress.totalStars, higherIsBetter: true)
        submit(.survival, score: progress.survivalBest, higherIsBetter: true)
    }

    /// Submits a race time (lower is better) to the daily or weekly board.
    func submitTime(_ board: Board, seconds: Double, periodKey: String) {
        guard signedIn, seconds.isFinite, seconds > 0 else { return }
        let hundredths = Int((seconds * 100).rounded())
        let key = bestKeyPrefix + board.rawValue + "." + periodKey
        let best = defaults.integer(forKey: key)
        guard best == 0 || hundredths < best else { return }
        Task {
            if (try? await GKLeaderboard.submitScore(hundredths, context: 0, player: GKLocalPlayer.local,
                                                     leaderboardIDs: [board.rawValue])) != nil {
                defaults.set(hundredths, forKey: key)
            }
        }
    }

    private func submit(_ board: Board, score: Int, higherIsBetter: Bool) {
        guard score > 0 else { return }
        let key = bestKeyPrefix + board.rawValue
        guard score > defaults.integer(forKey: key) else { return }
        Task {
            if (try? await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                                     leaderboardIDs: [board.rawValue])) != nil {
                defaults.set(score, forKey: key)
            }
        }
    }

    func openDashboard(_ board: Board? = nil) {
        guard signedIn else { return }
        if let board, #available(iOS 18.0, *) {
            GKAccessPoint.shared.trigger(leaderboardID: board.rawValue, playerScope: .global, timeScope: .today) {}
        } else {
            GKAccessPoint.shared.trigger(state: board == nil ? .dashboard : .leaderboards) {}
        }
    }

    private static func present(_ viewController: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewController, animated: true)
    }
}
