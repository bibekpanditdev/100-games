/// Small formatting + hashing helpers shared across features.
library;

/// FNV-1a 32-bit hash — stable across runs and isolates (unlike
/// `String.hashCode`), so "Popular" ordering and the daily challenge pick
/// don't reshuffle between launches.
int stableHash(String input) {
  var hash = 0x811c9dc5;
  for (final c in input.codeUnits) {
    hash ^= c;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}

/// `47` -> `47`, `1200` -> `1.2k`, `3500000` -> `3.5M`.
String compactNumber(int n) {
  if (n.abs() < 1000) return '$n';
  if (n.abs() < 1000000) {
    final k = n / 1000;
    return '${k >= 100 ? k.round().toString() : k.toStringAsFixed(1)}k';
  }
  final m = n / 1000000;
  return '${m >= 100 ? m.round().toString() : m.toStringAsFixed(1)}M';
}

/// `95` -> `1:35`.
String formatClock(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Local calendar day key, e.g. `2026-08-17`. Streak math must use local
/// days, not epoch millis, so "yesterday" is stable per device timezone.
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

DateTime dayKeyToDateTime(String key) => DateTime.parse(key);

String previousDayKey(String key) =>
    dayKey(dayKeyToDateTime(key).subtract(const Duration(days: 1)));
