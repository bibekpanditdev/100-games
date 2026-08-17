# 1000+ Offline Games — Flutter Android App

A production-ready, **fully offline** Android app bundling **2,300+ casual games** —
arcade, puzzle, cards, board, trivia and a dedicated **Puzzle & Mind Games**
module (logic / word / memory / math / spatial with Daily Brain Training) —
behind a modern, high-contrast, accessible Material 3 UI, with offline sound &
music, AdMob monetization, local leaderboards, achievements, coins, daily
streaks and a daily challenge.

Every game is playable in airplane mode — including procedural puzzle
generation and all audio. Ads and the optional Google Play Games sync are the
*only* network touchpoints, and both fail silently.

---

## 1. Quick start

The repository ships the complete Dart source, assets and tests. Platform folders
(`android/`) are generated on your machine so the template always matches your
Flutter version:

```bash
# 1. Install Flutter (stable) — https://docs.flutter.dev/get-started/install
flutter doctor

# 2. Inside this project folder, generate the platform scaffolding:
flutter create . --platforms android --project-name thousand_games --org com.thousandgames

# 3. Patch the generated AndroidManifest for AdMob + INTERNET (idempotent):
powershell -ExecutionPolicy Bypass -File tool/patch_android_manifest.ps1

# 4. Run:
flutter pub get
flutter run
```

To build a release AAB: `flutter build appbundle` (signing configured as usual in
`android/app/build.gradle`).

### Tests / analysis

```bash
flutter analyze
flutter test          # 60+ unit & widget tests
```

CI runs the same on every PR (`.github/workflows/ci.yml`) and on every push
to `main` (`.github/workflows/build-release.yml`, which also builds a
release APK artifact).

---

## 1a. Releases, signing & the installable APK

Pushing a **tag** like `v1.0.0` builds a **signed release APK + AAB** on
GitHub Actions and publishes them to a GitHub Release — no local build
needed.

### How signing works (and how to never lose it)

* The upload keystore lives **outside the repo** (git-ignored; the
  `.gitignore` blocks `*.jks`, `key.properties`, credentials files).
* CI pulls it from **GitHub Actions Secrets**:

  | Secret | Value |
  | --- | --- |
  | `KEYSTORE_BASE64` | base64 of the `upload-keystore.jks` file |
  | `KEYSTORE_PASSWORD` | keystore store password |
  | `KEY_ALIAS` | key alias (`thousandgames`) |
  | `KEY_PASSWORD` | key password |

* `tool/ci_prepare_android.sh` decodes the keystore, writes
  `android/key.properties` (git-ignored) and wires the release signing
  config into the generated `build.gradle`/`build.gradle.kts` each build —
  locally the same script falls back to debug signing so dev builds work
  with zero setup.

**⚠️ If you lose this keystore you can never sign an update to the same app
identity again.** Back it up somewhere safe outside GitHub (password
manager / encrypted drive). The current keystore + passwords are stored at
`..\thousand-games-signing\` next to this project folder.

### Regenerating a keystore (fresh start only)

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -alias thousandgames \
  -keyalg RSA -keysize 2048 -validity 10950 \
  -dname "CN=1000 Offline Games, OU=Mobile, O=Bibek Pandit, C=NP"
# macOS/Linux base64:  base64 -w0 upload-keystore.jks
# Windows PowerShell:  [Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks"))
```

Then update the four GitHub secrets (repo → Settings → Secrets and
variables → Actions).

### Release process (version management)

`pubspec.yaml`'s `version: X.Y.Z+N` is the single source of truth
(`X.Y.Z` = version name shown to users, `N` = monotonically increasing
version code):

1. Bump `version:` in `pubspec.yaml`.
2. Commit & push to `main` (CI runs analyze + tests; a release APK is
   attached as a workflow *artifact* for verification — no public release).
3. Tag and push: `git tag v1.0.0 && git push origin v1.0.0`.
4. GitHub Actions builds, signs and publishes the **GitHub Release** with
   `app-release-v{version}.apk` + `.aab` attached and auto-generated
   release notes.

### Installing the release APK on an Android device

1. Open the repo's **Releases** page and download the `.apk`.
2. If prompted, allow *"Install unknown apps"* for your browser/file
   manager (Settings → Apps → Special access → Install unknown apps).
3. Tap the downloaded file and confirm **Install**.

Android will show an *"unknown source"* warning because the build is
self-signed rather than Play-Store-distributed — that is expected and safe
for a personal build.

---

## 2. How "1000+ games" works

There are **27 game engines** (templates) — not thousands of screens:

| Category | Engines (template ids) |
| --- | --- |
| Arcade | `snake`, `breakout`, `whack_a_mole`, `tap_reflex`, `dodge_runner` |
| Puzzle | `match3`, `sliding_puzzle`, `block_fall`, `word_search` |
| Cards | `memory_match`, `higher_lower`, `blackjack` |
| Board | `tic_tac_toe`, `connect_four`, `dots_and_boxes` |
| Trivia | `trivia` (8 offline question banks × timed modes) |
| Mind | `sudoku`, `minesweeper`, `merge2048`, `math_sprint`, `maze`, `pipes`, `hangman`, `wordle_daily`, `simon`, `pattern_recall`, `odd_one_out` |

