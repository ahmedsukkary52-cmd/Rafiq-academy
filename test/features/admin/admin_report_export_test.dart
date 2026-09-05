import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/admin/domain/entities/academy_stats_entity.dart';
import 'package:rafiq_academy/features/admin/domain/entities/complaint_entity.dart';
import 'package:rafiq_academy/features/admin/presentation/admin_report_export.dart';

void main() {
  group('AdminReportExport', () {
    test('buildCsvRows for students includes stats', () {
      final rows = AdminReportExport.buildCsvRows(
        kind: AdminReportKind.students,
        stats: const AcademyStatsEntity(
          totalStudents: 10,
          totalTeachers: 2,
          totalHalaqat: 3,
          overallAttendancePercent: 0,
          totalVersesMemorizedThisMonth: 0,
        ),
      );
      expect(rows.length, greaterThan(1));
      expect(rows[1][1], '10');
    });

    test('toCsv escapes commas', () {
      final csv = AdminReportExport.toCsv([
        ['a', 'b,c'],
      ]);
      expect(csv, contains('"b,c"'));
    });
  });

  group('ComplaintEntity workflow', () {
    test('isOpen excludes resolved and archived', () {
      final open = ComplaintEntity(
        id: '1',
        senderId: 's',
        senderRole: 'parent',
        subject: 'x',
        message: 'm',
        status: ComplaintStatuses.open,
        createdAt: _epoch,
      );
      expect(open.isOpen, isTrue);

      final archived = ComplaintEntity(
        id: '2',
        senderId: 's',
        senderRole: 'parent',
        subject: 'x',
        message: 'm',
        status: ComplaintStatuses.archived,
        createdAt: _epoch,
      );
      expect(archived.isOpen, isFalse);
    });
  });
}

final _epoch = DateTime(2026, 1, 1);
