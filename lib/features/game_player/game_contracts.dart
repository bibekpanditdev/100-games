/// The frozen contract between the game-player shell (HUD, pause menu,
/// results, ads, coins) and every game engine template.
///
/// Engines are plain Flutter widgets plus an optional pure-logic class. They
/// must NOT depend on Riverpod, ads, storage or any other app service —
/// everything they need arrives through the [GameSessionController].
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../catalog/domain/game_definition.dart';
import '../../core/theme/palettes.dart';

/// Outcome of a finished (or abandoned) play session.
class GameOutcome {
  const GameOutcome({
    required this.score,
    required this.won,
    this.stats = const {},
  });

  final int score;

  /// Whether the player achieved the game's goal (vs. losing / running out).
  final bool won;

  /// Free-form engine stats, e.g. `{'cascades': 3, 'timeLeftSec': 12}`.
  /// Used by the achievements engine.
  final Map<String, int> stats;
}

/// Data rendered by the in-game HUD. Engines push updates via
/// [GameSessionController.updateHud].
@immutable
class GameHudData {
  const GameHudData({
    this.score = 0,
    this.status,
    this.detail,
    this.progress,
  });

  final int score;

  /// Prominent status line, e.g. `Time 12` or `Moves 8`.
  final String? status;

  /// Secondary line, e.g. `Target 2500` or `Level 2`.
  final String? detail;

  /// Optional 0..1 progress bar.
  final double? progress;

  GameHudData copyWith({
    int? score,
    String? status,
    String? detail,
    double? progress,
  }) =>
      GameHudData(
        score: score ?? this.score,
        status: status ?? this.status,
        detail: detail ?? this.detail,
        progress: progress ?? this.progress,
      );
}

/// Callback the shell injects to fulfil hint / continue requests.
/// Returns true when the player paid (coins or rewarded ad) and the engine
/// should proceed. Always returns false when offline / no ad available —
/// engines must treat that as "request declined", never as an error.
typedef SupportRequest = Future<bool> Function();

/// Mutable session state shared between the shell and one live engine.
///
/// Lifecycle rules:
///  * The shell creates the controller, attaches support handlers, then
///    builds the engine widget with it.
///  * Engines write HUD state and call [finish] exactly once per run.
///  * When the player is about to lose and the engine supports continues,
///    it MUST call [requestContinue] *before* calling [finish]. If the
///    request resolves `true`, [onExtraLifeGranted] has been invoked and the
///    engine should revive the player.
///  * Engines with their own loops/timers must stop ticking while
///    [isPaused] is true (the pause overlay owns resuming).
class GameSessionController extends ChangeNotifier {
  GameSessionController({
    required this.definition,
    GamePalette? palette,
  }) : palette = palette ?? paletteById(definition.themeId);

  final GameDefinition definition;
  final GamePalette palette;

  GameConfig get config => GameConfig(definition.config);

  GameHudData _hud = const GameHudData();
  bool _paused = false;
  bool _finished = false;

  /// Outcome is set when [_finished] flips true.
  GameOutcome? outcome;

  GameHudData get hud => _hud;
  bool get isPaused => _paused;
  bool get isFinished => _finished;
  int get score => _hud.score;

  /// Engine registers these to be notified when the shell grants a hint or
  /// an extra life (after coins were spent or a rewarded ad completed).
  void Function()? onHintGranted;
  void Function()? onExtraLifeGranted;

  SupportRequest? _hintRequest;
  SupportRequest? _continueRequest;

  /// Called by the shell right after construction.
  void attachSupportHandlers({
    SupportRequest? hint,
    SupportRequest? continueRequest,
  }) {
    _hintRequest = hint;
    _continueRequest = continueRequest;
  }

  /// Ask the shell for a hint (costs coins or a rewarded ad).
  Future<bool> requestHint() async => (await _hintRequest?.call()) ?? false;

  /// Ask the shell to revive the player. Call BEFORE [finish].
  Future<bool> requestContinue() async => (await _continueRequest?.call()) ?? false;

  /// HUD writers ----------------------------------------------------------

  void updateHud({
    int? score,
    String? status,
    String? detail,
    double? progress,
  }) {
    _hud = _hud.copyWith(
      score: score,
      status: status,
      detail: detail,
      progress: progress,
    );
    // Use a microtask to avoid "setState() or markNeedsBuild() called during build"
    // when engines call this in initState or build.
    Future.microtask(() {
      if (!_finished) notifyListeners();
    });
  }

  void addScore(int points) => updateHud(score: _hud.score + points);

  /// Lifecycle ------------------------------------------------------------

  void setPaused(bool value) {
    if (_paused == value) return;
    _paused = value;
    notifyListeners();
  }

  /// Engine-side grants (invoked by the shell after payment succeeded).
  void grantHint() => onHintGranted?.call();
  void grantExtraLife() => onExtraLifeGranted?.call();

  /// Ends the session. Ignored after the first call.
  void finish({required bool won, int? score, Map<String, int> stats = const {}}) {
    if (_finished) return;
    _finished = true;
    outcome = GameOutcome(
      score: score ?? _hud.score,
      won: won,
      stats: stats,
    );
    notifyListeners();
  }

  // --- Save / resume -----------------------------------------------------
  // Long puzzles (Sudoku, Nonogram, Crossword, ...) persist their board to
  // the Hive `gamestate` box through the shell so the player can exit and
  // resume later — even across app restarts, fully offline.

  /// State a previous run of this game persisted, or null on a fresh start.
  /// Engines read this in initState and rebuild their board from it.
  Map<String, dynamic>? restoredState;

  void Function(Map<String, dynamic> state)? _stateSaver;
  void Function()? _stateClearer;

  /// Called by the shell right after construction.
  void attachStatePersister({
    required Map<String, dynamic>? restored,
    required void Function(Map<String, dynamic> state) save,
    required void Function() clear,
  }) {
    restoredState = restored;
    _stateSaver = save;
    _stateClearer = clear;
  }

  /// Persist engine state (call on every meaningful move and on pause).
  /// Cheap: Hive box write keyed by game id.
  void saveState(Map<String, dynamic> state) => _stateSaver?.call(state);

  /// Wipe saved state (the shell calls this when a session finishes).
  void clearSavedState() => _stateClearer?.call();
}

/// A game template. Implementations live under `lib/features/games/**` and
/// are aggregated per category, then registered in the engine registry.
abstract class GameEngine {
  /// Unique template id referenced by manifest `template` fields
  /// (e.g. `snake`, `match3`, `trivia`).
  String get templateId;

  /// Short player-facing instructions shown in the pause menu and on the
  /// detail screen. Keep to 1–3 sentences.
  String get instructions;

  /// Whether the engine reacts to `session.requestHint()`.
  bool get supportsHint => false;

  /// Whether the engine reacts to `session.requestContinue()`.
  bool get supportsContinue => false;

  /// Builds the gameplay widget for one session.
  Widget build(GameSessionController session);
}