`lib/features/catalog/data/catalog_seeder.dart` deterministically expands
templates × **30 visual palettes** × **3 difficulty configs** (plus trivia
question-set/mode variants) into **2,388 game definitions** seeded into SQLite on
first launch. Thumbnails are painted procedurally (palette gradient + template
glyph + difficulty pips), so the whole catalog costs zero image assets and a tiny
APK.

Adding a game = adding a manifest entry (see **docs/ADDING_A_GAME.md**) — no code
changes, exactly as the spec requires. Adding a whole new *engine* is one folder +
one line in the category registrar.

### Puzzle & Mind Games — engine overview

The Mind category (logic / word / memory / math / spatial subcategories, filtered
by the `group` config key) is built on **five shared engine cores** under
`lib/features/games/mind/common/`, proving the add-on's shared-engine model:

| Shared core | Files | Games built on it |
| --- | --- | --- |
| Grid core | `grid_render.dart` (high-contrast cell rendering, colorblind-safe state marks) | `sudoku`, `minesweeper`, `merge2048` (+ math grid rendering) |
| Word core | `word_bank.json` loader + guess-evaluation logic | `hangman`, `wordle_daily` |
| Sequence core | `sequence_core.dart` (playback + input + strike state machine) | `simon`, `pattern_recall` |
| Match core | `match_core.dart` (attribute-item sets with exactly-one-different) | `odd_one_out` |
| Spatial core | per-game procedural generators (perfect-maze DFS, pipe spanning-tree) | `maze`, `pipes` |

Key add-on features:

* **Daily Brain Training** — deterministic daily routine of one game per
  subcategory; composite **Brain Score** (capped score + star bonus per game)
  stored per day in SQLite and charted on the Brain dashboard
  (`/brain`, linked from Home). Handles empty / partial / full history.
* **Save & resume** — long puzzles persist their board through the session
  controller (`saveState`/`restoredState`) into the Hive `gamestate` box;
  exit mid-Sudoku and resume after an app restart, fully offline.
* **Adaptive difficulty** — recent star results per template nudge a suggested
  difficulty (pure on-device heuristic, no ML/network).
* **Offline generators** — Sudoku (unique-solution verified), minesweeper
  (first-tap-safe), mazes (perfect-maze DFS), pipes (solvable-by-construction),
  2048 and math questions are all generated on-device at load time.
* New badges: Mind Master, Sudoku Solver, Wordle Ace, Brain streaks; per-
  subcategory leaderboards (Logic/Word/Memory/Math/Spatial boards in the
  Leaderboards screen).

### Audio system

`lib/core/services/audio_service.dart` is the single audio authority
(`AudioService.I.sfx(...)` / `.playBgm(...)`) — engines never own players.

* **Assets**: 35 synthesized SFX + 4 looping BGM tracks (menu / calm mind /
  upbeat arcade / neutral in-game), generated license-free by
  `tool/generate_audio.ps1` as small WAVs. Swap in compressed OGG/AAC masters
  later by dropping files with the same names into `assets/audio/` and updating
  the extensions in `audio_service.dart`.
* **Behavior**: SFX preloaded for low latency and safe to spam-tap (overlapping
  playback); BGM loops with ~250 ms crossfades between menu ↔ category-flavoured
  in-game loops; muting fades out instead of cutting.
* **Controls**: Settings has Sound/Music toggles **and** volume sliders
  (persisted in Hive, applied instantly everywhere); the in-game **pause menu
  has quick mute buttons** for music and SFX; Android silent mode is respected
  (`respectSilence`).
* New games inherit audio for free: call `AudioService.I.sfx(SfxKeys.hit)` (or
  any semantic key) at event points — keys are shared per engine family, so all
  variants of a template sound consistent.

---

## 3. Architecture

Feature-first layout with clean layering inside features:

```
lib/
  main.dart                 # startup: Hive -> SQLite -> seed -> ads (fire-and-forget)
  app.dart                  # MaterialApp, themes, theme-mode reactivity
  core/
    routing.dart            # route table + fade-through transitions (reduced-motion aware)
    storage/app_database.dart
    theme/                  # app_theme.dart (WCAG-tested), palettes.dart (30 skins)
    services/               # haptics/sound feedback, Play Games wrapper
    utils/                  # contrast math, stable hash, formatters
  shared/                   # design-system widgets: buttons, chips, dialogs,
                            # skeleton loaders, empty states, star rating,
                            # procedural thumbnails, confetti, splash
  features/
    catalog/                # domain (GameDefinition) + data (SQLite repo, seeder,
                            # custom-manifest merge) + presentation (home, browse, detail)
    game_player/            # in-game shell: HUD, pause, hint/continue payments,
                            # results screen, engine registry, engine contracts
    games/                  # the 16 engines, self-contained per template
    gamification/           # coins, streaks, scoring, achievements engine
    leaderboards/           # scores repository + screen
    settings/               # Hive-backed settings controller + screen
    ads/                    # AdMob wrapper (fail-silent) + banner slot + ad units
    analytics/              # offline event queue (attach any backend sink)
```

