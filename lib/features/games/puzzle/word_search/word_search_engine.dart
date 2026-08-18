/// Word search engine: drag across the grid (or tap start + end letters)
/// to find themed hidden words before the timer runs out.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import 'word_search_logic.dart';

/// Catalog engine for the `word_search` template.
class WordSearchEngine implements GameEngine {
  const WordSearchEngine();

  @override
  String get templateId => 'word_search';

  @override
  String get instructions =>
      'Drag across the grid — or tap a start and an end letter — to select '
      'hidden words in any direction. Find them all before time runs out.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) =>
      WordSearchGame(session: session);
}

const String _kWordsAsset = 'assets/wordsearch/words.json';

/// Offline fallback if the asset cannot be read (never blocks gameplay).
const List<String> _kFallbackWords = [
  'PUZZLE', 'GARDEN', 'MARKET', 'SILVER', 'PLANET', 'CASTLE',
  'BRIDGE', 'FOREST', 'MIRROR', 'ROCKET', 'TRAINS', 'WINTER',
];

/// The word search gameplay screen for one session.
class WordSearchGame extends StatefulWidget {
  const WordSearchGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<WordSearchGame> createState() => _WordSearchGameState();
}

class _WordSearchGameState extends State<WordSearchGame> {
  late final int _size;
  late final int _wordCount;

  WordSearchGrid? _grid;
  String _themeName = '';
  int _remaining = 0;
  Timer? _ticker;

