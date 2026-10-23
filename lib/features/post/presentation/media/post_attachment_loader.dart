import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/error/failure.dart';
import '../../domain/entities/posts_entities.dart';
import '../../domain/usecases/posts_usecases.dart';

typedef PostTempDirectoryProvider = Future<Directory> Function();

/// Session cache for post attachments fetched through Storage Rules (no
/// stored download URLs). Cleared on logout so the next account on a shared
/// device cannot open the previous account's files.
@lazySingleton
class PostAttachmentLoader {
  final DownloadPostAttachmentUseCase download;
  final PostTempDirectoryProvider _tempDirectory;

  final Map<String, File> _files = {};
  final Map<String, Future<Either<Failure, File>>> _inFlight = {};

  PostAttachmentLoader(
    this.download, {
    @ignoreParam PostTempDirectoryProvider? tempDirectory,
  }) : _tempDirectory = tempDirectory ?? getTemporaryDirectory;

  Future<Either<Failure, File>> localFile(
    PostEntity post,
    PostAttachmentEntity attachment,
  ) async {
    final key = attachment.storagePath;
    final cached = _files[key];
    if (cached != null && await cached.exists()) return Right(cached);

    return _inFlight.putIfAbsent(key, () async {
      try {
        final File file;
        try {
          final dir = await _attachmentDirectory(key);
          file = File(
            '${dir.path}${Platform.pathSeparator}${_localName(attachment)}',
          );
        } on FileSystemException {
          return const Left(ServerFailure('تعذر حفظ الملف على الجهاز'));
        }
        final result = await download(
          DownloadPostAttachmentParams(
            post: post,
            attachment: attachment,
            target: file,
          ),
        );
        return result.map((_) {
          _files[key] = file;
          return file;
        });
      } finally {
        _inFlight.remove(key);
      }
    });
  }

  Future<Directory> _root() async {
    final base = await _tempDirectory();
    return Directory('${base.path}${Platform.pathSeparator}post_attachments');
  }

  Future<Directory> _attachmentDirectory(String storagePath) async {
    final key = base64Url.encode(utf8.encode(storagePath)).replaceAll('=', '');
    final dir = Directory(
      '${(await _root()).path}${Platform.pathSeparator}$key',
    );
    await dir.create(recursive: true);
    return dir;
  }

  /// Display name without path separators, keeping the stored extension so
  /// external viewers detect the type.
  String _localName(PostAttachmentEntity attachment) {
    final ext = attachment.storagePath.split('.').last;
    var name = attachment.fileName
        .replaceAll(RegExp(r'[\\/\u0000-\u001f\u007f]'), '_')
        .trim();
    if (name.isEmpty || name == '.' || name == '..') name = 'attachment';
    return name.toLowerCase().endsWith('.$ext') ? name : '$name.$ext';
  }

  /// Drops disk copies (logout).
  Future<void> clear() async {
    _files.clear();
    try {
      final root = await _root();
      if (await root.exists()) await root.delete(recursive: true);
    } on Object {
      // Temp storage is OS-managed; a failed purge must not block logout.
    }
  }
}
