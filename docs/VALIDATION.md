# Validation report: Echo Lap 1.0

What has been checked, how, and what is still left for a real device. Every check below runs again on each push
(`.github/workflows/ios.yml`), so this stays true as the code changes.

## 1. Game logic: 107 automated tests (EchoLapCore)
Run on Linux and on the GitHub Mac (`swift test -c release`). All pass (plus 4 opt-in diagnostics that print track statistics).

| Area | What is proven |
|---|---|
| **Physics** (13 tests) | Acceleration stops at top speed; coasting rate; steering direction; no turning when stopped; corner speed matches turn rate; surfaces (sand, ice, grass) change top speed; draft and boost raise it; a docked car stays put; no steering in the air; spins ignore input; identical inputs give identical runs; hard cornering drifts; car contact. |
| **Race rules** (37 tests) | Countdown (short on retries), then GO; the clock starts at the line (flying start); a full race with laps, echoes and finish; an echo replays its lap exactly; saved runs race you from the line and the same driving takes the same time; driving backwards over the line doesn't count; echoes turn solid only once you pull clear; bumping a solid echo spins you once and empties the nitro; passing one by a whisker is a near miss that pays nitro, passing wide is not; riding the edge fills the nitro slowly; a tight corner at speed is a drift; soft echoes never spin you; Survival ends after three bumps; slipstream fills nitro and nitro spends it; no nitro without charge; the light racer drafts faster; parking on the pad opens the gate and the nitro button leaves it; a parked echo holds the gate; a closed gate blocks the shortcut; echo-held gate passes count; the sensor lowers the bridge for five seconds; ice cracks per pass and breaks after three; ice is fast and slippery; relay swap once per run; no swap without the rule; ramps launch and land; no jump when slow; wind pushes and an echo shelters; sand slows; the barrier along the kerb keeps you on the track and a hard hit costs speed, a scrape costs less but never stops you, the barrier has gaps at the bays and the lane; a car pinned on the barrier turns back onto the road; full lock on a straight still teaches the drift against the wall. |
| **Physics** (17 tests) | Automatic throttle; braking at the brake rate, never reversing; steering direction; no turning when stopped; holding a turn at speed drifts and releasing gives a tiered boost; gentle steering never drifts; drift corners tighter than grip; surfaces, draft and boost change top speed; docked and airborne cars; spins; determinism; car contact. |
| **Player policies** (2 tests) | On all 120 tracks, a player who drifts and fires the nitro reaches gold everywhere; a timid player who never drifts finishes everything, earns silver on 81 tracks and gold on 14 (tracks with no real corners), so gold needs the drift and silver mostly does not. |
| **Tracks** (3 + 9 tests) | All **120 career tracks** generate, pass every layout rule and are **driven to the finish by the robot**; daily, weekly and survival tracks too; builds are identical on every run (same track for everyone); every career track is one 20–45 s sprint; features per world and slot; medals match their world's skill; difficulty rises steadily; racers balanced and unlocking in order; **no other game names in any player-facing text**. |
| **Progress and rewards** (21 tests) | Fresh player sees only the first track; finishing opens the next; worlds open at their star thresholds; a two-star player can reach every world; racers unlock with stars; Survival and weekly unlock; star Sparks are incremental and a medal pays once; a slower run keeps the best time; an unfinished race pays nothing; XP and level-up Sparks; the Sparks balance always equals the reward lines shown; daily streak; weekly record; Survival Sparks capped; daily goals identical for the same day and unlocks, completed once, plus the bonus; buying and equipping; achievements unlock once; saves round-trip; **old or damaged saves still load**. |
| **Whole careers** (3 tests) | A simulated gold player opens everything (360 stars, 120 medals); a silver player still reaches all 120 tracks; a finish-only player is asked to improve before World 2. |
| **Utilities** (10 tests) | Vectors, seeded randomness, stable hashing, calendar edges (weeks start Monday, day changes in the player's calendar), time formats, ghost recording and playback, stars and pace. |

## 2. The app: builds and UI tests on an iPhone simulator
- Debug build for the simulator and **Release build for devices** both compile on the GitHub Mac with the newest
  Xcode. The Release check also confirms the privacy manifest is inside the app bundle.
- **UI tests (all pass):**
  - *First-launch journey:* intro (title, privacy link) → Start racing → the first race runs → results ("Nice
    driving!", stars, rewards) → Continue → home → Daily sheet → Garage → Trophies → Settings → World 1 map →
    track 1-2 detail → close.
  - *Pause menu:* pause opens the menu; resume closes it; restart starts a fresh race; quit asks for confirmation
    and returns to the menu.
  - *Controls:* the boost and pause buttons are at least 44 pt and expose their state to VoiceOver.

## 3. Screens reviewed on three devices
CI captures every main screen on an iPhone Pro Max, an iPhone SE (smallest supported screen) and a 13-inch iPad,
plus the UI tests' own screenshots (`[screens]` commits copies to `ci-screens/`). Reviewed by eye. Fixes made:

| Found | Fixed |
|---|---|
| Results buttons were invisible to UI tests and VoiceOver (an identifier on the container overrode them) | Identifier removed from the container |
| Mode card titles wrapped mid-word on the iPhone SE ("Gaunt-let") | Cards stack vertically on compact widths |
| Race HUD looked tiny on the 13-inch iPad | Timing panel and controls scale up on regular width |
| The first race waited for its track to build after "Start racing" | The intro builds it in the background |

Checked and correct: intro over the live demo race; race HUD (lap, time, gold-pace delta, echo chips, toasts,
gate status, boost); results (time, best and delta, stars, gold time, laps with best lap, medal, Spark lines, XP,
level-up); home (level and XP, stars, Sparks, medals, next track, modes, worlds, garage, trophies); world map with
rule card, medal and 15 tiles (locked, breather and boss marks); track detail with gold and silver times; daily
sheet with streak and goals; garage with racers, stats and styles; trophies; settings. Tutorial rewards add up:
3 stars (+50) + level 2 (+100) = 150 Sparks; 40 + 3×15 = 85 XP.

## 4. Still to check on real hardware (owner, with TestFlight)
- Feel of steering, boost and haptics on a real iPhone at 120 Hz; frame rate on an older device (iPhone 11 class).
- Game Center signed in (sandbox account) and signed out; achievement banners; leaderboard submissions.
- Sound with the silent switch on and off, and with music playing.
- iPad in a resizable window and with a game controller; iPhone Duo simulator (inner and outer displays).
- VoiceOver walk-through of the menus.