  List<int> _selection = const <int>[];
  int? _dragAnchor;
  int? _tapAnchor;
  Set<int> _foundCells = const <int>{};
  int? _hintCell;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    final cfg = widget.session.config;
    final size = cfg.getInt('size', 9);
    _size = size < 6 ? 6 : (size > 14 ? 14 : size);
    final wordCount = cfg.getInt('wordCount', 6);
    _wordCount = wordCount < 3 ? 3 : (wordCount > 12 ? 12 : wordCount);
    _remaining = cfg.getInt('timeSec', 240);
    widget.session.onHintGranted = _applyHint;
    widget.session.addListener(_onSessionChanged);
    _pushHud();
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    _loadWords();
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChanged);
    _ticker?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _onSessionChanged() {
    if (widget.session.isFinished) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  void _pushHud() {
    final grid = _grid;
    final total = grid?.placedWords.length ?? _wordCount;
    final found = grid?.found.length ?? 0;
    final ratio = total == 0 ? 0.0 : found / total;
    widget.session.updateHud(
      score: found * 100,
      status: 'Time $_remaining',
      detail: 'Words $found/$total',
      progress: ratio > 1 ? 1.0 : ratio,
    );
  }

  void _onTick([Timer? _]) {
    final session = widget.session;
    if (session.isPaused || session.isFinished || _grid == null) return;
    _remaining -= 1;
    if (_remaining <= 0) {
      _remaining = 0;
      AudioService.I.sfx(SfxKeys.lose);
      _pushHud();
      session.finish(
        won: false,
        stats: {'found': _grid?.found.length ?? 0},
      );
      return;
    }
    _pushHud();
  }

  Future<void> _loadWords() async {
    final cfg = widget.session.config;
    final random = Random();
    var themes = <String, List<String>>{};
    try {
      final raw = await rootBundle.loadString(_kWordsAsset);
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final rawThemes = decoded['themes'] as Map<String, dynamic>? ?? {};
      themes = {
        for (final entry in rawThemes.entries)
          entry.key: [
            for (final word in entry.value as List<dynamic>)
              word.toString(),
          ],
      };
    } catch (_) {
      themes = const {};
    }
    if (!mounted) return;

    var themeName = cfg.getString('theme', '');
    var pool = themes[themeName];
    if (pool == null || pool.isEmpty) {
      if (themes.isEmpty) {
        themeName = 'words';
        pool = _kFallbackWords;
      } else {
        final names = themes.keys.toList()..shuffle(random);
        themeName = names.first;
        pool = themes[themeName] ?? const <String>[];
      }
    }
    final maxLen = _size < 10 ? _size : 10;
    final candidates =
        pool.where((w) => w.length >= 3 && w.length <= maxLen).toList()
          ..shuffle(random);
    final chosen = candidates.take(_wordCount).toList();
    final grid =
        WordSearchGrid(size: _size, words: chosen, random: random);
    setState(() {
      _grid = grid;
      _themeName = themeName;
    });
    _pushHud();
    if (grid.placements.isEmpty) {
      widget.session.finish(won: true, stats: const {'found': 0});
    }
  }

  // Selection ----------------------------------------------------------------

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  int _cellAt(Offset local, double cellSize) {
    var r = local.dy ~/ cellSize;
    var c = local.dx ~/ cellSize;
    if (r < 0) r = 0;
    if (c < 0) c = 0;
    if (r >= _size) r = _size - 1;
    if (c >= _size) c = _size - 1;
    return r * _size + c;
  }

  void _onPanStart(DragStartDetails details, double cellSize) {
    if (!_interactive) return;
    _dragAnchor = _cellAt(details.localPosition, cellSize);
    _updateDragTo(_dragAnchor!);
  }

  void _onPanUpdate(DragUpdateDetails details, double cellSize) {
    final anchor = _dragAnchor;
    if (!_interactive || anchor == null) return;
    _updateDragTo(_cellAt(details.localPosition, cellSize));
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragAnchor == null) return;
    _dragAnchor = null;
    _commitSelection();
  }

  void _updateDragTo(int cellIndex) {
    final grid = _grid;
    final anchor = _dragAnchor;
    if (grid == null || anchor == null) return;
    final line = grid.snapLine(
      anchor ~/ _size,
      anchor % _size,
      cellIndex ~/ _size,
      cellIndex % _size,
    );
    setState(() => _selection = line);
  }

  void _onTapUp(TapUpDetails details, double cellSize) {
    if (!_interactive || _grid == null) return;
    final index = _cellAt(details.localPosition, cellSize);
    final anchor = _tapAnchor;
    if (anchor == null) {
      setState(() {
        _tapAnchor = index;
        _selection = <int>[index];
      });
      return;
    }
    final grid = _grid!;
    final line = grid.snapLine(
      anchor ~/ _size,
      anchor % _size,
      index ~/ _size,
      index % _size,
    );
    setState(() => _selection = line);
    _tapAnchor = null;
    _commitSelection();
  }

  void _commitSelection() {
    final grid = _grid;
    final selection = _selection;
    if (grid != null && selection.length >= 2) {
      final a = selection.first;
      final b = selection.last;
      final hit = grid.selectLine(
        a ~/ _size,
        a % _size,
        b ~/ _size,
        b % _size,
      );
      if (hit) {
        AudioService.I.sfx(SfxKeys.wordFound);
        _rebuildFoundCells(grid);
        _pushHud();
        if (grid.allFound) {
          AudioService.I.sfx(SfxKeys.win);
          widget.session.finish(
            won: true,
            stats: {'found': grid.found.length},
          );
        }
      } else {
        AudioService.I.sfx(SfxKeys.wrong);
      }
    }
    setState(() {
      _selection = const <int>[];
      _dragAnchor = null;
      _tapAnchor = null;
    });
  }

  void _rebuildFoundCells(WordSearchGrid grid) {
    final cells = <int>{};
    for (final placement in grid.placements) {
      if (!grid.found.contains(placement.word)) continue;
      cells.addAll(placement.cells(_size));
    }
    _foundCells = cells;
  }

  // Hints --------------------------------------------------------------------

  Future<void> _requestHint() async {
    // The shell applies the hint via onHintGranted after payment.
    await widget.session.requestHint();
  }

  void _applyHint() {
    final placement = _grid?.firstUnfound();
    if (placement == null || widget.session.isFinished) return;
    AudioService.I.sfx(SfxKeys.hint);
    _hintTimer?.cancel();
    setState(() => _hintCell = placement.row * _size + placement.col);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _hintCell = null);
    });
  }

  // Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    return SafeArea(
      child: grid == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(aspectRatio: 1, child: _buildBoard()),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Theme: $_themeName',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      _hintButton(),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _buildLegend(context),
                ),
              ],
            ),
    );
  }

  Widget _buildBoard() {
    final palette = widget.session.palette;
    final grid = _grid!;
    return Semantics(
      label: 'Word search grid, $_size by $_size letters',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.biggest.shortestSide / _size;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (d) => _onPanStart(d, cellSize),
            onPanUpdate: (d) => _onPanUpdate(d, cellSize),
            onPanEnd: _onPanEnd,
            onTapUp: (d) => _onTapUp(d, cellSize),
            child: Container(
              decoration: BoxDecoration(
                color: palette.boardB,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  for (var r = 0; r < _size; r++)
                    Expanded(
                      child: Row(
                        children: [
                          for (var c = 0; c < _size; c++)
                            Expanded(
                              child: _buildCell(r, c, cellSize),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCell(int r, int c, double cellSize) {
    final palette = widget.session.palette;
    final index = r * _size + c;
    final isSelected = _selection.contains(index);
    final isFound = _foundCells.contains(index);
    final isHint = _hintCell == index;
    final Color background;
    if (isSelected) {
      background = palette.accent;
    } else if (isFound) {
      background = palette.boardB;
    } else {
      background = (r + c) % 2 == 0 ? palette.boardA : palette.boardB;
    }
    final foreground =
        GamePalette.contrastOn(isSelected ? palette.accent : background);
    return Semantics(
      label: 'Letter ${_grid!.letterAt(r, c)}, row ${r + 1} column ${c + 1}'
          '${isFound ? ', part of a found word' : ''}',
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(4),
          border: isHint ? Border.all(color: palette.accent, width: 3) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          _grid!.letterAt(r, c),
          style: TextStyle(
            color: foreground,
            fontSize: cellSize * 0.44,
            fontWeight: isFound || isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    final grid = _grid!;
    final words = [...grid.placedWords]..sort();
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final word in words)
          Text(
            word,
            semanticsLabel: word + (grid.found.contains(word) ? ', found' : ''),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: grid.found.contains(word)
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
              color: grid.found.contains(word)
                  ? scheme.onSurfaceVariant
                  : scheme.onSurface,
            ),
          ),
      ],
    );
  }

  Widget _hintButton() {
    return Semantics(
      button: true,
      label: 'Get a hint',
      child: FilledButton.tonalIcon(
        onPressed: _interactive ? _requestHint : null,
        style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
        icon: const Icon(Icons.lightbulb_outline),
        label: const Text('Hint'),
      ),
    );
  }
}
