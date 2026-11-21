import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/error/user_facing_error.dart';
import 'package:rafiq_academy/features/audio_library/presentation/bloc/audio_state.dart';
import 'package:rafiq_academy/features/audio_library/domain/entities/audio_entities.dart';

void main() {
  group('audio library error / state hygiene', () {
    test('unsigned-session repository message stays user-facing Arabic', () {
      const exception = ServerException(signedOutErrorText);
      final failure = ServerFailure(exception.message);
      expect(failure.message, signedOutErrorText);
      expect(failure.message.contains('Exception'), isFalse);
      expect(failure.message.contains('authenticated'), isFalse);
    });

    test('raw Firebase dump is sanitized before UI consumption', () {
      final raw = ServerException(
        userFacingErrorText(
          '[cloud_firestore/permission-denied] Missing or insufficient permissions.',
        ),
      );
      expect(ServerFailure(raw.message).message, permissionDeniedErrorText);
    });

    test('filteredReciters returns favorites without debug side effects', () {
      const favorites = [
        ReciterEntity(
          id: '1',
          name: 'مفضل',
          recitationStyle: 'حفص',
          isFollowing: true,
        ),
      ];
      const all = [
        ReciterEntity(
          id: '1',
          name: 'مفضل',
          recitationStyle: 'حفص',
          isFollowing: true,
        ),
        ReciterEntity(
          id: '2',
          name: 'آخر',
          recitationStyle: 'ورش',
          isFollowing: false,
        ),
      ];
      final state = AudioLibraryState.initial().copyWith(
        favoriteReciters: favorites,
        allReciters: all,
      );
      expect(state.filteredReciters, favorites);
      expect(
        state.copyWith(searchQuery: 'آخر').filteredReciters.single.name,
        'آخر',
      );
    });
  });
}
