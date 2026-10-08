import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/mushaf_position.dart';

/// Pre-C15 device-wide page key. Never read: it is not scoped to a student.
const kLegacyLastMushafPageKey = 'last_mushaf_page';

/// Device-local, per-student copy of the last C15 write.
///
/// Only consulted when the C15 read itself fails (e.g. offline); a missing
/// C15 document is NOT a reason to read the mirror.
abstract class MushafReadingLocalMirror {
  Future<MushafPosition?> read(String studentId);

  Future<void> write(String studentId, MushafPosition position);
}

@LazySingleton(as: MushafReadingLocalMirror)
class MushafReadingPrefsMirror implements MushafReadingLocalMirror {
  static const keyPrefix = 'mushaf_last_read_v1_';

  static String keyFor(String studentId) => '$keyPrefix${studentId.trim()}';

  @override
  Future<MushafPosition?> read(String studentId) async {
    if (studentId.trim().isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyFor(studentId));
    if (raw == null) return null;
    final parts = raw.split(':');
    if (parts.length != 3) return null;
    final page = int.tryParse(parts[0]);
    final surah = int.tryParse(parts[1]);
    final ayah = int.tryParse(parts[2]);
    if (page == null || surah == null || ayah == null || ayah < 1) return null;
    final position = MushafPosition(
      pageNumber: page,
      surahNumber: surah,
      ayahNumber: ayah,
    );
    return position.isValid ? position : null;
  }

  @override
  Future<void> write(String studentId, MushafPosition position) async {
    if (studentId.trim().isEmpty || !position.isValid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      keyFor(studentId),
      '${position.pageNumber}:${position.surahNumber}:${position.ayahNumber}',
    );
    await prefs.remove(kLegacyLastMushafPageKey);
  }
}
