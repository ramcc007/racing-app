# Prompt for Claude Code — Stage 1: Market research + racing game concept

> Paste everything below the line into a new Claude Code session on the `racing-app` repo.

---

You are helping a solo app owner make their second iOS game. Their first, **NumFall** (a number/board puzzle game), is live on the App Store. The second will be an **original racing game for iPhone and iPad only**, with lots of levels, difficulty that keeps rising, and a hook players haven't seen before.

The owner is not a developer. Write everything in plain English, explain any jargon the first time you use it, and keep summaries short.

This session covers **Stage 1 (Concept) only**: research, then a concept with concept images. **Do not build the app, set up an Xcode project, or write any game code.** Stop at Gate 1 and hand the decisions back to the owner.

## Ground rules from the owner's launch brief

Every concept you propose has to follow these. Score anything that breaks one as a risk.

- **Originality.** Racing is very crowded, and Apple rejects copycat games (App Review Guidelines 4.1 and 4.3). The new part must come from *how the game plays*, not just how it looks.
- **No "first ever" claims.** Store text describes what the player does. It never claims to be a first.
- **Technology.** Top-down or side-on 2.5D in Apple's SpriteKit is the recommended route. Full 3D (RealityKit) is allowed only if you show it's worth the extra time and art. Graphics are drawn by code, not image files. Music and sound are made by code. Nothing needs a licence.
- **Tracks are generated and checked by code.** Every track has to be finishable. A robot driver sets the target times. Difficulty rises gradually. Aim for 100+ tracks or an endless generator, plus a daily track that's the same for every player.
- **Controls.** Must work one-thumbed, with touch targets of at least 44 pt and haptics on drifts and impacts. Tilt steering can be an option, but there's always a touch alternative.
- **Performance.** 120 Hz on ProMotion iPhones and a steady 60 fps on older ones. Don't drain the battery or overheat the phone.
- **Accessibility.** Reduce Motion support, a motion-sickness option, colour-blind-safe colours, VoiceOver on menus, Dynamic Type.
- **No live online races in version 1.** Rivalry comes from ghost races against your own best run (saved on the device) and Game Center leaderboards. The privacy label stays "Data Not Collected".
- **Legal.** No real car brands, logos or recognisable car shapes. No real racing series, circuits, teams or drivers. No other game's name anywhere a player or Apple could see it. Real app names are fine **in the research documents only**.
- **Age rating.** Cartoon crashes only. No gore, no real weapons, nothing that looks like gambling (no paid random crates or loot boxes).
- **Money.** In-app purchases come **later, not in version 1**. Design the reward economy so purchases can be added later without breaking it. Don't promise "free forever" or "no ads" anywhere.

## Part A — Research the top 10 iPhone racing games

### A1. Build the ranking

