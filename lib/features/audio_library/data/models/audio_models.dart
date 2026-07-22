import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/audio_entities.dart';

class ReciterModel extends ReciterEntity {
  const ReciterModel({
    required super.id,
    required super.name,
    super.imageUrl,
    required super.recitationStyle,
    required super.isFollowing,
    super.favoriteSurahs = const [],
  });

  factory ReciterModel.fromFirestore(
    DocumentSnapshot doc, {
    List<String> followedReciterIds = const [],
  }) {
    final data = doc.data() as Map<String, dynamic>?;
    return ReciterModel(
      id: doc.id,
      name: data?['name'] as String? ?? '',
      imageUrl: data?['imageUrl'] as String?,
      recitationStyle: data?['recitationStyle'] as String? ?? '',
      isFollowing: followedReciterIds.contains(doc.id),
      favoriteSurahs:
          (data?['favoriteSurahs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'recitationStyle': recitationStyle,
      'favoriteSurahs': favoriteSurahs,
    };
  }

  factory ReciterModel.fromEntity(ReciterEntity entity) {
    return ReciterModel(
      id: entity.id,
      name: entity.name,
      imageUrl: entity.imageUrl,
      recitationStyle: entity.recitationStyle,
      isFollowing: entity.isFollowing,
      favoriteSurahs: entity.favoriteSurahs,
    );
  }
}

class SurahAudioModel extends SurahAudioEntity {
  const SurahAudioModel({
    required super.id,
    required super.surahNumber,
    required super.surahName,
    super.reciterId,
    super.reciterName,
    required super.audioUrl,
    required super.duration,
    required super.pageCount,
    super.lastListenedTo,
  });

  factory SurahAudioModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final durationMs = data['durationMs'] as int? ?? 0;
    return SurahAudioModel(
      id: doc.id,
      surahNumber: data['surahNumber'] as int? ?? 0,
      surahName: data['surahName'] as String? ?? '',
      reciterId: data['reciterId'] as String?,
      reciterName: data['reciterName'] as String?,
      audioUrl: data['audioUrl'] as String? ?? '',
      duration: Duration(milliseconds: durationMs),
      pageCount: data['pageCount'] as int? ?? 0,
      lastListenedTo: (data['lastListenedTo'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'surahNumber': surahNumber,
      'surahName': surahName,
      if (reciterId != null) 'reciterId': reciterId,
      if (reciterName != null) 'reciterName': reciterName,
      'audioUrl': audioUrl,
      'durationMs': duration.inMilliseconds,
      'pageCount': pageCount,
      if (lastListenedTo != null)
        'lastListenedTo': Timestamp.fromDate(lastListenedTo!),
    };
  }

  factory SurahAudioModel.fromEntity(SurahAudioEntity entity) {
    return SurahAudioModel(
      id: entity.id,
      surahNumber: entity.surahNumber,
      surahName: entity.surahName,
      reciterId: entity.reciterId,
      reciterName: entity.reciterName,
      audioUrl: entity.audioUrl,
      duration: entity.duration,
      pageCount: entity.pageCount,
      lastListenedTo: entity.lastListenedTo,
    );
  }
}

class ListeningProgressModel extends ListeningProgressEntity {
  const ListeningProgressModel({
    required super.id,
    required super.userId,
    required super.surahAudioId,
    required super.position,
    required super.lastUpdated,
    super.isCompleted = false,
  });

  factory ListeningProgressModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final positionMs = data['positionMs'] as int? ?? 0;
    return ListeningProgressModel(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      surahAudioId: data['surahAudioId'] as String? ?? '',
      position: Duration(milliseconds: positionMs),
      lastUpdated:
          (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isCompleted: data['isCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'surahAudioId': surahAudioId,
      'positionMs': position.inMilliseconds,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
      'isCompleted': isCompleted,
    };
  }

  factory ListeningProgressModel.fromEntity(ListeningProgressEntity entity) {
    return ListeningProgressModel(
      id: entity.id,
      userId: entity.userId,
      surahAudioId: entity.surahAudioId,
      position: entity.position,
      lastUpdated: entity.lastUpdated,
      isCompleted: entity.isCompleted,
    );
  }
}
