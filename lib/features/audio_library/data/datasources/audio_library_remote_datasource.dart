import '../models/audio_models.dart';

abstract class AudioLibraryRemoteDatasource {
  Future<List<ReciterModel>> getReciters();

  Future<List<String>> getFollowedReciterIds(String userId);

  Future<List<ReciterModel>> getFavoriteReciters(String userId);

  Future<void> toggleFollowReciter({
    required String userId,
    required String reciterId,
    required bool isFollowing,
  });

  Future<List<SurahAudioModel>> getSurahAudios({String? reciterId});

  Future<SurahAudioModel?> getSurahAudioById(String id);

  Future<void> saveListeningProgress(ListeningProgressModel progress);

  Future<ListeningProgressModel?> getListeningProgress({
    required String userId,
    required String surahAudioId,
  });

  Future<SurahAudioModel?> getContinueListening(String userId);
}
