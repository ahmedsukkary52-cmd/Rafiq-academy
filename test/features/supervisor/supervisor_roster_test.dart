import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/supervisor/domain/supervisor_roster.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/halaqa_students_summary_entity.dart';

HalaqaEntity _halaqa({
  required String id,
  required String name,
  List<String> studentIds = const [],
}) {
  return HalaqaEntity(
    id: id,
    name: name,
    teacherId: 't1',
    supervisorId: 'sup1',
    studentIds: studentIds,
    schedule: const [],
    meetingLink: '',
    status: 'active',
  );
}

void main() {
  group('SupervisorRoster', () {
    test('uniqueStudentIds dedupes across halaqat', () {
      final ids = SupervisorRoster.uniqueStudentIds([
        _halaqa(id: 'h1', name: 'A', studentIds: const ['s1', 's2']),
        _halaqa(id: 'h2', name: 'B', studentIds: const ['s2', 's3']),
      ]);
      expect(ids, ['s1', 's2', 's3']);
    });

    test('membershipHalaqaIds returns both for dual member', () {
      final memberships = SupervisorRoster.membershipHalaqaIds(
        halaqat: [
          _halaqa(id: 'h1', name: 'A', studentIds: const ['s1']),
          _halaqa(id: 'h2', name: 'B', studentIds: const ['s1']),
        ],
        studentId: 's1',
      );
      expect(memberships, ['h1', 'h2']);
    });

    test('mergeSummaries ORs isAtRisk and keeps dual halaqa labels', () {
      final rows = SupervisorRoster.mergeSummaries(
        halaqat: [
          _halaqa(id: 'h1', name: 'صباحي', studentIds: const ['s1']),
          _halaqa(id: 'h2', name: 'مسائي', studentIds: const ['s1']),
        ],
        byHalaqaId: {
          'h1': const [
            HalaqaStudentSummaryEntity(
              uid: 's1',
              name: 'أحمد',
              isAtRisk: false,
              attendancePercent: 90,
            ),
          ],
          'h2': const [
            HalaqaStudentSummaryEntity(
              uid: 's1',
              name: 'أحمد',
              isAtRisk: true,
              attendancePercent: 70,
            ),
          ],
        },
      );
      expect(rows, hasLength(1));
      expect(rows.first.isAtRisk, isTrue);
      expect(rows.first.halaqaIds, ['h1', 'h2']);
      expect(rows.first.isDualMember, isTrue);
    });
  });

  group('SupervisorMembershipFormValidation', () {
    final halaqat = [
      _halaqa(id: 'h1', name: 'A', studentIds: const ['s1']),
      _halaqa(id: 'h2', name: 'B', studentIds: const ['s1']),
      _halaqa(id: 'h3', name: 'C', studentIds: const []),
    ];

    test('register rejects when already at cap 2', () {
      expect(
        SupervisorMembershipFormValidation.registerError(
          studentId: 's1',
          targetHalaqaId: 'h3',
          assignedHalaqat: halaqat,
        ),
        contains('حلقتان'),
      );
    });

    test('register allows first membership into empty target', () {
      expect(
        SupervisorMembershipFormValidation.registerError(
          studentId: 's9',
          targetHalaqaId: 'h3',
          assignedHalaqat: halaqat,
        ),
        isNull,
      );
    });

    test('transfer move requires source membership', () {
      expect(
        SupervisorMembershipFormValidation.transferError(
          studentId: 's1',
          sourceHalaqaId: 'h3',
          targetHalaqaId: 'h3',
          assignedHalaqat: halaqat,
          isMove: true,
        ),
        isNotNull,
      );
    });

    test('add-second validates when under cap', () {
      final oneHalaqa = [
        _halaqa(id: 'h1', name: 'A', studentIds: const ['s2']),
        _halaqa(id: 'h3', name: 'C', studentIds: const []),
      ];
      expect(
        SupervisorMembershipFormValidation.transferError(
          studentId: 's2',
          sourceHalaqaId: null,
          targetHalaqaId: 'h3',
          assignedHalaqat: oneHalaqa,
          isMove: false,
        ),
        isNull,
      );
    });
  });
}
