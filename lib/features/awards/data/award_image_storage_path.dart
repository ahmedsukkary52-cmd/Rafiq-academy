import '../../../shared/domain/storage_paths_contract.dart';
import '../../../shared/domain/upload_file_policy.dart';

/// Award certificate images: JPEG / PNG / WebP under 10 MB (storage.rules).
const List<UploadFormat> awardImageFormats = UploadFilePolicy.imageFormats;

String awardImageStoragePath({
  required String teacherId,
  required String extension,
  DateTime? now,
}) {
  final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final ext = extension.replaceAll('.', '').trim().toLowerCase();
  if (UploadFilePolicy.formatFor('x.$ext', awardImageFormats) == null) {
    throw ArgumentError.value(extension, 'extension', 'unsupported image type');
  }
  final tid = teacherId.trim();
  if (tid.isEmpty) {
    throw ArgumentError('teacherId is required for award image path');
  }
  return '${StoragePathsContract.awardsPrefix}/$tid/$ts.$ext';
}
