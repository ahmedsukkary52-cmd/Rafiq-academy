import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_models.dart';

/// Default reciter: مشاري راشد العفاسي (mp3quran id = 123).
const kDefaultReciterId = '123';

/// Legacy id kept for SharedPreferences migration.
const kLegacyReciterId = 'afs';

class Mp3ReciterEntry {
  final int id;
  final String name;
  final int moshafId;
  final String moshafName;
  final String server;
  final List<int> surahNumbers;

  const Mp3ReciterEntry({
    required this.id,
    required this.name,
    required this.moshafId,
    required this.moshafName,
    required this.server,
    required this.surahNumbers,
  });

  factory Mp3ReciterEntry.fromJson(Map<String, dynamic> json) {
    final surahListRaw = json['surahNumbers'] as List<dynamic>? ?? [];
    return Mp3ReciterEntry(
      id: json['id'] as int,
      name: json['name'] as String,
      moshafId: json['moshafId'] as int,
      moshafName: json['moshafName'] as String,
      server: json['server'] as String,
      surahNumbers: surahListRaw.map((e) => e as int).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'moshafId': moshafId,
    'moshafName': moshafName,
    'server': server,
    'surahNumbers': surahNumbers,
  };
}

class Mp3SurahMeta {
  final int id;
  final String name;
  final int pageCount;

  const Mp3SurahMeta({
    required this.id,
    required this.name,
    required this.pageCount,
  });
}

/// Fetches and caches mp3quran.net v3 catalog (reciters + surah metadata).

@injectable
class Mp3QuranCatalogService {
  static const _recitersCacheKey = 'mp3quran_reciters_cache_v1';
  static const _suwarCacheKey = 'mp3quran_suwar_cache_v1';
  static const _cacheFetchedAtKey = 'mp3quran_cache_fetched_at_v1';
  static const _cacheTtl = Duration(days: 7);

  static const _recitersApiUrl =
      'https://www.mp3quran.net/api/v3/reciters?language=ar';
  static const _suwarApiUrl =
      'https://www.mp3quran.net/api/v3/suwar?language=ar';

  List<Mp3ReciterEntry>? _recitersMemory;
  Map<int, Mp3SurahMeta>? _suwarMemory;
  List<SurahAudioModel>? _surahAudiosMemory;
  Future<List<Mp3ReciterEntry>>? _recitersRequest;
  Future<Map<int, Mp3SurahMeta>>? _suwarRequest;

  Future<List<Mp3ReciterEntry>> getReciters() async {
    if (_recitersMemory != null) return _recitersMemory!;
    return _recitersRequest ??= _loadReciters();
  }

  Future<List<Mp3ReciterEntry>> _loadReciters() async {
    final cached = await _readCachedReciters();
    if (cached != null) {
      _recitersMemory = cached;
      return cached;
    }

    try {
      final fetched = await _fetchRecitersFromApi();
      _recitersMemory = fetched;
      await _writeRecitersCache(fetched);
      return fetched;
    } catch (_) {
      _recitersMemory = _fallbackReciters();
      return _recitersMemory!;
    }
  }

  Future<Map<int, Mp3SurahMeta>> getSuwarMeta() async {
    if (_suwarMemory != null) return _suwarMemory!;
    return _suwarRequest ??= _loadSuwarMeta();
  }

  Future<Map<int, Mp3SurahMeta>> _loadSuwarMeta() async {
    final cached = await _readCachedSuwar();
    if (cached != null) {
      _suwarMemory = cached;
      return cached;
    }

    try {
      final fetched = await _fetchSuwarFromApi();
      _suwarMemory = fetched;
      await _writeSuwarCache(fetched);
      return fetched;
    } catch (_) {
      _suwarMemory = _fallbackSuwarMeta();
      return _suwarMemory!;
    }
  }

  Future<List<SurahAudioModel>> getSurahAudios({String? reciterId}) async {
    final reciters = await getReciters();
    final suwar = await getSuwarMeta();

    _surahAudiosMemory ??= _buildSurahAudios(reciters: reciters, suwar: suwar);

    if (reciterId == null) return _surahAudiosMemory!;

    return _surahAudiosMemory!.where((s) => s.reciterId == reciterId).toList();
  }

  List<ReciterModel> toReciterModels(List<Mp3ReciterEntry> entries) {
    return entries
        .map(
          (e) => ReciterModel(
            id: e.id.toString(),
            name: e.name,
            recitationStyle: e.moshafName,
            isFollowing: false,
          ),
        )
        .toList();
  }

