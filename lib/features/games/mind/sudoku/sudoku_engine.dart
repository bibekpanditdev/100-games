/// Sudoku engine: seeded uniquely-solvable puzzles, candidate notes, a
/// mistake checker, three free hints per session (paid hints via the
/// session) and full save/resume through [GameSessionController].
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../game_player/game_contracts.dart';
import '../../../../core/services/audio_service.dart';
import 'sudoku_logic.dart';
import 'sudoku_widgets.dart';

/// Catalog engine for the `sudoku` template.
class SudokuEngine implements GameEngine {
  const SudokuEngine();

  @override
  String get templateId => 'sudoku';

  @override
  String get instructions =>
      'Fill the grid so every row, column and bold 3×3 box holds the digits '
      '1 to 9. Wrong entries are marked with a cross — erase or overwrite '
      'them. You get three free hints per session.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => SudokuGame(session: session);
}

/// The Sudoku gameplay screen for one session.
class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key, required this.session});

  final GameSessionController session;

  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  static const int freeHintsPerSession = 3;

  late SudokuLogic _logic;
  int? _selected;
  bool _notesMode = false;
  int _score = 0;
  int _mistakes = 0;
  int _seconds = 0;
  int _freeHints = freeHintsPerSession;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final restored = widget.session.restoredState;
    final restoredLogic = _restoreLogic(restored);
    if (restoredLogic != null) {
      _logic = restoredLogic;
      _seconds = _toInt(restored?['seconds'], 0);
      _mistakes = _toInt(restored?['mistakes'], 0);
      _score = _toInt(restored?['score'], 0);
      _freeHints = _toInt(restored?['freeHints'], freeHintsPerSession);
    } else {
      _logic = _freshLogic();
      _save();
    }
    widget.session.onHintGranted = _grantPaidHint;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _pushHud();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  SudokuLogic _freshLogic() {
    final clues = widget.session.config.getInt('clues', 40);
    final clamped = clues < 24
        ? 24
        : clues > 60
            ? 60
            : clues;
    return SudokuLogic(clues: clamped, random: Random());
  }

  SudokuLogic? _restoreLogic(Map<String, dynamic>? state) {
    if (state == null) return null;
    final cells = state['cells'];
    final solution = state['solution'];
    final given = state['given'];
    final notes = state['notes'];
    if (cells is! List || solution is! List || given is! List) return null;
    if (cells.length != 81 || solution.length != 81 || given.length != 81) {
      return null;
    }
    final solutionList = <int>[
      for (final v in solution) v is num ? v.toInt() : 0,
    ];
    if (!SudokuLogic.isValidSolution(solutionList)) return null;
    final cellList = <int>[
      for (final v in cells) v is num ? v.toInt() : 0,
    ];
    final givenList = <bool>[
      for (final g in given) g == true || g == 1 || g == 'true',
    ];
    final logic = SudokuLogic.fromPuzzle(
      puzzle: SudokuPuzzle(
        cells: cellList,
        solution: solutionList,
        given: givenList,
      ),
    );
    if (notes is List && notes.length == 81) {
      for (var i = 0; i < 81; i++) {
        final n = notes[i];
        if (n is List) {
          logic.notes[i] = <int>{
            for (final d in n)
              if (d is num && d.toInt() >= 1 && d.toInt() <= 9) d.toInt(),
          };
        }
      }
    }
    return logic;
  }

  static int _toInt(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;

  bool get _interactive =>
      !widget.session.isPaused && !widget.session.isFinished;

  void _tick() {
    if (!mounted || !_interactive) return;
    _seconds += 1;
    // Keep the persisted clock fresh without writing every single second.
    if (_seconds % 15 == 0) _save();
    _pushHud();
    setState(() {});
  }

  void _pushHud() {
    widget.session.updateHud(
      score: _score,
      status: 'Time $_seconds',
      detail: 'Mistakes $_mistakes',
      progress: (81 - _logic.emptyCount) / 81,
    );
  }

  void _onCellTap(int index) {
    if (!_interactive) return;
    setState(() => _selected = _selected == index ? null : index);
  }

  void _inputDigit(int digit) {
    final sel = _selected;
    if (sel == null || !_interactive || _logic.isGiven(sel)) return;
    if (_notesMode) {
      if (_logic.valueAt(sel) != 0) return;
      _logic.toggleNote(sel, digit);
    } else {
      if (_logic.valueAt(sel) == digit) return;
      final correct = _logic.place(sel, digit);
      if (correct) {
        _score += 50;
        AudioService.I.sfx(SfxKeys.place);
      } else {
        _mistakes += 1;
        _score = max(0, _score - 20);
        AudioService.I.sfx(SfxKeys.wrong);
      }
    }
    _save();
    _pushHud();
    setState(() {});
    _checkSolved();
  }

  void _erase() {
    final sel = _selected;
    if (sel == null || !_interactive || _logic.isGiven(sel)) return;
    _logic.erase(sel);
    _save();
    _pushHud();
    setState(() {});
  }

  void _toggleNotes() {
    if (!_interactive) return;
    setState(() => _notesMode = !_notesMode);
  }

  Future<void> _onHintPressed() async {
    if (!_interactive) return;
    if (_freeHints > 0) {
      _applyHint(consumeFree: true);
      return;
    }
    // Further hints go through the shell (coins / rewarded ad). A false
    // return simply means the request was declined.
    await widget.session.requestHint();
  }

  /// Shell-invoked hint (payment already granted).
  void _grantPaidHint() => _applyHint(consumeFree: false);

  void _applyHint({required bool consumeFree}) {
    if (!_interactive) return;
    final index = _logic.applyHint();
    if (index == null) return;
    if (consumeFree) _freeHints -= 1;
    _selected = index;
    AudioService.I.sfx(SfxKeys.hint);
    _save();
    _pushHud();
    setState(() {});
    _checkSolved();
  }

  void _checkSolved() {
    if (!_logic.isSolved || widget.session.isFinished) return;
    _timer?.cancel();
    AudioService.I.sfx(SfxKeys.solved);
    widget.session.finish(
      won: true,
      score: _score,
      stats: {'mistakes': _mistakes, 'seconds': _seconds},
    );
  }

  void _save() {
    widget.session.saveState(<String, dynamic>{
      'cells': List<int>.of(_logic.cells),
      'given': List<bool>.of(_logic.given),
      'notes': <List<int>>[
        for (final n in _logic.notes) List<int>.of(n),
      ],
      'seconds': _seconds,
      'mistakes': _mistakes,
      'solution': List<int>.of(_logic.solution),
      'score': _score,
      'freeHints': _freeHints,
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.session.palette;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Semantics(
                    label: 'Sudoku board, 9 by 9',
                    child: SudokuBoard(
                      logic: _logic,
                      selected: _selected,
                      onCellTap: _onCellTap,
                      palette: palette,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SudokuControls(
            notesMode: _notesMode,
            freeHints: _freeHints,
            onDigit: _inputDigit,
            onErase: _erase,
            onToggleNotes: _toggleNotes,
            onHint: _onHintPressed,
            palette: palette,
            enabled: _interactive,
          ),
        ],
      ),
    );
  }
}
