# App Store compliance: Echo Lap 1.0

How the app meets each App Review Guideline and Human Interface Guideline that applies to it, and where that
lives in the code. Research behind this: `research/notes/apple-guidelines-2026.md` (25 Oct 2026). Re-check Apple's
current rules before each submission. This is not legal advice.

Legend: ✅ done in code/CI · 👤 owner action in App Store Connect or GitHub (see `docs/OWNER_STEPS.md`)

## Build and platform
| Requirement | Status | Where |
|---|---|---|
| Built with Xcode 26+ / iOS 26 SDK (floor since 28 Apr 2026); iOS 27 SDK from Apr 2027 | ✅ CI selects the newest Xcode on the runner and prints it | `.github/workflows/ios.yml`, `testflight.yml` |
| Universal iPhone + iPad, iPad supports all four orientations and resizable windows | ✅ `TARGETED_DEVICE_FAMILY 1,2`, iPad orientations, no `UIRequiresFullScreen` | `ios/project.yml` |
| Race scene adapts to any size (iPad windows, iPhone Duo inner/outer display) | ✅ `.resizeFill` scene, camera zoom from the shorter side | `Game/GameScene.swift` (`zoom`) |
| Menus fit every size: content capped at 560–760 pt wide and centred, adaptive grids | ✅ | `Views/*.swift` |
| Launch screen is a plain colour matching the first frame (no logo, no splash) | ✅ `UILaunchScreen` → `LaunchBackground` #0E1116 | `project.yml`, asset catalog |
| App icon 1024×1024 PNG, no alpha, no rounded corners | ✅ rendered from code, flattened to RGB | `design/icon/icon.html`, `tools/icon/` |
| `ITSAppUsesNonExemptEncryption = NO` | ✅ | `project.yml` |
| 120 Hz on ProMotion iPhones | ✅ `CADisableMinimumFrameDurationOnPhone`, `preferredFramesPerSecond 120` | `project.yml`, `GameScene.swift` |
| Game controllers | ✅ `GCSupportsControllerUserInteraction`, extended gamepad mapping | `RaceController.currentInput()` |

## 2.1 App completeness, 2.3 accurate metadata, 2.5.19 no hidden features
| Requirement | Status | Where |
|---|---|---|
| No placeholder content, no "coming soon": all 120 tracks, daily, weekly and survival are in the binary | ✅ every track is generated on device and verified by the robot driver; CI test drives all 120 | `EchoLapCore/TrackLibrary.swift`, `Tests/.../TrackCatalogTests.swift` |
| Everything reachable through play; locked content shows exactly how to unlock it | ✅ lock toasts and cards ("opens at N stars", "finish 1-4") | `AppModel.play`, `WorldMapView`, `HomeView` |
| No remote config or feature flags (2.5.19); no network use at all | ✅ the app makes no network requests (links open Safari) | whole app |
| No crashes: robust save loading, no force-unwraps on saved data | ✅ fail-safe `Codable` (missing/garbled fields fall back to defaults); atomic writes | `EchoLapCore/Progress.swift`, `AppModel.save()` |
| Debug-only launch flags compiled out of release | ✅ `#if DEBUG` around autopilot, fast-forward, screenshot scenes | `RaceController`, `ScreenshotScene.swift` |
| Screenshots show real gameplay | ✅ captured from the app by CI | `tools/ci/screenshots.sh` |

## 4.1 / 4.3 originality
| Requirement | Status |
|---|---|
| Original core mechanic: every finished lap becomes an echo car used as a tool (slipstream, pads, relay swap, sensor bridge, shelter from wind) | ✅ |
| No real brands, cars, tracks or other game names anywhere visible | ✅ code-drawn cars and tracks; checked by search before each submission (`grep -rIniE "<brand list>" ios site docs/APP_STORE_LISTING.md`) |
| Listing leads with the twist; first screenshot shows echoes on track | 👤 order in `docs/APP_STORE_LISTING.md` |

