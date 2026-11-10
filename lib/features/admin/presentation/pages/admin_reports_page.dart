import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:printing/printing.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/exception.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/admin_reports_repository.dart';
import '../../domain/admin_reports.dart';
import '../../domain/entities/admin_payment_record.dart';
import '../admin_report_pdf.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';

typedef ReportFileSaver = Future<bool> Function(String fileName, Uint8List bytes);
typedef ReportPdfSharer = Future<void> Function(String fileName, Uint8List bytes);

/// Asks where to save; returns false when the user cancels.
Future<bool> saveReportFile(String fileName, Uint8List bytes) async {
  final ext = fileName.split('.').last;
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ التقرير',
    fileName: fileName,
    type: FileType.custom,
    allowedExtensions: [ext],
    bytes: bytes,
  );
  if (path == null) return false;
  // Mobile plugins write [bytes] themselves; desktop only returns the path.
  if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS)) {
    await File(path).writeAsBytes(bytes, flush: true);
  }
  return true;
}

Future<void> shareReportPdf(String fileName, Uint8List bytes) =>
    Printing.sharePdf(bytes: bytes, filename: fileName);

class AdminReportsPage extends StatefulWidget {
  final AdminReportsRepository? repository;
  final ReportFontLoader fontLoader;
  final ReportFileSaver saveFile;
  final ReportPdfSharer sharePdf;
  final DateTime Function() clock;

  const AdminReportsPage({
    super.key,
    this.repository,
    this.fontLoader = loadReportFonts,
    this.saveFile = saveReportFile,
    this.sharePdf = shareReportPdf,
    this.clock = DateTime.now,
  });

  @override
  State<AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  late final AdminReportsRepository _repo =
      widget.repository ??
      AdminReportsRepository(firestore: sl<FirebaseFirestore>());

  AdminReportType _type = AdminReportType.students;
  ReportRangePreset _preset = ReportRangePreset.thisMonth;
  late ReportRange _range = ReportRange.preset(_preset, widget.clock());
  String? _halaqaId;
  PaymentLedgerFilter _paymentFilter = PaymentLedgerFilter.all;

