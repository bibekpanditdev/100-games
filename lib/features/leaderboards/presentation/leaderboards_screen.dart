/// Leaderboards screen: offline personal bests per category (Local tab)
/// plus an optional Google Play Games global view (Global tab). Everything
/// local works without an account or connectivity — the global tab is
/// strictly opt-in.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/feedback.dart';
import '../../../core/services/play_games_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/star_rating.dart';
import '../../catalog/domain/game_definition.dart';
import '../../catalog/presentation/catalog_providers.dart';
import '../scores_repository.dart';

/// Top personal bests per game for one category (`null` = all categories).
///
/// Public so the Settings screen's "Reset all progress" can invalidate it.
final topScoresProvider =
    FutureProvider.family<List<ScoreEntry>, GameCategory?>(
  (ref, category) => ref.watch(scoresRepoProvider).topForCategory(category),
);

/// Mind-module sub-boards: bests within one subcategory (`null` = all mind
/// games). Add-on spec §6 — per-subcategory leaderboards.
final mindGroupScoresProvider =
    FutureProvider.family<List<ScoreEntry>, String?>(
  (ref, group) => ref.watch(scoresRepoProvider).topForMindGroup(group),
);

/// Local leaderboard + optional global (Google Play Games) view.
class LeaderboardsScreen extends ConsumerStatefulWidget {
  const LeaderboardsScreen({super.key});

  @override
  State<LeaderboardsScreen> createState() => _LeaderboardsScreenState();
}

class _LeaderboardsScreenState extends ConsumerState<LeaderboardsScreen> {
  /// Category filter for the Local tab (`null` = All).
  GameCategory? _category;

  /// Mind subcategory filter (logic/word/memory/math/spatial); only used
  /// while the Mind category chip is selected.
  String? _mindGroup;

  /// Mirrors [PlayGamesService.signedIn] so sign-in attempts update the UI.
  bool _pgSignedIn = PlayGamesService.instance.signedIn;

  /// Opens the native Play Games leaderboard UI, signing in first if needed.
  /// Never throws — offline devices just get a friendly snackbar.
  Future<void> _openPlayGames() async {
    AppFeedback.tap();
    try {
      if (!PlayGamesService.instance.signedIn) {
        final signedIn = await PlayGamesService.instance.signIn();
        if (!mounted) return;
        if (!signedIn) {
          _snack('Sign-in unavailable offline');
          return;
        }
        setState(() => _pgSignedIn = true);
      }
      await PlayGamesService.instance.showLeaderboards();
    } catch (_) {
      if (mounted) _snack('Sign-in unavailable offline');
    }
  }

  /// Sign-in entry point from the Global tab's empty state.
  Future<void> _signIn() async {
    AppFeedback.tap();
    try {
      final signedIn = await PlayGamesService.instance.signIn();
      if (!mounted) return;
      setState(() => _pgSignedIn = signedIn);
      if (!signedIn) _snack('Sign-in unavailable offline');
    } catch (_) {
      if (mounted) _snack('Sign-in unavailable offline');
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboards'),
          actions: [
            IconButton(
              tooltip: 'Google Play Games leaderboards',
              onPressed: _openPlayGames,
              icon: const Icon(Icons.sports_esports_outlined),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Local'),
              Tab(text: 'Global'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _LocalLeaderboards(
              category: _category,
              mindGroup: _mindGroup,
              onCategorySelected: (category) => setState(() {
                _category = category;
                if (category != GameCategory.mind) _mindGroup = null;
              }),
              onMindGroupSelected: (group) => setState(() => _mindGroup = group),
            ),
            _GlobalLeaderboards(
              signedIn: _pgSignedIn,
              onSignIn: _signIn,
              onOpenNative: _openPlayGames,
            ),
          ],
        ),
      ),
    );
  }
}

/// Offline personal-best ranking with category filter chips (+ mind
/// subcategory chips when the Mind category is selected).
class _LocalLeaderboards extends ConsumerWidget {
  const _LocalLeaderboards({
    required this.category,
    required this.mindGroup,
    required this.onCategorySelected,
    required this.onMindGroupSelected,
  });

