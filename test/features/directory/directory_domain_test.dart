import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/directory/domain/directory_models.dart';
import 'package:rafiq_academy/features/directory/domain/relationship_history_text.dart';

void main() {
  test('academy codes are normalized; other text is not a code', () {
    expect(normalizeAcademyRef('s3'), 'S-003');
    expect(normalizeAcademyRef(' S-003 '), 'S-003');
    expect(normalizeAcademyRef('p 12'), 'P-012');
    expect(normalizeAcademyRef('H-1'), 'H-001');
    expect(normalizeAcademyRef('عمر'), isNull);
    expect(normalizeAcademyRef('ST-3'), isNull);
    expect(normalizeAcademyRef(''), isNull);
  });

  test('people are captioned by role and code, never by id', () {
    const p = DirectoryPerson(uid: 'uid-xyz', name: 'عمر أحمد', role: 'student', academyRef: 'S-003');
    expect(p.caption, 'طالب · S-003');
    const a = DirectoryPerson(uid: 'uid-a', name: '', role: 'assistant_teacher');
    expect(a.displayName, 'مساعد مدرس');
    expect(a.caption, 'مساعد مدرس');
    expect(DirectoryRole.fromWire('assistant_teacher'), DirectoryRole.assistant);
    expect(DirectoryRole.fromWire('owner'), isNull);
  });

  group('relationship history sentences', () {
    String person(String id) => const {
      'p1': 'محمد أحمد',
      'p2': 'علي حسن',
      's3': 'عمر أحمد',
      't1': 'أحمد علي',
      't2': 'خالد حسن',
      'a1': 'خالد سعيد',
      'v1': 'سعيد عمر',
    }[id] ?? 'حساب';
    String halaqa(String id) => const {'h1': 'حلقة الفجر', 'h2': 'حلقة العصر'}[id] ?? 'حلقة';
    String d(Map<String, dynamic> e) => describeRelationshipEntry(e, person: person, halaqa: halaqa);

    test('every kind written by the backend has a readable sentence', () {
      expect(d({'kind': 'parent_child', 'operation': 'link', 'parentId': 'p1', 'studentId': 's3'}),
          'ربط عمر أحمد بولي الأمر محمد أحمد');
      expect(
        d({'kind': 'parent_child', 'operation': 'replace', 'parentId': 'p2', 'previousParentId': 'p1', 'studentId': 's3'}),
        'نقل ولاية عمر أحمد من محمد أحمد إلى علي حسن',
      );
      expect(d({'kind': 'halaqa_membership', 'operation': 'admit', 'halaqaId': 'h1', 'studentId': 's3'}),
          'إضافة عمر أحمد إلى حلقة الفجر');
      expect(
        d({'kind': 'halaqa_membership', 'operation': 'transfer', 'fromHalaqaId': 'h1', 'toHalaqaId': 'h2', 'studentId': 's3'}),
        'نقل عمر أحمد من حلقة الفجر إلى حلقة العصر',
      );
      expect(
        d({'kind': 'halaqa_teacher', 'operation': 'assign', 'halaqaId': 'h1', 'staffId': 't2', 'previousStaffId': 't1'}),
        'تغيير معلم حلقة الفجر من أحمد علي إلى خالد حسن',
      );
      expect(d({'kind': 'halaqa_supervisor', 'operation': 'unassign', 'halaqaId': 'h1', 'previousStaffId': 'v1'}),
          'إلغاء إشراف سعيد عمر على حلقة الفجر');
      expect(d({'kind': 'halaqa_assistant', 'operation': 'assign', 'halaqaId': 'h1', 'staffId': 'a1'}),
          'تعيين خالد سعيد مساعداً في حلقة الفجر');
      expect(
        d({'kind': 'halaqa_cover', 'operation': 'start', 'halaqaId': 'h1', 'staffId': 'a1', 'previousStaffId': 't1'}),
        'بدء تغطية مؤقتة لـحلقة الفجر بواسطة خالد سعيد — المعلم الأساسي أحمد علي يبقى معلم الحلقة',
      );
      expect(d({'kind': 'halaqa_cover', 'operation': 'end', 'halaqaId': 'h1', 'staffId': 'a1'}),
          'انتهاء التغطية المؤقتة لـحلقة الفجر (خالد سعيد)');
    });

    test('unresolved ids render as neutral words, never raw', () {
      final s = d({'kind': 'parent_child', 'operation': 'link', 'parentId': 'zzUid9', 'studentId': 'qqUid7'});
      expect(s, isNot(contains('zzUid9')));
      expect(s, isNot(contains('qqUid7')));
      expect(d({'kind': 'unknown'}), 'تغيير في العلاقات');
    });

    test('entry ids are split into people and halaqat for name lookup', () {
      final ids = relationshipEntryIds({
        'kind': 'halaqa_cover',
        'halaqaId': 'h1',
        'staffId': 'a1',
        'previousStaffId': 't1',
        'actorId': 'ad1',
        'coverId': 'c1',
      });
      expect(ids.people, {'a1', 't1', 'ad1'});
      expect(ids.halaqat, {'h1'});
    });
  });
}
