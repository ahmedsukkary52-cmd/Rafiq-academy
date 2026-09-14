import '../../../shared/domain/storage_paths_contract.dart';

String awardImageStoragePath({
  required String teacherId,
  required String extension,
  DateTime? now,
}) {
  final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final ext = extension.replaceAll('.', '').trim().toLowerCase();
  final safeExt = ext.isEmpty ? 'jpg' : ext;
  final tid = teacherId.trim();
  if (tid.isEmpty) {
    throw ArgumentError('teacherId is required for award image path');
  }
  return '${StoragePathsContract.awardsPrefix}/$tid/$ts.$safeExt';
}
