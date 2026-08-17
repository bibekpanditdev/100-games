# Adding a new game (no code changes)

The catalog is manifest-driven. A game = one entry in
`assets/manifests/custom_games.json`. On every launch the catalog repository
merges that file into the SQLite `games` table, and the game immediately appears
in Home/Browse with full offline play, leaderboards, coins, achievements and ads
handling.

## 1. Manifest entry

```json
{
  "id": "custom_snake_turbo",          // required, unique
  "title": "Turbo Snake",              // required
  "category": "arcade",                // arcade | puzzle | cards | board | trivia
  "template": "snake",                 // required — must match an engine template id
  "difficulty": "hard",                // easy | medium | hard
  "theme": "neon",                     // any palette id (see lib/core/theme/palettes.dart)
  "thumbnail": null,                   // optional asset path, e.g. "assets/thumbs/x.webp"
  "unlocked": true,
  "config": {                          // template-specific knobs (see tables below)
    "grid": 16,
    "speed": 9.0,
    "wrap": false
  }
}
```

Entries with an unknown `template` (or missing `id`/`template`) are skipped
safely — a bad manifest can never break the catalog.

### Adding a themed pack or difficulty tier (no code)

Because every config knob is manifest-driven, a themed pack is just N entries
sharing a `theme` with tuned configs — e.g. a "Sudoku — Halloween" pack:
five entries with `"theme": "volcano"`, `"template": "sudoku"` and clue counts
50/45/40/35/30. They appear instantly (merged at every launch), get procedural
thumbnails from the palette, and join leaderboards/achievements automatically.

## 2. Config keys per template

Missing keys always fall back to engine defaults, so a minimal `"config": {}`
is valid too.

| Template | Keys |
| --- | --- |
| `snake` | `grid` (12–20), `speed` (4–9 moves/s), `wrap` (bool) |
| `breakout` | `rows` (4–8), `speed` (180–300), `lives` (int) |
| `whack_a_mole` | `holes` (9/12), `spawnMs`, `durationSec` |
| `tap_reflex` | `rounds`, `windowMs` |
| `dodge_runner` | `lanes` (3/4), `speed`, `targetSec` |
| `match3` | `cols`, `rows`, `moves`, `target` (3-star at 1.25×target) |
| `sliding_puzzle` | `size` (3/4/5) |
| `block_fall` | `cols`, `speed`, `targetLines` |
| `word_search` | `size`, `wordCount`, `timeSec` |
| `memory_match` | `pairs`, `peekSec` |
| `higher_lower` | `rounds` |
| `blackjack` | `rounds` |
| `tic_tac_toe` | `aiLevel` (1–3) |
| `connect_four` | `aiLevel` (1–3) |
| `dots_and_boxes` | `size`, `aiLevel` |
| `trivia` | `qset` (general/science/movies/sports/history/geography/technology/mixed), `count`, `timePerQ` (0 = untimed) |
| `sudoku` | `clues` (30–50) — also set `"group": "logic"` |
| `minesweeper` | `size` (8–12), `mines` — `"group": "logic"` |
| `merge2048` | `target` (1024/2048/4096) — `"group": "math"` |
| `math_sprint` | `durationSec`, `maxOperand` — `"group": "math"` |
| `maze` | `size` (odd number), `timeSec` — `"group": "spatial"` |
| `pipes` | `size` (5–7) — `"group": "spatial"` |
| `hangman` | `minLen`, `maxLen`, `lives` — `"group": "word"` |
| `wordle_daily` | `maxGuesses` (5–7) — `"group": "word"` |
| `simon` | `startLength`, `stepMs` — `"group": "memory"` |
| `pattern_recall` | `grid`, `cells`, `rounds` — `"group": "memory"` |
| `odd_one_out` | `items`, `rounds` — `"group": "memory"` |

Mind-game entries should carry a `"group"` of `logic` / `word` / `memory` /
`math` / `spatial` — it drives the subcategory filter chips, the per-subcategory
leaderboards and the Daily Brain Training routine. A missing group is harmless
(the game just isn't routine-eligible).

## 3. Theme ids

`ocean, sunset, forest, neon, candy, desert, arctic, space, cherry, mint, royal,
amber, lagoon, volcano, glacier, meadow, midnight, coral, violet, storm, honey,
jade, tulip, steel, ember, tundra, rally, orchid, citrus, harbor` — defined in
`lib/core/theme/palettes.dart` (add palettes there; the theme name composes the
title of seeded variants like "Neon Snake").

## 4. Thumbnails (optional)

By default the UI paints a procedural thumbnail from palette + template glyph +
difficulty pips (zero APK cost). To ship a real image instead, set `"thumbnail"`
to an asset path, declare the folder under `flutter: assets:` in `pubspec.yaml`,
and drop the file there (WebP recommended). If the asset fails to load the
procedural painter takes over automatically.

## 5. Adding a whole new ENGINE (code, but tiny and isolated)

1. Create `lib/features/games/<category>/<template>/`:
   * `<template>_logic.dart` — pure game logic, constructor takes `Random` for
     deterministic tests.
   * `<template>_engine.dart` — `class MyEngine implements GameEngine` with
     `templateId`, `instructions`, `supportsHint` / `supportsContinue`, and
     `build(session)` returning a widget driven by the `GameSessionController`
     (see `game_contracts.dart` for the full contract: HUD writes, `finish()`,
     pause handling, hint/continue flows).
2. Append the engine to the category registrar, e.g.
   `lib/features/games/arcade/arcade_engines.dart`.
3. Add config knobs (ranges above) and variants either in
   `catalog_seeder.dart` or purely via the custom manifest.
4. Add a logic unit test under `test/unit/games/`.

That's it — registry, catalog, leaderboards, achievements, coins, ads and
results flow attach automatically.
