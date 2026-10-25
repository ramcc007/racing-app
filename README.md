# Echo Lap

A one-thumb top-down drift racer for iPhone and iPad. The car drives itself; you drag to steer, hold a turn hard to
drift and let go for a boost. Nitro comes from risk: drift releases, near misses, riding the edge, slipstream.
Every sprint is 20 to 45 seconds against a named rival, and your best runs come back as **echo** cars: the echo
ladder puts one more of them on the road with every new best, up to five. Beat all five with gold to master a track.
8 worlds × 15 tracks, a daily track, a weekly gauntlet and Echo Survival. Free, offline, no ads, no purchases.

## Repository map
| Path | What |
|---|---|
| `ios/EchoLapCore/` | Swift package with all game rules: physics at 120 Hz, echoes, every world rule, the track generator, the robot driver that test-drives each track, targets, rewards, progress and saving. Platform-independent and fully unit-tested. |
| `ios/EchoLap/` | The app: SwiftUI menus, SpriteKit race scene, sound, haptics, Game Center. |
| `ios/EchoLapUITests/` | UI tests: first launch → first sprint → results → GO AGAIN → every menu; pause menu; control sizes; the first race's lessons driven with real touches. |
| `ios/project.yml` | XcodeGen project spec (the `.xcodeproj` is generated, not committed). |
| `.github/workflows/` | `ios.yml` (tests, build, UI tests, screenshots on every push), `testflight.yml` (signed upload, started by hand), `pages.yml` (website). |
| `site/` | Privacy policy, terms, support page (GitHub Pages). |
| `docs/` | App Store compliance, Game Center setup, listing text, owner steps. |
| `research/`, `concept/`, `GATE-1.md` | Market research and the original concept. |

## Build and test
- **Game logic on any machine (Linux or Mac):** `tools/swift/linux-swift.sh test -c release` (Linux) or
  `cd ios/EchoLapCore && swift test -c release` (Mac). It drives all 120 tracks with the robot, plays them with
  a drifting nitro player and a timid player to keep the star targets honest, and simulates whole careers to check
  the reward numbers.
- **The app on a Mac:** `brew install xcodegen && cd ios && xcodegen && open EchoLap.xcodeproj`, then run the
  EchoLap scheme. Needs Xcode 26 or later.
- **Without a Mac:** push to GitHub; the **iOS build** workflow does everything on a GitHub-hosted Mac. Put
  `[screens]` in a commit message to have small screenshots committed to `ci-screens/` on that branch.

## Shipping
See `docs/OWNER_STEPS.md`.
