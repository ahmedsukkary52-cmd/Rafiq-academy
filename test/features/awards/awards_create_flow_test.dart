import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/awards/data/award_image_storage_path.dart';
import 'package:rafiq_academy/features/awards/domain/award_recipient_selection.dart';
import 'package:rafiq_academy/features/awards/domain/entities/award_entities.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';
import 'package:rafiq_academy/features/student/domain/merge_student_achievements.dart';
import 'package:rafiq_academy/shared/data/achievements_firestore_contract.dart';

GrantedAwardEntity _grant({
  required String id,
  required DateTime at,
  String studentId = '',
  List<String> recipientIds = const [],
}) {
  return GrantedAwardEntity(
    id: id,
    studentId: studentId,
    studentName: 'n',
    type: AwardType.attendance,
    title: 'حضور مثالي',
    grantedBy: 't1',
    halaqaId: 'h1',
    grantedAt: at,
    recipientStudentIds: recipientIds,
    recipientCount: recipientIds.isEmpty
        ? (studentId.isEmpty ? 0 : 1)
        : recipientIds.length,
  );
}

void main() {
  group('AwardTypeInfo.fromKey', () {
    test('keeps legacy keys and maps unknown to custom', () {
      expect(AwardTypeInfo.fromKey('student_of_week'), AwardType.studentOfWeek);
      expect(AwardTypeInfo.fromKey('attendance'), AwardType.attendance);
      expect(AwardTypeInfo.fromKey('custom'), AwardType.custom);
      expect(AwardTypeInfo.fromKey('not_a_type'), AwardType.custom);
    });
  });

  group('computeAwardsStats', () {
    test('counts one multi-recipient grant as one award', () {
      final now = DateTime(2026, 8, 14);
      final stats = computeAwardsStats(
        [
          _grant(
            id: 'g1',
            at: DateTime(2026, 8, 2),
            recipientIds: const ['s1', 's2', 's3'],
          ),
          _grant(
            id: 'g2',
            at: DateTime(2026, 7, 1),
            studentId: 's1',
          ),
        ],
        now: now,
      );

      expect(stats.totalAwardsCount, 2);
      expect(stats.thisMonthCount, 1);
      expect(stats.totalRecipients, 3);
    });
  });

  group('mergeStudentAchievements', () {
    test('keeps legacy studentId docs and new recipient-array docs', () {
      final oldDoc = AchievementEntity(
        id: 'old',
        studentId: 's1',
        type: AchievementType.studentOfWeek,
        title: 'قديم',
        issuedBy: 't1',
        date: DateTime(2026, 7, 1),
      );
      final newDoc = AchievementEntity(
        id: 'new',
        studentId: 's2',
        type: AchievementType.attendance,
        title: 'جديد',
        issuedBy: 't1',
        date: DateTime(2026, 8, 1),
        recipientStudentIds: const ['s1', 's2'],
      );
      final duplicate = AchievementEntity(
        id: 'new',
        studentId: 's1',
        type: AchievementType.attendance,
        title: 'جديد مكرر',
        issuedBy: 't1',
        date: DateTime(2026, 8, 1),
        recipientStudentIds: const ['s1', 's2'],
      );

      final merged = mergeStudentAchievements([oldDoc, duplicate], [newDoc]);
      expect(merged.map((a) => a.id), ['new', 'old']);
    });
  });

  group('awardImageStoragePath', () {
    test('follows existing feature/uid/timestamp.ext pattern', () {
      expect(
        awardImageStoragePath(
          teacherId: 't1',
          extension: 'PNG',
          now: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
        'awards/t1/1000.png',
      );
    });
  });

  group('AchievementsFirestoreContract teacherGrantFields recipients', () {
    test('writes one payload with recipientStudentIds and separate description', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'attendance',
        title: 'حضور مثالي',
        description: 'للالتزام بالحضور طوال الشهر',
        grantedBy: 'teacher-1',
        halaqaId: 'h1',
        recipientStudentIds: const ['s1', 's2'],
      );

      expect(fields[AchievementsFirestoreContract.titleField], 'حضور مثالي');
      expect(fields[AchievementsFirestoreContract.noteField], 'حضور مثالي');
      expect(
        fields[AchievementsFirestoreContract.descriptionField],
        'للالتزام بالحضور طوال الشهر',
      );
      expect(
        fields[AchievementsFirestoreContract.recipientStudentIdsField],
        ['s1', 's2'],
      );
      expect(fields[AchievementsFirestoreContract.recipientCountField], 2);
      expect(fields[AchievementsFirestoreContract.halaqaIdField], 'h1');
      expect(fields[AchievementsFirestoreContract.halaqaIdsField], ['h1']);
      expect(fields[AchievementsFirestoreContract.grantedByField], 'teacher-1');
      expect(fields[AchievementsFirestoreContract.issuedByField], 'teacher-1');
      expect(
        fields[AchievementsFirestoreContract.grantedAtField],
        isA<FieldValue>(),
      );
    });
  });

  group('AwardRecipientSelection', () {
    const morning = AwardHalaqaOption(id: 'h-morning', name: 'حلقة الصباح');
    const evening = AwardHalaqaOption(id: 'h-evening', name: 'حلقة المساء');
    const review = AwardHalaqaOption(id: 'h-review', name: 'حلقة المراجعة');
    const teacherHalaqat = [morning, evening, review];

    final rosters = <String, List<AwardRecipientStudent>>{
      'h-morning': const [
        AwardRecipientStudent(uid: 's1', name: 'أحمد محمد'),
        AwardRecipientStudent(uid: 's2', name: 'محمد علي'),
      ],
      'h-evening': const [
        AwardRecipientStudent(uid: 's3', name: 'يوسف أحمد'),
        AwardRecipientStudent(uid: 's4', name: 'عمر خالد'),
        AwardRecipientStudent(uid: 's4', name: 'عمر خالد مكرر'),
      ],
      'h-review': const [
        AwardRecipientStudent(uid: 's5', name: 'محمود حسن'),
        AwardRecipientStudent(uid: 's6', name: 'علي أحمد'),
        AwardRecipientStudent(uid: 's1', name: 'أحمد محمد'),
      ],
    };

    test('toggles halaqa selection and tracks selected halaqa count', () {
      var selection = const AwardRecipientSelection();
      expect(selection.hasHalaqa, isFalse);
      expect(selection.selectedHalaqaCount, 0);

      selection = selection.toggleHalaqa(
        'h-evening',
        allHalaqaIds: teacherHalaqat.map((h) => h.id),
        rosters: rosters,
      );
      expect(selection.selectedHalaqaIds, {'h-evening'});
      expect(selection.selectedHalaqaCount, 1);

      selection = selection.toggleSelectAllHalaqat(
        allHalaqaIds: teacherHalaqat.map((h) => h.id),
        rosters: rosters,
      );
      expect(selection.selectedHalaqaCount, 3);

      selection = selection.toggleSelectAllHalaqat(
        allHalaqaIds: teacherHalaqat.map((h) => h.id),
        rosters: rosters,
      );
      expect(selection.hasHalaqa, isFalse);
      expect(selection.selectedHalaqaCount, 0);
    });

    test('filters student groups to selected halaqat only', () {
      final selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-evening', 'h-review'},
      );
      final groups = AwardRecipientSelection.visibleGroups(
        teacherHalaqat: teacherHalaqat,
        selectedHalaqaIds: selection.selectedHalaqaIds,
        rosters: rosters,
      );

      expect(groups.map((g) => g.halaqaId), ['h-evening', 'h-review']);
      expect(groups.first.students.map((s) => s.uid), ['s3', 's4']);
      expect(groups.last.students.map((s) => s.uid), ['s5', 's6', 's1']);
    });

    test('selects all current students of one halaqa', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-evening'},
      );
      selection = selection.toggleSelectAllInHalaqa('h-evening', rosters);

      expect(selection.selectedStudentIds, {'s3', 's4'});
      expect(selection.isHalaqaFullySelected('h-evening', rosters), isTrue);

      selection = selection.toggleStudent('s3');
      expect(selection.isHalaqaFullySelected('h-evening', rosters), isFalse);
      expect(selection.selectedStudentIds, {'s4'});
    });

    test('supports multiple halaqat with mixed student selection', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-evening', 'h-review'},
      );
      selection = selection.toggleSelectAllInHalaqa('h-evening', rosters);
      selection = selection.toggleStudent('s5');

      expect(selection.selectedHalaqaCount, 2);
      expect(selection.selectedStudentIds, {'s3', 's4', 's5'});
      expect(selection.uniqueRecipientIds(rosters), ['s3', 's4', 's5']);
    });

    test('global select all covers unique students across selected halaqat', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-morning', 'h-review'},
      );
      selection = selection.toggleSelectAllStudents(rosters);

      expect(selection.isGlobalAllSelected(rosters), isTrue);
      expect(selection.selectedStudentCount, 4);
      expect(selection.uniqueRecipientIds(rosters).toSet(), {
        's1',
        's2',
        's5',
        's6',
      });

      selection = selection.toggleStudent('s2');
      expect(selection.isGlobalAllSelected(rosters), isFalse);
      expect(selection.isHalaqaFullySelected('h-morning', rosters), isFalse);
    });

    test('selected student count matches unique resolved recipients', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-morning', 'h-review'},
      );
      selection = selection.toggleSelectAllStudents(rosters);

      expect(selection.selectedStudentCount, 4);
      expect(selection.resolvedRecipients(rosters).length, 4);
    });

    test('does not duplicate recipient IDs when a student appears twice', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-evening'},
      );
      selection = selection.toggleSelectAllInHalaqa('h-evening', rosters);

      expect(selection.uniqueRecipientIds(rosters), ['s3', 's4']);
      expect(selection.uniqueRecipientIds(rosters).toSet().length, 2);

      selection = selection.toggleHalaqa(
        'h-review',
        allHalaqaIds: teacherHalaqat.map((h) => h.id),
        rosters: rosters,
      );
      selection = selection.toggleSelectAllInHalaqa('h-review', rosters);
      final ids = selection.uniqueRecipientIds(rosters);
      expect(ids.toSet().length, ids.length);
      expect(ids.toSet(), {'s3', 's4', 's5', 's6', 's1'});
    });

    test('rejects grant when no halaqa or student is selected', () {
      expect(
        AwardRecipientSelection.canGrant(
          hasHalaqa: false,
          hasStudent: true,
          title: 'حضور مثالي',
        ),
        isFalse,
      );
      expect(
        AwardRecipientSelection.canGrant(
          hasHalaqa: true,
          hasStudent: false,
          title: 'حضور مثالي',
        ),
        isFalse,
      );
      expect(
        AwardRecipientSelection.canGrant(
          hasHalaqa: true,
          hasStudent: true,
          title: '  ',
        ),
        isFalse,
      );
      expect(
        AwardRecipientSelection.canGrant(
          hasHalaqa: true,
          hasStudent: true,
          title: 'حضور مثالي',
        ),
        isTrue,
      );
    });

    test('unchecking a halaqa drops students that are no longer visible', () {
      var selection = const AwardRecipientSelection(
        selectedHalaqaIds: {'h-evening', 'h-review'},
      );
      selection = selection.toggleSelectAllStudents(rosters);
      expect(selection.selectedStudentIds.contains('s3'), isTrue);
      expect(selection.selectedStudentIds.contains('s5'), isTrue);

      selection = selection.toggleHalaqa(
        'h-evening',
        allHalaqaIds: teacherHalaqat.map((h) => h.id),
        rosters: rosters,
      );
      expect(selection.selectedHalaqaIds, {'h-review'});
      expect(selection.selectedStudentIds.contains('s3'), isFalse);
      expect(selection.selectedStudentIds.contains('s5'), isTrue);
    });
  });

  group('multi-halaqa award persistence', () {
    test('single-halaqa award writes halaqaIds with one ID', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'attendance',
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h-morning',
        halaqaName: 'حلقة الصباح',
        halaqaIds: const ['h-morning'],
        halaqaNames: const ['حلقة الصباح'],
        recipientStudentIds: const ['s1'],
      );

      expect(fields[AchievementsFirestoreContract.halaqaIdField], 'h-morning');
      expect(fields[AchievementsFirestoreContract.halaqaIdsField], ['h-morning']);
      expect(fields[AchievementsFirestoreContract.halaqaNameField], 'حلقة الصباح');
      expect(
        fields[AchievementsFirestoreContract.halaqaNamesField],
        ['حلقة الصباح'],
      );
      expect(
        fields[AchievementsFirestoreContract.recipientStudentIdsField],
        ['s1'],
      );
    });

    test('multi-halaqa award persists every selected ID in one payload', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'attendance',
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h-morning',
        halaqaName: 'حلقة الصباح',
        halaqaIds: const ['h-morning', 'h-evening'],
        halaqaNames: const ['حلقة الصباح', 'حلقة المساء'],
        recipientStudentIds: const ['s1', 's3'],
      );

      expect(fields[AchievementsFirestoreContract.halaqaIdField], 'h-morning');
      expect(
        fields[AchievementsFirestoreContract.halaqaIdsField],
        ['h-morning', 'h-evening'],
      );
      expect(
        fields[AchievementsFirestoreContract.halaqaNamesField],
        ['حلقة الصباح', 'حلقة المساء'],
      );
      expect(
        fields[AchievementsFirestoreContract.recipientStudentIdsField],
        ['s1', 's3'],
      );
      expect(fields[AchievementsFirestoreContract.recipientCountField], 2);
      expect(fields.containsKey('recipientScope'), isFalse);
    });

    test('duplicate halaqa IDs are removed', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'attendance',
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h1',
        halaqaIds: const ['h1', 'h1', 'h2', 'h2', ''],
        recipientStudentIds: const ['s1'],
      );

      expect(
        fields[AchievementsFirestoreContract.halaqaIdsField],
        ['h1', 'h2'],
      );
    });

    test('legacy document without halaqaIds maps to [halaqaId]', () {
      final data = <String, dynamic>{
        'halaqaId': 'h-legacy',
        'halaqaName': 'حلقة قديمة',
        'studentId': 's1',
        'type': 'completion_badge',
      };

      expect(
        AchievementsFirestoreContract.resolveHalaqaIds(data),
        ['h-legacy'],
      );
      expect(
        AchievementsFirestoreContract.resolveHalaqaNames(data),
        ['حلقة قديمة'],
      );

      final legacy = _grant(id: 'old', at: DateTime(2026, 7, 1), studentId: 's1');
      expect(legacy.halaqaIds, isEmpty);
      expect(legacy.resolvedHalaqaIds, ['h1']);
      expect(legacy.belongsToHalaqa('h1'), isTrue);
      expect(legacy.belongsToHalaqa('h2'), isFalse);
    });

    test('multi-halaqa history displays all relevant halaqat', () {
      final award = GrantedAwardEntity(
        id: 'g1',
        studentId: 's1',
        studentName: 'n',
        type: AwardType.attendance,
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h-morning',
        halaqaName: 'حلقة الصباح',
        halaqaIds: const ['h-morning', 'h-evening'],
        halaqaNames: const ['حلقة الصباح', 'حلقة المساء'],
        grantedAt: DateTime(2026, 8, 14),
        recipientStudentIds: const ['s1', 's3'],
        recipientCount: 2,
      );

      expect(award.halaqaScopeLabel, 'حلقة الصباح + حلقة المساء');
      expect(award.halaqaName, 'حلقة الصباح');
    });

    test('stats/history do not treat a multi-halaqa award as only the first halaqa', () {
      final now = DateTime(2026, 8, 14);
      final multi = GrantedAwardEntity(
        id: 'multi',
        studentId: 's1',
        studentName: 'n',
        type: AwardType.attendance,
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h1',
        halaqaName: 'حلقة الصباح',
        halaqaIds: const ['h1', 'h2'],
        halaqaNames: const ['حلقة الصباح', 'حلقة المساء'],
        grantedAt: DateTime(2026, 8, 2),
        recipientStudentIds: const ['s1', 's2'],
        recipientCount: 2,
      );
      final onlyFirst = _grant(
        id: 'only-h1',
        at: DateTime(2026, 8, 3),
        studentId: 's9',
      );
      final all = [multi, onlyFirst];

      expect(multi.belongsToHalaqa('h1'), isTrue);
      expect(multi.belongsToHalaqa('h2'), isTrue);

      final forH1 = awardsForHalaqa(all, 'h1').toList();
      final forH2 = awardsForHalaqa(all, 'h2').toList();
      expect(forH1.map((g) => g.id), ['multi', 'only-h1']);
      expect(forH2.map((g) => g.id), ['multi']);

      expect(computeAwardsStats(forH1, now: now).totalAwardsCount, 2);
      expect(computeAwardsStats(forH2, now: now).totalAwardsCount, 1);

      final merged = mergeHalaqaScopedAwards(
        byHalaqaIdField: [onlyFirst],
        byHalaqaIdsField: [multi, onlyFirst],
        idOf: (grant) => grant.id,
        grantedAtOf: (grant) => grant.grantedAt,
      );
      expect(merged.map((g) => g.id), ['only-h1', 'multi']);
    });

    test('recipientStudentIds stay explicit and independent of halaqa scope', () {
      final fields = AchievementsFirestoreContract.teacherGrantFields(
        studentId: 's1',
        studentName: 'أحمد',
        type: 'attendance',
        title: 'حضور مثالي',
        grantedBy: 't1',
        halaqaId: 'h1',
        halaqaIds: const ['h1', 'h2'],
        recipientStudentIds: const ['s1'],
      );

      expect(
        fields[AchievementsFirestoreContract.recipientStudentIdsField],
        ['s1'],
      );
      expect(fields[AchievementsFirestoreContract.recipientCountField], 1);
      expect(
        fields[AchievementsFirestoreContract.halaqaIdsField],
        ['h1', 'h2'],
      );
    });
  });
}
