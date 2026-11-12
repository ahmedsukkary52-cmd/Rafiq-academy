import '../../../shared/domain/payment_review_amounts.dart';
import '../../../shared/presentation/academy_currency_label.dart';
import '../data/staff_lifecycle_repository.dart' show StaffStatus;
import 'entities/admin_halaqa_roster_entity.dart';
import '../../../shared/domain/payment_status_label.dart';
import 'entities/admin_payment_record.dart';
import 'entities/teacher_management_entity.dart';

enum AdminReportType {
  students('الطلاب والحضور'),
  teachers('المعلمون والحصص'),
  finance('المالية');

  const AdminReportType(this.label);
  final String label;
}

enum ReportRangePreset {
  thisMonth('هذا الشهر'),
  lastMonth('الشهر الماضي'),
  last30Days('آخر 30 يوماً'),
  custom('فترة مخصصة');

  const ReportRangePreset(this.label);
  final String label;
}

String reportYmd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Inclusive calendar-day range.
class ReportRange {
  final DateTime from;
  final DateTime to;

  ReportRange(DateTime from, DateTime to)
    : from = DateTime(from.year, from.month, from.day),
      to = DateTime(to.year, to.month, to.day);

  static const maxDays = 366;

  factory ReportRange.preset(ReportRangePreset preset, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (preset) {
      ReportRangePreset.thisMonth || ReportRangePreset.custom => ReportRange(
        DateTime(today.year, today.month),
        today,
      ),
      ReportRangePreset.lastMonth => ReportRange(
        DateTime(today.year, today.month - 1),
        DateTime(today.year, today.month, 0),
      ),
      ReportRangePreset.last30Days => ReportRange(
        today.subtract(const Duration(days: 29)),
        today,
      ),
    };
  }

  DateTime get endExclusive => DateTime(to.year, to.month, to.day + 1);
  String get fromKey => reportYmd(from);
  String get toKey => reportYmd(to);
  int get days => endExclusive.difference(from).inDays;
  String get label => 'من $fromKey إلى $toKey';

  /// Arabic reason the range cannot be used, or null.
  String? get problem {
    if (to.isBefore(from)) return 'تاريخ النهاية قبل تاريخ البداية';
    if (days > maxDays) return 'أقصى مدة للتقرير سنة واحدة';
    return null;
  }

  bool contains(DateTime d) => !d.isBefore(from) && d.isBefore(endExclusive);
}

class ReportTable {
  final String title;
  final ReportRange range;
  final List<String> filters;
  final List<String> headers;
  final List<List<String>> rows;
  final List<(String, String)> summary;

  /// The source query hit its cap; totals cover only the rows read.
  final bool truncated;

  const ReportTable({
    required this.title,
    required this.range,
    this.filters = const [],
    required this.headers,
    required this.rows,
    this.summary = const [],
    this.truncated = false,
  });

  static const truncatedNotice =
      'تجاوزت البيانات الحد الأقصى للتقرير؛ ضيّق الفترة أو أضف عاملاً للتصفية';

  String get fileStem => 'rafiq_${_slug(title)}_${range.fromKey}_${range.toKey}';

  /// UTF-8 BOM so spreadsheet apps read Arabic correctly.
  String toCsv() {
    final lines = <List<String>>[
      [title],
      ['الفترة', range.label],
      for (final f in filters) ['التصفية', f],
      if (truncated) ['تنبيه', truncatedNotice],
      const [],
      headers,
      ...rows,
      if (summary.isNotEmpty) const [],
      for (final (k, v) in summary) [k, v],
    ];
    return '\uFEFF${lines.map((r) => r.map(_cell).join(',')).join('\r\n')}';
  }

  static String _cell(String v) =>
      v.contains(',') || v.contains('"') || v.contains('\n')
      ? '"${v.replaceAll('"', '""')}"'
      : v;

  static String _slug(String title) => switch (title) {
    _ when title.contains('الطلاب') => 'students',
    _ when title.contains('المعلم') => 'teachers',
    _ => 'finance',
  };
}

