import 'quran_surah_catalog.dart';

/// An everyayah.com recitation folder serving `SSSAAA.mp3` per ayah.
class MushafReciter {
  final String id;
  final String name;
  final String subDirectory;

  const MushafReciter({
    required this.id,
    required this.name,
    required this.subDirectory,
  });
}

const kDefaultMushafReciter = MushafReciter(
  id: 'minshawi',
  name: 'محمد صديق المنشاوي',
  subDirectory: 'Minshawy_Murattal_128kbps',
);

class MushafReciters {
  const MushafReciters._();

  static const String _baseUrl = 'https://everyayah.com/data';

  /// Only folders verified to serve audio (1:1 … 114:6). Do not add entries
  /// without checking the folder on everyayah.com.
  static const List<MushafReciter> all = [
    kDefaultMushafReciter,
    MushafReciter(
      id: 'husary',
      name: 'محمود خليل الحصري',
      subDirectory: 'Husary_128kbps',
    ),
    MushafReciter(
      id: 'afasy',
      name: 'مشاري العفاسي',
      subDirectory: 'Alafasy_128kbps',
    ),
  ];

  static MushafReciter? byId(String id) {
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Null when the surah/ayah pair is out of range.
  static String? ayahUrl(MushafReciter reciter, int surah, int ayah) {
    if (!QuranSurahCatalog.isValidSurah(surah)) return null;
    if (ayah < 1 || ayah > QuranSurahCatalog.of(surah).ayahCount) return null;
    final s = surah.toString().padLeft(3, '0');
    final a = ayah.toString().padLeft(3, '0');
    return '$_baseUrl/${reciter.subDirectory}/$s$a.mp3';
  }
}
