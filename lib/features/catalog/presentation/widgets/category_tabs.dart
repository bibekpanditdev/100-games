/// Home screen category shortcut bar.
library;

import 'package:flutter/material.dart';

import '../../../../core/routing.dart';
import '../../../../shared/widgets/badges.dart';
import '../../domain/game_definition.dart';

/// Horizontal "All / Arcade / Puzzle / Cards / Board / Trivia" tab row.
///
/// Tabs are navigation shortcuts — tapping opens [BrowseScreen] filtered
/// to that category ('All' passes no category). Selection state lives on
/// the browse screen, so no tab is highlighted here.
class CategoryTabBar extends StatelessWidget {
  const CategoryTabBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ActionChip(
            avatar: const Icon(Icons.apps, size: 18),
            label: const Text('All'),
            onPressed: () => Navigator.of(context).pushNamed(Routes.browse),
          ),
          const SizedBox(width: 8),
          for (final category in GameCategory.values) ...[
            ActionChip(
              avatar: Icon(categoryIcon(category), size: 18),
              label: Text(category.label),
              onPressed: () => Navigator.of(context)
                  .pushNamed(Routes.browse, arguments: category),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}
