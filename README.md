# Echo Lap

A one-thumb top-down racing game for iPhone and iPad. Every lap you finish stays on the track as an **echo** car:
slipstream it for boost, park it on a switch to hold a shortcut open, swap places with it, or dodge it.
8 worlds × 15 tracks, a daily track, a weekly gauntlet and Echo Survival. Free, offline, no ads, no purchases.

## Repository map
| Path | What |
|---|---|
| `ios/EchoLapCore/` | Swift package with all game rules: physics at 120 Hz, echoes, every world rule, the track generator, the robot driver that test-drives each track, targets, rewards, progress and saving. Platform-independent and fully unit-tested. |
| `ios/EchoLap/` | The app: SwiftUI menus, SpriteKit race scene, sound, haptics, Game Center. |
| `ios/EchoLapUITests/` | UI tests: first launch → first race → results → every menu; pause menu; control sizes. |
| `ios/project.yml` | XcodeGen project spec (the `.xcodeproj` is generated, not committed). |
| `.github/workflows/` | `ios.yml` (tests, build, UI tests, screenshots on every push), `testflight.yml` (signed upload, started by hand), `pages.yml` (website). |
| `site/` | Privacy policy, terms, support page (GitHub Pages). |
| `docs/` | App Store compliance, Game Center setup, listing text, owner steps. |
| `research/`, `concept/`, `GATE-1.md` | Market research and the original concept. |

## Build and test
- **Game logic on any machine (Linux or Mac):** `tools/swift/linux-swift.sh test -c release` (Linux) or
  `cd ios/EchoLapCore && swift test -c release` (Mac). It drives all 120 tracks with the robot and simulates whole
  careers to check the reward numbers.
- **The app on a Mac:** `brew install xcodegen && cd ios && xcodegen && open EchoLap.xcodeproj`, then run the
  EchoLap scheme. Needs Xcode 26 or later.
- **Without a Mac:** push to GitHub; the **iOS build** workflow does everything on a GitHub-hosted Mac. Put
  `[screens]` in a commit message to have small screenshots committed to `ci-screens/` on that branch.

## Shipping
See `docs/OWNER_STEPS.md`.
