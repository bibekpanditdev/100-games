/// Game-engine binding for the trivia template.
library;

import 'package:flutter/material.dart';

import '../../game_player/game_contracts.dart';
import 'trivia_screen.dart';

/// Multiple-choice quiz engine driven by the offline bank in
/// `assets/trivia/questions.json`.
///
/// Config keys (read defensively, with fallbacks):
///  * `qset` — `general`, `science`, `movies`, `sports`, `history`,
///    `geography`, `technology` or `mixed` (default `mixed`).
///  * `count` — 10 (default) or 20 questions per session.
///  * `timePerQ` — seconds per question; 0 = untimed, otherwise 12 or 20.
class TriviaEngine implements GameEngine {
  const TriviaEngine();

  @override
  String get templateId => 'trivia';

  @override
  String get instructions =>
      'Answer multiple-choice questions before the timer runs out. Each correct '
      'answer scores 100 points plus a time bonus — get 60% or more right to '
      'win the round.';

  @override
  bool get supportsHint => true;

  @override
  bool get supportsContinue => false;

  @override
  Widget build(GameSessionController session) => TriviaQuizScreen(session: session);
}