  final GameCategory? category;
  final String? mindGroup;
  final ValueChanged<GameCategory?> onCategorySelected;
  final ValueChanged<String?> onMindGroupSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMind = category == GameCategory.mind;
    final scores = isMind
        ? ref.watch(mindGroupScoresProvider(mindGroup))
        : ref.watch(topScoresProvider(category));

    return Column(
      children: [
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _CategoryFilterChip(
                label: 'All',
                selected: category == null,
                onTap: () => onCategorySelected(null),
              ),
              for (final c in GameCategory.values) ...[
                const SizedBox(width: 8),
                _CategoryFilterChip(
                  label: c.label,
                  selected: category == c,
                  onTap: () => onCategorySelected(c),
                ),
              ],
            ],
          ),
        ),
        if (isMind)
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _CategoryFilterChip(
                  label: 'All mind',
                  selected: mindGroup == null,
                  onTap: () => onMindGroupSelected(null),
                ),
                for (final entry in const {
                  'Logic': 'logic',
                  'Word': 'word',
                  'Memory': 'memory',
                  'Math': 'math',
                  'Spatial': 'spatial',
                }.entries) ...[
                  const SizedBox(width: 8),
                  _CategoryFilterChip(
                    label: entry.key,
                    selected: mindGroup == entry.value,
                    onTap: () => onMindGroupSelected(entry.value),
                  ),
                ],
              ],
            ),
          ),
        Expanded(
          child: scores.when(
            loading: () => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, __) => const SkeletonBox(height: 56, radius: 14),
            ),
            error: (error, _) => EmptyState(
              icon: Icons.cloud_off_outlined,
              title: "Couldn't load scores",
              message: 'Something went wrong reading local scores. ($error)',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(topScoresProvider(category)),
            ),
            data: (entries) => entries.isEmpty
                ? const EmptyState(
                    icon: Icons.emoji_events,
                    title: 'No scores yet',
                    message: 'Play a game to set your first record!',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _ScoreRow(rank: index + 1, entry: entries[index]),
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategoryFilterChip extends StatelessWidget {
  const _CategoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        AppFeedback.tap();
        onTap();
      },
    );
  }
}

/// One ranked personal best: rank, category icon, title, stars, date, score.
class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.rank, required this.entry});

  final int rank;
  final ScoreEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = _rankTint(rank);

    return Semantics(
      label: 'Rank $rank: ${entry.gameTitle}, '
          '${compactNumber(entry.score)} points, ${entry.stars} stars',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: medal ?? scheme.surfaceContainerHighest,
              ),
              child: Text(
                '#$rank',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: medal != null ? Colors.white : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Icon(categoryIcon(entry.category), size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.gameTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      StarRating(
                        stars: entry.stars.clamp(0, 3).toInt(),
                        size: 14,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _shortDate(entry.playedAt),
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              compactNumber(entry.score),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explanatory global view. Sign-in is opt-in and gameplay never needs it;
/// [PlayGamesService] itself never throws (offline just returns false).
class _GlobalLeaderboards extends StatelessWidget {
  const _GlobalLeaderboards({
    required this.signedIn,
    required this.onSignIn,
    required this.onOpenNative,
  });

  final bool signedIn;
  final VoidCallback onSignIn;
  final VoidCallback onOpenNative;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 16),
        EmptyState(
          icon: Icons.public,
          title: signedIn ? 'Global leaderboards' : 'Go global',
          message: signedIn
              ? 'Compare your best scores with players around the world '
                  'through Google Play Games.'
              : 'Sign in to compare your scores with players around the world.',
          actionLabel: signedIn
              ? 'Open Play Games leaderboards'
              : 'Sign in with Google Play Games',
          onAction: signedIn ? onOpenNative : onSignIn,
        ),
        const SizedBox(height: 8),
        Text(
          'Optional — gameplay never requires an account or internet.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Medal tints for the podium rows; null renders a plain neutral badge.
Color? _rankTint(int rank) => switch (rank) {
      1 => const Color(0xFFF9A825), // gold
      2 => const Color(0xFF78909C), // silver
      3 => const Color(0xFF8D6E63), // bronze
      _ => null,
    };

/// Local date as `MM/dd`, e.g. `03/09`.
String _shortDate(DateTime t) =>
    '${t.month.toString().padLeft(2, '0')}/${t.day.toString().padLeft(2, '0')}';
