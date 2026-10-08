import 'package:equatable/equatable.dart';

import '../../domain/mushaf_reciter.dart';

enum MushafAudioStatus { idle, loading, playing, paused, error }

class MushafAudioState extends Equatable {
  final MushafAudioStatus status;
  final String? errorMessage;
  final MushafReciter reciter;
  final int? surahNumber;
  final int? ayahNumberInSurah;

  /// Repeat the same ayah on completion. Never advances to the next ayah.
  final bool isLooping;

  const MushafAudioState({
    this.status = MushafAudioStatus.idle,
    this.errorMessage,
    this.reciter = kDefaultMushafReciter,
    this.surahNumber,
    this.ayahNumberInSurah,
    this.isLooping = false,
  });

  bool get isPlaying => status == MushafAudioStatus.playing;
  bool get isLoading => status == MushafAudioStatus.loading;
  bool get isPaused => status == MushafAudioStatus.paused;
  bool get hasError => status == MushafAudioStatus.error;

  /// Loading, playing or paused — a track is (or is about to be) engaged.
  bool get isActive => isLoading || isPlaying || isPaused;

  bool get hasTarget => surahNumber != null && ayahNumberInSurah != null;

  bool isTarget(int surah, int ayah) =>
      surahNumber == surah && ayahNumberInSurah == ayah;

  MushafAudioState copyWith({
    MushafAudioStatus? status,
    String? errorMessage,
    bool clearError = false,
    MushafReciter? reciter,
    int? surahNumber,
    int? ayahNumberInSurah,
    bool clearTarget = false,
    bool? isLooping,
  }) {
    return MushafAudioState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      reciter: reciter ?? this.reciter,
      surahNumber: clearTarget ? null : (surahNumber ?? this.surahNumber),
      ayahNumberInSurah: clearTarget
          ? null
          : (ayahNumberInSurah ?? this.ayahNumberInSurah),
      isLooping: isLooping ?? this.isLooping,
    );
  }

  @override
  List<Object?> get props => [
    status,
    errorMessage,
    reciter.id,
    surahNumber,
    ayahNumberInSurah,
    isLooping,
  ];
}
