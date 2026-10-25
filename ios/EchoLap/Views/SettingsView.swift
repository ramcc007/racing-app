import SwiftUI
import EchoLapCore

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @ObservedObject private var gameCenter = GameCenterService.shared
    @State private var confirmReset = false

    private func binding<T>(_ keyPath: WritableKeyPath<GameSettings, T>) -> Binding<T> {
        Binding(get: { app.progress.settings[keyPath: keyPath] },
                set: { value in
                    app.update { $0.settings[keyPath: keyPath] = value }
                    app.applySettings()
                })
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Steering sensitivity")
                        Spacer()
                        Text(String(format: "%.1f×", app.progress.settings.steeringSensitivity)).monospacedDigit().foregroundStyle(Theme.muted)
                    }
                    Slider(value: binding(\.steeringSensitivity), in: 0.6...1.6, step: 0.1) {
                        Text("Steering sensitivity")
                    } minimumValueLabel: {
                        Image(systemName: "tortoise.fill")
                    } maximumValueLabel: {
                        Image(systemName: "hare.fill")
                    }
                    .accessibilityIdentifier("sensitivity")
                }
                Toggle("Tilt to steer", isOn: binding(\.tiltSteering))
                Toggle("Nitro button on the left", isOn: binding(\.boostButtonOnLeft))
                Picker("Camera", selection: binding(\.camera)) {
                    Text("Follows the car").tag(GameSettings.Camera.follow)
                    Text("Fixed, north up").tag(GameSettings.Camera.fixed)
                }
            } header: {
                Text("Controls")
            } footer: {
                Text("The car drives by itself. Drag anywhere to steer, hold a turn hard to drift, pull your thumb down to brake, and swipe up (or tap NITRO) to fire the nitro. Game controllers work too.")
            }

            Section {
                Toggle("Direction arrows", isOn: binding(\.showGuide))
                Toggle("Coaching hints", isOn: binding(\.showHints))
                Toggle("Calm effects", isOn: binding(\.calmEffects))
            } header: {
                Text("Display")
            } footer: {
                Text("Calm effects turns off camera shake, speed lines, sparks and slow motion. It switches on by itself when Reduce Motion is on.")
            }

            Section("Sound and haptics") {
                Toggle("Sound effects", isOn: binding(\.sound))
                Toggle("Haptics", isOn: binding(\.haptics))
            }

            Section("Help") {
                NavigationLink("How to play") { HowToPlayView() }
                Button("Replay the first race") { app.replayTutorial() }
            }

            Section {
                if gameCenter.signedIn {
                    Button("Open Game Center") { gameCenter.openDashboard() }
                } else {
                    Text("Sign in to Game Center in the Settings app to see leaderboards and achievements there. The game works fully without it.")
                        .font(.footnote).foregroundStyle(Theme.muted)
                }
            } header: {
                Text("Game Center")
            }

            Section {
                Link("Privacy policy", destination: AppLinks.privacy)
                Link("Terms of use", destination: AppLinks.terms)
                Link("Support", destination: AppLinks.support)
                LabeledContent("Version", value: Self.version)
            } header: {
                Text("About")
            } footer: {
                Text("Echo Lap collects no data. Progress is saved only on this device. No ads, no purchases, no account.")
            }

            Section {
                Button("Reset all progress", role: .destructive) { confirmReset = true }
                    .accessibilityIdentifier("resetProgress")
            }
        }
        .scrollContentBackground(.hidden)
        .background(MenuBackground())
        .navigationTitle("Settings")
        .alert("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { app.resetProgress() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Stars, Sparks, racers, styles, saved runs and records on this device will be erased. This can't be undone.")
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}

/// Every control and every rule in one place. Rules of worlds not yet open stay hidden until they are.
struct HowToPlayView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        List {
            Section("Driving") {
                row("hand.draw.fill", "Steer", "Your car drives by itself. Drag your thumb left or right anywhere on the screen.")
                row("arrow.turn.down.right", "Drift", "Hold a turn hard at speed and the car drifts: sparks fly and the DRIFT pips fill. Let go for a boost. The longer the drift, the bigger the boost.")
                row("arrow.down", "Brake", "Pull your thumb straight down. You rarely need it: a long drift slows you too.")
                row("bolt.fill", "Nitro", "Swipe up, tap with a second finger or press NITRO. One fire costs the marked part of the meter.")
                row("gamecontroller.fill", "Controllers", "Left stick steers, A or left trigger brakes, B or right trigger fires nitro, X swaps.")
            }
            Section("Filling the nitro") {
                row("sparkles", "Drift boosts", "Every drift you release adds nitro, more for a longer drift.")
                row("car.2.fill", "Near misses", "Pass a solid echo by a whisker without touching it.")
                row("road.lanes", "The edge", "Ride the very edge of the road at speed. Over the kerb and it stops.")
                row("wind", "Slipstream", "Drive right behind an echo.")
                row("exclamationmark.triangle.fill", "Touching an echo", "Spins you out and empties the whole meter.")
            }
            Section("Echoes and the ladder") {
                row("repeat", "Your runs come back", "Your best runs on a track race you from the line as echo cars. Each one shows its rung: 1 is your best.")
                row("chart.bar.fill", "The echo ladder", "Every new best time puts one more of your runs on the road, up to five. Five echoes beaten with gold masters the track.")
                row("person.fill.viewfinder", "The rival", "Each world's rival drives the gold pace. Finish ahead for three stars.")
            }
            Section("Stars and rewards") {
                row("star.fill", "Stars", "1 star for finishing, 2 for beating the silver time, 3 for beating the rival. Stars open worlds and racers.")
                row("medal.fill", "Medals", "Each track has a medal goal that uses the skills: drift boosts, near misses, gates, swaps.")
                row("sparkle", "Sparks", "Earned from stars, medals, ladder rungs, daily goals and streaks. Spend them on styles in the garage.")
                row("chevron.up.2", "Level", "Every race earns XP. Each new level pays 100 Sparks.")
            }
            Section("World rules") {
                ForEach(World.allCases) { world in
                    if app.progress.isUnlocked(world) {
                        row("\(world.rawValue).circle.fill", world.ruleTitle, world.ruleText)
                    } else {
                        row("lock.fill", "World \(world.rawValue)", "Opens at \(world.starsToUnlock) stars.")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MenuBackground())
        .navigationTitle("How to play")
    }

    private func row(_ icon: String, _ title: String, _ text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Theme.rounded(.headline, .bold))
                Text(text).font(Theme.rounded(.subheadline, .regular)).foregroundStyle(Theme.muted)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
