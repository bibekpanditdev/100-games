/// Home screen search bar with a 300 ms debounce.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/routing.dart';

/// Rounded search field that opens [BrowseScreen] with the typed query.
///
/// Typing navigates after a 300 ms pause (so we don't push a route per
/// keystroke); pressing enter/submit navigates immediately. Empty queries
/// never navigate.
class HomeSearchField extends StatefulWidget {
  const HomeSearchField({super.key});

  @override
  State<HomeSearchField> createState() => _HomeSearchFieldState();
}

class _HomeSearchFieldState extends State<HomeSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _debounce = Timer(const Duration(milliseconds: 300), () => _open(trimmed));
  }

  void _onSubmitted(String query) {
    _debounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    _open(trimmed);
  }

  void _open(String query) {
    if (!mounted) return;
    Navigator.of(context).pushNamed(Routes.browse, arguments: query);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: _onSubmitted,
        onChanged: _onChanged,
        decoration: InputDecoration(
          hintText: 'Search games',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