  ReportTable? _table;
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<AdminBloc>();
      if (bloc.state.rosterStatus != SectionStatus.loaded) {
        bloc.add(const LoadStudentRosterEvent());
      }
      if (bloc.state.teachersStatus != SectionStatus.loaded) {
        bloc.add(const LoadAllTeachersEvent());
      }
    });
  }

  void _changed(VoidCallback update) => setState(() {
    update();
    _table = null;
    _error = null;
  });

  Future<void> _pickCustomRange() async {
    final now = widget.clock();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _range.from, end: _range.to),
      helpText: 'اختر فترة التقرير',
    );
    if (picked == null) return;
    _changed(() {
      _preset = ReportRangePreset.custom;
      _range = ReportRange(picked.start, picked.end);
    });
  }

  Future<void> _generate() async {
    final problem = _range.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final state = context.read<AdminBloc>().state;
    if (_type == AdminReportType.students &&
        state.rosterStatus != SectionStatus.loaded) {
      setState(() => _error = 'قائمة الطلاب لم تُحمَّل بعد. أعد المحاولة بعد لحظات.');
      context.read<AdminBloc>().add(const LoadStudentRosterEvent());
      return;
    }
    if (_type == AdminReportType.teachers &&
        state.teachersStatus != SectionStatus.loaded) {
      setState(() => _error = 'قائمة المعلمين لم تُحمَّل بعد. أعد المحاولة بعد لحظات.');
      context.read<AdminBloc>().add(const LoadAllTeachersEvent());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _table = null;
    });
    try {
      final table = switch (_type) {
        AdminReportType.students => await () async {
          final data = await _repo.attendance(_range, halaqaId: _halaqaId);
          return buildStudentsReport(
            range: _range,
            roster: state.studentRoster,
            attendance: data.items,
            halaqaId: _halaqaId,
            truncated: data.truncated,
          );
        }(),
        AdminReportType.teachers => await () async {
          final data = await _repo.sessions(_range);
          return buildTeachersReport(
            range: _range,
            teachers: state.teachers,
            sessions: data.items,
            now: widget.clock(),
            truncated: data.truncated,
          );
        }(),
        AdminReportType.finance => await () async {
          final data = await _repo.payments(_range, filter: _paymentFilter);
          return buildFinanceReport(
            range: _range,
            payments: data.items,
            filter: _paymentFilter,
            truncated: data.truncated,
          );
        }(),
      };
      if (mounted) setState(() => _table = table);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportCsv(ReportTable table) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _exporting = true);
    try {
      final saved = await widget.saveFile(
        '${table.fileStem}.csv',
        Uint8List.fromList(utf8.encode(table.toCsv())),
      );
      if (saved && mounted) AppSnackBar.showSuccess(context, 'تم حفظ ملف CSV');
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'تعذر حفظ الملف');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf(ReportTable table) async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _exporting = true);
    try {
      final ReportFonts fonts;
      try {
        fonts = await widget.fontLoader();
      } catch (_) {
        if (mounted) AppSnackBar.showError(context, reportFontUnavailableMessage);
        return;
      }
      final bytes = await buildReportPdf(
        table,
        fonts: fonts,
        generatedAt: widget.clock(),
      );
      await widget.sharePdf('${table.fileStem}.pdf', bytes);
    } catch (_) {
      if (mounted) AppSnackBar.showError(context, 'تعذر إنشاء ملف PDF');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'مركز التقارير',
      subtitle: 'تقارير الطلاب والمعلمين والمالية بفترة زمنية',
      body: BlocBuilder<AdminBloc, AdminState>(
        buildWhen: (p, c) =>
            p.studentRoster != c.studentRoster || p.rosterStatus != c.rosterStatus,
        builder: (context, state) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const AdminSectionHeader(title: 'نوع التقرير'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in AdminReportType.values)
                  AdminFilterChip(
                    key: Key('report-type-${t.name}'),
                    label: t.label,
                    selected: _type == t,
                    onTap: () => _changed(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            const AdminSectionHeader(title: 'الفترة'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in ReportRangePreset.values)
                  AdminFilterChip(
                    key: Key('report-range-${p.name}'),
                    label: p.label,
                    selected: _preset == p,
                    onTap: p == ReportRangePreset.custom
                        ? _pickCustomRange
                        : () => _changed(() {
                            _preset = p;
                            _range = ReportRange.preset(p, widget.clock());
                          }),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _range.label,
              key: const Key('report-range-label'),
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            if (_type == AdminReportType.students)
              DropdownButtonFormField<String?>(
                key: const Key('report-halaqa'),
                initialValue: _halaqaId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'الحلقة'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('كل الحلقات')),
                  for (final h in state.studentRoster)
                    DropdownMenuItem(value: h.id, child: Text(h.name)),
                ],
                onChanged: (v) => _changed(() => _halaqaId = v),
              ),
            if (_type == AdminReportType.finance)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final f in PaymentLedgerFilter.values)
                    AdminFilterChip(
                      key: Key('report-payment-${f.name}'),
                      label: f.label,
                      selected: _paymentFilter == f,
                      onTap: () => _changed(() => _paymentFilter = f),
                    ),
                ],
              ),
            const SizedBox(height: 18),
            AppButton(
              key: const Key('report-generate'),
              label: _loading ? 'جارٍ إعداد التقرير...' : 'عرض التقرير',
              onPressed: _loading ? null : _generate,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('report-error'),
                style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
              ),
            ],
            if (_table != null) ...[
              const SizedBox(height: 18),
              _ReportPreview(table: _table!),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      key: const Key('report-export-csv'),
                      label: 'حفظ CSV',
                      onPressed: _exporting ? null : () => _exportCsv(_table!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AppButton(
                      key: const Key('report-export-pdf'),
                      label: 'PDF',
                      onPressed: _exporting ? null : () => _exportPdf(_table!),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportPreview extends StatelessWidget {
  final ReportTable table;
  const _ReportPreview({required this.table});

  static const previewRows = 20;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      key: const Key('report-preview'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(table.title, style: AppTextStyles.titleMedium),
          Text(
            [table.range.label, ...table.filters].join(' · '),
            style: AppTextStyles.labelSmall,
          ),
          if (table.truncated)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                ReportTable.truncatedNotice,
                key: const Key('report-truncated'),
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          const Divider(),
          for (final (k, v) in table.summary)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(k, style: AppTextStyles.labelMedium)),
                  Text(
                    v,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          if (table.rows.isEmpty)
            Text('لا توجد بيانات في هذه الفترة', style: AppTextStyles.bodyMedium)
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 32,
                dataRowMaxHeight: 40,
                columns: [
                  for (final h in table.headers)
                    DataColumn(
                      label: Text(h, style: AppTextStyles.labelMedium),
                    ),
                ],
                rows: [
                  for (final r in table.rows.take(previewRows))
                    DataRow(
                      cells: [
                        for (final c in r)
                          DataCell(Text(c, style: AppTextStyles.labelSmall)),
                      ],
                    ),
                ],
              ),
            ),
          if (table.rows.length > previewRows)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'يعرض أول $previewRows من ${table.rows.length} صفاً؛ '
                'الملف المصدَّر يحتوي على كل الصفوف.',
                style: AppTextStyles.labelSmall,
              ),
            ),
        ],
      ),
    );
  }
}
