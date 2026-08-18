/// Domain model for a single game in the catalog.
library;

/// The six top-level game categories.
enum GameCategory {
  arcade,
  puzzle,
  cards,
  board,
  trivia,
  mind;

  static GameCategory fromString(String value) => GameCategory.values
      .firstWhere((c) => c.name == value.toLowerCase(), orElse: () => arcade);

  String get label => switch (this) {
        arcade => 'Arcade',
        puzzle => 'Puzzle',
        cards => 'Cards',
        board => 'Board',
        trivia => 'Trivia',
        mind => 'Mind',
      };

  String get description => switch (this) {
        arcade => 'Fast reflex and action games',
        puzzle => 'Brain teasers and logic',
        cards => 'Card and memory games',
        board => 'Classic board games vs. the CPU',
        trivia => 'Offline quiz challenges',
        mind => 'Puzzle & mind games — logic, word, memory, math, spatial',
      };
}

enum Difficulty {
  easy,
  medium,
  hard;

  static Difficulty fromString(String value) => Difficulty.values
      .firstWhere((d) => d.name == value.toLowerCase(), orElse: () => easy);

  String get label => switch (this) {
        easy => 'Easy',
        medium => 'Medium',
        hard => 'Hard',
      };
}

class GameDefinition {
  const GameDefinition({
    required this.id,
    required this.title,
    required this.category,
    required this.template,
    required this.difficulty,
    required this.themeId,
    this.level = 1,
    this.config = const GameConfig({}),
    this.thumbnail,
    this.unlocked = true,
    this.popularity = 0,
    this.isNew = false,
  });

  final String id;
  final String title;
  final GameCategory category;
  final String template;
  final Difficulty difficulty;
  final String themeId;

  /// Game level (1..12).
  final int level;

  /// Template-specific knobs (grid size, speed, target score, ...).
  final GameConfig config;

  final String? thumbnail;
  final bool unlocked;
  final int popularity;
  final bool isNew;

  factory GameDefinition.fromJson(Map<String, dynamic> json) {
    return GameDefinition(
      id: json['id'] as String,
      title: json['title'] as String,
      category: GameCategory.fromString(json['category'] as String? ?? ''),
      template: json['template'] as String,
      difficulty: Difficulty.fromString(json['difficulty'] as String? ?? ''),
      themeId: json['theme'] as String? ?? json['themeId'] as String? ?? 'ocean',
      level: json['level'] as int? ?? 1,
      config: GameConfig((json['config'] as Map<String, dynamic>?) ?? const {}),
      thumbnail: json['thumbnail'] as String?,
      unlocked: json['unlocked'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'template': template,
        'difficulty': difficulty.name,
        'theme': themeId,
        'level': level,
        'thumbnail': thumbnail,
        'unlocked': unlocked,
        'config': config.raw,
      };
}

class GameConfig {
  const GameConfig(this.raw);

  final Map<String, dynamic> raw;

  dynamic operator [](String key) => raw[key];

  bool containsKey(String key) => raw.containsKey(key);

  int getInt(String key, int fallback) {
    final v = raw[key];
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  double getDouble(String key, double fallback) {
    final v = raw[key];
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  bool getBool(String key, bool fallback) {
    final v = raw[key];
    if (v is bool) return v;
    if (v is String) return v == 'true' || v == '1';
    return fallback;
  }

  String getString(String key, String fallback) {
    final v = raw[key];
    if (v is String && v.isNotEmpty) return v;
    return fallback;
  }
}
