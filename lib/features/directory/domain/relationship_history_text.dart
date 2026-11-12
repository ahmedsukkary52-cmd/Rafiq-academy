/// Arabic sentence for one `relationshipHistory` entry. Ids are resolved to
/// names by the caller; an unresolved id renders as a neutral word, never as
/// the raw id.
String describeRelationshipEntry(
  Map<String, dynamic> entry, {
  required String Function(String uid) person,
  required String Function(String halaqaId) halaqa,
}) {
  String id(String field) => '${entry[field] ?? ''}'.trim();
  String p(String field) => id(field).isEmpty ? '' : person(id(field));
  String h(String field) => id(field).isEmpty ? '' : halaqa(id(field));

  final operation = '${entry['operation'] ?? ''}';
  switch ('${entry['kind'] ?? ''}') {
    case 'parent_child':
      return switch (operation) {
        'unlink' => 'إلغاء ربط ${p('studentId')} بولي الأمر ${p('parentId')}',
        'replace' =>
          'نقل ولاية ${p('studentId')} من ${p('previousParentId')} إلى ${p('parentId')}',
        _ => 'ربط ${p('studentId')} بولي الأمر ${p('parentId')}',
      };
    case 'halaqa_membership':
      return operation == 'transfer'
          ? 'نقل ${p('studentId')} من ${h('fromHalaqaId')} إلى ${h('toHalaqaId')}'
          : 'إضافة ${p('studentId')} إلى ${h('halaqaId')}';
    case 'halaqa_teacher':
      if (operation == 'create') {
        return 'إنشاء ${h('halaqaId')} بالمعلم ${p('staffId')}';
      }
      return id('previousStaffId').isEmpty
          ? 'إسناد ${h('halaqaId')} إلى المعلم ${p('staffId')}'
          : 'تغيير معلم ${h('halaqaId')} من ${p('previousStaffId')} إلى ${p('staffId')}';
    case 'halaqa_supervisor':
      if (operation == 'unassign') {
        return 'إلغاء إشراف ${p('previousStaffId')} على ${h('halaqaId')}';
      }
      return id('previousStaffId').isEmpty
          ? 'تعيين ${p('staffId')} مشرفاً على ${h('halaqaId')}'
          : 'تغيير مشرف ${h('halaqaId')} من ${p('previousStaffId')} إلى ${p('staffId')}';
    case 'halaqa_assistant':
      return operation == 'unassign'
          ? 'إلغاء تعيين ${p('staffId')} مساعداً في ${h('halaqaId')}'
          : 'تعيين ${p('staffId')} مساعداً في ${h('halaqaId')}';
    case 'halaqa_cover':
      return operation == 'end'
          ? 'انتهاء التغطية المؤقتة لـ${h('halaqaId')} (${p('staffId')})'
          : 'بدء تغطية مؤقتة لـ${h('halaqaId')} بواسطة ${p('staffId')}'
                '${id('previousStaffId').isEmpty ? '' : ' — المعلم الأساسي ${p('previousStaffId')} يبقى معلم الحلقة'}';
    default:
      return 'تغيير في العلاقات';
  }
}

/// Every id an entry refers to, split by what it names.
({Set<String> people, Set<String> halaqat}) relationshipEntryIds(
  Map<String, dynamic> entry,
) {
  final people = <String>{};
  final halaqat = <String>{};
  for (final f in const ['studentId', 'parentId', 'previousParentId', 'staffId', 'previousStaffId', 'actorId']) {
    final v = '${entry[f] ?? ''}'.trim();
    if (v.isNotEmpty) people.add(v);
  }
  for (final f in const ['halaqaId', 'fromHalaqaId', 'toHalaqaId']) {
    final v = '${entry[f] ?? ''}'.trim();
    if (v.isNotEmpty) halaqat.add(v);
  }
  return (people: people, halaqat: halaqat);
}