## 3.1 payments and 5.6 manipulation
| Requirement | Status |
|---|---|
| v1: no purchases, no ads, no loot boxes, no energy or timers | ✅ |
| Sparks are earned only, have no money value, can't be bought or exchanged | ✅ stated in the garage purchase dialog and terms |
| Economy ready for a future IAP version (cosmetics only, never pay-to-win) | ✅ prices in `Economy.swift`; future IAP must use StoreKit 2 with Restore Purchases |
| Rating prompt: `requestReview` only after a 3-star result, at most twice, never from a button or for a reward | ✅ `ResultsView.maybeAskForReview` |

## 5.1 privacy
| Requirement | Status | Where |
|---|---|---|
| Privacy label "Data Not Collected" | 👤 answer in App Store Connect | |
| Privacy manifest: no tracking, no collected data, UserDefaults CA92.1 | ✅ | `Resources/PrivacyInfo.xcprivacy` |
| No third-party SDKs | ✅ | |
| Privacy policy linked in App Store Connect and inside the app (intro, home footer, Settings) | ✅ in app · 👤 publish site, paste URL | `AppLinks`, `site/privacy.html` |
| No permission prompts at all (no tracking, notifications, camera, location). Tilt steering uses CoreMotion, which needs no permission | ✅ | |
| Progress stays on device; reset available (Settings → Reset all progress) | ✅ | `SettingsView` |

## Game Center
| Requirement | Status | Where |
|---|---|---|
| Entitlement written in full for all configurations; CI checks the archived app has it | ✅ | `project.yml`, `testflight.yml` |
| Silent sign-in after the first race; never blocks; all GameKit failures ignored | ✅ | `GameCenter.swift` |
| Access point on menus only (hidden on intro, tutorial and races) | ✅ | `HomeRoot` |
| 4 leaderboards + 36 achievements created and attached to version 1.0 | 👤 | `docs/GAME_CENTER_SETUP.md` |

## Age rating
4+: bumps and spins only (no damage, explosions or people). Questionnaire answers in `docs/APP_STORE_LISTING.md`. 👤

## Human Interface Guidelines
| Area | Status | Where |
|---|---|---|
| Play within seconds of first launch: no account, no splash, one tap to race; tutorial teaches by playing and can be replayed | ✅ | `IntroView`, `RaceController` hints, Settings |
| Touch targets ≥ 44 pt (pause 48, boost 84, swap 68; menu buttons use `.controlSize(.large)`) | ✅ UI test asserts sizes | `RaceView`, `EchoLapUITests` |
| System edge gestures deferred, status bar and home indicator hidden during races; race pauses when the app leaves the foreground | ✅ | `RaceScreen` |
| Pause menu with resume, restart, quick settings and a confirmed quit; no in-app "Quit app" | ✅ | `PauseMenu` |
| Liquid Glass on iOS 26+ (`glassEffect`, `.glass`, `.glassProminent`), material fallback on iOS 17–25; no glass over the moving race (HUD uses solid, high-contrast backing) | ✅ | `Theme.swift` |
| Dark appearance throughout (games may fix their appearance) | ✅ `UIUserInterfaceStyle Dark` | |
| Dynamic Type in menus up to accessibility3; HUD numbers fixed size by design | ✅ | `EchoLapApp` |
| VoiceOver: every menu control labelled; race HUD readable; the race view allows direct touch | ✅ | accessibility labels/identifiers across `Views/` |
| Reduce Motion: no camera rotation, shake or particles; star reveal instant | ✅ + "Calm effects" setting | `GameScene`, `ResultsView` |
| Colour is never the only signal: echoes carry lap numbers; Okabe–Ito colour-blind-safe palette | ✅ | `Theme.echo`, `EchoChips`, `GameScene` labels |
| Haptics and sound can each be turned off; sound uses the ambient category (respects the silent switch, mixes with music) | ✅ | `Sound.swift`, Settings |

## Before every submission
1. CI green on the commit being shipped: core tests, simulator build, UI tests.
2. Brand-name search clean (see 4.3 above).
3. TestFlight build installed on a real iPhone and iPad: play the first race, a World 2 track, the daily track; check Game Center signed in and signed out.
4. Website pages live (privacy, terms, support).
5. Game Center components attached to the version.
