import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/data/achievements_firestore_contract.dart';

void main() {
  group('AchievementsFirestoreContract (H7 / A-H7)', () {
    test('teacherGrantFields dual-writes actor, time, and title aliases', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'completion_badge',
        note: 'ختم جزء عمّ',
        grantedBy: 'teacher-1',
        halaqaId: 'h1',
      );

      expect(fields[AchievementsFirestoreContract.studentIdField], 's1');
      expect(fields[AchievementsFirestoreContract.halaqaIdField], 'h1');
      expect(fields[AchievementsFirestoreContract.halaqaIdsField], ['h1']);
      expect(fields[AchievementsFirestoreContract.typeField], 'completion_badge');
      expect(fields[AchievementsFirestoreContract.grantedByField], 'teacher-1');
      expect(fields[AchievementsFirestoreContract.issuedByField], 'teacher-1');
      expect(fields[AchievementsFirestoreContract.titleField], 'ختم جزء عمّ');
      expect(fields[AchievementsFirestoreContract.noteField], 'ختم جزء عمّ');
      expect(
        fields[AchievementsFirestoreContract.grantedAtField],
        isA<FieldValue>(),
      );
      expect(fields[AchievementsFirestoreContract.dateField], isA<FieldValue>());
    });

    test('supervisorIssueFields dual-writes actor, time, title, and halaqaId', () {
      final at = DateTime(2026, 7, 31, 10);
      final fields = AchievementsFirestoreContract.supervisorIssueFields(
        studentId: 's2',
        type: 'badge',
        title: 'شارة التميز',
        issuedBy: 'sup-1',
        halaqaId: 'h2',
        at: at,
      );

      expect(fields[AchievementsFirestoreContract.halaqaIdField], 'h2');
      expect(fields[AchievementsFirestoreContract.issuedByField], 'sup-1');
      expect(fields[AchievementsFirestoreContract.grantedByField], 'sup-1');
      expect(fields[AchievementsFirestoreContract.titleField], 'شارة التميز');
      expect(fields[AchievementsFirestoreContract.noteField], 'شارة التميز');
      expect(
        fields[AchievementsFirestoreContract.dateField],
        Timestamp.fromDate(at),
      );
      expect(
        fields[AchievementsFirestoreContract.grantedAtField],
        Timestamp.fromDate(at),
      );
    });

    test('resolve helpers tolerate legacy teacher-only docs', () {
      final at = DateTime(2026, 1, 2, 12);
      final data = <String, dynamic>{
        'note': 'من المعلم',
        'grantedBy': 't1',
        'grantedAt': Timestamp.fromDate(at),
        'type': 'completion_badge',
      };
      expect(AchievementsFirestoreContract.resolveTitle(data), 'من المعلم');
      expect(AchievementsFirestoreContract.resolveActor(data), 't1');
      expect(AchievementsFirestoreContract.resolveDate(data), at);
    });

    test('resolve helpers tolerate legacy supervisor-only docs', () {
      final at = DateTime(2026, 2, 3, 12);
      final data = <String, dynamic>{
        'title': 'من المشرف',
        'issuedBy': 'sv1',
        'date': Timestamp.fromDate(at),
        'type': 'star',
      };
      expect(AchievementsFirestoreContract.resolveTitle(data), 'من المشرف');
      expect(AchievementsFirestoreContract.resolveActor(data), 'sv1');
      expect(AchievementsFirestoreContract.resolveDate(data), at);
    });

    test('resolve prefers title/issuedBy/date when both shapes present', () {
      final preferred = DateTime(2026, 3, 4, 12);
      final other = DateTime(2026, 5, 6, 12);
      final data = <String, dynamic>{
        'title': 'عنوان',
        'note': 'ملاحظة',
        'issuedBy': 'issuer',
        'grantedBy': 'granter',
        'date': Timestamp.fromDate(preferred),
        'grantedAt': Timestamp.fromDate(other),
      };
      expect(AchievementsFirestoreContract.resolveTitle(data), 'عنوان');
      expect(AchievementsFirestoreContract.resolveActor(data), 'issuer');
      expect(AchievementsFirestoreContract.resolveDate(data), preferred);
    });
  });
}
