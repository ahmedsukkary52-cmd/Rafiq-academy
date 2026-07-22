import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:rafiq_academy/features/audio_library/domain/featured_reciters.dart';

const _recitersUrl = 'https://www.mp3quran.net/api/v3/reciters?language=ar';
const _defaultOutput = 'assets/data/audio_durations.json';
const _probeBytes = 128 * 1024;

Future<void> main(List<String> args) async {
  final outputPath = _option(args, 'output') ?? _defaultOutput;
  final concurrency = int.tryParse(_option(args, 'concurrency') ?? '') ?? 6;
  final onlyReciter = _option(args, 'reciter');
  final limit = int.tryParse(_option(args, 'limit') ?? '');

  final existing = await _readExisting(outputPath);
  final reciters = await _fetchFeaturedReciters();
  final selected = onlyReciter == null
      ? reciters
      : reciters.where((r) => r.id == onlyReciter).toList();

  if (selected.isEmpty) {
    stderr.writeln('No matching featured reciters found.');
    exitCode = 2;
    return;
  }

  final pendingJobs = <_ProbeJob>[
    for (final reciter in selected)
      for (final surah in reciter.surahs)
        if (!existing.containsKey('${reciter.id}_$surah'))
          _ProbeJob(
            key: '${reciter.id}_$surah',
            url: '${reciter.server}${surah.toString().padLeft(3, '0')}.mp3',
          ),
  ];
  final jobs = limit == null ? pendingJobs : pendingJobs.take(limit).toList();

  stdout.writeln(
    'Probing ${jobs.length} files for ${selected.length} featured reciters...',
  );

  var cursor = 0;
  var completed = 0;
  final workers = List.generate(concurrency, (_) async {
    while (true) {
      final index = cursor++;
      if (index >= jobs.length) return;
      final job = jobs[index];
      try {
        final seconds = await _probeDuration(job.url);
        existing[job.key] = seconds;
        completed++;
        stdout.writeln('[$completed/${jobs.length}] ${job.key}: ${seconds}s');
        if (completed % 20 == 0) {
          await _writeOutput(outputPath, existing);
        }
      } catch (error) {
        stderr.writeln('[skip] ${job.key}: $error');
      }
    }
  });

  await Future.wait(workers);
  await _writeOutput(outputPath, existing);
  stdout.writeln('Saved ${existing.length} durations to $outputPath');
}

Future<List<_ApiReciter>> _fetchFeaturedReciters() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_recitersUrl));
    final response = await request.close().timeout(const Duration(seconds: 20));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Catalog HTTP ${response.statusCode}');
    }
    final body = await response.transform(utf8.decoder).join();
    final decoded = json.decode(body) as Map<String, dynamic>;
    final apiReciters = decoded['reciters'] as List<dynamic>? ?? const [];
    final featured = featuredReciterIds.toSet();
    final result = <_ApiReciter>[];

    for (final raw in apiReciters) {
      final data = raw as Map<String, dynamic>;
      final id = data['id'].toString();
      if (!featured.contains(id)) continue;
      final moshafs = data['moshaf'] as List<dynamic>? ?? const [];
      final moshaf = _pickMoshaf(moshafs);
      if (moshaf == null) continue;
      final server = _withTrailingSlash(moshaf['server'] as String? ?? '');
      final surahs = (moshaf['surah_list'] as String? ?? '')
          .split(',')
          .map((value) => int.tryParse(value.trim()))
          .whereType<int>()
          .toList();
      if (server.isNotEmpty && surahs.isNotEmpty) {
        result.add(_ApiReciter(id: id, server: server, surahs: surahs));
      }
    }
    return result;
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic>? _pickMoshaf(List<dynamic> moshafs) {
  Map<String, dynamic>? complete;
  Map<String, dynamic>? fallback;
  for (final raw in moshafs) {
    final moshaf = raw as Map<String, dynamic>;
    fallback ??= moshaf;
    final total = moshaf['surah_total'] as int? ?? 0;
    if ((moshaf['rewaya_id'] as int? ?? 0) == 1 && total == 114) {
      return moshaf;
    }
    if (total == 114) complete ??= moshaf;
  }
  return complete ?? fallback;
}

Future<int> _probeDuration(String url) async {
  final uri = Uri.parse(url);
  final contentLength = await _contentLength(uri);
  final bytes = await _readRange(uri);
  final frame = _findMpegFrame(bytes);
  if (frame == null) throw const FormatException('No MPEG frame found');

  final xingSeconds = _readXingDuration(bytes, frame);
  if (xingSeconds != null && xingSeconds > 0) return xingSeconds.round();

  final vbriSeconds = _readVbriDuration(bytes, frame);
  if (vbriSeconds != null && vbriSeconds > 0) return vbriSeconds.round();

  if (contentLength <= 0 || frame.bitrateKbps <= 0) {
    throw const FormatException('Missing size or bitrate');
  }
  final audioBytes = contentLength - frame.offset;
  return (audioBytes * 8 / (frame.bitrateKbps * 1000)).round();
}

