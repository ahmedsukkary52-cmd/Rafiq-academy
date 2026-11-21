import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Resolves a [PlatformFile] to a readable local path for upload.
///
/// On some platforms (notably web / certain Android gallery paths) [PlatformFile.path]
/// is null while [PlatformFile.bytes] is present. We materialize a temp file so
/// `putFile` can proceed without inventing a second upload API.
Future<String?> resolveChatPickedLocalPath(
  PlatformFile file, {
  Future<Directory> Function()? createTempDir,
  Future<void> Function(File file, List<int> bytes)? writeBytes,
}) async {
  final path = file.path?.trim();
  if (path != null && path.isNotEmpty) {
    final existing = File(path);
    if (await existing.exists()) return path;
  }

  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) return null;

  final dir = createTempDir != null
      ? await createTempDir()
      : await Directory.systemTemp.createTemp('basma_chat_pick_');
  final rawName = file.name.trim().isEmpty ? 'attachment.bin' : file.name.trim();
  final safeName = rawName.replaceAll(RegExp(r'[\\/]'), '_');
  final out = File('${dir.path}${Platform.pathSeparator}$safeName');
  if (writeBytes != null) {
    await writeBytes(out, bytes);
  } else {
    await out.writeAsBytes(Uint8List.fromList(bytes), flush: true);
  }
  return out.path;
}