  List<SurahAudioModel> _buildSurahAudios({
    required List<Mp3ReciterEntry> reciters,
    required Map<int, Mp3SurahMeta> suwar,
  }) {
    final audios = <SurahAudioModel>[];

    for (final reciter in reciters) {
      for (final surahNumber in reciter.surahNumbers) {
        final meta = suwar[surahNumber];
        audios.add(
          SurahAudioModel(
            id: '${reciter.id}_${reciter.moshafId}_$surahNumber',
            surahNumber: surahNumber,
            surahName: meta?.name ?? 'سورة $surahNumber',
            reciterId: reciter.id.toString(),
            reciterName: reciter.name,
            audioUrl: buildAudioUrl(reciter.server, surahNumber),
            // mp3quran suwar API has no duration field — use Duration.zero here
            // and read real length from AudioPlayer.durationStream when playing.
            duration: Duration.zero,
            pageCount: meta?.pageCount ?? 0,
          ),
        );
      }
    }

    audios.sort((a, b) {
      final reciterCmp = (a.reciterId ?? '').compareTo(b.reciterId ?? '');
      if (reciterCmp != 0) return reciterCmp;
      return a.surahNumber.compareTo(b.surahNumber);
    });

    return audios;
  }

  static String buildAudioUrl(String server, int surahNumber) {
    final base = server.endsWith('/') ? server : '$server/';
    return '$base${surahNumber.toString().padLeft(3, '0')}.mp3';
  }

  Future<List<Mp3ReciterEntry>> _fetchRecitersFromApi() async {
    final body = await _httpGet(_recitersApiUrl);
    final decoded = json.decode(body) as Map<String, dynamic>;
    final list = decoded['reciters'] as List<dynamic>? ?? [];

    final entries = <Mp3ReciterEntry>[];
    for (final raw in list) {
      final reciter = raw as Map<String, dynamic>;
      final moshafs = reciter['moshaf'] as List<dynamic>? ?? [];
      if (moshafs.isEmpty) continue;

      final primary = _pickPrimaryMoshaf(moshafs);
      if (primary == null) continue;

      final surahNumbers = _parseSurahList(primary['surah_list'] as String?);
      if (surahNumbers.isEmpty) continue;

      entries.add(
        Mp3ReciterEntry(
          id: reciter['id'] as int,
          name: reciter['name'] as String,
          moshafId: primary['id'] as int,
          moshafName: primary['name'] as String? ?? '',
          server: primary['server'] as String? ?? '',
          surahNumbers: surahNumbers,
        ),
      );
    }

    if (entries.isEmpty) {
      throw const HttpException('Empty reciters list from mp3quran API');
    }

    return entries;
  }

  Future<Map<int, Mp3SurahMeta>> _fetchSuwarFromApi() async {
    final body = await _httpGet(_suwarApiUrl);
    final decoded = json.decode(body) as Map<String, dynamic>;
    final list = decoded['suwar'] as List<dynamic>? ?? [];

    final map = <int, Mp3SurahMeta>{};
    for (final raw in list) {
      final s = raw as Map<String, dynamic>;
      final id = s['id'] as int;
      final startPage = s['start_page'] as int? ?? 0;
      final endPage = s['end_page'] as int? ?? startPage;
      map[id] = Mp3SurahMeta(
        id: id,
        name: s['name'] as String? ?? 'سورة $id',
        pageCount: (endPage - startPage + 1).clamp(1, 999),
      );
    }
    return map;
  }

  Map<String, dynamic>? _pickPrimaryMoshaf(List<dynamic> moshafs) {
    Map<String, dynamic>? full114;
    Map<String, dynamic>? any;

    for (final raw in moshafs) {
      final m = raw as Map<String, dynamic>;
      any ??= m;
      final total = m['surah_total'] as int? ?? 0;
      final rewayaId = m['rewaya_id'] as int? ?? 0;
      if (rewayaId == 1 && total == 114) return m;
      if (total == 114) full114 ??= m;
    }

    return full114 ?? any ?? (moshafs.first as Map<String, dynamic>);
  }