Future<int> _contentLength(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.headUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode >= 400) {
      throw HttpException('HEAD HTTP ${response.statusCode}');
    }
    return response.contentLength;
  } finally {
    client.close(force: true);
  }
}

Future<Uint8List> _readRange(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-${_probeBytes - 1}');
    final response = await request.close().timeout(const Duration(seconds: 15));
    if (response.statusCode != HttpStatus.partialContent) {
      throw HttpException(
        'Server did not honor Range request (${response.statusCode})',
      );
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  } finally {
    client.close(force: true);
  }
}

_MpegFrame? _findMpegFrame(Uint8List bytes) {
  var offset = _id3Size(bytes);
  for (; offset + 4 < bytes.length; offset++) {
    if (bytes[offset] != 0xFF || (bytes[offset + 1] & 0xE0) != 0xE0) continue;
    final versionBits = (bytes[offset + 1] >> 3) & 0x03;
    final layerBits = (bytes[offset + 1] >> 1) & 0x03;
    final bitrateIndex = (bytes[offset + 2] >> 4) & 0x0F;
    final sampleRateIndex = (bytes[offset + 2] >> 2) & 0x03;
    if (versionBits == 1 ||
        layerBits != 1 ||
        bitrateIndex == 0 ||
        bitrateIndex == 15 ||
        sampleRateIndex == 3) {
      continue;
    }

    final isMpeg1 = versionBits == 3;
    final bitrateTable = isMpeg1
        ? const [32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
        : const [8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160];
    const baseRates = [44100, 48000, 32000];
    var sampleRate = baseRates[sampleRateIndex];
    if (versionBits == 2) sampleRate ~/= 2;
    if (versionBits == 0) sampleRate ~/= 4;
    final channelMode = (bytes[offset + 3] >> 6) & 0x03;

    return _MpegFrame(
      offset: offset,
      isMpeg1: isMpeg1,
      sampleRate: sampleRate,
      bitrateKbps: bitrateTable[bitrateIndex - 1],
      mono: channelMode == 3,
    );
  }
  return null;
}

double? _readXingDuration(Uint8List bytes, _MpegFrame frame) {
  final sideInfo = frame.isMpeg1
      ? (frame.mono ? 17 : 32)
      : (frame.mono ? 9 : 17);
  final offset = frame.offset + 4 + sideInfo;
  if (offset + 12 >= bytes.length) return null;
  final marker = ascii.decode(bytes.sublist(offset, offset + 4));
  if (marker != 'Xing' && marker != 'Info') return null;
  final flags = _uint32(bytes, offset + 4);
  if ((flags & 0x01) == 0) return null;
  final frames = _uint32(bytes, offset + 8);
  final samplesPerFrame = frame.isMpeg1 ? 1152 : 576;
  return frames * samplesPerFrame / frame.sampleRate;
}

double? _readVbriDuration(Uint8List bytes, _MpegFrame frame) {
  final offset = frame.offset + 36;
  if (offset + 18 >= bytes.length) return null;
  if (ascii.decode(bytes.sublist(offset, offset + 4)) != 'VBRI') return null;
  final frames = _uint32(bytes, offset + 14);
  final samplesPerFrame = frame.isMpeg1 ? 1152 : 576;
  return frames * samplesPerFrame / frame.sampleRate;
}

int _id3Size(Uint8List bytes) {
  if (bytes.length < 10 ||
      bytes[0] != 0x49 ||
      bytes[1] != 0x44 ||
      bytes[2] != 0x33) {
    return 0;
  }
  final size =
      ((bytes[6] & 0x7F) << 21) |
      ((bytes[7] & 0x7F) << 14) |
      ((bytes[8] & 0x7F) << 7) |
      (bytes[9] & 0x7F);
  return 10 + size;
}

int _uint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

Future<Map<String, int>> _readExisting(String path) async {
  final file = File(path);
  if (!await file.exists()) return {};
  final decoded =
      json.decode(await file.readAsString()) as Map<String, dynamic>;
  return decoded.map((key, value) => MapEntry(key, (value as num).round()));
}

Future<void> _writeOutput(String path, Map<String, int> durations) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  final sortedKeys = durations.keys.toList()..sort();
  final sorted = {for (final key in sortedKeys) key: durations[key]};
  await file.writeAsString(
    const JsonEncoder.withIndent('  ').convert(sorted),
    flush: true,
  );
}

String? _option(List<String> args, String name) {
  final prefix = '--$name=';
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

String _withTrailingSlash(String value) =>
    value.endsWith('/') ? value : '$value/';

class _ApiReciter {
  final String id;
  final String server;
  final List<int> surahs;

  const _ApiReciter({
    required this.id,
    required this.server,
    required this.surahs,
  });
}

class _ProbeJob {
  final String key;
  final String url;

  const _ProbeJob({required this.key, required this.url});
}

class _MpegFrame {
  final int offset;
  final bool isMpeg1;
  final int sampleRate;
  final int bitrateKbps;
  final bool mono;

  const _MpegFrame({
    required this.offset,
    required this.isMpeg1,
    required this.sampleRate,
    required this.bitrateKbps,
    required this.mono,
  });
}
