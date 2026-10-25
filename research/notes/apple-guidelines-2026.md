# Apple requirements for submitting Echo Lap (as of 25 Oct 2026)

Research date: 2026-10-25. Scope: a new, free, offline iPhone + iPad game ("Echo Lap": SwiftUI + SpriteKit, portrait on iPhone, no accounts/ads/IAP in v1, optional Game Center, local saves + optional iCloud key-value sync, privacy label "Data Not Collected").

## Method and limitations (read first)

- Only WebSearch was available (35 searches, the session cap). No page could be opened directly, so every claim comes from a search-result summary. Source URLs are inline.
- **[unverified]** marks anything I could not confirm in this session: single secondary sources, forum posts without an Apple answer, or things taken from prior knowledge (anything up to mid-2026) that I did not re-check.
- NumFall checklist items (privacy policy URL, `ITSAppUsesNonExemptEncryption = NO`, no brand names, 2.4.1 iPad layout, 4.3, 2.1, review notes + demo video, DSA trader status, 6.9"/13" screenshots) are not repeated here, apart from where something has changed.

### Two new things since NumFall that change the build
1. **iOS 27 / Xcode 27 shipped in September 2026, and Xcode 27.1 shipped on 15 Oct 2026.** This means the Liquid Glass opt-out key no longer works for new builds, and the iOS 27 SDK becomes mandatory in April 2027.
2. **iPhone Duo (Apple's foldable) launched in Sept–Oct 2026.** Apple expects all apps to adapt to any scene size. On the inner display, a portrait lock is not guaranteed to hold. **iPhone Duo screenshots become mandatory for submissions from April 2027.** A portrait-only SpriteKit game must therefore cope with being resized.

---

## 1. SDK / Xcode minimum and CI runner

**Findings**
- **Current upload floor:** since **28 April 2026**, uploads must be built with **Xcode 26 or later using the iOS/iPadOS 26 SDK**. Apple's page gives the exact date ([developer.apple.com/news/upcoming-requirements](https://www.developer.apple.com/news/upcoming-requirements/); confirmed by [Expo](https://expo.dev/blog/app-store-connect-minimum-sdk-26) and [Capawesome](https://capawesome.io/blog/xcode-26-requirement-for-capacitor-apps/)). The rule restricts the SDK you build with, not the deployment target ([Choicely](https://www.choicely.com/tutorials/how-to-publish-an-app-to-the-app-store)).
- **Next floor:** "Starting April 2027" uploads must use the **iOS/iPadOS 27 SDK** ([MacTech, 10 Sep 2026](https://www.mactech.com/2026/09/10/app-store-submissions-now-open-for-the-latest-os-releases/), [iphonesoft.fr](https://iphonesoft.fr/2026/09/11/ios-27-developpeurs-soumettre-applications-xcode-27-obligatoire-avril)). Apple has not given the exact day ([forum 839939](https://developer.apple.com/forums/thread/839939)).
- **Current Xcode:** **Xcode 27.1 (27A9275), released 15 Oct 2026** ([Apple releases](https://developer.apple.com/news/releases?id=10152026a), [Xcode 27.1 release notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_1-release-notes.md), [Classmethod weekly, 17 Oct](https://dev.classmethod.jp/articles/ios-dev-weekly-changes-20261017/)). It ships Swift 6.4 and the 27.x SDKs, including the **iPhone Duo SDK and simulator**, and **requires macOS Tahoe 26.6 or later**. Apple opened App Store submissions for Xcode 27 RC builds on ~10 Sep 2026, and iOS 27 shipped on 14 Sep ([igeeksblog](https://www.igeeksblog.com/app-store-submissions-ios-27-macos-27/), [9to5mac](https://9to5mac.com/?p=1069115)). Xcode 26.x is therefore no longer the latest, though it is still accepted until April 2027.
- **GitHub Actions:**
  - GitHub now publishes a **separate image per Xcode major version**. The **Xcode 27 runner image became GA on 15 Oct 2026**. Its labels are **`xcode-27`** and **`xcode-27-xlarge`**, it is **arm64 (Apple silicon) only**, and since 10 Sep 2026 it runs on **macOS 27** ([GA](https://github.blog/changelog/2026-10-15-xcode-27-runner-image-generally-available), [preview](https://github.blog/changelog/2026-07-16-xcode-27-runner-image-now-in-public-preview), [moved to macOS 27](https://github.blog/changelog/2026-09-10-xcode-27-runner-image-now-runs-on-macos-27)).
  - **`macos-latest` = `macos-26`** since June 2026, with Xcode **26.6 as the default** from 21 Jul 2026 ([runner-images release notes](https://newreleases.io/project/github/actions/runner-images/release/macos-26%2F20260805.0449)). It passes today's floor but **not** April 2027's. Whether `macos-26` also carries Xcode 27.x: **[unverified]**.
  - `macos-15` has Xcode 16 by default, which is below the floor. Do not use it.

**What to do**
- Build and archive with **Xcode 27.1**, and use `runs-on: xcode-27` in CI. This passes both the current and April-2027 floors and gives full iPhone Duo adaptivity. Apps built with the iOS 26 SDK or earlier run on Duo "but won't adapt to all layouts" ([Adapty](https://adapty.io/blog/markdown/adapt-your-ios-app-to-iphone-duo.md), [InfoQ](https://infoq.com/news/2026/09/apple-iphone-duo-api)).
- Print `xcodebuild -version` in the workflow, and fail the job if it isn't 27.x. Select the exact version with `xcode-select` if the image has more than one. The Xcode path on the image is **[unverified]**, so list `/Applications/Xcode*` once to find it.
- **Deployment target: iOS/iPadOS 26.0** (my recommendation). All the Liquid Glass SwiftUI APIs then work without `#available` branches, and iOS 26 runs on iPhone 11 and later. **[unverified]** Current iOS 26+ adoption share was not checked.
- For local Mac builds: macOS Tahoe 26.6+ is needed for Xcode 27.1.
- The repo is public, so standard GitHub-hosted macOS minutes are free. Whether `xcode-27` counts as a standard (free) runner: **[unverified]**. `-xlarge` is a paid larger runner.

## 2. iOS 26/27 design: Liquid Glass

**Findings**
- **Automatic adoption:** Apple says standard SwiftUI/UIKit/AppKit controls and navigation elements "pick up the appearance and behavior of this material automatically" when built with the latest SDKs. Custom elements can opt in. Custom backgrounds on controls and bars "might overlay or interfere with Liquid Glass", so remove them ([Liquid Glass overview](https://developer.apple.com/documentation/technologyoverviews/liquid-glass.md), [Adopting Liquid Glass](https://developer.apple.com/tutorials/data/documentation/technologyoverviews/adopting-liquid-glass.md)).
- **SwiftUI APIs, all iOS 26.0+:** `glassEffect(_:in:)` with `Glass.regular` / `.clear` / `.identity`, `.tint()`, `.interactive()`; `GlassEffectContainer(spacing:)` to group nearby glass shapes, which also helps rendering cost; `glassEffectID(_:in:)` with a `@Namespace` for morphing; `glassEffectUnion(id:namespace:)`; `.buttonStyle(.glass)` and `.buttonStyle(.glassProminent)` ([Donny Wals](https://www.donnywals.com/grouping-liquid-glass-components-using-glasseffectunion-on-ios-26/), [Medium reference](https://medium.com/@veersr9/ios-26-liquid-glass-in-swiftui-a-practical-reference-demo-app-liquidglassreference-69b8d46dc055)). The exact signatures and "iOS 26.0+" availability come from prior knowledge of Apple's docs: **[unverified this session]**.
- **Opt-out flag `UIDesignRequiresCompatibility`:**
  - When built with the **Xcode 27 SDKs** the key is **ignored**, even with a deployment target of 26 or earlier.
  - When built with the Xcode 26 SDKs it is still honoured on the 26 and 27 releases.
  - Source: Apple engineer's accepted answer in [forum 838637](https://developer.apple.com/forums/thread/838637), plus [836833](https://developer.apple.com/forums/thread/836833) and [832543](https://developer.apple.com/forums/thread/832543). Apple had said at WWDC25 that it would remove the option "in the next major release" ([BayTech](https://www.baytechconsulting.com/blog/liquid-glass-app-store-deadline-misunderstood.md)). Combined with the April 2027 SDK floor, the opt-out is effectively finished.
- **HIG for games:** I found no game-specific Liquid Glass guidance. The general HIG (Materials) says Liquid Glass belongs to the **controls/navigation layer floating above content**, not to the content itself, and should be used sparingly. That is from prior knowledge: **[unverified this session]**.

**What to do**
- **Don't set `UIDesignRequiresCompatibility`.** It has no effect with Xcode 27.
- Treat the **SpriteKit race scene as content** and SwiftUI menus/HUD as the glass layer:
  - Menu, world map and settings: use standard SwiftUI controls, plus `.buttonStyle(.glass)` / `.glassProminent` for primary actions (for example "Race").
  - Group clusters of floating buttons in one `GlassEffectContainer`.
  - In-race HUD (pause, lap counter): keep glass to at most 1–2 small elements, or use solid/opaque chips. Text must stay legible over fast-moving track colours, and glass over a 120 fps `SpriteView` costs GPU time. Profile with Instruments. This is a judgment call: **[unverified]** perf data.
- Don't put custom backgrounds on `NavigationStack` toolbars or sheets. Let the system do it.
- Test with **Reduce Transparency, Increase Contrast and Reduce Motion** on. System glass adapts to these automatically; custom glass may need checks. **[unverified]**
- App Review does not require Liquid Glass inside custom game UI. I found no rule that it does, but also no explicit statement that it doesn't: **[unverified]**.

## 3. App icon (iOS 26+)

**Findings**
- **Icon Composer `.icon` file** (Xcode 26+):
  - Drag it into the project, check target membership, and set **Target ▸ General ▸ App Icons ▸ App Icon** to its name without the extension ([DTS answer, forum 813010](https://developer.apple.com/forums/thread/813010), [Use Your Loaf](https://useyourloaf.com/blog/adding-icon-composer-icons-to-xcode/)).
  - Xcode generates the default, dark, clear and tinted variants from it, so you don't need separate variants in the asset catalog.
  - Don't add manual icon keys to Info.plist.
  - Export rules: use the full canvas and never pre-apply a rounded-rectangle mask ([WWDC25 361 notes](https://wwdcnotes.com/documentation/wwdc25-361-create-icons-with-icon-composer/)).
- **Plain 1024 PNG is still accepted:** App Store Connect validation asks for a **1024×1024 PNG in the "Any Appearance" slot** of the asset catalog ([forum 794028](https://developer.apple.com/forums/thread/794028)). A flat PNG is enough to submit, and **dark/tinted variants are optional** ([anything.com guide](https://www.anything.com/blog/ios-app-icon-guidelines)). Both sources are a forum post and a third-party guide: **[unverified against Apple's "Configuring your app icon" page]**.
- **App Store icon rules:** 1024×1024, PNG, sRGB (or Display P3), **no transparency / no alpha channel**, square, no rounded corners. Same guide; this is long-standing Apple practice.
- **Known pitfalls:** some developers hit "Validation Failed" with Icon Composer icons ([forum 799917](https://developer.apple.com/forums/thread/799917)). Dark variants from a `.icon` file sometimes didn't appear in Xcode betas ([forum 787447](https://developer.apple.com/forums/thread/787447)).

**What to do**
- Make the icon in **Icon Composer** (2–3 layers: background, track/echo shape, car). This gives proper Liquid Glass, dark and tinted looks on iOS 26/27.
- **Do an early TestFlight upload (week 1) only to check icon validation.** If App Store Connect complains, also add an `AppIcon` asset with a flat 1024×1024 PNG (no alpha) in "Any Appearance".
- Check the icon still reads in **tinted mode** (monochrome) and **dark mode**, and at small sizes in Settings/Spotlight.
- Flatten the PNG and strip alpha before upload, for example with `sips -s format png --deleteProperty hasAlpha` or by exporting without transparency. Check with `sips -g hasAlpha icon.png`.

## 4. First launch, onboarding, controls (HIG)

**Findings**
- **Launch screen (HIG "Launching"):** "A launch screen isn't an onboarding experience or a splash screen… its sole function is to enhance the perception of your experience as quick to launch". "Avoid creating a screen that looks like a splash screen… don't include logos or other branding elements unless they're a fixed part of your app's first screen." Ask for permission only after people show interest in the feature that needs it ([HIG Launching](https://developer-rno.apple.com/design/human-interface-guidelines/patterns/launching)).
- **Onboarding (HIG "Onboarding"):** "Ideally, people can understand your app or game simply by experiencing it". If you need onboarding, make it "fast, fun, and optional". It happens after launch, not during it. Teaching too much overwhelms people. Make the tutorial optional and re-findable in settings/help. If you have a splash screen, put it at the start of onboarding and keep it short ([HIG Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding.md)).
- **Touch controls (HIG "Game controls"):**
  - Frequently used controls must be at least **44×44 pt**; less important ones (menus) at least **28×28 pt**.
  - Put frequent buttons within thumb reach and away from the areas used for movement/camera input.
  - Give virtual controls a **visible pressed state**, ideally with sound + haptics.
  - Support physical game controllers as well as touch, and match on-screen glyphs to the connected controller.
  - Players may also touch game elements directly.
  - Source: [HIG Game controls](https://developer.apple.com/design/human-interface-guidelines/game-controls.md).
- **Touch Controller framework:** onscreen buttons, d-pads, thumbsticks, throttles and touchpads for **Metal-based** games. It appears as a `GCController`, so the same input code handles touch and physical pads ([TouchController docs](https://developer.apple.com/documentation/touchcontroller.md), [WWDC26 "Make your game great with touch", session 358](https://developer.apple.com/videos/play/wwdc2026/358/)). Whether it works with a SpriteKit `SKView`: **[unverified]**.
- **Game Center access point (HIG):** players must be signed in to Game Center to use it. Put it on the **main menu**. **Don't show it on splash screens, cinematics or tutorials before the menu** ([HIG access point](https://developer-mdn.apple.com/design/human-interface-guidelines/technologies/game-center/access-point)). GameKit's advice to set `authenticateHandler` as early as possible after launch (which shows Apple's welcome banner) is from prior knowledge: **[unverified this session]**.
- I could not retrieve HIG "Designing for games" in this session. Its game-specific advice is from prior knowledge: **[unverified]**. Examples: let people play as soon as possible, defer setup, design for every screen size and safe area, support controllers, keep text legible.

**What to do — Echo Lap's first screens**
1. **Launch screen:** use `UILaunchScreen` in Info.plist with only a **background colour equal to the first frame of the live track/menu**. No logo, no text, no spinner.
2. **First run, straight into play (≤ 5 s after the icon tap):**
   - Open on a short "Lap 0" tutorial track rendered live behind a minimal title overlay. A single "Hold to steer" hint shows; the first touch starts the car.
   - **Teach the echo mechanic by playing.** Lap 2 spawns your first echo, with one inline prompt ("Draft behind your echo for boost").
   - No name entry, account, age gate, permission prompt or Game Center sheet before the first race.
3. **First results screen:** show the time and a ghost/echo replay. Then "Continue" goes to the **world map = main menu**, which is where the **Game Center access point** appears (top corner, clear of the safe area).
4. **Game Center sign-in:** call `GKLocalPlayer.local.authenticateHandler` early but **non-blocking**, for example after the first frame renders. If the player isn't signed in or cancels, the game works exactly the same. Never show a "you must sign in" screen.
5. **Later, on the menu:**
   - Settings: replay tutorial, sound, haptics, left/right-hand mode, reduce motion, and an iCloud sync on/off toggle.
   - iCloud key-value sync needs no permission prompt.
6. **No permission prompts at all in v1.** No notifications (nothing to notify about offline) and no ATT. If a daily-track reminder is ever added, ask only after the player opts in from the daily-track screen.
7. **Controls:**
   - Make the one-thumb steering zone large: the bottom ~40% of the screen, whole width.
   - Make pause and other HUD buttons **≥ 44×44 pt**, inside the safe area and away from the steering zone, with a visible pressed state, a haptic and a click sound.
   - Use `.defersSystemGestures(on: .bottom)` / `persistentSystemOverlays(.hidden)` during races to avoid accidental home-indicator swipes (prior knowledge: **[unverified]**).
8. **Game controllers (nice to have):** read `GCController` (the left stick or d-pad steers, A = boost/swap). Apple recommends it, but App Review doesn't require it for a non-Arcade game **[unverified]**. If supported, set the Info.plist controller keys (`GCSupportsControllerUserInteraction`, and `GCSupportsGameMode` for iOS Game Mode) **[unverified]**.
9. **120 Hz:** set `CADisableMinimumFrameDurationOnPhone = YES` and `preferredFramesPerSecond = 120` on the SKView for ProMotion iPhones **[unverified]**.
10. **Resizable layout (iPhone Duo and iPad windows):**
    - Never size from `UIScreen.main.bounds` or branch on idiom/orientation. Use the scene/view size ([Adapty Duo guide](https://adapty.io/blog/markdown/adapt-your-ios-app-to-iphone-duo.md)).
    - Apple's position: you "cannot" opt out of adaptivity, and every app should adapt to any scene size ([forum 847836](https://developer.apple.com/forums/thread/847836)).
    - On the Duo inner display, a portrait-only lock no longer stops rotation ([forum 847755](https://developer.apple.com/forums/thread/847755)).
    - In SpriteKit, use `scaleMode = .resizeFill` and compute the camera zoom from the shorter side. This keeps the track readable in portrait, near-square (Duo inner display), 50/50 Duo split view and iPad windows.
    - On iPad, declare **all four orientations** and don't rely on `UIRequiresFullScreen`. Its future is uncertain ([forum 820475](https://developer.apple.com/forums/thread/820475), [Blake Crosley on iOS 27 resizability](https://blakecrosley.com/blog/ipad-continuous-resizability-ios-27)).

## 5. Age rating

**Findings**
- **Tiers:** 4+, 9+, **13+, 16+, 18+**. The 12+/17+ tiers were replaced in 2025. Every app had to answer the **new questionnaire by 31 Jan 2026**; missing it blocks updates ([9to5mac](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/), [igeeksblog](https://www.igeeksblog.com/apple-app-store-age-ratings/)). A new app simply answers the new questionnaire. It now covers in-app controls (parental controls/age assurance), capabilities (chat, UGC, ads, web access), medical/wellness topics and violence. Ratings can differ by region.
- **Mapping:** "Infrequent cartoon or fantasy violence" → **9+**; frequent → **13+**; 4+ = no objectionable material ([App Store Connect Help: Age ratings](https://developer.apple.com/help/app-store-connect/reference/age-ratings), [capgo guide](https://capgo.app/blog/app-store-age-ratings-guide/)). No racing-specific example was found.
- **Kids Category caution:** a "For Kids" app had updates rejected because **Game Center on iPadOS 26 offers a route to the App Store** ([summary of GameKit forum posts](https://developer.apple.com/forums/topics/graphics-and-games-topic/graphics-and-games-topic-gamekit)). **[unverified detail]**
- **Declared Age Range API / state laws:**
  - Texas SB 2420: the Fifth Circuit stayed the injunction on 1 Jun 2026, and Apple now applies the Texas rules to new Texas Apple Accounts ([AppleInsider](https://appleinsider.com/articles/26/06/03/age-verification-now-mandatory-for-app-store-users-in-texas), [PPC Land](https://ppc.land/apple-activates-texas-sb-2420-age-rules-for-app-store-after-injunction-lifted/), [MobileIDWorld](https://www.mobileidworld.com/apple-applies-texas-age-assurance-rules-to-new-apple-accounts/)).
  - Apple says developers "will need to adopt new capabilities and modify behavior within their apps to meet their obligations under the law". The tools are the **Declared Age Range** API (entitlement `com.apple.developer.declared-age-range`) and a **Significant Change API** for re-consent after material changes ([9to5mac Oct 2025](https://9to5mac.com/2025/10/08/apple-announces-new-requirements-for-apps-available-in-texas/), [FKKS](https://technologylaw.fkks.com/post/102lxsp/countdown-to-jan-1-2026-mobile-developers-must-adopt-apple-google-apis-to-com)).
  - Utah and Louisiana laws were reportedly delayed to May/Jul 2027 ([Amazon developer docs](https://www.developer.amazon.com/docs/app-submission/user-age-verification.html)). **[unverified, single source]**

**What to do**
- Design crashes as **bumps, spins and sparks**: no explosions, wreck damage, drivers or injury. Then answer **Cartoon/Fantasy Violence = None → 4+**. If cars visibly wreck or explode, answer **Infrequent → 9+**. Don't under-rate, because App Review can correct ratings and an inaccurate rating is a metadata problem.
- Answer **No** to: chat/messaging, UGC, advertising, unrestricted web access, gambling/simulated gambling, loot boxes, medical topics, parental controls/age assurance.
- **Don't** choose the Kids Category. List the game under Games ▸ Racing, with Games ▸ Casual or Arcade as secondary.
- **Declared Age Range: no App Review obligation found for v1.** Echo Lap has no accounts, no age-dependent features, no data collection and no purchases, and Apple handles parental consent at download. **[unverified — this is a legal question, not an App Review rule]**. Revisit before v2 adds IAP: adding monetisation may count as a "significant change" under the Texas law, which would need the Significant Change API flow.

## 6. Game Center

**Findings**
- New or changed **leaderboards, leaderboard sets, achievements, challenges and activities must be reviewed**. **First-time components must go in the same submission as the app version**; later ones can be submitted on their own ([Submit Game Center components](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-game-center-components)).
- **Challenges** (iOS 26+) are **built on a leaderboard**. Each needs:
  - a 3840×2160 RGB image with no transparency, at least 72 ppi
  - at least one localisation
  - Limit: 20 per app.

  **Activities** (deep links into a mode/track; can link to leaderboards/achievements) are also limited to 20 per app, and also reviewed ([Challenges](https://developer.apple.com/help/app-store-connect/reference/game-center/challenges), [Manage activities](https://www.developer.apple.com/help/app-store-connect/configure-game-center/manage-activities)).
- The **Apple Games app** (iOS 26) lists games automatically. It shows achievements, challenges and events. The **Game Overlay** lets players see friends and events in-game ([iThinkDiff](https://www.ithinkdiff.com/app-store-updates-ios-26-games-analytics/), [AppleInsider](https://appleinsider.com/articles/25/06/10/apple-gives-ios-gaming-a-real-home-just-not-a-new-direction)). I found no source saying achievements are *required*.
- **Pitfalls:**
  - The Game Center capability was enabled only for the **Debug** configuration, so Release builds didn't report ([forum 668584](https://developer.apple.com/forums/thread/668584)).
  - `GKErrorDomain Code=15 "not recognized by Game Center"` appears before the app/build is set up in App Store Connect ([forum 698731](https://developer.apple.com/forums/thread/698731)).
  - Bugs on iOS 26: the access point doesn't show, `authenticateHandler` isn't called, `GKGameCenterViewController` freezes (GameKit forum summary above).
- **Not found:** whether enabling the capability with zero components is rejected, and what `submitScore` does with an unknown leaderboard ID. My understanding is that it **returns an error rather than crashing**: **[unverified]**.

**What to do**
- Set up **all v1 leaderboards and achievements in App Store Connect before the first TestFlight build**. Attach them to the 1.0 version and submit them **with** the app. An empty Game Center (an access point opening to nothing) invites a 2.1 "incomplete" rejection **[unverified]**.
- Keep v1 small so the metadata stays manageable. 120 per-track leaderboards would each need a localisation:
  - **Leaderboards:** one **recurring "Daily Track"** leaderboard (lower time is better, elapsed-time format), plus **one per world** (sum of best times) = ~9.
  - **Achievements:** ~15–25, each with a name, description and image.
  - Leave challenges/activities out of v1. If you add one, base it on the Daily Track leaderboard and budget for the 3840×2160 image.
- **Code defensively:**
  - Every GameKit call checks `GKLocalPlayer.local.isAuthenticated` and logs and ignores errors. Never crash or block on GameKit.
  - Keep leaderboard IDs in one constants file that matches App Store Connect exactly.
  - Hide the access point during races (`GKAccessPoint.shared.isActive = false`).
- Enable the Game Center capability for **all** build configurations, and confirm `com.apple.developer.game-center` is in the archived entitlements.
- Test with a **sandbox Game Center account** on a real device running iOS 26 and 27, both signed in and signed out.
- Privacy: don't store or send `gamePlayerID`/`teamPlayerID` anywhere off the device. This keeps "Data Not Collected" consistent with Apple's definition (data sent off the device that you can access). **[unverified that Game Center needs no label entry]**

## 7. Common rejection reasons and 2026 guideline changes

**Findings**
- **Feb 6, 2026:** a guidelines revision ([Mac Observer](https://www.macobserver.com/news/apple-app-review-guidelines-2026-changes-explained/)). Details not retrieved.
- **8 Jun 2026 (WWDC26):**
  - Guidelines and DPLA rewritten.
  - **4.3(b)** now says don't submit apps "indistinguishable from what's already widely available", and names "opportunistic variants" of existing categories or popular apps.
  - Apple can now **remove live apps** in saturated categories that aren't updated, improved or attracting users.
  - Repeated low-effort submissions can cost you **Developer Program membership**.
  - 1.2 (UGC) was sharpened, and a new 4.5.3 bans Live Activity spam.
  - Sources: [MacRumors](https://www.macrumors.com/2026/06/09/app-store-guidelines-low-quality-apps/), [9to5mac](https://9to5mac.com/2026/06/09/apple-tightens-app-review-guidelines/), [Medianama](https://www.medianama.com/2026/06/223-apple-remove-app-store-apps-low-engagement/).
- **16 Oct 2026:**
  - 1.2 extended to AI content-creation apps and AI intimate imagery.
  - **New 2.5.19:** apps that **hide features during review and enable them after approval** face removal from the store and the Program.
  - Possibly a new "creative assets" section: **[unverified, single model-generated source]**.
  - Sources: [ithinkdiff](https://www.ithinkdiff.com/app-store-rules-ai-deepfakes-nudify-apps/), [letsdatascience](https://letsdatascience.com/news/apple-revises-app-review-guidelines-for-ai-deepfakes-and-hid-76fdff63), [Conduct Atlas](https://conductatlas.com/change/2026-10-17-apple-apple-app-store-review-guidelines-5687/).
- **Accessibility Nutrition Labels** are voluntary for now. Apple says they will become required for new apps and updates later, with "ample time" first and no date yet ([App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)).
- **The usual top reasons** (2.1 crashes/bugs/placeholder content, 4.2 minimum functionality, 2.3 metadata, 5.1.1 privacy, 2.4.1 iPad) still apply ([capgo 2026 guide](https://capgo.app/blog/how-to-pass-app-store-review-2026/)). NumFall covered these.

**What to do**
- **4.3 / racing:**
  - Make the echo mechanic the **first thing in the screenshots and preview video**, and in the first line of the description and the review notes ("every lap you finish becomes a solid car you can draft, park on switches, or swap with").
  - Avoid generic "car racing 3D" naming, keywords and visual tropes. Racing is a crowded category, and the 2026 4.3(b) wording targets lookalikes.
- **2.5.19 / 2.3.1:** **ship v1 with no remote config or feature flags** that unlock content after review. Everything a reviewer could see must be in the binary and reachable. This also keeps the game offline and "Data Not Collected". Content updates go through new app versions.
- **2.1:**
  - Test on the oldest supported device (iPhone 11-class), iPhone Duo (simulator, ideally a device), an iPad in a window, iOS 26.x and 27.x.
  - Zero crashes. No "coming soon" worlds: lock them behind play, not behind "TBD".
- **2.3:**
  - Screenshots show real gameplay on the right device.
  - No mention of other platforms or prices.
  - Game Center features shown in screenshots must exist at launch.
- **Plan for April 2027:** iPhone Duo screenshots become **mandatory for any submission** from then ([Apple developer post via 9to5mac](https://9to5mac.com/2026/10/05/apple-invites-developers-to-sub=), [ithinkdiff](https://www.ithinkdiff.com/apple-opens-app-store-submissions-for-iphone-duo-optimized-apps-and-games/), [PPC Land](https://ppc.land/apple-forces-developers-to-add-iphone-duo-screenshots-from-april-2027/)). Uploading them now is optional but cheap. Check the exact pixel sizes in App Store Connect "Screenshot specifications". The reported ~2007×2853 (inner) and ~1398×2034 (outer) are **[unverified]**.
- **Accessibility Nutrition Labels:** fill them in now, claiming only what works across the main tasks (likely Dark Interface, Sufficient Contrast, Reduced Motion, perhaps Differentiate Without Color). Don't claim VoiceOver unless menus *and* racing work with it.

## 8. Privacy manifest (`PrivacyInfo.xcprivacy`)

**Findings**
- **User defaults** (`NSPrivacyAccessedAPICategoryUserDefaults`) → **CA92.1** (data used only by the app itself) ([Unity's list](https://docs.unity3d.com/Manual/apple-privacy-manifest-policy.html)).
- **System boot time** (`NSPrivacyAccessedAPICategorySystemBootTime`):
  - Apple's listed APIs are **`ProcessInfo.systemUptime`** and **`mach_absolute_time()`**.
  - **35F9.1** = measure elapsed time between events in the app / timer calculations.
  - Other reasons are 8FFB.1 and 3D61.1.
  - Sources: [Firebase issue 12557](https://github.com/firebase/firebase-ios-sdk/issues/12557), [Delphi-PRAXiS](https://en.delphipraxis.net/topic/13126-apple-gettimertick64-mach_absolute_time-how-to-handle-the-nsprivacyaccessedapitype-privacy).
- **`CACurrentMediaTime()`:** it wraps `mach_absolute_time`, and one source claims this places it in the category ([ptkd.com](https://ptkd.com/journal/how-to-fix-missing-api-declaration-for-system-boot-time)). That source is single and promotional, and Apple's list doesn't name it: **[unverified]**. Apple's upload check (ITMS-91053) scans the symbols your binary references, so the reliable test is to inspect your own binary.
- **File timestamp** → **C617.1** (files inside the app container, app group or CloudKit container). Needed only if you read creation/modification dates (`attributesOfItem`, `.contentModificationDateKey`, `stat`…) ([Unity](https://docs.unity3d.com/Manual/apple-privacy-manifest-policy.html), [AppsFlyer](https://support.appsflyer.com/hc/en-us/articles/21677433322641)).
- **Disk space:** sources disagree between **E174.1** (check there's room to write) and **85F4.1** ([Unity](https://docs.unity3d.com/Manual/apple-privacy-manifest-policy.html) vs [CocoaPods guide](https://skills.cat/skills/thebushidocollective/han/cocoapods-privacy-manifests)). Avoid the API altogether.
- **`NSUbiquitousKeyValueStore`** is not on the required-reason list as far as I know: **[unverified]**. iCloud KVS data stays in the user's own iCloud account, which the developer can't access, so it isn't "collected" **[unverified]**.

**What to do**
- Ship one `PrivacyInfo.xcprivacy` in the app target with:
  - `NSPrivacyTracking = false`
  - `NSPrivacyTrackingDomains = []`
  - `NSPrivacyCollectedDataTypes = []`
  - `NSPrivacyAccessedAPITypes`:
    - `NSPrivacyAccessedAPICategoryUserDefaults` → `CA92.1` (settings and progress)
    - `NSPrivacyAccessedAPICategorySystemBootTime` → `35F9.1`, **if** any code calls `CACurrentMediaTime()`, `ProcessInfo.processInfo.systemUptime`, `mach_absolute_time` or `DispatchTime.now()`. Lap timing is exactly "elapsed time between in-app events", so the declaration is truthful. Declaring it costs nothing and avoids an ITMS-91053 email.
    - `NSPrivacyAccessedAPICategoryFileTimestamp` → `C617.1`, **only if** you read file dates. Better: store a `savedAt` field *inside* the save JSON and never read file attributes.
    - Disk space: **don't use it**, so don't declare it.
- Prefer SpriteKit's `update(_ currentTime:)` timestamp for gameplay and lap timing. The framework supplies it, so your code doesn't call boot-time APIs directly. Keep the 35F9.1 entry anyway if any SwiftUI or haptics code uses `CACurrentMediaTime`.
- **CI check after archive:** run `nm -u <App>.app/<App> | grep -E 'mach_absolute_time|CACurrentMediaTime|statfs|getattrlist|stat$'` and `strings <App> | grep -E 'systemUptime|volumeAvailableCapacity|creationDate|modificationDate'`. Fail the build if a symbol appears without a matching manifest entry. **[unverified]** This approximates Apple's scanner.
- Add no third-party SDKs (no analytics or crash SDKs). This keeps the label "Data Not Collected" and avoids SDK manifest/signature requirements.

---

## Submission checklist (Echo Lap 1.0)

**Build**
- [ ] Built with **Xcode 27.1** (iOS 27 SDK); CI `runs-on: xcode-27`, with the version asserted in the log
- [ ] Deployment target iOS/iPadOS 26.0; iPhone + iPad (universal); iPad declares all 4 orientations; no reliance on `UIRequiresFullScreen`
- [ ] No `UIDesignRequiresCompatibility`; standard SwiftUI controls (auto Liquid Glass); glass used sparingly; in-race HUD legible
- [ ] SpriteKit scene resizes (`.resizeFill` + camera zoom from the short side). Checked on iPhone portrait, **iPhone Duo inner/outer/split**, iPad full-screen and windowed
- [ ] `UILaunchScreen` = plain background colour matching the first frame (no logo/text)
- [ ] Icon: Icon Composer `.icon` set as App Icon (plus a flat 1024 PNG with no alpha in AppIcon "Any Appearance" if validation asks); checked in dark/tinted
- [ ] `PrivacyInfo.xcprivacy`: tracking false, no collected types, UserDefaults CA92.1, SystemBootTime 35F9.1 (if any timing API is used), FileTimestamp C617.1 only if needed; `nm`/`strings` check passes
- [ ] `ITSAppUsesNonExemptEncryption = NO`; no third-party SDKs; no network calls; **no remote feature flags** (2.5.19)
- [ ] Game Center capability in **all** configurations; GameKit failures are non-fatal; access point on the menu only, hidden in races and the tutorial
- [ ] Touch targets ≥ 44×44 pt (menus ≥ 28×28 pt); pressed state + haptic; system edge gestures deferred during races

**First-run experience**
- [ ] Racing within ~5 s of tapping the icon; tutorial teaches through play and can be replayed from Settings
- [ ] No sign-in, account, age gate, notification or ATT prompts; Game Center auth is silent and optional
- [ ] All worlds reachable through play (no "coming soon"); zero crashes on iOS 26.x/27.x, an iPhone 11-class device, an iPad and the iPhone Duo simulator

**App Store Connect**
- [ ] Leaderboards (Daily recurring + per-world) and achievements created, localised and attached to version 1.0. Challenges/activities: none in v1, or each with a 3840×2160 image
- [ ] Age rating questionnaire: violence None (bump-only crashes) → 4+, or Infrequent → 9+; everything else No; **not** Kids Category
- [ ] Privacy label "Data Not Collected"; privacy policy URL; DSA trader status
- [ ] Screenshots: 6.9" (1320×2868) and 13" iPad (2064×2752) showing **echo gameplay first**; optional iPhone Duo set now (mandatory from April 2027)
- [ ] Accessibility Nutrition Labels: only features that truly work
- [ ] Review notes: what the echo mechanic is, how to reach each feature, that Game Center is optional and the game is fully offline, plus a demo video link
- [ ] Early TestFlight upload done in week 1 to catch icon/manifest/entitlement validation errors

**Watch list (re-check before submitting)**
- Exact April 2027 dates for the iOS 27 SDK floor and iPhone Duo screenshots; Duo screenshot pixel sizes
- Whether the 16 Oct 2026 guidelines added a "creative assets" section
- Texas/Utah/Louisiana age-assurance obligations before v2 adds IAP