  List<int> _parseSurahList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  Future<String> _httpGet(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode} for $url');
      }
      return await response.transform(utf8.decoder).join();
    } finally {
      client.close();
    }
  }

  Future<bool> _isCacheValid() async {
    final prefs = await SharedPreferences.getInstance();
    final fetchedAt = prefs.getInt(_cacheFetchedAtKey);
    if (fetchedAt == null) return false;
    final age = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(fetchedAt),
    );
    return age < _cacheTtl;
  }

  Future<List<Mp3ReciterEntry>?> _readCachedReciters() async {
    if (!await _isCacheValid()) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recitersCacheKey);
    if (raw == null) return null;
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => Mp3ReciterEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<int, Mp3SurahMeta>?> _readCachedSuwar() async {
    if (!await _isCacheValid()) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_suwarCacheKey);
    if (raw == null) return null;
    final list = json.decode(raw) as List<dynamic>;
    final map = <int, Mp3SurahMeta>{};
    for (final item in list) {
      final s = item as Map<String, dynamic>;
      map[s['id'] as int] = Mp3SurahMeta(
        id: s['id'] as int,
        name: s['name'] as String,
        pageCount: s['pageCount'] as int,
      );
    }
    return map;
  }

  Future<void> _writeRecitersCache(List<Mp3ReciterEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recitersCacheKey,
      json.encode(entries.map((e) => e.toJson()).toList()),
    );
    await prefs.setInt(
      _cacheFetchedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _writeSuwarCache(Map<int, Mp3SurahMeta> suwar) async {
    final prefs = await SharedPreferences.getInstance();
    final list = suwar.values
        .map((s) => {'id': s.id, 'name': s.name, 'pageCount': s.pageCount})
        .toList();
    await prefs.setString(_suwarCacheKey, json.encode(list));
    await prefs.setInt(
      _cacheFetchedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  List<Mp3ReciterEntry> _fallbackReciters() {
    return const [
      Mp3ReciterEntry(
        id: 123,
        name: 'مشاري راشد العفاسي',
        moshafId: 123,
        moshafName: 'حفص عن عاصم - مرتل',
        server: 'https://server8.mp3quran.net/afs/',
        surahNumbers: [
          1,
          2,
          3,
          4,
          5,
          6,
          7,
          8,
          9,
          10,
          11,
          12,
          13,
          14,
          15,
          16,
          17,
          18,
          19,
          20,
          21,
          22,
          23,
          24,
          25,
          26,
          27,
          28,
          29,
          30,
          31,
          32,
          33,
          34,
          35,
          36,
          37,
          38,
          39,
          40,
          41,
          42,
          43,
          44,
          45,
          46,
          47,
          48,
          49,
          50,
          51,
          52,
          53,
          54,
          55,
          56,
          57,
          58,
          59,
          60,
          61,
          62,
          63,
          64,
          65,
          66,
          67,
          68,
          69,
          70,
          71,
          72,
          73,
          74,
          75,
          76,
          77,
          78,
          79,
          80,
          81,
          82,
          83,
          84,
          85,
          86,
          87,
          88,
          89,
          90,
          91,
          92,
          93,
          94,
          95,
          96,
          97,
          98,
          99,
          100,
          101,
          102,
          103,
          104,
          105,
          106,
          107,
          108,
          109,
          110,
          111,
          112,
          113,
          114,
        ],
      ),
    ];
  }

  Map<int, Mp3SurahMeta> _fallbackSuwarMeta() {
    const names = [
      'الفاتحة',
      'البقرة',
      'آل عمران',
      'النساء',
      'المائدة',
      'الأنعام',
      'الأعراف',
      'الأنفال',
      'التوبة',
      'يونس',
      'هود',
      'يوسف',
      'الرعد',
      'إبراهيم',
      'الحجر',
      'النحل',
      'الإسراء',
      'الكهف',
      'مريم',
      'طه',
      'الأنبياء',
      'الحج',
      'المؤمنون',
      'النور',
      'الفرقان',
      'الشعراء',
      'النمل',
      'القصص',
      'العنكبوت',
      'الروم',
      'لقمان',
      'السجدة',
      'الأحزاب',
      'سبأ',
      'فاطر',
      'يس',
      'الصافات',
      'ص',
      'الزمر',
      'غافر',
      'فصلت',
      'الشورى',
      'الزخرف',
      'الدخان',
      'الجاثية',
      'الأحقاف',
      'محمد',
      'الفتح',
      'الحجرات',
      'ق',
      'الذاريات',
      'الطور',
      'النجم',
      'القمر',
      'الرحمن',
      'الواقعة',
      'الحديد',
      'المجادلة',
      'الحشر',
      'الممتحنة',
      'الصف',
      'الجمعة',
      'المنافقون',
      'التغابن',
      'الطلاق',
      'التحريم',
      'الملك',
      'القلم',
      'الحاقة',
      'المعارج',
      'نوح',
      'الجن',
      'المزمل',
      'المدثر',
      'القيامة',
      'الإنسان',
      'المرسلات',
      'النبأ',
      'النازعات',
      'عبس',
      'التكوير',
      'الإنفطار',
      'المطففين',
      'الإنشقاق',
      'البروج',
      'الطارق',
      'الأعلى',
      'الغاشية',
      'الفجر',
      'البلد',
      'الشمس',
      'الليل',
      'الضحى',
      'الشرح',
      'التين',
      'العلق',
      'القدر',
      'البينة',
      'الزلزلة',
      'العاديات',
      'القارعة',
      'التكاثر',
      'العصر',
      'الهمزة',
      'الفيل',
      'قريش',
      'الماعون',
      'الكوثر',
      'الكافرون',
      'النصر',
      'المسد',
      'الإخلاص',
      'الفلق',
      'الناس',
    ];
    return {
      for (var i = 0; i < names.length; i++)
        i + 1: Mp3SurahMeta(id: i + 1, name: names[i], pageCount: 0),
    };
  }
}

String normalizeReciterId(String? id) {
  if (id == null) return kDefaultReciterId;
  if (id == kLegacyReciterId) return kDefaultReciterId;
  return id;
}
