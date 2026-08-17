/// Browse screen: full catalog grid with search, category/difficulty
/// filters and sorting.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/badges.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../ads/widgets/banner_slot.dart';
import '../domain/game_definition.dart';
import 'catalog_providers.dart';
import 'widgets/game_card_consumer.dart';

enum _SortOrder { popular, newest, az }

/// Full-catalog browser.
///
/// [initialCategory] preselects a category chip (routing passes a
/// [GameCategory] as the route argument); [initialQuery] pre-fills the
/// search field (routing passes a [String] query).
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({
    super.key,
    this.initialCategory,
    this.initialQuery = '',
  });

  final GameCategory? initialCategory;
  final String initialQuery;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  late final TextEditingController _search;
  late bool _searchOpen;
  late String _query;
  GameCategory? _category;
  Difficulty? _difficulty;
  _SortOrder _sort = _SortOrder.popular;

  /// Mind-module subcategory filter (logic/word/memory/math/spatial);
  /// only shown while the Mind category is selected.
  String? _mindGroup;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.initialQuery);
    _searchOpen = widget.initialQuery.isNotEmpty;
    _query = widget.initialQuery;
    _category = widget.initialCategory;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogGamesProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searchOpen ? _buildSearchField() : const Text('Browse'),
        actions: [
          if (!_searchOpen)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searchOpen = true),
            ),
          PopupMenuButton<_SortOrder>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _SortOrder.popular,
                child: Text('Popular'),
              ),
              PopupMenuItem(value: _SortOrder.newest, child: Text('New')),
              PopupMenuItem(value: _SortOrder.az, child: Text('A-Z')),
            ],
          ),
        ],
      ),
      // Collapses to zero height when no ad is available.
      bottomNavigationBar: const BannerAdSlot(),
      body: catalog.when(
        loading: () => ListView(
          children: const [
            SizedBox(height: 8),
            SkeletonGrid(itemCount: 12),
          ],
        ),
        error: (error, _) => EmptyState(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load games",
          message: 'Something went wrong reading the catalog. ($error)',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(catalogGamesProvider),
        ),
        data: (games) {
          final filtered = _applyFilters(games);
          return Column(
            children: [
              _buildCategoryRow(),
              if (_category == GameCategory.mind) _buildMindGroupRow(),
              _buildDifficultyRow(),
              Expanded(
                child: filtered.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        title: 'No games found',
                        message: 'Try a different search term '
                            'or clear the filters.',
                        actionLabel: 'Clear filters',
                        onAction: _clearFilters,
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.56,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            ProviderGameCard(definition: filtered[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _search,
      autofocus: true,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => _query = value),
      decoration: InputDecoration(
        hintText: 'Search games',
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        contentPadding: EdgeInsets.zero,
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Close search',
          icon: const Icon(Icons.close),
          onPressed: () {
            _search.clear();
            setState(() {
              _searchOpen = false;
              _query = '';
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildCategoryRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ChoiceChip(
            avatar: const Icon(Icons.apps, size: 18),
            label: const Text('All'),
            selected: _category == null,
            onSelected: (_) => setState(() => _category = null),
          ),
          const SizedBox(width: 8),
          for (final category in GameCategory.values) ...[
            ChoiceChip(
              avatar: Icon(categoryIcon(category), size: 18),
              label: Text(category.label),
              selected: _category == category,
              onSelected: (_) => setState(() {
                _category = category;
                if (category != GameCategory.mind) _mindGroup = null;
              }),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  /// Subcategory chips for the Mind category (spec add-on §4): logic /
  /// word / memory / math / spatial.
  Widget _buildMindGroupRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final entry in const {
            'All mind': null,
            'Logic': 'logic',
            'Word': 'word',
            'Memory': 'memory',
            'Math': 'math',
            'Spatial': 'spatial',
          }.entries) ...[
            ChoiceChip(
              avatar: entry.value == null ? const Icon(Icons.psychology, size: 18) : null,
              label: Text(entry.key),
              selected: _mindGroup == entry.value,
              onSelected: (_) => setState(() => _mindGroup = entry.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildDifficultyRow() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final entry in const {
            'Any': null,
            'Easy': Difficulty.easy,
            'Medium': Difficulty.medium,
            'Hard': Difficulty.hard,
          }.entries) ...[
            ChoiceChip(
              label: Text(entry.key),
              selected: _difficulty == entry.value,
              onSelected: (_) => setState(() => _difficulty = entry.value),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _clearFilters() {
    _search.clear();
    setState(() {
      _query = '';
      _category = null;
      _difficulty = null;
      _mindGroup = null;
    });
  }

  List<GameDefinition> _applyFilters(List<GameDefinition> games) {
    final query = _query.trim().toLowerCase();
    final filtered = games
        .where(
          (g) =>
              (_category == null || g.category == _category) &&
              (_difficulty == null || g.difficulty == _difficulty) &&
              (_mindGroup == null || g.config['group'] == _mindGroup) &&
              (query.isEmpty || g.title.toLowerCase().contains(query)),
        )
        .toList();
    switch (_sort) {
      case _SortOrder.popular:
        filtered.sort((a, b) => b.popularity.compareTo(a.popularity));
      case _SortOrder.newest:
        filtered.sort(
          (a, b) => b.isNew != a.isNew
              ? (b.isNew ? 1 : -1)
              : b.popularity.compareTo(a.popularity),
        );
      case _SortOrder.az:
        filtered.sort((a, b) => a.title.compareTo(b.title));
    }
    return filtered;
  }
}
