/// In-game shell: hosts one engine instance plus the shared HUD, pause
/// menu, exit confirmation, hint/continue payment flow, score recording,
/// achievements and the results hand-off. Engines never see any of this —
/// they only talk to their [GameSessionController].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/routing.dart';
import '../../core/services/audio_service.dart';
import '../../core/services/feedback.dart';
import '../ads/ads_service.dart';
import '../catalog/domain/game_definition.dart';
import '../catalog/presentation/catalog_providers.dart';
import '../gamification/achievements/achievements_repository.dart';
import '../gamification/progress_controller.dart';
import '../gamification/scoring.dart';
import '../leaderboards/scores_repository.dart';
import '../mind/brain_training/brain_providers.dart';
import '../../shared/widgets/app_dialogs.dart';
import 'engine_registry.dart';
import 'game_contracts.dart';
import 'results_payload.dart';

class GamePlayerScreen extends ConsumerStatefulWidget {
  const GamePlayerScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends ConsumerState<GamePlayerScreen> {
  GameDefinition? _definition;
  GameEngine? _engine;
  GameSessionController? _session;
  int _runKey = 0;
  bool _finishing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final def = await ref.read(catalogRepoProvider).byId(widget.gameId);
    if (!mounted) return;
    if (def == null) {
      setState(() => _loading = false);
      return;
    }
    _startSession(def);
    setState(() => _loading = false);
    ref.read(analyticsProvider).log('game_start', {'template': def.template, 'game': def.id});
  }

  void _startSession(GameDefinition def) {
    final engine = engineFor(def.template);
    final session = GameSessionController(definition: def);

    // Save/resume for long puzzles (Sudoku & friends): restore a previous
    // run's board, persist on every saveState() call, wipe on finish.
    final stateBox = ref.read(gameStateBoxProvider);
    final saved = stateBox.get(def.id);
    session.attachStatePersister(
      restored: saved is Map ? Map<String, dynamic>.from(saved) : null,
      save: (state) => stateBox.put(def.id, state),
      clear: () => stateBox.delete(def.id),
    );

    session.attachSupportHandlers(
      hint: () => _payAndGrant(
        cost: ProgressController.hintCost,
        onGranted: session.grantHint,
        unavailableMessage: 'No hints available right now.',
      ),
      continueRequest: () => _payAndGrant(
        cost: ProgressController.extraLifeCost,
        onGranted: session.grantExtraLife,
        unavailableMessage: 'No continues available right now.',
      ),
    );
    session.addListener(_onSessionChanged);
    AudioService.I.playBgm(AudioService.bgmForCategory(def.category.name));
    setState(() {
      _definition = def;
      _engine = engine;
      _session = session;
      _runKey++;
    });
  }