1. Make a long list of **at least 25 racing games currently on the iPhone App Store**. Cover every kind: arcade, simulation, drag, drift, physics hill-climb, motorbike, kart, endless traffic, hyper-casual, Apple Arcade and premium. Some names to start from (check each one, don't assume): Asphalt Legends Unite, Asphalt 8, Real Racing 3, CSR Racing 2, Hill Climb Racing, Hill Climb Racing 2, Need for Speed No Limits, Traffic Rider, Traffic Racer, Beach Buggy Racing 2, Rush Rally 3, CarX Drift Racing 2, Mad Skills Motocross 3, Bike Race, Race Master 3D, Drive Ahead!, Horizon Chase, GRID Autosport, Mario Kart Tour. Add any others you find in current top-grossing and top-free racing charts.
2. **Measuring installs and reviews.** Apple doesn't publish install numbers, so use these, in this order:
   - **Ratings count and average rating** from the iTunes Lookup API (`https://itunes.apple.com/lookup?id=<id>&country=us`, fields `userRatingCount` and `averageUserRating`). Look up the app IDs with `https://itunes.apple.com/search?term=<name>&entity=software&country=us`. Get the same fields for at least the **US, UK, India and Germany** stores.
   - **Download estimates** from public sources: Sensor Tower, AppMagic or data.ai articles and press releases, developer announcements, and Google Play install ranges as a cross-platform guide. Label all of these clearly as estimates.
   - **Current chart position** in the racing category, where you can get it.
3. Rank by a score you state up front, for example 60% US ratings count and 40% best available lifetime download estimate, each normalised. Show the formula and the full long list with scores, then the top 10.
4. **Never invent a number.** Every figure gets its source URL and the date you accessed it. If a source is blocked or missing, write "not found" and move on. If the network blocks a host you need, tell the owner which host it was.

### A2. Study each of the top 10

For each app, record:

| Area | What to capture |
|---|---|
| Basics | Developer, launch year, price model, download size, minimum iOS, iPad support, orientation |
| View and tech | 2D, 2.5D or 3D; camera style; how realistic or cartoony it looks |
| Controls | Steering method, gas/brake, drift, boost; how many fingers; tilt option |
| Core loop | What happens in 10 seconds, in one race and in a week; typical race and session length |
| Levels and environments | Number of tracks, levels or events; environments and biomes; career/season structure; how new content is unlocked |
| Difficulty | How difficulty rises (opponents, track shape, obstacles, time targets, vehicle stat checks); where players hit a wall |
| Points and rewards | Score system, stars/medals, currencies (soft and hard), XP and levels, daily rewards, chests, streaks, achievements, leaderboards |
| Upgrades and collection | Vehicles, upgrade trees, parts, cosmetics, how they're earned |
| Monetisation (for later) | IAP types and price points, ads (rewarded vs forced), energy/fuel timers, battle or season pass, subscriptions, loot boxes. Flag anything that would break our "no gambling look" rule. |
| Social and replay | Multiplayer, ghosts, clubs, events, daily challenges |
| What players love | Top themes, with counts and 2–3 short quotes each |
| What's missing or annoying | Top complaints, with counts and 2–3 short quotes each |

**Review mining.** For each app, pull recent written reviews from the App Store RSS feed: `https://itunes.apple.com/<cc>/rss/customerreviews/page=<1-10>/id=<id>/sortby=mostrecent/json`. Use the US store plus at least one other. Aim for 300+ reviews per app if the feed has that many. Sort them into themes with a simple, repeatable method you describe, then count each theme and report the share of reviews. Save the raw reviews so the numbers can be checked again. Quotes must be copied word for word and kept short.

### A3. Patterns across all 10

- What almost every game does (table stakes we need too).
- What's **saturated**: mechanics and looks so common that copying them invites a 4.3 rejection and player boredom.
- The most common complaints across the genre, ranked. For example: energy timers, pay-to-win walls, forced ads, always-online requirements, repetitive tracks, huge downloads, battery drain and heat, poor iPad layouts, fiddly controls. Confirm these from the data; don't assume them.
- **Gaps:** what players ask for that nobody delivers well. Plot every app on two or three simple maps (for example, *casual ↔ deep* against *realistic ↔ stylised*, or *one-thumb ↔ two-hand* against *short sessions ↔ long sessions*) and point out the empty corners.
- What a solo developer can realistically compete on, and what to stay away from (licensed cars, photoreal 3D, live PvP).

## Part B — The concept

### B1. Twists

Write **at least 5 truly different gameplay twists**, each in 2–3 lines. Make sure several of them change the *controls or the track itself*, not only the theme. Examples of the kind of idea we mean, not ones to copy: a track that rebuilds itself as you race, steering by drawing your racing line, racing on a surface that changes under you.

Score each twist from 1 to 5 on the criteria below. Show the table, then recommend one, and briefly say why each of the others lost.

1. Novelty: can it pass 4.3, and can it be explained in one sentence?
2. Fun within 30 seconds
3. Works one-thumbed on iPhone; also feels good on iPad
4. Can be built in SpriteKit 2.5D with code-drawn art
5. Enough depth for 100+ levels with rising difficulty
6. Fixes the gaps found in Part A
7. Works in short "can you beat this?" videos
8. Can take cosmetic or convenience purchases later without becoming pay-to-win
9. Risk, scored so that higher means safer: technical, review and legal risk

### B2. The recommended concept, fully written up

- One-line pitch and a 30-second description, written the way a player would tell a friend.
- **Core loop** for one moment, one race, one session, and the long game.
- **Controls** step by step, with the iPad differences. Mention haptics and the accessibility options.
- **Levels and environments:** worlds and biomes (at least 6), how many tracks each has, and the order new mechanics arrive in. Explain how the generator and the robot-driver check guarantee every track is finishable, and how the daily track works. Include a **difficulty curve** with real numbers for target times, obstacle density, speed and the like, from level 1 to 100+, including rest levels and boss tracks.
- **Points and rewards:** scoring, 1–3 stars or medals, currencies, unlocks, achievements, daily and weekly goals, streaks, and ghost and leaderboard rivalry. Everything must be fair, with no random paid rewards.
- **Purchases for later (design only, nothing built):** list 3–5 options that fit the economy, such as cosmetic packs, a level-pack expansion, a one-time "remove ads" or premium unlock, or a season pass with no paid randomness. For each, say how it avoids pay-to-win.
- **Why players will love it:** tie each feature back to a "what's missing" finding from Part A.
- **Risks** and how to handle them, including how the game feels, performance, how it could be mistaken for a copy, and scope.
- **Names:** suggest 3–5 original names. For each, check that no App Store app already uses the name (iTunes Search API) and whether the `.com` domain looks free (WHOIS or a registrar lookup), and say how you checked. Don't use a name close to an existing game's.

### B3. Concept images

Make concept images **by code**: SVG or HTML/CSS, rendered to PNG with the Playwright and Chromium already installed in this environment. Don't run `playwright install`. Use the same code-drawn style the real game would use. Original shapes only, with no real cars, logos or other games' styles. Make:

1. Key art (hero image) for the concept.
2. A mid-race gameplay screen on iPhone, at 1320×2868 portrait or 2868×1320 landscape, whichever the concept uses.
3. The same moment on iPad at 2064×2752 (or landscape), showing how the layout uses the bigger screen.
4. The world or level-select map, showing progression and stars.
5. The race-results and rewards screen.
6. An environment mood board covering the 6+ worlds.
7. A vehicle line-up of 4–6 original designs.
8. A diagram of the main twist: one picture that explains the new mechanic.

Keep the source files next to the PNGs so they can be edited, and label every image **"Concept — not final art"**.

## Deliverables

Put everything in this repo:

```
research/
  top10-racing-apps.md      # ranking method, long list, top 10, per-app breakdowns, cross-app patterns
  data/apps.json            # raw metrics per app with source URLs and access dates
  data/reviews/<app>.json   # raw reviews used for theme counts
  scripts/                  # any fetch/analysis scripts, runnable again
concept/
  concept-brief.md          # Part B in full
  images/*.png + sources
GATE-1.md                   # one-page summary + the decisions the owner must make
```

Also put the research summary, the concept and the images together in **one easy-to-read HTML report** for the owner to review on their phone, and publish it as a private Artifact.

`GATE-1.md` must end with these owner decisions, each with your recommendation:

1. Which concept (your pick, plus the runner-up).
2. Which name.
3. View: 2.5D SpriteKit or 3D.
4. Portrait or landscape.
5. Repo: public (free build minutes, idea visible) or private (idea secret, extra build minutes likely paid).

Commit with clear messages and push to the working branch. Don't open a pull request. Finish with a short chat summary: the top 10 in one line each, the recommended concept in three lines, and the link to the report.
