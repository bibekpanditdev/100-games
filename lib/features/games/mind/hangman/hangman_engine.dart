/// Hangman engine — guess the hidden word letter by letter before the
/// friendly hearts run out (no gallows imagery). Full save/resume through
/// [GameSessionController] so a run survives app restarts, fully offline.
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../core/utils/formatters.dart';
import 'hangman_logic.dart';

class HangmanEngine implements GameEngine {
  const HangmanEngine();

  @override
  String get templateId => 'hangman';

  @override
  String get instructions =>
      'Guess the hidden word one letter at a time before your hearts run '
      'out. Every wrong letter costs a heart — reveal the whole word to win.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => HangmanGame(session: session);
}

class HangmanGame extends StatefulWidget {
  const HangmanGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<HangmanGame> createState() => _HangmanGameState();
}

class _HangmanGameState extends State<HangmanGame> {
  static const String _bankPath = 'assets/mind/words/word_bank.json';
  static const List<String> _letters = [
    for (var c = 65; c <= 90; c++) String.fromCharCode(c),
  ];

  HangmanLogic? _logic;
  String? _error;

  GameSessionController get _session => widget.session;

  bool get _interactive => !_session.isPaused && !_session.isFinished;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var words = const <String>[];
    try {
      final raw = await rootBundle.loadString(_bankPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        words = HangmanLogic.wordsFromBank(decoded);
      }
    } catch (_) {
      // A failed asset read falls through to the logic's fallback pool.
    }
    if (!mounted) return;
    if (widget.session.restoredState == null && words.isEmpty) {
      setState(() => _error = 'The offline word bank is unavailable.');
      return;
    }
    final cfg = _session.config;
    final minLen = cfg.getInt('minLen', 4).clamp(3, 12).toInt();
    final maxLen = cfg.getInt('maxLen', 9).clamp(3, 12).toInt();
    final lives = cfg.getInt('lives', 7).clamp(3, 12).toInt();
    // Seed from the definition id so every variant picks its own word,
    // reproducibly and fully offline.
    final logic = HangmanLogic.tryFromMap(_session.restoredState) ??
        HangmanLogic.start(
          bank: words,
          minLen: min(minLen, maxLen),
          maxLen: max(minLen, maxLen),
          lives: lives,
          random: Random(stableHash(_session.definition.id)),
        );
    _logic = logic;
    _pushHud();
    setState(() {});
  }

  void _pushHud() {
    final logic = _logic;
    if (logic == null) return;
    _session.updateHud(
      score: 0,
      status: 'Lives ♥ ${logic.lives}',
      detail: 'Vowels found: ${logic.vowelsFound}',
      progress: logic.revealedCount / logic.word.length,
    );
  }

  void _save() {
    final logic = _logic;
    if (logic != null) _session.saveState(logic.toMap());
  }

  void _onKey(String letter) {
    final logic = _logic;
    if (logic == null || !_interactive || logic.isOver) return;
    final result = logic.tryLetter(letter);
    switch (result) {
      case HangmanGuessResult.hit:
        AudioService.I.sfx(SfxKeys.letter);
      case HangmanGuessResult.miss:
        AudioService.I.sfx(SfxKeys.wrong);
        HapticFeedback.lightImpact();
      case HangmanGuessResult.alreadyTried:
        AudioService.I.sfx(SfxKeys.uiError);
      case HangmanGuessResult.ignored:
        return;
    }
    _save();
    _pushHud();
    setState(() {});
    if (logic.isWon) {
      AudioService.I.sfx(SfxKeys.wordFound);
      _session.finish(
        won: true,
        score: logic.lives * 100 + 200,
        stats: {'wordLen': logic.word.length},
      );
    } else if (logic.isLost) {
      AudioService.I.sfx(SfxKeys.lose);
      _session.finish(
        won: false,
        score: logic.revealedCount * 20,
        stats: {'wordLen': logic.word.length},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final logic = _logic;
    if (logic == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            const SizedBox(height: 8),
            _heartsRow(constraints.maxWidth),
            const SizedBox(height: 4),
            Expanded(child: Center(child: _wordBoard(constraints.maxWidth))),
            _keyboard(constraints.maxWidth),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  /// Friendly lives meter — hearts instead of any gallows imagery.
  Widget _heartsRow(double width) {
    final logic = _logic!;
    final size = (width / (logic.maxLives + 2)).clamp(16.0, 30.0);
    return Semantics(
      label: 'Lives ${logic.lives} of ${logic.maxLives}',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < logic.maxLives; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                i < logic.lives ? Icons.favorite : Icons.favorite_border,
                size: size,
                color: i < logic.lives
                    ? kPieceColors[5]
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
              ),
            ),
        ],
      ),
    );
  }

  Widget _wordBoard(double width) {
    final logic = _logic!;
    final boxSize = (width / logic.word.length - 8).clamp(28.0, 52.0);
    final masked = logic.maskedWord;
    final theme = Theme.of(context);
    return Semantics(
      label: 'Hidden word, ${logic.word.length} letters: '
          '${masked.split('').join(' ')}',
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 8,
        children: [
          for (var i = 0; i < logic.word.length; i++)
            Container(
              width: boxSize,
              height: boxSize * 1.15,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: masked[i] == '_'
                    ? theme.colorScheme.surfaceContainerHighest
                    : _session.palette.boardA,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: _session.palette.accent,
                    width: 3,
                  ),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  masked[i] == '_' ? '' : masked[i],
                  key: ValueKey(masked[i]),
                  style: TextStyle(
                    fontSize: boxSize * 0.55,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: GamePalette.contrastOn(_session.palette.boardA),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _keyboard(double width) {
    var columns = 6;
    if (width >= 560) {
      columns = 9;
    } else if (width >= 420) {
      columns = 8;
    } else if (width >= 340) {
      columns = 7;
    }
    var size = ((width - 16) / columns) - 6;
    var scrollable = false;
    if (size < 44) {
      size = 44;
      scrollable = true;
    }
    size = size.clamp(44.0, 62.0);
    final rows = <Widget>[];
    for (var start = 0; start < _letters.length; start += columns) {
      final end = min(start + columns, _letters.length);
      final row = Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final letter in _letters.sublist(start, end))
            _key(letter, size),
        ],
      );
      rows.add(
        scrollable
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: row,
              )
            : row,
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _key(String letter, double size) {
    final logic = _logic!;
    final theme = Theme.of(context);
    final disabled = theme.colorScheme.onSurface.withOpacity(0.38);
    final tried = logic.hasTried(letter);
    final hit = tried && logic.word.contains(letter);
    Color bg;
    Color fg;
    TextDecoration decoration = TextDecoration.none;
    String stateLabel = '';
    if (hit) {
      bg = kPieceColors[2];
      fg = GamePalette.contrastOn(bg);
      stateLabel = ', in the word';
    } else if (tried) {
      bg = theme.colorScheme.surfaceContainerHighest.withOpacity(0.6);
      fg = disabled;
      decoration = TextDecoration.lineThrough;
      stateLabel = ', already tried';
    } else {
      bg = _session.palette.boardB;
      fg = GamePalette.contrastOn(_session.palette.boardB);
    }
    final enabled = _interactive && !tried && !logic.isOver;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Letter $letter$stateLabel',
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: GestureDetector(
          onTap: enabled ? () => _onKey(letter) : null,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontSize: size * 0.45,
                fontWeight: FontWeight.w700,
                height: 1,
                color: fg,
                decoration: decoration,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
