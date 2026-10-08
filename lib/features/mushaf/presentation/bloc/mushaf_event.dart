import 'package:equatable/equatable.dart';

import '../../domain/entities/mushaf_ayah.dart';
import '../../domain/entities/mushaf_position.dart';
import '../../domain/entities/quran_text_bundle.dart';

abstract class MushafEvent extends Equatable {
  const MushafEvent();

  @override
  List<Object?> get props => [];
}

/// Load Quran text + resolve D23 open position for [studentId].
class InitializeMushafEvent extends MushafEvent {
  final String studentId;

  /// Optional deep-link surah (ignored when ≤ 0). Does not override last-read
  /// unless [forceSurahJump] is true.
  final int? preferredSurah;

  final bool forceSurahJump;

  const InitializeMushafEvent({
    required this.studentId,
    this.preferredSurah,
    this.forceSurahJump = false,
  });

  @override
  List<Object?> get props => [studentId, preferredSurah, forceSurahJump];
}

class MushafGoToPageEvent extends MushafEvent {
  final int pageNumber;

  /// True for explicit jumps (page field); false for swipes.
  final bool fromNavigation;

  const MushafGoToPageEvent(this.pageNumber, {this.fromNavigation = false});

  @override
  List<Object?> get props => [pageNumber, fromNavigation];
}

class MushafGoToSurahEvent extends MushafEvent {
  final int surahNumber;

  const MushafGoToSurahEvent(this.surahNumber);

  @override
  List<Object?> get props => [surahNumber];
}

class MushafGoToJuzEvent extends MushafEvent {
  final int juzNumber;

  const MushafGoToJuzEvent(this.juzNumber);

  @override
  List<Object?> get props => [juzNumber];
}

/// Return to [MushafState.resumePosition].
class MushafResumeLastReadEvent extends MushafEvent {
  const MushafResumeLastReadEvent();
}

class MushafSelectAyahEvent extends MushafEvent {
  final MushafAyah ayah;

  const MushafSelectAyahEvent(this.ayah);

  @override
  List<Object?> get props => [ayah];
}

class MushafClearSelectionEvent extends MushafEvent {
  const MushafClearSelectionEvent();
}

class MushafRetryEvent extends MushafEvent {
  const MushafRetryEvent();
}

class MushafToggleChromeEvent extends MushafEvent {
  const MushafToggleChromeEvent();
}

class MushafSetNightModeEvent extends MushafEvent {
  final bool isNight;

  const MushafSetNightModeEvent(this.isNight);

  @override
  List<Object?> get props => [isNight];
}

/// Internal flush after debounce — not for UI. [studentId] is captured when
/// the write is scheduled so a later student switch cannot redirect it.
class MushafPersistPositionEvent extends MushafEvent {
  final String studentId;
  final MushafPosition position;

  const MushafPersistPositionEvent({
    required this.studentId,
    required this.position,
  });

  @override
  List<Object?> get props => [studentId, position];
}

// Re-export bundle type for listeners if needed
typedef MushafQuranBundle = QuranTextBundle;
