/// Offline daily word-guess engine — deterministic per-day answer (same
/// word all day per variant, changes at local midnight), duplicate-aware
/// letter feedback that is never colour-only (check / dot / strike markers)
/// and full save/resume through [GameSessionController].
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import '../../../../core/theme/palettes.dart';
import '../../../../core/utils/formatters.dart';
import 'wordle_daily_logic.dart';

class WordleDailyEngine implements GameEngine {
  const WordleDailyEngine();

  @override
  String get templateId => 'wordle_daily';

  @override
  String get instructions =>
      'Guess the five-letter daily word. Green with a check means the right '
      'letter in the right spot, amber with a dot means it belongs elsewhere, '
      'and struck-out grey letters are not in the word. The word is the same '
      'all day and changes at midnight.';

  @override
  bool get supportsHint => false;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => WordleDailyGame(session: session);
}

class WordleDailyGame extends StatefulWidget {
  const WordleDailyGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<WordleDailyGame> createState() => _WordleDailyGameState();
}

class _WordleDailyGameState extends State<WordleDailyGame>
    with SingleTickerProviderStateMixin {
  static const String _bankPath = 'assets/mind/words/word_bank.json';
  static const List<String> _rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];

  WordleDailyLogic? _logic;
  String? _error;
  String _entry = '';
  String? _message;
  Timer? _messageTimer;
  late final AnimationController _shake;

  GameSessionController get _session => widget.session;

  bool get _interactive => !_session.isPaused && !_session.isFinished;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _shake.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var answers = const <String>[];
    var allowed = const <String>[];
    try {
      final raw = await rootBundle.loadString(_bankPath);
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        answers = WordleDailyLogic.answersFromBank(decoded);
        allowed = WordleDailyLogic.allowedFromBank(decoded);
      }
    } catch (_) {
      // Falls through to the logic's tiny built-in fallback bank.
    }
    if (!mounted) return;
    if (answers.isEmpty) {
      setState(() => _error = 'The offline word bank is unavailable.');
      return;
    }
    final cfg = _session.config;
    final maxGuesses = cfg.getInt('maxGuesses', 6).clamp(4, 8).toInt();
    final today = dayKey(DateTime.now());
    // Only resume when the save is from the SAME day — the answer changes
    // at midnight, so yesterday's guesses must not leak into today's run.
    final restoredRaw = _session.restoredState;
    WordleDailyLogic? restored;
    if (restoredRaw != null && restoredRaw['day'] == today) {
      restored = WordleDailyLogic.tryFromMap(
        <String, dynamic>{
          'answer': restoredRaw['answer'],
          'maxGuesses': maxGuesses,
          'guesses': restoredRaw['guesses'],
        },
      );
    }
    final logic = restored ??
        WordleDailyLogic.daily(
          bank5: answers,
          dayKey: today,
          definitionId: _session.definition.id,
          maxGuesses: maxGuesses,
          extraValid: allowed.toSet(),
        );
    _logic = logic;
    if (restored != null) {
      _showMessage('Resumed — ${logic.guessesLeft} guesses left');
    }
    _pushHud();
    setState(() {});
  }

  void _pushHud() {
    final logic = _logic;
    if (logic == null) return;
    final current = logic.isOver
        ? logic.guessCount
        : logic.guessCount + 1;
    _session.updateHud(
      score: 0,
      status: 'Guess $current/${logic.maxGuesses}',
      detail: 'Daily word',
      progress: logic.guessCount / logic.maxGuesses,
    );
  }

  void _save() {
    final logic = _logic;
    if (logic == null) return;
    _session.saveState(<String, dynamic>{
      'day': dayKey(DateTime.now()),
      ...logic.toMap(),
    });
  }

  void _showMessage(String text) {
    _messageTimer?.cancel();
    _messageTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _message = null);
    });
    setState(() => _message = text);
  }

  void _onLetter(String letter) {
    final logic = _logic;
    if (logic == null || !_interactive || logic.isOver) return;
    if (_entry.length >= 5) return;
    AudioService.I.sfx(SfxKeys.uiTap);
    setState(() => _entry += letter);
  }

  void _onBackspace() {
    final logic = _logic;
    if (logic == null || !_interactive || logic.isOver || _entry.isEmpty) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _submit() {
    final logic = _logic;
    if (logic == null || !_interactive || logic.isOver) return;
    final reject = logic.checkGuess(_entry);
    if (reject != null) {
      AudioService.I.sfx(SfxKeys.uiError);
      HapticFeedback.lightImpact();
      _shake.forward(from: 0);
      _showMessage(switch (reject) {
        WordleReject.badLength => 'Not enough letters',
        WordleReject.badLetters => 'Letters A–Z only',
        WordleReject.notInDictionary => 'Not in the word list',
        WordleReject.gameOver => 'Run is over',
      });
      return;
    }
    logic.submit(_entry)!;
    _entry = '';
    AudioService.I.sfx(SfxKeys.place);
    _save();
    _pushHud();
    setState(() {});
    if (logic.isWon) {
      AudioService.I.sfx(SfxKeys.win);
      _session.finish(
        won: true,
        score: 300 + logic.guessesLeft * 100,
        stats: {
          'guesses': logic.guessCount,
          'perfect': logic.guessCount == 1 ? 1 : 0,
        },
      );
    } else if (logic.isLost) {
      AudioService.I.sfx(SfxKeys.lose);
      _showMessage('The word was ${logic.answer}');
      Timer(const Duration(milliseconds: 1200), () {
        if (mounted && _session.isFinished == false) {
          _session.finish(
            won: false,
            score: 100,
            stats: {
              'guesses': logic.guessCount,
              'perfect': 0,
            },
          );
        }
      });
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
        builder: (context, constraints) {
          final cell = (constraints.biggest.shortestSide * 0.92 / 5)
              .clamp(38.0, 62.0);
          final shakeOffset = _shake.isAnimating
              ? sin(_shake.value * pi * 5) * 7
              : 0.0;
          return Column(
            children: [
              SizedBox(height: 8),
              Expanded(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(shakeOffset, 0),
                    child: _grid(logic, cell),
                  ),
                ),
              ),
              SizedBox(
                height: 22,
                child: _message == null
                    ? null
                    : Text(
                        _message!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
              ),
              _keyboard(constraints.maxWidth),
              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }

  Widget _grid(WordleDailyLogic logic, double cell) {
    final activeRow = logic.guessCount;
    return Semantics(
      label: 'Daily word board, ${logic.maxGuesses} rows of five letters. '
          'Guess ${min(activeRow + 1, logic.maxGuesses)} of '
          '${logic.maxGuesses}.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < logic.maxGuesses; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < 5; c++)
                  _cell(logic, r, c, cell, isActiveRow: r == activeRow),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cell(WordleDailyLogic logic, int r, int c, double cell,
      {required bool isActiveRow}) {
    WordleMark? mark;
    String letter = '';
    if (r < logic.guessCount) {
      final guess = logic.guesses[r];
      letter = guess.word[c];
      mark = guess.marks[c];
    } else if (isActiveRow && c < _entry.length) {
      letter = _entry[c];
    }
    final theme = Theme.of(context);
    final disabled = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    Color bg;
    Color fg;
    Widget? marker;
    var decoration = TextDecoration.none;
    String stateLabel = 'empty';
    switch (mark) {
      case WordleMark.correct:
        bg = kPieceColors[2];
        fg = GamePalette.contrastOn(bg);
        marker = Icon(Icons.check, size: cell * 0.24, color: fg);
        stateLabel = 'correct spot';
      case WordleMark.present:
        bg = kPieceColors[1];
        fg = GamePalette.contrastOn(bg);
        marker = Icon(Icons.circle, size: cell * 0.2, color: fg);
        stateLabel = 'wrong spot';
      case WordleMark.absent:
        bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
        fg = disabled;
        decoration = TextDecoration.lineThrough;
        stateLabel = 'not in word';
      case null:
        bg = isActiveRow
            ? _session.palette.boardA
            : _session.palette.boardB.withValues(alpha: 0.6);
        fg = GamePalette.contrastOn(_session.palette.boardA);
    }
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Semantics(
        label: letter.isEmpty
            ? 'Empty letter slot'
            : 'Letter $letter, $stateLabel',
        child: Container(
          width: cell,
          height: cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: isActiveRow && letter.isNotEmpty
                ? Border.all(
                    color: _session.palette.accent,
                    width: 2,
                  )
                : null,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: Text(
                    letter,
                    key: ValueKey('$r-$c-$letter'),
                    style: TextStyle(
                      fontSize: cell * 0.48,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      color: fg,
                      decoration: decoration,
                    ),
                  ),
                ),
              ),
              if (marker != null)
                Positioned(top: 2, right: 3, child: marker),
            ],
          ),
        ),
      ),
    );
  }

  Widget _keyboard(double width) {
    var size = ((width - 12) / 10) - 5;
    var scrollable = false;
    if (size < 44) {
      size = 44;
      scrollable = true;
    }
    size = size.clamp(44.0, 58.0);
    Widget buildRow(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        );
    final rows = <Widget>[
      _wrapRow(
        scrollable,
        buildRow([for (final l in _rows[0].split('')) _key(l, size)]),
      ),
      _wrapRow(
        scrollable,
        buildRow([for (final l in _rows[1].split('')) _key(l, size)]),
      ),
      _wrapRow(
        scrollable,
        buildRow([
          _actionKey(
            label: 'ENTER',
            width: size * 1.45,
            height: size,
            icon: Icons.subdirectory_arrow_left,
            onTap: _submit,
          ),
          for (final l in _rows[2].split('')) _key(l, size),
          _actionKey(
            label: 'Backspace',
            width: size * 1.45,
            height: size,
            icon: Icons.backspace_outlined,
            onTap: _onBackspace,
          ),
        ]),
      ),
    ];
    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _wrapRow(bool scrollable, Widget row) => scrollable
      ? SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: row,
        )
      : row;

  Widget _key(String letter, double size) {
    final logic = _logic!;
    final theme = Theme.of(context);
    final disabled = theme.colorScheme.onSurface.withValues(alpha: 0.38);
    final state = logic.keyboardState[letter];
    final used = _interactive &&
        !logic.isOver &&
        logic.canSubmit &&
        !_isEntryFull;
    Color bg;
    Color fg;
    Widget? marker;
    var decoration = TextDecoration.none;
    String stateLabel = '';
    switch (state) {
      case WordleMark.correct:
        bg = kPieceColors[2];
        fg = GamePalette.contrastOn(bg);
        marker = Icon(Icons.check, size: size * 0.22, color: fg);
        stateLabel = ', right spot';
      case WordleMark.present:
        bg = kPieceColors[1];
        fg = GamePalette.contrastOn(bg);
        marker = Icon(Icons.circle, size: size * 0.17, color: fg);
        stateLabel = ', in word elsewhere';
      case WordleMark.absent:
        bg = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
        fg = disabled;
        decoration = TextDecoration.lineThrough;
        stateLabel = ', not in word';
      case null:
        bg = _session.palette.boardB;
        fg = GamePalette.contrastOn(_session.palette.boardB);
    }
    return Semantics(
      button: true,
      label: 'Letter $letter$stateLabel',
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: GestureDetector(
          onTap: used ? () => _onLetter(letter) : null,
          child: Container(
            width: size,
            height: size * 0.86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: fg,
                      decoration: decoration,
                    ),
                  ),
                ),
                if (marker != null)
                  Positioned(top: 1, right: 2, child: marker),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _isEntryFull => _entry.length >= 5;

  Widget _actionKey({
    required String label,
    required double width,
    required double height,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final enabled =
        _interactive && _logic != null && !_logic!.isOver;
    final fg = GamePalette.contrastOn(_session.palette.accent);
    return Semantics(
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.all(2.5),
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            width: width,
            height: height * 0.86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _session.palette.accent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: height * 0.32, color: fg),
                if (label == 'ENTER')
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      'GO',
                      style: TextStyle(
                        fontSize: height * 0.24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: fg,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
