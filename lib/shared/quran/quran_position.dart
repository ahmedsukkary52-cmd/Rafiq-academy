/// Learning-journey position engine (plan §5.4 and §5.6-3, Phase 1A).
///
/// Maps the end of a new-memorization range to the journey position
/// `{juz, level, progressBp}` against a [QuranIndex] that is always passed in.
/// This file embeds no Quran data: the real index is generated only in
/// Phase 1B, and Phase 1A is tested on synthetic, non-Quranic fixtures
/// (`test/fixtures/quran_journey_synthetic_v1.json`).
///
/// The server mirror is `functions/src/quran/quranPosition.ts`. Both sides
/// must return literally equal results for every position, which is why all
/// arithmetic is on integers (no `double`, no rounding helpers).
library;

import 'package:equatable/equatable.dart';

/// Basis points of a whole juz: the last verse of a juz is exactly this.
const int kProgressBpWhole = 10000;

/// Largest integer that Dart (VM and web) and JavaScript all hold exactly.
const int kMaxSafeInteger = 9007199254740991;

/// Upper bound for the total word count of an index, so that
/// `kProgressBpWhole * words` never leaves the exact integer range on either
/// side.
const int kMaxIndexWords = kMaxSafeInteger ~/ kProgressBpWhole;

/// One verse, addressed by 1-based surah and ayah numbers (`{s, a}` in the
/// stored `Range` shape, plan §4).
class QuranVerseRef extends Equatable {
  const QuranVerseRef(this.surah, this.ayah);

  final int surah;
  final int ayah;

  @override
  List<Object?> get props => [surah, ayah];

  @override
  String toString() => '$surah:$ayah';
}

/// An inclusive verse range; valid only when `from` does not come after `to`.
class QuranRange extends Equatable {
  const QuranRange(this.from, this.to);

  final QuranVerseRef from;
  final QuranVerseRef to;

  @override
  List<Object?> get props => [from, to];

  @override
  String toString() => '$from-$to';
}

/// The derived journey position stored in the journey head (plan §4).
class JourneyPosition extends Equatable {
  const JourneyPosition({
    required this.juz,
    required this.level,
    required this.progressBp,
  });

  /// 1-based juz that contains the end of the range.
  final int juz;

  /// `juzCount + 1 - juz` (decision #1: levels run in reverse juz order).
  final int level;

  /// Progress inside [juz] in basis points, `1..kProgressBpWhole`.
  final int progressBp;

  @override
  List<Object?> get props => [juz, level, progressBp];

  @override
  String toString() => 'juz $juz, level $level, $progressBp bp';
}

/// Why index data was rejected by [QuranIndex.fromParts].
enum QuranIndexIssue {
  emptyCatalog,
  invalidAyahCount,
  wordCountLengthMismatch,
  invalidWordCount,
  totalWordsTooLarge,
  emptyJuzStarts,
  juzStartOutOfCatalog,
  firstJuzNotAtStart,
  juzStartsNotIncreasing,
}

/// Malformed index data. This is a data or generator defect, never a user
/// input error.
class QuranIndexFormatException implements Exception {
  const QuranIndexFormatException(this.issue, this.message);

  final QuranIndexIssue issue;
  final String message;

  @override
  String toString() => 'QuranIndexFormatException(${issue.name}): $message';
}

/// Why a verse or range is not valid against an index. Callers map any of
/// these to `invalid-argument` (plan §5.4-4).
enum QuranReferenceIssue { surahOutOfRange, ayahOutOfRange, reversedRange }

/// Thrown by [globalIndex] and [computeJourneyPosition] for an invalid
/// reference. Use [quranVerseIssue] or [quranRangeIssue] to check first
/// without throwing.
class InvalidQuranReferenceException implements Exception {
  const InvalidQuranReferenceException(this.issue, this.reference);

  final QuranReferenceIssue issue;

  /// The offending verse or range.
  final Object reference;

  @override
  String toString() =>
      'InvalidQuranReferenceException(${issue.name}): $reference';
}

