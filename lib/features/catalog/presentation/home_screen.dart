/// Catalog home: header, search, category shortcuts, daily challenge,
/// Continue/Popular/New carousels and the first slice of the full grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/routing.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../ads/widgets/banner_slot.dart';
import '../domain/game_definition.dart';
import 'catalog_providers.dart' show catalogGamesProvider, progressProvider;
import 'widgets/brain_training_card.dart';
import 'widgets/category_tabs.dart';
import 'widgets/daily_challenge_card.dart';
import 'widgets/game_card_consumer.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_field.dart';

/// Number of games shown in the "All games" preview grid.
const int _kPreviewCount = 30;

/// Home tab. Const-constructible — routing builds it as `const HomeScreen()`.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            HomeHeader(),
            HomeSearchField(),
            CategoryTabBar(),
            Expanded(child: _HomeBody()),
          ],
        ),
      ),
      // Collapses to zero height when no ad is available.
      bottomNavigationBar: const BannerAdSlot(),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogGamesProvider);
    return catalog.when(
      loading: () => ListView(
        children: const [
          SizedBox(height: 16),
          SkeletonCarousel(),
          SkeletonGrid(itemCount: 9),
        ],
      ),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: "Couldn't load games",
        message: 'Something went wrong reading the catalog. '
            '($error)',
        actionLabel: 'Retry',
        onAction: () => ref.invalidate(catalogGamesProvider),
      ),
      data: (games) => _CatalogContent(games: games),
    );
  }
}

class _CatalogContent extends ConsumerWidget {
  const _CatalogContent({required this.games});

  final List<GameDefinition> games;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final byId = {for (final g in games) g.id: g};
    final popular = [...games]..sort((a, b) => b.popularity.compareTo(a.popularity));
    final fresh = games.where((g) => g.isNew).take(12).toList();

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: DailyChallengeCard()),
        const SliverToBoxAdapter(child: BrainTrainingCard()),
        ..._carouselSlivers('Continue Playing', _continuePlaying(ref, byId)),
        ..._carouselSlivers('Popular', popular.take(12).toList()),
        ..._carouselSlivers('New', fresh),
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'All games',
            actionLabel: 'Browse all',
            onAction: () => Navigator.of(context).pushNamed(Routes.browse),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => index == _kPreviewCount
                  ? const _ViewAllCard()
                  : ProviderGameCard(definition: games[index]),
              // Tail ("View all") card only when there is more to browse.
              childCount:
                  games.length > _kPreviewCount ? _kPreviewCount + 1 : games.length,
            ),
          ),
        ),
      ],
    );
  }

  /// Most recently played games (newest first), capped at 10.
  List<GameDefinition> _continuePlaying(
    WidgetRef ref,
    Map<String, GameDefinition> byId,
  ) {
    final progress = ref.watch(progressProvider);
    final recent = progress.lastPlayed.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return recent
        .take(10)
        .map((entry) => byId[entry.key])
        .whereType<GameDefinition>()
        .toList();
  }

  List<Widget> _carouselSlivers(String title, List<GameDefinition> games) {
    if (games.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: SectionHeader(title: title),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180, // Slightly taller for premium feel
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: games.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) =>
                ProviderGameCard(definition: games[index], compact: true),
          ),
        ),
      ),
    ];
  }
}

/// Tail cell of the preview grid — shortcut to the full browse screen.
class _ViewAllCard extends StatelessWidget {
  const _ViewAllCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.35),
      elevation: 1,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(Routes.browse),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 32,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'View all',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
