import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../models/audio_models.dart';
import 'audio_library_remote_datasource.dart';
import 'mp3quran_catalog_service.dart';

@LazySingleton(as: AudioLibraryRemoteDatasource)
class AudioLibraryRemoteDatasourceImpl implements AudioLibraryRemoteDatasource {
  final FirebaseFirestore firestore;
  final Mp3QuranCatalogService _mp3QuranCatalog;

  AudioLibraryRemoteDatasourceImpl({
    required this.firestore,
    Mp3QuranCatalogService? mp3QuranCatalog,
  }) : _mp3QuranCatalog = mp3QuranCatalog ?? Mp3QuranCatalogService();

  CollectionReference get _surahAudiosRef =>
      firestore.collection(FirestoreCollections.surahAudios);

  CollectionReference get _listeningProgressRef =>
      firestore.collection(FirestoreCollections.listeningProgress);

  CollectionReference get _usersRef =>
      firestore.collection(FirestoreCollections.users);

  @override
  Future<List<String>> getFollowedReciterIds(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      final data = userDoc.data() as Map<String, dynamic>?;
      return (data?['followedReciterIds'] as List<dynamic>?)
              ?.map((e) => normalizeReciterId(e as String))
              .toList() ??
          [];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<ReciterModel>> getReciters() async {
    final entries = await _mp3QuranCatalog.getReciters();
    return _mp3QuranCatalog.toReciterModels(entries);
  }

  @override
  Future<List<ReciterModel>> getFavoriteReciters(String userId) async {
    try {
      final userDoc = await _usersRef.doc(userId).get();
      final data = userDoc.data() as Map<String, dynamic>?;
      final followedIds =
          (data?['followedReciterIds'] as List<dynamic>?)
              ?.map((e) => normalizeReciterId(e as String))
              .toList() ??
          [];

      if (followedIds.isEmpty) return [];

      final entries = await _mp3QuranCatalog.getReciters();
      final byId = {for (final entry in entries) entry.id.toString(): entry};
      return [
        for (final id in followedIds)
          if (byId[id] != null)
            ReciterModel(
              id: id,
              name: byId[id]!.name,
              recitationStyle: byId[id]!.moshafName,
              isFollowing: true,
            ),
      ];
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<List<SurahAudioModel>> getSurahAudios({String? reciterId}) async {
    final catalog = await _mp3QuranCatalog.getSurahAudios(
      reciterId: reciterId != null ? normalizeReciterId(reciterId) : null,
    );
    final durations = await _loadSavedDurations(reciterId: reciterId);

    return catalog.map((audio) {
      final seconds =
          durations[_durationKey(audio.reciterId ?? '', audio.surahNumber)];
      if (seconds == null || seconds <= 0) return audio;
      return SurahAudioModel(
        id: audio.id,
        surahNumber: audio.surahNumber,
        surahName: audio.surahName,
        reciterId: audio.reciterId,
        reciterName: audio.reciterName,
        audioUrl: audio.audioUrl,
        duration: Duration(seconds: seconds),
        pageCount: audio.pageCount,
        lastListenedTo: audio.lastListenedTo,
      );
    }).toList();
  }

  Future<Map<String, int>> _loadSavedDurations({String? reciterId}) async {
    final durations = <String, int>{};

    try {
      final raw = await rootBundle.loadString(
        'assets/data/audio_durations.json',
      );
      final decoded = json.decode(raw) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final seconds = (entry.value as num?)?.round();
        if (seconds != null && seconds > 0) durations[entry.key] = seconds;
      }
    } catch (_) {
      // The generated local file is optional; Firestore may hold the values.
    }

    try {
      Query query = _surahAudiosRef;
      if (reciterId != null) {
        query = query.where(
          'reciterId',
          isEqualTo: normalizeReciterId(reciterId),
        );
      }
      final snap = await query.get();
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        final id = normalizeReciterId(data['reciterId']?.toString());
        final surahNumber = data['surahNumber'] as int?;
        if (surahNumber == null) continue;
        final seconds =
            (data['durationSeconds'] as num?)?.round() ??
            ((data['durationMs'] as num?)?.round() ?? 0) ~/ 1000;
        if (seconds > 0) {
          durations[_durationKey(id, surahNumber)] = seconds;
        }
      }
    } catch (_) {
      // Local generated durations remain usable while offline.
    }

    return durations;
  }

  String _durationKey(String reciterId, int surahNumber) =>
      '${normalizeReciterId(reciterId)}_$surahNumber';

  @override
  Future<void> toggleFollowReciter({
    required String userId,
    required String reciterId,
    required bool isFollowing,
  }) async {
    try {
      final normalizedId = normalizeReciterId(reciterId);
      if (isFollowing) {
        await _usersRef.doc(userId).update({
          'followedReciterIds': FieldValue.arrayUnion([normalizedId]),
        });
      } else {
        await _usersRef.doc(userId).update({
          'followedReciterIds': FieldValue.arrayRemove([normalizedId]),
        });
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<SurahAudioModel?> getSurahAudioById(String id) async {
    try {
      final doc = await _surahAudiosRef.doc(id).get();
      if (!doc.exists) return null;
      return SurahAudioModel.fromFirestore(doc);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<void> saveListeningProgress(ListeningProgressModel progress) async {
    try {
      if (progress.id.isEmpty) {
        await _listeningProgressRef.add(progress.toFirestore());
      } else {
        await _listeningProgressRef
            .doc(progress.id)
            .set(progress.toFirestore(), SetOptions(merge: true));
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<ListeningProgressModel?> getListeningProgress({
    required String userId,
    required String surahAudioId,
  }) async {
    try {
      final snap = await _listeningProgressRef
          .where('userId', isEqualTo: userId)
          .where('surahAudioId', isEqualTo: surahAudioId)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return ListeningProgressModel.fromFirestore(snap.docs.first);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  @override
  Future<SurahAudioModel?> getContinueListening(String userId) async {
    try {
      final snap = await _listeningProgressRef
          .where('userId', isEqualTo: userId)
          .where('isCompleted', isEqualTo: false)
          .orderBy('lastUpdated', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final progress = ListeningProgressModel.fromFirestore(snap.docs.first);
      final audioDoc = await _surahAudiosRef.doc(progress.surahAudioId).get();

      if (!audioDoc.exists) return null;

      return SurahAudioModel.fromFirestore(audioDoc);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