/// Validated, immutable index the engine computes against: ayah counts per
/// surah, the first verse of every juz, and the word count of every verse.
///
/// Juz starts are given as verse references; their global indexes are
/// derived here, so callers never handle the internal coordinate.
class QuranIndex {
  QuranIndex._({
    required List<int> ayahCounts,
    required List<int> surahStart,
    required List<int> juzStartGlobal,
    required List<int> cumulativeWords,
  }) : _ayahCounts = ayahCounts,
       _surahStart = surahStart,
       _juzStartGlobal = juzStartGlobal,
       _cumulativeWords = cumulativeWords;

  /// Validates the parts and precomputes the prefix sums.
  ///
  /// Throws [QuranIndexFormatException] when any part is malformed.
  factory QuranIndex.fromParts({
    required List<int> ayahCounts,
    required List<QuranVerseRef> juzStarts,
    required List<int> wordCounts,
  }) {
    if (ayahCounts.isEmpty) {
      throw const QuranIndexFormatException(
        QuranIndexIssue.emptyCatalog,
        'ayahCounts is empty',
      );
    }
    // surahStart[i] = number of verses before surah i + 1.
    final surahStart = List<int>.filled(ayahCounts.length, 0);
    var verseCount = 0;
    for (var i = 0; i < ayahCounts.length; i++) {
      final count = ayahCounts[i];
      // Every verse has at least one word, so a count above kMaxIndexWords
      // can never be valid; rejecting it early also keeps the sum exact.
      if (count < 1 || count > kMaxIndexWords) {
        throw QuranIndexFormatException(
          QuranIndexIssue.invalidAyahCount,
          'surah ${i + 1} has $count verses',
        );
      }
      surahStart[i] = verseCount;
      verseCount += count;
    }
    if (wordCounts.length != verseCount) {
      throw QuranIndexFormatException(
        QuranIndexIssue.wordCountLengthMismatch,
        '${wordCounts.length} word counts for $verseCount verses',
      );
    }
    // cumulativeWords[g] = words in verses 1..g; cumulativeWords[0] = 0.
    final cumulativeWords = List<int>.filled(verseCount + 1, 0);
    for (var g = 1; g <= verseCount; g++) {
      final words = wordCounts[g - 1];
      if (words < 1) {
        throw QuranIndexFormatException(
          QuranIndexIssue.invalidWordCount,
          'verse $g has $words words',
        );
      }
      final before = cumulativeWords[g - 1];
      if (words > kMaxIndexWords - before) {
        throw const QuranIndexFormatException(
          QuranIndexIssue.totalWordsTooLarge,
          'total words exceed $kMaxIndexWords',
        );
      }
      cumulativeWords[g] = before + words;
    }
    if (juzStarts.isEmpty) {
      throw const QuranIndexFormatException(
        QuranIndexIssue.emptyJuzStarts,
        'juzStarts is empty',
      );
    }
    final juzStartGlobal = <int>[];
    for (final start in juzStarts) {
      if (_verseIssue(ayahCounts, start) != null) {
        throw QuranIndexFormatException(
          QuranIndexIssue.juzStartOutOfCatalog,
          'juz start $start is not in the catalog',
        );
      }
      final g = surahStart[start.surah - 1] + start.ayah;
      if (juzStartGlobal.isEmpty && g != 1) {
        throw QuranIndexFormatException(
          QuranIndexIssue.firstJuzNotAtStart,
          'first juz starts at $start, not at the first verse',
        );
      }
      if (juzStartGlobal.isNotEmpty && g <= juzStartGlobal.last) {
        throw QuranIndexFormatException(
          QuranIndexIssue.juzStartsNotIncreasing,
          'juz start $start does not follow the previous one',
        );
      }
      juzStartGlobal.add(g);
    }
    return QuranIndex._(
      ayahCounts: List.unmodifiable(ayahCounts),
      surahStart: List.unmodifiable(surahStart),
      juzStartGlobal: List.unmodifiable(juzStartGlobal),
      cumulativeWords: List.unmodifiable(cumulativeWords),
    );
  }

  final List<int> _ayahCounts;
  final List<int> _surahStart;
  final List<int> _juzStartGlobal;
  final List<int> _cumulativeWords;

  int get surahCount => _ayahCounts.length;
  int get verseCount => _cumulativeWords.length - 1;
  int get juzCount => _juzStartGlobal.length;

  /// Number of verses in [surah]; throws [RangeError] outside `1..surahCount`.
  int ayahCount(int surah) {
    RangeError.checkValueInInterval(surah, 1, surahCount, 'surah');
    return _ayahCounts[surah - 1];
  }