class AttendanceRow {
  final String studentId;
  final String halaqaId;
  final String status;
  final DateTime date;

  const AttendanceRow({
    required this.studentId,
    required this.halaqaId,
    required this.status,
    required this.date,
  });
}

class SessionRow {
  final String teacherId;
  final String status;
  final String date;

  const SessionRow({
    required this.teacherId,
    required this.status,
    required this.date,
  });
}

String _percent(int part, int whole) =>
    whole == 0 ? '—' : '${(part * 100 / whole).round()}%';

ReportTable buildStudentsReport({
  required ReportRange range,
  required List<AdminHalaqaRosterEntity> roster,
  required List<AttendanceRow> attendance,
  String? halaqaId,
  bool truncated = false,
}) {
  final counts = <String, Map<String, int>>{};
  for (final a in attendance) {
    if (!range.contains(a.date)) continue;
    final key = '${a.halaqaId}|${a.studentId}';
    final c = counts.putIfAbsent(key, () => {});
    c[a.status] = (c[a.status] ?? 0) + 1;
  }
  final halaqat = roster.where((h) => halaqaId == null || h.id == halaqaId);
  final rows = <List<String>>[];
  var present = 0, total = 0, students = 0;
  for (final h in halaqat) {
    for (final s in h.students) {
      final c = counts['${h.id}|${s.uid}'] ?? const {};
      final p = c['present'] ?? 0, l = c['late'] ?? 0;
      final ab = c['absent'] ?? 0, ex = c['excused'] ?? 0;
      final t = p + l + ab + ex;
      students++;
      present += p + l;
      total += t;
      rows.add([
        s.name,
        h.name,
        s.isActive ? 'نشط' : 'موقوف',
        '$p',
        '$l',
        '$ab',
        '$ex',
        _percent(p + l, t),
      ]);
    }
  }
  rows.sort((a, b) => a[0].compareTo(b[0]));
  final filterName = halaqaId == null
      ? null
      : roster.where((h) => h.id == halaqaId).map((h) => h.name).firstOrNull;
  return ReportTable(
    title: 'تقرير الطلاب والحضور',
    range: range,
    filters: [if (filterName != null) 'الحلقة: $filterName'],
    headers: const [
      'الطالب',
      'الحلقة',
      'الحالة',
      'حاضر',
      'متأخر',
      'غائب',
      'بعذر',
      'نسبة الحضور',
    ],
    rows: rows,
    summary: [
      ('عدد الطلاب', '$students'),
      ('سجلات الحضور في الفترة', '$total'),
      ('نسبة الحضور الإجمالية', _percent(present, total)),
    ],
    truncated: truncated,
  );
}

ReportTable buildTeachersReport({
  required ReportRange range,
  required List<TeacherManagementEntity> teachers,
  required List<SessionRow> sessions,
  required DateTime now,
  bool truncated = false,
}) {
  final today = reportYmd(now);
  final byTeacher = <String, Map<String, int>>{};
  for (final s in sessions) {
    if (s.date.compareTo(range.fromKey) < 0 || s.date.compareTo(range.toKey) > 0) {
      continue;
    }
    final bucket = switch (s.status) {
      'completed' => 'completed',
      'cancelled' => 'cancelled',
      _ when s.date.compareTo(today) < 0 => 'unrecorded',
      _ => 'upcoming',
    };
    final c = byTeacher.putIfAbsent(s.teacherId, () => {});
    c[bucket] = (c[bucket] ?? 0) + 1;
  }
  var completedAll = 0, heldOrDueAll = 0;
  final rows = <List<String>>[];
  for (final t in teachers) {
    final c = byTeacher[t.uid] ?? const {};
    final done = c['completed'] ?? 0, cancelled = c['cancelled'] ?? 0;
    final unrecorded = c['unrecorded'] ?? 0, upcoming = c['upcoming'] ?? 0;
    completedAll += done;
    heldOrDueAll += done + unrecorded;
    final rating = t.performanceRating;
    rows.add([
      t.name,
      StaffStatus.values
          .firstWhere(
            (s) => s.wire == t.staffStatus,
            orElse: () => StaffStatus.active,
          )
          .label,
      '${t.halaqatIds.length}',
      t.weeklyQuota > 0 ? '${t.weeklyQuota}' : 'غير محدد',
      rating == null ? 'لم يُحدد' : rating.toStringAsFixed(1),
      '$done',
      '$unrecorded',
      '$cancelled',
      '$upcoming',
      _percent(done, done + unrecorded),
    ]);
  }
  rows.sort((a, b) => a[0].compareTo(b[0]));
  return ReportTable(
    title: 'تقرير المعلمين والحصص',
    range: range,
    headers: const [
      'المعلم',
      'الحالة',
      'الحلقات',
      'النصاب الأسبوعي',
      'التقييم',
      'حصص مكتملة',
      'حصص لم تُسجَّل',
      'ملغاة',
      'قادمة',
      'نسبة الإنجاز',
    ],
    rows: rows,
    summary: [
      ('عدد المعلمين', '${teachers.length}'),
      ('الحصص المكتملة', '$completedAll'),
      ('نسبة الإنجاز الإجمالية', _percent(completedAll, heldOrDueAll)),
    ],
    truncated: truncated,
  );
}

