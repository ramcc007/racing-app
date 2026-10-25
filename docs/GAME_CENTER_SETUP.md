# Game Center setup for Echo Lap 1.0

Everything below must exist in App Store Connect **before the first TestFlight build is tested** and must be
**attached to version 1.0 and submitted with it** (first-time Game Center components can't be reviewed on their own).
The identifiers are used in code exactly as written (`ios/EchoLap/GameCenter.swift`,
`ios/EchoLapCore/Sources/EchoLapCore/Achievements.swift`). A typo here means that item silently never reports.

Where: App Store Connect → Apps → Echo Lap → **Services → Game Center** (enable it for the app first), then
**Version 1.0 → Game Center → add the leaderboards and achievements** before you submit.

The game works fully without Game Center. Sign-in is silent and starts only after the first race. The access point
shows only on menus, never on the intro, in the tutorial or during a race.

## Leaderboards (4)

| ID | Name (English) | Type | Sort | Score format | What is submitted |
|---|---|---|---|---|---|
| `echolap.lb.stars` | Career stars | Classic | High to low | Integer | Total career stars (0–360), after every save |
| `echolap.lb.daily` | Daily track | **Recurring**, every 1 day, starting at 00:00 UTC | Low to high | Elapsed time, hundredths of a second | Best time on today's daily track |
| `echolap.lb.weekly` | Weekly gauntlet | **Recurring**, every 7 days, starting Monday 00:00 UTC | Low to high | Elapsed time, hundredths of a second | Total time of the three gauntlet races |
| `echolap.lb.survival` | Echo Survival | Classic | High to low | Integer (suffix "laps") | Best number of laps survived |

Notes:
- Scores for time boards are sent in **hundredths of a second** (`Int(seconds × 100)`), so choose the
  *Elapsed Time – to the hundredth of a second* format.
- Daily and weekly tracks change at **local** midnight on the player's device. A recurring board resets on one
  schedule for everyone (UTC); a time set late in the evening in some time zones can land in the next board's
  period. This is harmless (the board just shows the best time in that period).
- Score range: stars 0–360, survival 0–500, times 1–3,000,000 (protects against bogus values).

## Achievements (36, 999 points of the 1,000 allowed)

Each needs: reference name, ID, points, "Hidden: No", "Achievable more than once: No", and one English
localisation with a title, a pre-earned description, an earned description and a **512×512 (or 1024×1024) PNG**.
Use the title and description below for both descriptions. Images can be simple: the app icon's car on the
world colour works (export from `design/icon/icon.html`).

| ID | Title | Description | Points |
|---|---|---|---|
| `echolap.ach.firstFinish` | Lights out | Finish your first race. | 10 |
| `echolap.ach.firstGold` | Gold standard | Earn three stars on a track. | 15 |
| `echolap.ach.world1` | Harbour cleared | Finish the boss track of Harbour. | 14 |
| `echolap.ach.world2` | Red Canyon cleared | Finish the boss track of Red Canyon. | 18 |
| `echolap.ach.world3` | Neon City cleared | Finish the boss track of Neon City. | 22 |
| `echolap.ach.world4` | Glacier cleared | Finish the boss track of Glacier. | 26 |
| `echolap.ach.world5` | Jungle Ruins cleared | Finish the boss track of Jungle Ruins. | 30 |
| `echolap.ach.world6` | Foundry cleared | Finish the boss track of Foundry. | 34 |
| `echolap.ach.world7` | Sky Port cleared | Finish the boss track of Sky Port. | 38 |
| `echolap.ach.world8` | Orbit Ring cleared | Finish the boss track of Orbit Ring. | 42 |
| `echolap.ach.stars50` | Star collector | Earn 50 stars. | 25 |
| `echolap.ach.stars150` | Constellation | Earn 150 stars. | 30 |
| `echolap.ach.stars300` | Galaxy | Earn 300 stars. | 50 |
| `echolap.ach.stars360` | Every star | Earn all 360 stars. | 80 |
| `echolap.ach.medals10` | Decorated | Earn 10 echo medals. | 20 |
| `echolap.ach.medals60` | Medal case | Earn 60 echo medals. | 35 |
| `echolap.ach.medals120` | Full honours | Earn every echo medal. | 60 |
| `echolap.ach.mastered1` | Top of the ladder | Master a track: five echoes beaten with gold. | 20 |
| `echolap.ach.mastered15` | Ladder climber | Master 15 tracks. | 40 |
| `echolap.ach.mastered60` | Echo legend | Master 60 tracks. | 80 |
| `echolap.ach.drifts100` | Sideways | Earn 100 drift boosts. | 15 |
| `echolap.ach.drifts1000` | Drift king | Earn 1,000 drift boosts. | 30 |
| `echolap.ach.nearMiss50` | By a whisker | Pass your echoes within a whisker 50 times. | 20 |
| `echolap.ach.nearMiss500` | Paint trader | 500 near misses. | 35 |
| `echolap.ach.drafts100` | Slipstreamer | Slipstream behind echoes 100 times. | 15 |
| `echolap.ach.boosts250` | Afterburner | Fire the nitro 250 times. | 20 |
| `echolap.ach.swaps50` | Relay runner | Relay-swap 50 times. | 25 |
| `echolap.ach.gate25` | Gatekeeper | Pass 25 gates or bridges your echoes opened. | 25 |
| `echolap.ach.ice30` | Icebreaker | Break 30 sheets of thin ice. | 25 |
| `echolap.ach.jumps100` | Moonwalker | Take 100 jumps. | 25 |
| `echolap.ach.sprints1000` | Marathon | Finish 1,000 sprints. | 30 |
| `echolap.ach.daily1` | Daily driver | Finish a daily track. | 10 |
| `echolap.ach.streak3` | Three in a row | Finish the daily track 3 days in a row. | 15 |
| `echolap.ach.streak7` | Week streak | Finish the daily track 7 days in a row. | 25 |
| `echolap.ach.streak30` | Month streak | Finish the daily track 30 days in a row. | 40 |
| `echolap.ach.weekly1` | Gauntlet runner | Finish a weekly gauntlet. | 20 |
| `echolap.ach.survival10` | Crowd control | Survive 10 laps in Echo Survival. | 20 |
| `echolap.ach.survival25` | Echo chamber | Survive 25 laps in Echo Survival. | 30 |
| `echolap.ach.level10` | Pro driver | Reach driver level 10. | 20 |
| `echolap.ach.level25` | Champion | Reach driver level 25. | 35 |
| `echolap.ach.garage` | Full garage | Unlock all six racers. | 25 |
| `echolap.ach.stylist` | Stylist | Own 10 paints, trails or celebrations you bought. | 15 |

## Testing

1. In App Store Connect → Users and Access → **Sandbox**, create a sandbox Apple Account.
2. On a test iPhone: Settings → Game Center → sign in with the sandbox account (or sign in when the game asks).
3. Install the TestFlight build, finish the first race, go to the menu: the Game Center access point appears top-left.
4. Finish a daily track → Trophies → Leaderboards shows your time. Finish 1-15 → "Harbour cleared" banner.
5. Also test **signed out**: everything must work the same with no Game Center at all.
