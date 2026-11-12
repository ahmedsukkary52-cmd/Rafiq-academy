import '../../../shared/domain/arabic_search_normalizer.dart';
import '../../awards/domain/entities/award_entities.dart';
import 'entities/admin_halaqa_roster_entity.dart';

/// One searchable student with every halaqa they belong to.
class RewardStudentOption {
  final String uid;
  final String name;
  final List<String> halaqaNames;

  const RewardStudentOption({
    required this.uid,
    required this.name,
    required this.halaqaNames,
  });

  String get displayName => name.trim().isEmpty ? 'طالب بدون اسم' : name.trim();

  String get halaqaContext =>
      halaqaNames.isEmpty ? 'بدون حلقة' : halaqaNames.join('، ');
}

List<RewardStudentOption> rewardStudentOptions(
  List<AdminHalaqaRosterEntity> roster,
) {
  final names = <String, String>{};
  final halaqat = <String, List<String>>{};
  for (final h in roster) {
    final halaqaName = h.name.trim().isEmpty ? 'حلقة بدون اسم' : h.name.trim();
    for (final s in h.students) {
      names.putIfAbsent(s.uid, () => s.name);
      final list = halaqat.putIfAbsent(s.uid, () => []);
      if (!list.contains(halaqaName)) list.add(halaqaName);
    }
  }
  final out = [
    for (final uid in names.keys)
      RewardStudentOption(
        uid: uid,
        name: names[uid]!,
        halaqaNames: halaqat[uid] ?? const [],
      ),
  ]..sort((a, b) => a.displayName.compareTo(b.displayName));
  return out;
}

List<RewardStudentOption> filterRewardStudents(
  List<RewardStudentOption> options,
  String query,
) {
  final q = ArabicSearchNormalizer.normalize(query);
  if (q.isEmpty) return options;
  return options
      .where((o) => ArabicSearchNormalizer.normalize(o.name).contains(q))
      .toList();
}

/// Labels for the form's reward types (`star`/`badge`/`certificate`).
String adminRewardFormTypeLabel(String type) => switch (type) {
  'star' => 'نجمة',
  'badge' => 'شارة',
  'certificate' => 'شهادة',
  _ => type,
};

class AdminRewardHistoryEntry {
  final String id;
  final String title;
  final String typeLabel;
  final String studentName;
  final String halaqaName;
  final int recipientCount;
  final String reason;
  final DateTime? date;

  const AdminRewardHistoryEntry({
    required this.id,
    required this.title,
    required this.typeLabel,
    required this.studentName,
    required this.halaqaName,
    required this.recipientCount,
    required this.reason,
    required this.date,
  });

  String get recipientLabel {
    if (recipientCount > 1) return '$recipientCount طالب';
    return studentName.isEmpty ? 'طالب' : studentName;
  }

  factory AdminRewardHistoryEntry.fromMap(
    String id,
    Map<String, dynamic> data, {
    required DateTime? date,
  }) {
    final rawCount = data['recipientCount'];
    final ids = data['recipientStudentIds'];
    final count = rawCount is num
        ? rawCount.toInt()
        : (ids is List ? ids.length : 1);
    String text(Object? v) => v is String ? v.trim() : '';
    final title = text(data['title']).isNotEmpty
        ? text(data['title'])
        : text(data['note']);
    return AdminRewardHistoryEntry(
      id: id,
      title: title.isEmpty ? 'جائزة بدون عنوان' : title,
      typeLabel: AwardTypeInfo.fromKey(text(data['type'])).title,
      studentName: text(data['studentName']),
      halaqaName: text(data['halaqaName']),
      recipientCount: count,
      reason: text(data['description']),
      date: date,
    );
  }
}
