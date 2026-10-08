import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/policies/chat_media_policy.dart';
import '../../domain/usecases/chat_usecases.dart';

typedef ChatTempDirectoryProvider = Future<Directory> Function();

/// Session cache for chat media fetched through Storage Rules (no public
/// download URLs). Cleared on logout so the next account on a shared device
/// cannot open the previous account's files.
@lazySingleton
class ChatMediaLoader {
  final DownloadChatMediaUseCase download;
  final ChatTempDirectoryProvider _tempDirectory;

  static const int _maxCachedImages = 24;

  final LinkedHashMap<String, Uint8List> _images = LinkedHashMap();
  final Map<String, File> _files = {};
  final Map<String, Future<Either<Failure, Uint8List>>> _inFlight = {};

  ChatMediaLoader(
    this.download, {
    @ignoreParam ChatTempDirectoryProvider? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  Future<Either<Failure, Uint8List>> imageBytes(ChatMediaEntity media) async {
    final cached = _images.remove(media.storagePath);
    if (cached != null) {
      _images[media.storagePath] = cached;
      return Right(cached);
    }
    final result = await _fetch(media);
    result.fold((_) {}, (bytes) {
      _images[media.storagePath] = bytes;
      while (_images.length > _maxCachedImages) {
        _images.remove(_images.keys.first);
      }
    });
    return result;
  }

  /// Local copy for playback / opening. Named after the display file name so
  /// external viewers detect the type.
  Future<Either<Failure, File>> localFile(ChatMediaEntity media) async {
    final cached = _files[media.storagePath];
    if (cached != null && await cached.exists()) return Right(cached);

    final result = await _fetch(media);
    return result.fold(Left.new, (bytes) async {
      try {
        final dir = await _mediaDirectory(media.storagePath);
        final file = File(
          '${dir.path}${Platform.pathSeparator}${_localName(media)}',
        );
        await file.writeAsBytes(bytes, flush: true);
        _files[media.storagePath] = file;
        return Right(file);
      } on FileSystemException {
        return const Left(ServerFailure('تعذر حفظ الملف على الجهاز'));
      }
    });
  }

  Future<Either<Failure, Uint8List>> _fetch(ChatMediaEntity media) {
    return _inFlight.putIfAbsent(media.storagePath, () async {
      try {
        return await download(media);
      } finally {
        _inFlight.remove(media.storagePath);
      }
    });
  }

  Future<Directory> _root() async {
    final base = await _tempDirectory();
    return Directory('${base.path}${Platform.pathSeparator}chat_media');
  }

  Future<Directory> _mediaDirectory(String storagePath) async {
    final key = base64Url.encode(utf8.encode(storagePath)).replaceAll('=', '');
    final dir = Directory(
      '${(await _root()).path}${Platform.pathSeparator}$key',
    );
    await dir.create(recursive: true);
    return dir;
  }

  String _localName(ChatMediaEntity media) {
    final name = ChatMediaPolicy.displayFileName(media.fileName);
    final ext = ChatMediaPolicy.extensionOf(name);
    if (ext.isNotEmpty) return name;
    final fallbackExt = ChatMediaPolicy.extensionOf(media.storagePath);
    return fallbackExt.isEmpty ? name : '$name.$fallbackExt';
  }

  /// Drops memory + disk copies (logout).
  Future<void> clear() async {
    _images.clear();
    _files.clear();
    try {
      final root = await _root();
      if (await root.exists()) await root.delete(recursive: true);
    } on Object {
      // Temp storage is OS-managed; a failed purge must not block logout.
    }
  }
}