ReportTable buildFinanceReport({
  required ReportRange range,
  required List<AdminPaymentRecord> payments,
  PaymentLedgerFilter filter = PaymentLedgerFilter.all,
  bool truncated = false,
}) {
  bool keep(AdminPaymentRecord p) => switch (filter) {
    PaymentLedgerFilter.all => true,
    PaymentLedgerFilter.awaitingReview => p.awaitingReview,
    PaymentLedgerFilter.due => p.status == 'due',
    PaymentLedgerFilter.overdue => p.status == 'overdue',
    PaymentLedgerFilter.paid => p.status == 'paid',
  };
  final list = payments
      .where((p) => p.dueDate != null && range.contains(p.dueDate!) && keep(p))
      .toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  var invoiced = 0.0, collected = 0.0, outstanding = 0.0, overdue = 0.0;
  var awaiting = 0;
  final rows = <List<String>>[];
  for (final p in list) {
    final confirmed = p.status == 'paid'
        ? p.amount
        : (p.amountPaidConfirmed ?? 0).clamp(0, p.amount).toDouble();
    final remaining = p.status == 'paid' ? 0.0 : p.amount - confirmed;
    invoiced += p.amount;
    collected += confirmed;
    outstanding += remaining;
    if (p.status == 'overdue') overdue += remaining;
    if (p.awaitingReview) awaiting++;
    rows.add([
      p.studentName,
      p.parentName,
      p.periodKey ?? '—',
      reportYmd(p.dueDate!),
      formatMoneyAmount(p.amount),
      formatMoneyAmount(confirmed),
      formatMoneyAmount(remaining),
      paymentStatusLabel(p.status),
      paymentReviewStatusLabel(p.reviewStatus),
      paymentMethodLabel(p.method),
    ]);
  }
  return ReportTable(
    title: 'التقرير المالي',
    range: range,
    filters: [
      if (filter != PaymentLedgerFilter.all) 'الحالة: ${filter.label}',
    ],
    headers: const [
      'الطالب',
      'ولي الأمر',
      'الفترة',
      'تاريخ الاستحقاق',
      'المبلغ ($academyCurrencyLabel)',
      'المحصّل ($academyCurrencyLabel)',
      'المتبقي ($academyCurrencyLabel)',
      'الحالة',
      'الإيصال',
      'وسيلة الدفع',
    ],
    rows: rows,
    summary: [
      ('عدد الفواتير', '${list.length}'),
      ('إجمالي المستحق', academyMoneyLabel(invoiced)),
      ('إجمالي المحصّل', academyMoneyLabel(collected)),
      ('المتبقي', academyMoneyLabel(outstanding)),
      ('منه متأخر', academyMoneyLabel(overdue)),
      ('إيصالات بانتظار المراجعة', '$awaiting'),
    ],
    truncated: truncated,
  );
}
