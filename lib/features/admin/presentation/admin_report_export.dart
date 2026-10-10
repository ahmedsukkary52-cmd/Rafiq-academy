import '../domain/entities/academy_stats_entity.dart';
import '../domain/entities/complaint_entity.dart';
import '../domain/entities/financial_summary_entity.dart';
import '../domain/entities/teacher_management_entity.dart';

enum AdminReportKind { students, teachers, finance }

/// Client-side report rows — no backend generation (Admin Option A).
class AdminReportExport {
  const AdminReportExport._();

  static List<List<String>> buildCsvRows({
    required AdminReportKind kind,
    AcademyStatsEntity? stats,
    FinancialSummaryEntity? finance,
    List<ComplaintEntity>? complaints,
    List<TeacherManagementEntity>? teachers,
  }) {
    return switch (kind) {
      AdminReportKind.students => [
        ['المؤشر', 'القيمة'],
        ['إجمالي الطلاب', '${stats?.totalStudents ?? 0}'],
        ['إجمالي الحلقات', '${stats?.totalHalaqat ?? 0}'],
      ],
      AdminReportKind.teachers => [
        ['المعلم', 'الحلقات', 'التقييم', 'النصاب'],
        ...?teachers?.map(
          (t) => [
            t.name,
            '${t.halaqatIds.length}',
            '${t.performanceRating ?? '—'}',
            '${t.weeklyQuota}',
          ],
        ),
      ],
      AdminReportKind.finance => [
        ['البند', 'المبلغ (ر.س)', 'العدد'],
        [
          'مدفوع',
          '${finance?.totalRevenue.round() ?? 0}',
          '${finance?.paidCount ?? 0}',
        ],
        [
          'معلق',
          '${finance?.totalPending.round() ?? 0}',
          '${finance?.dueCount ?? 0}',
        ],
        [
          'متأخر',
          '${finance?.totalOverdue.round() ?? 0}',
          '${finance?.overdueCount ?? 0}',
        ],
      ],
    };
  }

  static String toCsv(List<List<String>> rows) {
    return rows.map((row) => row.map(_escapeCsvCell).join(',')).join('\n');
  }

  static String _escapeCsvCell(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }
}