  /// Payment flow shared by hints and continues: coins first, rewarded ad
  /// as fallback, friendly decline when neither is possible (offline).
  Future<bool> _payAndGrant({
    required int cost,
    required VoidCallback onGranted,
    required String unavailableMessage,
  }) async {
    final progress = ref.read(progressProvider);
    if (progress.spendCoins(cost)) {
      onGranted();
      return true;
    }
    final earned = await AdsService.instance.showRewarded();
    if (earned) {
      onGranted();
      return true;
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(unavailableMessage)));
    }
    return false;
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null || !session.isFinished || _finishing) return;
    _finishing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleFinish(session));
  }

  Future<void> _handleFinish(GameSessionController session) async {
    final def = _definition!;
    final outcome = session.outcome!;
    final stars = Scoring.starsFor(
      score: outcome.score,
      won: outcome.won,
      difficulty: def.difficulty,
      target: def.config['target'] is int ? def.config['target'] as int : null,
    );
    final coins = Scoring.coinsFor(
      score: outcome.score,
      won: outcome.won,
      difficulty: def.difficulty,
    );

    final scores = ref.read(scoresRepoProvider);
    final previousBest = await scores.bestForGame(def.id);
    await scores.record(game: def, score: outcome.score, stars: stars);
    session.clearSavedState();

    final progress = ref.read(progressProvider);
    progress.recordPlay(def.id);
    progress.touchDailyStreak();
    progress.earnCoins(coins);
    progress.recordResultForAdaptive(def.template, stars);

    // Daily Brain Training bookkeeping (no-op for non-routine games).
    ref.read(brainTrainingProvider).refreshDay(DateTime.now());

    final unlocked = await ref
        .read(achievementsServiceProvider)
        .applyAndCollectUnlocked(GameResultInput(
          category: def.category,
          template: def.template,
          won: outcome.won,
          score: outcome.score,
          stars: stars,
          stats: outcome.stats,
        ));

    ref.read(analyticsProvider).log('game_finish', {
      'template': def.template,
      'category': def.category.name,
      'score': outcome.score,
      'won': outcome.won,
    });

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(
      Routes.results,
      arguments: ResultsPayload(
        definition: def,
        outcome: outcome,
        stars: stars,
        coinsEarned: coins,
        previousBest: previousBest?.score,
        newAchievements: unlocked,
      ),
    );
  }

  void _restart() {
    final def = _definition;
    if (def == null) return;
    setState(() => _finishing = false);
    _startSession(def);
  }

  Future<void> _quit() async {
    final confirmed = await AppDialogs.confirm(
      context: context,
      title: 'Quit game?',
      message: 'Your current progress in this run will be lost.',
      confirmLabel: 'Quit',
    );
    if (!confirmed || !mounted) return;
    _session?.setPaused(true);
    _leaveGame();
  }

  /// Back to home; frequency-capped interstitial on the way out.
  void _leaveGame() {
    final progress = ref.read(progressProvider);
    progress.noteGameExit();
    AudioService.I.playBgm('menu_loop');
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (progress.shouldShowInterstitial()) {
      progress.noteInterstitialShown();
      AdsService.instance.showInterstitial(() {});
    }
  }

  @override
  void dispose() {
    AudioService.I.playBgm('menu_loop');
    _session?.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final def = _definition;
    if (def == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game not found')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'This game is not in the catalog. It may have been removed from a custom manifest.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final engine = _engine;
    if (engine == null) {
      return Scaffold(
        appBar: AppBar(title: Text(def.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.extension_off, size: 56, color: theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  'Unknown game template "${def.template}".',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final session = _session!;
    final palette = session.palette;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _quit();
      },
      child: Scaffold(
        backgroundColor: theme.brightness == Brightness.dark
            ? palette.backgroundDark
            : palette.backgroundLight,
        body: SafeArea(
          child: AnimatedBuilder(
            animation: session,
            builder: (context, _) {
              return Stack(
                children: [
                  Column(
                    children: [
                      _HudBar(
                        title: def.title,
                        hud: session.hud,
                        onPause: session.isFinished ? null : () {
                          AppFeedback.tap();
                          session.setPaused(true);
                        },
                      ),
                      Expanded(
                        key: ValueKey('engine-$_runKey'),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: engine.build(session),
                        ),
                      ),
                    ],
                  ),
                  if (session.isPaused && !session.isFinished)
                    _PauseOverlay(
                      engine: engine,
                      definition: def,
                      onResume: () => session.setPaused(false),
                      onRestart: () {
                        session.setPaused(false);
                        _restart();
                      },
                      onQuit: _quit,
                      onHint: () async {
                        final ok = await session.requestHint();
                        if (!ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('No hints available right now.')),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HudBar extends StatelessWidget {
  const _HudBar({
    required this.title,
    required this.hud,
    this.onPause,
  });

  final String title;
  final GameHudData hud;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back',
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.stars, size: 16, color: theme.colorScheme.tertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${hud.score}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      if (hud.status != null) ...[
                        const SizedBox(width: 12),
                        Text(hud.status!, style: theme.textTheme.labelLarge?.copyWith(color: onSurface)),
                      ],
                      if (hud.detail != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          hud.detail!,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onPause != null)
              IconButton(
                onPressed: onPause,
                icon: const Icon(Icons.pause_circle_outline),
                tooltip: 'Pause',
              ),
          ],
        ),
        if (hud.progress != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 2),
            child: LinearProgressIndicator(
              value: hud.progress!.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}

class _PauseOverlay extends ConsumerWidget {
  const _PauseOverlay({
    required this.engine,
    required this.definition,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
    required this.onHint,
  });

  final GameEngine engine;
  final GameDefinition definition;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  final Future<void> Function() onHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Card(
        margin: const EdgeInsets.all(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Paused', style: theme.textTheme.headlineSmall)),
                  // Quick audio toggles (add-on spec §4: reachable from the
                  // pause menu, not buried in Settings).
                  IconButton(
                    tooltip: settings.musicOn ? 'Mute music' : 'Unmute music',
                    onPressed: () => settings.setMusic(!settings.musicOn),
                    icon: Icon(
                      settings.musicOn ? Icons.music_note : Icons.music_off,
                    ),
                  ),
                  IconButton(
                    tooltip: settings.soundOn ? 'Mute sound effects' : 'Unmute sound effects',
                    onPressed: () => settings.setSound(!settings.soundOn),
                    icon: Icon(
                      settings.soundOn ? Icons.volume_up : Icons.volume_off,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                engine.instructions,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume'),
              ),
              const SizedBox(height: 8),
              if (engine.supportsHint)
                OutlinedButton.icon(
                  onPressed: () => onHint(),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Hint (150 coins or ad)'),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onRestart,
                icon: const Icon(Icons.refresh),
                label: const Text('Restart'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onQuit,
                child: const Text('Quit game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
