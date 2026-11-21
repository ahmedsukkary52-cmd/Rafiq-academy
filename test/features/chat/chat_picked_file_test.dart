import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/chat/presentation/media/chat_picked_file.dart';

void main() {
  test('returns existing path when file is on disk', () async {
    final temp = await Directory.systemTemp.createTemp('basma_pick_exist_');
    addTearDown(() => temp.delete(recursive: true));
    final file = File('${temp.path}${Platform.pathSeparator}photo.jpg');
    await file.writeAsBytes([1, 2, 3], flush: true);

    final path = await resolveChatPickedLocalPath(
      PlatformFile(name: 'photo.jpg', size: 3, path: file.path),
    );
    expect(path, file.path);
  });

  test('materializes temp file from bytes when path is null', () async {
    Directory? created;
    final path = await resolveChatPickedLocalPath(
      PlatformFile(
        name: 'doc.pdf',
        size: 4,
        bytes: Uint8List.fromList([9, 8, 7, 6]),
      ),
      createTempDir: () async {
        created = await Directory.systemTemp.createTemp('basma_pick_bytes_');
        return created!;
      },
    );
    addTearDown(() async {
      if (created != null && await created!.exists()) {
        await created!.delete(recursive: true);
      }
    });

    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
    expect(await File(path).readAsBytes(), [9, 8, 7, 6]);
    expect(path.endsWith('doc.pdf'), isTrue);
  });

  test('returns null when path missing and bytes empty', () async {
    final path = await resolveChatPickedLocalPath(
      PlatformFile(name: 'empty.bin', size: 0),
    );
    expect(path, isNull);
  });
}
