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

  /// Playback rate restored from the legacy mushaf reader.
  final double playbackSpeed;

  final bool isMuted;

  const MushafAudioState({
    this.status = MushafAudioStatus.idle,
    this.errorMessage,
    this.reciter = kDefaultMushafReciter,
    this.surahNumber,
    this.ayahNumberInSurah,
    this.isLooping = false,
    this.playbackSpeed = 1.0,
    this.isMuted = false,
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
    double? playbackSpeed,
    bool? isMuted,
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
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      isMuted: isMuted ?? this.isMuted,
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
    playbackSpeed,
    isMuted,
  ];
}
