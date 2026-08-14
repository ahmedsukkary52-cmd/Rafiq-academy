String awardImageStoragePath({
  required String teacherId,
  required String extension,
  DateTime? now,
}) {
  final ts = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final ext = extension.replaceAll('.', '').trim().toLowerCase();
  final safeExt = ext.isEmpty ? 'jpg' : ext;
  return 'awards/$teacherId/$ts.$safeExt';
}
