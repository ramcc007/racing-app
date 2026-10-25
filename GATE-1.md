# Gate 1: pick the concept and the name

Stage 1 summary · 25 Oct 2026 · details in `research/top10-racing-apps.md` and `concept/concept-brief.md`

## What we learned
- **Top 10 iPhone racing games** (by ratings and downloads): Race Master 3D, Asphalt Legends, Bike Race, Need for Speed No Limits, CSR Racing 2, Asphalt 8, Hill Climb Racing, Hill Climb Racing 2, Rebel Racing, Drive Ahead!.
- **Players hate:** pay-to-win walls, fuel timers, forced ads, online-only games that shut down (Real Racing 3 was pulled in Dec 2025), and paid loot boxes.
- **Players love:** short sessions, physics that feel good, one-thumb controls that are easy to learn but hard to master, offline play, fair or no-purchase games, and racing ghosts.
- **The open gap:** a one-thumb racer that is also *deep*. Every one-thumb game is shallow, and every deep one needs two hands, licences and aggressive monetisation.
- **Avoid:** licensed 3D cars, highway traffic weaving, drag timing, and especially side-view hill-climb looks, which are crowded and draw Apple "copycat" (4.3) rejections.

## The recommended concept: **Echo Lap**
Every lap you finish stays on the track as an *echo*: a solid car that replays your exact line. Draft your echoes for boost, park one on a switch to hold a shortcut open, swap places with one, and dodge your own old mistakes. It's one thumb, top-down, offline, with 8 worlds × 15 tracks = 120 tracks, a daily track for everyone, and no timers, ads or paid randomness.

- **Scored 39/45**, the best of six twists, and still first when novelty counts double.
- **Runner-up: Fold**, where you fold the paper map for shortcuts. It's the most original idea, but riskier to build and to steer with one thumb.
- **Honest caveat:** "past runs come back as cars" exists in a 2015 commute puzzle (Does Not Commute) and two free jam games. What's new in Echo Lap is that echoes are *tools* (slipstream, switches, swaps, thin ice) inside a full racing game.

## Research gaps to close before Gate 1 sign-off
1. **App Store name check** for the shortlist. The search budget ran out; one more pass is needed.
2. **First-party App Store data and 300+ reviews per game.** This needs `itunes.apple.com` allowed in the environment's network settings; the scripts are ready.
3. Re-check the details marked ⓚ in the research (from prior knowledge), mainly Rebel Racing and Bike Race.

## Your decisions

| # | Decision | Recommendation | Why |
|---|---|---|---|
| 1 | **Concept** | **Echo Lap** (runner-up: Fold) | Best mix of feel, one-thumb fit, depth and buildability, and it answers the top complaints |
| 2 | **Name** | **Echo Lap** (`echolap.com` available); alternatives Lapback, Overlap Racer | Says what the game is; .com free. App Store clash check pending |
| 3 | **View** | **Top-down 2.5D in SpriteKit** | Faster to build, small download, easy to tune remotely; echoes read best from above |
| 4 | **Orientation** | **Portrait on iPhone**; portrait or landscape on iPad | One-handed play is part of the pitch, and stands out from landscape-only racers |
| 5 | **Repo** | **Private** | The twist is the whole product; keep it secret until launch. Expect to pay for extra Mac build minutes, or build less often |

**Next:** reply with your five choices. Any changes to the concept are welcome too. Stage 2 then starts: a version you can play in the iPhone browser, plus every screen designed.
