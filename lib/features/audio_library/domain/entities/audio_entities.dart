import 'package:equatable/equatable.dart';

class ReciterEntity extends Equatable {
  final String id;
  final String name;
  final String? imageUrl;
  final String recitationStyle; // like "حجر", "تريل", "جود عالية"
  final bool isFollowing;
  final List<String> favoriteSurahs;

  const ReciterEntity({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.recitationStyle,
    required this.isFollowing,
    this.favoriteSurahs = const [],
  });

  ReciterEntity copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? recitationStyle,
    bool? isFollowing,
    List<String>? favoriteSurahs,
  }) {
    return ReciterEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      recitationStyle: recitationStyle ?? this.recitationStyle,
      isFollowing: isFollowing ?? this.isFollowing,
      favoriteSurahs: favoriteSurahs ?? this.favoriteSurahs,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    imageUrl,
    recitationStyle,
    isFollowing,
    favoriteSurahs,
  ];
}

class SurahAudioEntity extends Equatable {
  final String id;
  final int surahNumber;
  final String surahName;
  final String? reciterId;
  final String? reciterName;
  final String audioUrl;
  final Duration duration;
  final int pageCount; // Number of pages in mushaf
  final DateTime? lastListenedTo;

  const SurahAudioEntity({
    required this.id,
    required this.surahNumber,
    required this.surahName,
    this.reciterId,
    this.reciterName,
    required this.audioUrl,
    required this.duration,
    required this.pageCount,
    this.lastListenedTo,
  });

  SurahAudioEntity copyWith({
    String? id,
    int? surahNumber,
    String? surahName,
    String? reciterId,
    String? reciterName,
    String? audioUrl,
    Duration? duration,
    int? pageCount,
    DateTime? lastListenedTo,
  }) {
    return SurahAudioEntity(
      id: id ?? this.id,
      surahNumber: surahNumber ?? this.surahNumber,
      surahName: surahName ?? this.surahName,
      reciterId: reciterId ?? this.reciterId,
      reciterName: reciterName ?? this.reciterName,
      audioUrl: audioUrl ?? this.audioUrl,
      duration: duration ?? this.duration,
      pageCount: pageCount ?? this.pageCount,
      lastListenedTo: lastListenedTo ?? this.lastListenedTo,
    );
  }

  @override
  List<Object?> get props => [
    id,
    surahNumber,
    surahName,
    reciterId,
    reciterName,
    audioUrl,
    duration,
    pageCount,
    lastListenedTo,
  ];
}

class ListeningProgressEntity extends Equatable {
  final String id;
  final String userId;
  final String surahAudioId;
  final Duration position;
  final DateTime lastUpdated;
  final bool isCompleted;

  const ListeningProgressEntity({
    required this.id,
    required this.userId,
    required this.surahAudioId,
    required this.position,
    required this.lastUpdated,
    this.isCompleted = false,
  });

  ListeningProgressEntity copyWith({
    String? id,
    String? userId,
    String? surahAudioId,
    Duration? position,
    DateTime? lastUpdated,
    bool? isCompleted,
  }) {
    return ListeningProgressEntity(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      surahAudioId: surahAudioId ?? this.surahAudioId,
      position: position ?? this.position,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    surahAudioId,
    position,
    lastUpdated,
    isCompleted,
  ];
}
