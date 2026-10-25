# Owner steps: from this repo to the App Store

Everything that needs your Apple or GitHub account. The code side is done and tested by CI. Never paste keys,
passwords or card details into a chat: they go only into the GitHub and Apple pages named below.

## 0. Decisions only you can make
| Decision | Default in the code | Change where |
|---|---|---|
| Bundle ID (permanent once registered) | `store.numfall.echolap` (same publisher prefix as NumFall) | `ios/project.yml` (two places), `tools/ci/screenshots.sh`, `.github/workflows/testflight.yml` (two places) |
| App name on the Home Screen | Echo Lap | `CFBundleDisplayName` in `ios/project.yml`, intro title in `Views/IntroView.swift`, `site/*.html` |
| Support email on the website | support@numfall.store (NumFall's public address) | `site/*.html` |
| Website address | https://ramcc007.github.io/racing-app/ | `AppLinks` in `ios/EchoLap/EchoLapApp.swift` |

Before submitting: run a formal trademark search for the final name (USPTO, EUIPO, India IP office). The name
search on 25 Oct 2026 found no app, game or trademark called "Echo Lap". `echolap.com` was free on that date.

## 1. Publish the website (privacy, terms, support) — 5 minutes
1. Merge this branch into `main` (or open a pull request and merge it).
2. GitHub → racing-app → **Settings → Pages** → Build and deployment → Source: **GitHub Actions**.
3. GitHub → **Actions → Website → Run workflow** (it also runs by itself on every change to `site/`).
4. Open https://ramcc007.github.io/racing-app/privacy.html to check it's live.

## 2. Register the app with Apple — 15 minutes
1. https://developer.apple.com/account → **Certificates, Identifiers & Profiles → Identifiers → +** →
   App IDs → App → Description "Echo Lap", Bundle ID **explicit** `store.numfall.echolap`.
   Capabilities: tick **Game Center**. Register.
2. https://appstoreconnect.apple.com → **Apps → + → New App**: platform iOS, name "Echo Lap",
   primary language English (U.S.), bundle ID `store.numfall.echolap`, SKU `echolap-ios`, full access.

## 3. Let GitHub sign and upload builds — 10 minutes (reuse NumFall's key)
The TestFlight workflow uses an App Store Connect API key. You can reuse the key NumFall already uses.
GitHub → racing-app → **Settings → Secrets and variables → Actions → New repository secret**, four times:

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | the key ID (10 characters) |
| `ASC_ISSUER_ID` | the issuer ID (UUID above the keys list) |
| `ASC_KEY_P8` | the whole text of the `AuthKey_XXXXXXXXXX.p8` file, including the BEGIN/END lines |
| `APPLE_TEAM_ID` | your Team ID (developer.apple.com → Account → Membership details) |

Each upload creates a short-lived "EchoLap CI …" distribution certificate and profile, and removes the old ones on
the next run (never right after an upload: Apple checks the signature while processing). Apple allows only a few
distribution certificates per team: avoid running the NumFall and Echo Lap uploads at the same moment.

## 4. Game Center — 45 minutes
Follow `docs/GAME_CENTER_SETUP.md`: enable Game Center for the app, create the 4 leaderboards and 36 achievements
with the exact IDs, and later attach them to version 1.0.

## 5. First TestFlight build
1. Wait for **iOS build** to be green on GitHub for the commit you want.
2. GitHub → **Actions → TestFlight upload → Run workflow** → version `1.0` → Run (about 15 minutes).
3. App Store Connect → TestFlight: the build appears after Apple's processing (10–30 minutes).
   Answer the export compliance question if asked: the app uses no non-exempt encryption (already declared).
4. Install TestFlight on your iPhone and iPad, play: first race, a World 2 track, the daily track, garage purchase,
   pause/resume, switching the app away mid-race (it pauses). Try Game Center signed in and signed out.

## 6. Fill in the App Store page
All the text is in `docs/APP_STORE_LISTING.md`:
- Name, subtitle, keywords, promotional text, description, categories, URLs, copyright.
- Age rating questionnaire (all None/No → 4+). App privacy: **Data Not Collected**.
- Screenshots: download the **screenshots** artifact from the latest green iOS build run (Actions → run → Artifacts).
  Upload the iPhone 6.9" set and the iPad 13" set. First screenshot = race with echoes.
- Accessibility Nutrition Labels: only the ones listed in the listing doc.
- App Review notes: paste from the listing doc, add a demo video link (record the screen on the TestFlight build).
- EU Digital Services Act trader status (as for NumFall).

## 7. Submit
Version 1.0 → Build: choose the TestFlight build → Game Center: add all leaderboards and achievements →
**Add for Review → Submit**. Choose manual release if you want to pick the launch day.

## Later (not needed for 1.0)
- iPhone Duo screenshots become mandatory for submissions from April 2027; the iOS 27 SDK too.
- Purchases (cosmetics only) in a later version: needs the Paid Apps Agreement, StoreKit 2 with Restore Purchases,
  privacy policy update, and re-checking age-assurance rules (Texas) before adding monetisation.