**Engine contract** (`features/game_player/game_contracts.dart`): an engine is a
plain Flutter widget + a `GameEngine` registration object. It receives a
`GameSessionController` — HUD writes, `finish()`, `requestHint()` /
`requestContinue()` — and touches nothing else (no Riverpod, no ads, no storage).
That's what keeps 16 engines independently buildable and unit-testable.

**State management:** Riverpod (providers in `catalog/presentation/catalog_providers.dart`).
**Storage:** Hive for settings/progress (fast KV), SQLite for catalog/scores/
achievements/analytics queue (spec §1).

---

## 4. Monetization (AdMob)

* **Banner** on Home + Browse (`shared BannerAdSlot` — collapses to zero height
  offline; layouts never shift).
* **Interstitial** between game sessions — frequency-capped: every 3rd exit,
  minimum 2 minutes apart (`ProgressController.noteGameExit`).
* **Rewarded video** pays for hints (150 coins) and extra lives (250 coins) when
  the coin balance is short.

All unit ids live in `lib/features/ads/ad_units.dart`. They default to Google's
**test ids**; put your real ids in the `_production*` constants before release —
the app switches automatically in release builds. The AdMob application id is
patched into `AndroidManifest.xml` by `tool/patch_android_manifest.ps1`
(Google's sample id — replace with yours).

Every ad call path is exception-guarded: offline devices see no ads and gameplay
is never blocked (spec §4). A future "Remove Ads" IAP only needs to gate the
`AdsService.instance.available` check in one place.

---

## 5. Gamification

* **Coins** — earned per session (`Scoring.coinsFor`), spent on hints/extra lives.
* **Local leaderboards** — per-game personal bests + per-category tops (SQLite).
  Global tab uses optional Google Play Games sign-in (Settings); never required.
* **Achievements** — 21 badges with progress tracking
  (`gamification/achievements/achievement_definitions.dart`); data-driven rules
  over a session snapshot, synced opportunistically to Play Games.
* **Daily streak** + **daily challenge** (deterministic per-day pick).

---

## 6. Accessibility & design

* Material 3, light + dark, hand-picked color tokens **verified by unit test**
  against WCAG AA (`test/unit/theme_contrast_test.dart`).
* Colorblind-safe piece colors (Okabe–Ito) **plus shape redundancy** in every engine.
* Inter font bundled offline; full text scaling; 48dp minimum touch targets;
  Semantics labels on interactive elements; reduced-motion setting shortens
  transitions and disables confetti.
* Skeleton loaders, empty states, haptics, win confetti — all offline.

---

## 7. Analytics & crash reporting

`features/analytics/analytics_service.dart` is an **offline event queue** (SQLite)
with a pluggable sink. To attach Firebase Analytics + Crashlytics:

1. `flutter pub add firebase_core firebase_analytics firebase_crashlytics` and run
   `flutterfire configure`.
2. In `main()`, after `runApp`: `analyticsProvider` → `attachSink((name, params) =>
   FirebaseAnalytics.instance.logEvent(name: name, parameters: params))`.
3. Wrap `main()` in `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError`.

No call sites change — events already flow through the queue and flush when a
sink is attached. (Firebase is intentionally NOT pre-wired so the project builds
without a `firebase_options.dart` / console project.)

---

## 8. Adding games & engines

* **Add a game variant** — one entry in `assets/manifests/custom_games.json`
  (merged at every launch). Full guide: **docs/ADDING_A_GAME.md**.
* **Add an engine** — implement `GameEngine` in `features/games/<category>/<template>/`,
  register it in the category registrar, add config knobs to the seeder matrix or
  ship variants via the custom manifest.

## 9. Deliberate deviations from the original brief

* **Flame is not used.** Arcade engines use a shared ticker/CustomPainter pattern
  with zero extra dependencies — same 60fps target, smaller dep surface. The
  engine contract is rendering-agnostic, so Flame can be adopted per-engine later.
* **Firebase is not pre-wired** (see §7) to keep the repo buildable without a
  Firebase project; the analytics abstraction is Firebase-shaped.
* **Thumbnails are procedural** (painter-based) instead of 1,400 WebP files, per
  the spec's own APK-size guidance (§7); manifests may still point at asset files.
* Background **music toggle** ships as a setting with a stub player (no audio
  assets bundled); sound effects use system sounds + haptics.

## 10. Test suite

* **Unit** — seeder (1000+ guarantee, determinism, config contracts), WCAG
  contrast, scoring economy, streaks, coins, interstitial cap, session contract,
  catalog/scores/achievements repositories (in-memory SQLite via `sqflite_common_ffi`),
  plus per-engine logic tests (match-3 cascades, sliding-puzzle solvability,
  minimax unbeatability, blackjack hand math, trivia bank validation, …).
* **Widget** — home rendering/navigation, browse filtering, settings persistence,
  results screen flows.

Run everything: `flutter test`.
