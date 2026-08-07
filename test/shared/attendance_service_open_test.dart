import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/entities/attendance_record_entity.dart';
import 'package:rafiq_academy/features/teacher/domain/repositories/teacher_repository.dart';
import 'package:rafiq_academy/shared/domain/attendance_service.dart';
import 'package:rafiq_academy/shared/utils/attendance_policy.dart';

void main() {
  const service = AttendanceService();
  const halaqaId = 'halaqa1';
  const sessionId = 'halaqa1_20260805';
  const studentId = 'student1';
  final wednesday = DateTime(2026, 8, 5, 10);

  HalaqaEntity halaqaWithWednesday() => const HalaqaEntity(
        id: halaqaId,
        name: 'حلقة',
        teacherId: 't1',
        supervisorId: 's1',
        studentIds: [studentId],
        schedule: [
          HalaqaScheduleEntity(
            day: 'الأربعاء',
            startTime: '10:00',
            endTime: '11:00',
          ),
        ],
        meetingLink: '',
        status: 'active',
      );

  AttendanceRecordEntity record({
    required String id,
    required AttendanceStatus status,
    required String sessionIdField,
    DateTime? date,
  }) {
    return AttendanceRecordEntity(
      id: id,
      studentId: studentId,
      studentName: 'طالب',
      halaqaId: halaqaId,
      date: date ?? DateTime(2026, 8, 5),
      status: status,
      recordedBy: 't1',
      sessionId: sessionIdField,
    );
  }

  group('AttendanceService.openRegister', () {
    test('defaults to today operational session when schedule matches', () {
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: const [],
        now: wednesday,
      );
      expect(open.sessionId, sessionId);
      expect(open.mode, AttendanceRegisterMode.create);
      expect(open.canEdit, isTrue);
      expect(open.sessionEndAt, DateTime(2026, 8, 5, 11));
    });

    test('create → edit when session marks exist', () {
      final preferred = AttendancePolicy.documentId(
        sessionId: sessionId,
        studentId: studentId,
      );
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: [
          record(
            id: preferred,
            status: AttendanceStatus.present,
            sessionIdField: sessionId,
          ),
        ],
        now: wednesday,
      );
      expect(open.mode, AttendanceRegisterMode.edit);
      expect(open.existingByStudentId[studentId], AttendanceStatus.present);
    });

    test('closed after schedule endAt — view-only', () {
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: const [],
        now: DateTime(2026, 8, 5, 11),
      );
      expect(open.canEdit, isFalse);
    });
  });

  group('AttendanceService.planSessionSave', () {
    test('uses sessionId_studentId document identity + mandatory sessionId', () {
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: const [],
        now: wednesday,
      );
      final result = service.planSessionSave(
        open: open,
        recordedBy: 'teacher1',
        rosterStudentIds: const [studentId, 'student2'],
        marks: const [
          AttendanceDraftMark(
            studentId: studentId,
            studentName: 'طالب',
            status: AttendanceStatus.late,
          ),
          AttendanceDraftMark(
            studentId: 'student2',
            studentName: 'آخر',
            status: AttendanceStatus.excused,
          ),
        ],
        now: wednesday,
      );

      expect(result.isReady, isTrue);
      final plan = result.plan!;
      expect(plan.sessionId, sessionId);
      expect(
        plan.records.map((r) => r.id).toSet(),
        {
          AttendancePolicy.documentId(
            sessionId: sessionId,
            studentId: studentId,
          ),
          AttendancePolicy.documentId(
            sessionId: sessionId,
            studentId: 'student2',
          ),
        },
      );
      expect(plan.records.every((r) => r.sessionId == sessionId), isTrue);
      expect(
        plan.records.firstWhere((r) => r.studentId == 'student2').status,
        AttendanceStatus.excused,
      );
      expect(
        plan.retireDocumentIds,
        contains(
          AttendancePolicy.legacyDocumentId(
            halaqaId: halaqaId,
            studentId: studentId,
            date: DateTime(2026, 8, 5),
          ),
        ),
      );
    });

    test('second save same session keeps same document id (update)', () {
      final preferred = AttendancePolicy.documentId(
        sessionId: sessionId,
        studentId: studentId,
      );
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: [
          record(
            id: preferred,
            status: AttendanceStatus.absent,
            sessionIdField: sessionId,
          ),
        ],
        now: wednesday,
      );
      expect(open.mode, AttendanceRegisterMode.edit);

      final result = service.planSessionSave(
        open: open,
        recordedBy: 'teacher1',
        rosterStudentIds: const [studentId],
        marks: const [
          AttendanceDraftMark(
            studentId: studentId,
            studentName: 'طالب',
            status: AttendanceStatus.present,
          ),
        ],
        now: wednesday,
      );
      expect(result.plan!.records.single.id, preferred);
      expect(result.plan!.records.single.status, AttendanceStatus.present);
    });

    test('blocks save after session closed', () {
      final open = service.openRegister(
        halaqaId: halaqaId,
        halaqa: halaqaWithWednesday(),
        existingRecords: const [],
        now: DateTime(2026, 8, 5, 10, 30),
      );
      final result = service.planSessionSave(
        open: open,
        recordedBy: 'teacher1',
        rosterStudentIds: const [studentId],
        marks: const [
          AttendanceDraftMark(
            studentId: studentId,
            studentName: 'طالب',
            status: AttendanceStatus.present,
          ),
        ],
        now: DateTime(2026, 8, 5, 11),
      );
      expect(result.blockReason, AttendanceSaveBlockReason.sessionClosed);
    });
  });

  group('AttendancePolicy session identity', () {
    test('documentId is sessionId_studentId', () {
      expect(
        AttendancePolicy.documentId(
          sessionId: sessionId,
          studentId: studentId,
        ),
        '${sessionId}_$studentId',
      );
    });

    test('excused is not attended and not absent', () {
      expect(AttendancePolicy.isAttendedStatus('excused'), isFalse);
      expect(AttendancePolicy.isAbsentStatus('excused'), isFalse);
      expect(AttendancePolicy.isExcusedStatus('excused'), isTrue);
      expect(
        AttendancePolicy.attendancePercentFromStatuses([
          'present',
          'excused',
          'absent',
        ]),
        50,
      );
    });
  });
}
