import 'package:equatable/equatable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../domain/entities/audio_entities.dart';
import '../../domain/featured_reciters.dart';

class _Unset {
  const _Unset();
}

const _unset = _Unset();

class AudioLibraryState extends Equatable {
  final SectionStatus recitersStatus;
  final List<ReciterEntity> allReciters;
  final List<ReciterEntity> favoriteReciters;
  final String? recitersError;

  final SectionStatus surahAudiosStatus;
  final List<SurahAudioEntity> surahAudios;
  final String? surahAudiosError;

  final SectionStatus continueListeningStatus;
  final SurahAudioEntity? continueListening;
  final String? continueListeningError;

  final SurahAudioEntity? selectedSurah;

  // Playback state
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final bool isLoading;
  final String? playbackError;

  // Search state
  final String searchQuery;

  // Reciter selection state
  final String? selectedReciterId;
  final List<String> recentReciterIds;

  const AudioLibraryState({
    this.recitersStatus = SectionStatus.initial,
    this.allReciters = const [],
    this.favoriteReciters = const [],
    this.recitersError,
    this.surahAudiosStatus = SectionStatus.initial,
    this.surahAudios = const [],
    this.surahAudiosError,
    this.continueListeningStatus = SectionStatus.initial,
    this.continueListening,
    this.continueListeningError,
    this.selectedSurah,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.isLoading = false,
    this.playbackError,
    this.searchQuery = '',
    this.selectedReciterId,
    this.recentReciterIds = const [],
  });

  factory AudioLibraryState.initial() => const AudioLibraryState();

  // Getters for filtered results
  List<ReciterEntity> get filteredReciters {
    if (searchQuery.isEmpty) {
      final result = favoriteReciters.isEmpty ? allReciters : favoriteReciters;
      print(
        '[AudioLibraryState] No search query, returning ${result.length} reciters (${favoriteReciters.isEmpty ? "all" : "favorites"})',
      );
      return result;
    }
    final query = searchQuery.toLowerCase();
    final result = allReciters
        .where(
          (reciter) =>
              reciter.name.toLowerCase().contains(query) ||
              reciter.recitationStyle.toLowerCase().contains(query),
        )
        .toList();
    print(
      '[AudioLibraryState] Searching for "$query", found ${result.length} reciters',
    );
    return result;
  }

  List<SurahAudioEntity> get filteredSurahAudios {
    var filtered = surahAudios;

    if (selectedReciterId != null) {
      filtered = filtered
          .where((s) => s.reciterId == selectedReciterId)
          .toList();
    }

    final query = searchQuery.trim();
    if (query.isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      final digitQuery = _normalizeDigits(query);

      filtered = filtered.where((surah) {
        final matchesName = surah.surahName.toLowerCase().contains(lowerQuery);
        final matchesReciter =
            surah.reciterName?.toLowerCase().contains(lowerQuery) ?? false;
        final matchesNumber =
            surah.surahNumber.toString() == query ||
            surah.surahNumber.toString().contains(query) ||
            _normalizeDigits(surah.surahNumber.toString()) == digitQuery ||
            _normalizeDigits(surah.surahNumber.toString()).contains(digitQuery);
        return matchesName || matchesReciter || matchesNumber;
      }).toList();
    }

    return filtered;
  }

  ReciterEntity? get selectedReciter {
    if (selectedReciterId == null) return null;
    for (final reciter in allReciters) {
      if (reciter.id == selectedReciterId) return reciter;
    }
    return null;
  }

  /// Main-page order:
  /// user-added/followed reciters, recently listened reciters, then featured.
  List<ReciterEntity> get homeReciters {
    final byId = {for (final reciter in allReciters) reciter.id: reciter};
    final orderedIds = <String>[
      ...favoriteReciters.map((reciter) => reciter.id),
      ...recentReciterIds,
      ...featuredReciterIds,
    ];

    final seen = <String>{};
    return [
      for (final id in orderedIds)
        if (seen.add(id) && byId[id] != null) byId[id]!,
    ];
  }

  AudioLibraryState copyWith({
    SectionStatus? recitersStatus,
    List<ReciterEntity>? allReciters,
    List<ReciterEntity>? favoriteReciters,
    Object? recitersError = _unset,
    SectionStatus? surahAudiosStatus,
    List<SurahAudioEntity>? surahAudios,
    Object? surahAudiosError = _unset,
    SectionStatus? continueListeningStatus,
    Object? continueListening = _unset,
    Object? continueListeningError = _unset,
    Object? selectedSurah = _unset,
    bool? isPlaying,
    Duration? position,
    Object? duration = _unset,
    bool? isLoading,
    Object? playbackError = _unset,
    String? searchQuery,
    Object? selectedReciterId = _unset,
    List<String>? recentReciterIds,
  }) {
    return AudioLibraryState(
      recitersStatus: recitersStatus ?? this.recitersStatus,
      allReciters: allReciters ?? this.allReciters,
      favoriteReciters: favoriteReciters ?? this.favoriteReciters,
      recitersError: identical(recitersError, _unset)
          ? this.recitersError
          : recitersError as String?,
      surahAudiosStatus: surahAudiosStatus ?? this.surahAudiosStatus,
      surahAudios: surahAudios ?? this.surahAudios,
      surahAudiosError: identical(surahAudiosError, _unset)
          ? this.surahAudiosError
          : surahAudiosError as String?,
      continueListeningStatus:
          continueListeningStatus ?? this.continueListeningStatus,
      continueListening: identical(continueListening, _unset)
          ? this.continueListening
          : continueListening as SurahAudioEntity?,
      continueListeningError: identical(continueListeningError, _unset)
          ? this.continueListeningError
          : continueListeningError as String?,
      selectedSurah: identical(selectedSurah, _unset)
          ? this.selectedSurah
          : selectedSurah as SurahAudioEntity?,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: identical(duration, _unset)
          ? this.duration
          : duration as Duration?,
      isLoading: isLoading ?? this.isLoading,
      playbackError: identical(playbackError, _unset)
          ? this.playbackError
          : playbackError as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedReciterId: identical(selectedReciterId, _unset)
          ? this.selectedReciterId
          : selectedReciterId as String?,
      recentReciterIds: recentReciterIds ?? this.recentReciterIds,
    );
  }

  @override
  List<Object?> get props => [
    recitersStatus,
    allReciters,
    favoriteReciters,
    recitersError,
    surahAudiosStatus,
    surahAudios,
    surahAudiosError,
    continueListeningStatus,
    continueListening,
    continueListeningError,
    selectedSurah,
    isPlaying,
    position,
    duration,
    isLoading,
    playbackError,
    searchQuery,
    selectedReciterId,
    recentReciterIds,
  ];
}

String _normalizeDigits(String input) {
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = input;
  for (var i = 0; i < arabic.length; i++) {
    result = result.replaceAll(arabic[i], i.toString());
  }
  return result;
}