  /// Global index of the first verse of each juz, ascending, starting at 1.
  List<int> get juzStartGlobal => _juzStartGlobal;
}

QuranReferenceIssue? _verseIssue(List<int> ayahCounts, QuranVerseRef ref) {
  if (ref.surah < 1 || ref.surah > ayahCounts.length) {
    return QuranReferenceIssue.surahOutOfRange;
  }
  if (ref.ayah < 1 || ref.ayah > ayahCounts[ref.surah - 1]) {
    return QuranReferenceIssue.ayahOutOfRange;
  }
  return null;
}

/// Why [ref] is not a verse of [index], or null when it is.
QuranReferenceIssue? quranVerseIssue(QuranIndex index, QuranVerseRef ref) =>
    _verseIssue(index._ayahCounts, ref);

/// Why [range] is not valid against [index], or null when it is.
///
/// Checks `from`, then `to`, then their order (`from` after `to` is
/// [QuranReferenceIssue.reversedRange]).
QuranReferenceIssue? quranRangeIssue(QuranIndex index, QuranRange range) {
  final issue =
      quranVerseIssue(index, range.from) ?? quranVerseIssue(index, range.to);
  if (issue != null) return issue;
  if (globalIndex(index, range.from) > globalIndex(index, range.to)) {
    return QuranReferenceIssue.reversedRange;
  }
  return null;
}

/// 1-based position of [ref] in reading order across the whole index
/// (`g = surahStart[s] + a`, plan §5.4-1).
///
/// Throws [InvalidQuranReferenceException] when [ref] is not in the index.
int globalIndex(QuranIndex index, QuranVerseRef ref) {
  final issue = quranVerseIssue(index, ref);
  if (issue != null) throw InvalidQuranReferenceException(issue, ref);
  return index._surahStart[ref.surah - 1] + ref.ayah;
}

/// Number of elements of the ascending list [sorted] that are `<= value`
/// (a count, not an element index; plan §5.4-2).
int upperBound(List<int> sorted, int value) {
  var low = 0;
  var high = sorted.length;
  while (low < high) {
    final mid = low + ((high - low) >> 1);
    if (sorted[mid] <= value) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  return low;
}

/// 1-based juz of the verse at global index [g]: `upperBound(juzStartG, g)`.
/// A verse on a juz start belongs to that juz.
///
/// Throws [RangeError] when [g] is outside `1..verseCount`.
int juzOf(QuranIndex index, int g) {
  RangeError.checkValueInInterval(g, 1, index.verseCount, 'g');
  return upperBound(index._juzStartGlobal, g);
}

/// Level of [juz]: `juzCount + 1 - juz` (decision #1: reverse part order).
///
/// Throws [RangeError] when [juz] is outside `1..juzCount`.
int levelForJuz(QuranIndex index, int juz) {
  RangeError.checkValueInInterval(juz, 1, index.juzCount, 'juz');
  return index.juzCount + 1 - juz;
}

/// Journey position for a new-memorization [range] (plan §5.6-3).
///
/// The juz, level and progress come from the end of the range only, so a
/// range that spans two parts lands in the later one (D6). The last verse of
/// a juz is exactly [kProgressBpWhole]; the position never moves on to the
/// next juz by itself.
///
/// Throws [InvalidQuranReferenceException] when [range] is invalid.
JourneyPosition computeJourneyPosition(QuranIndex index, QuranRange range) {
  final issue = quranRangeIssue(index, range);
  if (issue != null) throw InvalidQuranReferenceException(issue, range);

  final g = globalIndex(index, range.to);
  final juz = juzOf(index, g);
  final starts = index._juzStartGlobal;
  final firstVerse = starts[juz - 1];
  final nextJuzFirstVerse = juz < starts.length
      ? starts[juz]
      : index.verseCount + 1;
  final cw = index._cumulativeWords;
  final wordsBeforeJuz = cw[firstVerse - 1];
  final done = cw[g] - wordsBeforeJuz;
  final total = cw[nextJuzFirstVerse - 1] - wordsBeforeJuz;
  return JourneyPosition(
    juz: juz,
    level: levelForJuz(index, juz),
    progressBp: (kProgressBpWhole * done) ~/ total,
  );
}
