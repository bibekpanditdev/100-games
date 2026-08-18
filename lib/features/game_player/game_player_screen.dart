/// Full-screen gameplay host.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/audio_service.dart';
import '../../../core/services/feedback.dart';
import '../catalog/domain/game_definition.dart';
import '../catalog/presentation/catalog_providers.dart';
import '../gamification/achievements/achievements_repository.dart';
import '../gamification/progress_controller.dart';
import 'engine_registry.dart';
import 'game_contracts.dart';
import 'results_payload.dart';
import 'results_screen.dart';

class GamePlayerScreen extends ConsumerStatefulWidget {
  const GamePlayerScreen({
    super.key,
    required this.gameId,
  });

  final String gameId;

  @override
  ConsumerState<GamePlayerScreen> createState() => _GamePlayerScreenState();
}

class _GamePlayerScreenState extends ConsumerState<GamePlayerScreen> {
  GameSessionController? _session;
  GameDefinition? _definition;
  GameEngine? _engine;
  int _runKey = 0;
  bool _loading = true;
  bool _showIntro = true;

  @override
  void initState() {
    super.initState();
    _loadGame();
  }

  Future<void> _loadGame() async {
    final def = await ref.read(gameByIdProvider(widget.gameId).future);
    if (!mounted) return;
    
    if (def == null) {
      setState(() => _loading = false);
      return;
    }

    final engine = engineFor(def.template);
    setState(() {
      _definition = def;
      _engine = engine;
      _loading = false;
      if (engine != null) _initSession(def);
    });

    // Hide intro after delay.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showIntro = false);
    });
  }

  void _initSession(GameDefinition def) {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    
    final session = GameSessionController(definition: def);
    session.attachSupportHandlers(
      hint: () async {
        final progress = ref.read(progressProvider);
        if (progress.spendCoins(ProgressController.hintCost)) {
          AppFeedback.coin();
          return true;
        }
        return false;
      },
      continueRequest: () async {
        final progress = ref.read(progressProvider);
        if (progress.spendCoins(ProgressController.extraLifeCost)) {
          AppFeedback.coin();
          return true;
        }
        return false;
      },
    );
    
    session.addListener(_onSessionChanged);
    _session = session;
    
    ref.read(progressProvider).recordPlay(def.id);
    AudioService.I.playBgm(AudioService.bgmForCategory(def.category.name));
  }

  void _onSessionChanged() {
    final session = _session;
    if (session != null && session.isFinished) {
      _finishSession(session);
    }
    if (mounted) setState(() {});
  }

  Future<void> _finishSession(GameSessionController session) async {
    final def = _definition!;
    
    final stars = session.outcome?.won == true ? (session.score > 1000 ? 3 : 2) : 1;
    final coins = stars * 50;

    final scoresRepo = ref.read(scoresRepoProvider);
    final previousBest = await scoresRepo.bestForGame(def.id);
    
    await scoresRepo.record(game: def, score: session.score, stars: stars);
    
    final progress = ref.read(progressProvider);
    progress.earnCoins(coins);
    progress.recordResultForAdaptive(def.template, stars);
    progress.touchDailyStreak();

    final newAchievements = await ref.read(achievementsServiceProvider).applyAndCollectUnlocked(
      GameResultInput(
        category: def.category,
        template: def.template,
        won: session.outcome?.won ?? false,
        score: session.score,
        stars: stars,
        stats: session.outcome?.stats ?? {},
      ),
    );

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(
          payload: ResultsPayload(
            definition: def,
            outcome: session.outcome!,
            stars: stars,
            coinsEarned: coins,
            previousBest: previousBest?.score,
            newAchievements: newAchievements,
          ),
        ),
      ),
    );
  }

  void _quit() {
    AppFeedback.tap();
    Navigator.of(context).pop();
  }

  void _restart() {
    AppFeedback.tap();
    setState(() {
      _runKey++;
      _initSession(_definition!);
    });
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final def = _definition;
    if (def == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Game not found')),
        body: const Center(child: Text('Game not found in catalog.')),
      );
    }

    final engine = _engine;
    if (engine == null) {
      return Scaffold(
        appBar: AppBar(title: Text(def.title)),
        body: Center(child: Text('Unknown template "${def.template}"')),
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
        backgroundColor: theme.brightness == Brightness.dark ? palette.backgroundDark : palette.backgroundLight,
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
                      session: session,
                      onQuit: _quit,
                      onResume: () => session.setPaused(false),
                      onRestart: _restart,
                      onHint: () async {
                        final ok = await session.requestHint();
                        if (!ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Not enough coins!')),
                          );
                        }
                      },
                    ),
                  if (_showIntro && !session.isFinished)
                    _LevelIntro(level: def.level, title: def.title),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LevelIntro extends StatelessWidget {
  const _LevelIntro({required this.level, required this.title});
  final int level;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1800),
      builder: (context, val, child) {
        final opacity = (1.5 - val * 2).clamp(0.0, 1.0);
        if (opacity <= 0) return const SizedBox.shrink();
        return Container(
          color: theme.brightness == Brightness.light 
              ? Colors.white.withValues(alpha: opacity) 
              : Colors.black.withValues(alpha: opacity),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + val * 0.2,
                  child: Text(
                    'LEVEL $level',
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4 + val * 20,
                      color: theme.colorScheme.onSurface.withValues(alpha: opacity),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelLarge?.copyWith(
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary.withValues(alpha: opacity),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.pause_circle_outline, size: 32),
                onPressed: onPause,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    if (hud.status != null)
                      Text(
                        hud.status!,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
              Text(
                '${hud.score}',
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          if (hud.progress != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: hud.progress, minHeight: 6),
              ),
            ),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.session,
    required this.onQuit,
    required this.onResume,
    required this.onRestart,
    required this.onHint,
  });

  final GameSessionController session;
  final VoidCallback onQuit;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onHint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'PAUSED',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 48),
              _PauseBtn(label: 'RESUME', icon: Icons.play_arrow, onTap: onResume, primary: true),
              const SizedBox(height: 16),
              _PauseBtn(label: 'RESTART', icon: Icons.refresh, onTap: onRestart),
              const SizedBox(height: 16),
              _PauseBtn(label: 'QUIT', icon: Icons.close, onTap: onQuit),
              const SizedBox(height: 48),
              TextButton.icon(
                onPressed: onHint,
                icon: const Icon(Icons.lightbulb, color: Colors.amber),
                label: Text(
                  'GET A HINT (${ProgressController.hintCost} coins)',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PauseBtn extends StatelessWidget {
  const _PauseBtn({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: primary ? theme.colorScheme.primary : Colors.white12,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
      ),
    );
  }
}
