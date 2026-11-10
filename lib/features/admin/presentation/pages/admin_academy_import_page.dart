import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/academy_import_repository.dart';
import '../../domain/academy_import.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';

typedef PickedCsv = ({String name, String content});
typedef PickCsv = Future<PickedCsv?> Function();

Future<PickedCsv?> pickCsvFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['csv'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  final bytes = file?.bytes;
  if (file == null || bytes == null) return null;
  return (name: file.name, content: utf8.decode(bytes, allowMalformed: true));
}

/// Academy bulk import: template → file → validation preview → idempotent
/// row-by-row provisioning → report with one-time credentials.
class AdminAcademyImportPage extends StatefulWidget {
  const AdminAcademyImportPage({super.key, this.repository, this.pickFile});

  final AcademyImportRepository? repository;
  final PickCsv? pickFile;

  @override
  State<AdminAcademyImportPage> createState() => _AdminAcademyImportPageState();
}

class _AdminAcademyImportPageState extends State<AdminAcademyImportPage> {
  late final AcademyImportRepository _repo =
      widget.repository ??
      AcademyImportRepository(functions: sl<FirebaseFunctions>());

  PickedCsv? _file;
  ImportPlan? _plan;
  final Map<String, ImportRowOutcome> _outcomes = {};
  final List<ImportRowOutcome> _credentials = [];
  bool _running = false;
  int _done = 0;

  Future<void> _pick() async {
    final picked = await (widget.pickFile ?? pickCsvFile)();
    if (picked == null || !mounted) return;
    setState(() {
      _file = picked;
      _plan = validateAcademyImport(picked.content);
      _outcomes.clear();
      _credentials.clear();
      _done = 0;
    });
  }

  Future<void> _run() async {
    final plan = _plan;
    final file = _file;
    if (plan == null || file == null || plan.hasErrors) return;
    final importId = importRunId(file.content);
    setState(() {
      _running = true;
      _done = 0;
    });
    for (final row in plan.rows) {
      final previous = _outcomes[row.ref];
      if (previous != null && previous.status != ImportRowStatus.failed) {
        setState(() => _done++);
        continue;
      }
      final outcome = await _repo.importRow(importId, row);
      if (!mounted) return;
      setState(() {
        _outcomes[row.ref] = outcome;
        if (outcome.hasCredential) _credentials.add(outcome);
        _done++;
      });
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _copyTemplate() async {
    await Clipboard.setData(const ClipboardData(text: academyImportTemplate));
    if (mounted) AppSnackBar.showSuccess(context, 'تم نسخ القالب');
  }

  Future<void> _copyCredentials() async {
    final lines = [
      'الاسم,النوع,اسم المستخدم,كلمة المرور المؤقتة',
      for (final c in _credentials)
        '${c.row.name},${c.row.kind.label},${c.username},${c.temporaryPassword}',
    ];
    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (mounted) AppSnackBar.showSuccess(context, 'تم نسخ بيانات الدخول');
  }

  int _count(ImportRowStatus s) => _outcomes.values.where((o) => o.status == s).length;

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    final failed = _outcomes.values.where((o) => o.status == ImportRowStatus.failed).toList();
    final started = _outcomes.isNotEmpty;
    return AdminSubpageScaffold(
      title: 'استيراد بيانات الأكاديمية',
      subtitle: 'الحلقات والطاقم وأولياء الأمور والطلاب',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const AdminSectionHeader(title: '١. القالب'),
          const SizedBox(height: 8),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final line in academyImportGuide)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $line', style: AppTextStyles.labelMedium),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('import-copy-template'),
                  onPressed: _copyTemplate,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('نسخ القالب (CSV)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const AdminSectionHeader(title: '٢. الملف'),
          const SizedBox(height: 8),
          AppButton(
            key: const Key('import-pick'),
            label: _file == null ? 'اختيار ملف CSV' : 'تغيير الملف (${_file!.name})',
            onPressed: _running ? null : _pick,
            leading: const Icon(Icons.upload_file_rounded, color: Colors.white),
          ),
          if (plan != null) ...[
            const SizedBox(height: 16),
            const AdminSectionHeader(title: '٣. المعاينة'),
            const SizedBox(height: 8),
            _PlanSummary(plan: plan),
            if (plan.issues.isNotEmpty) ...[
              const SizedBox(height: 8),
              _IssueList(issues: plan.issues),
            ],
            const SizedBox(height: 12),
            AppButton(
              key: const Key('import-start'),
              label: started ? 'إعادة المحاولة للسجلات المتبقية' : 'بدء الاستيراد',
              isLoading: _running,
              onPressed: plan.hasErrors || plan.rows.isEmpty || _running
                  ? null
                  : _run,
            ),
            if (plan.hasErrors)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'صحّح الأخطاء في الملف ثم اختره مجدداً. لم يُنشأ أي سجل.',
                  key: const Key('import-blocked'),
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.error),
                ),
              ),
          ],
          if (_running || started) ...[
            const SizedBox(height: 16),
            const AdminSectionHeader(title: '٤. النتيجة'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: plan == null || plan.rows.isEmpty ? null : _done / plan.rows.length,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
            ),
            const SizedBox(height: 8),
            Text(
              'تم إنشاؤه: ${_count(ImportRowStatus.created)} · موجود سابقاً: ${_count(ImportRowStatus.existing)} · فشل: ${failed.length}',
              key: const Key('import-report'),
              style: AppTextStyles.bodyMedium,
            ),
            for (final o in failed)
              ListTile(
                key: Key('import-failed-${o.row.ref}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  o.retryable ? Icons.refresh_rounded : Icons.edit_note_rounded,
                  color: o.retryable ? AppColors.warning : AppColors.error,
                ),
                title: Text('${o.row.ref} · ${o.row.name}'),
                subtitle: Text(
                  '${o.message}\n${o.retryable ? 'يمكن إعادة المحاولة' : 'يحتاج تصحيحاً في الملف'}',
                ),
              ),
          ],
          if (_credentials.isNotEmpty) ...[
            const SizedBox(height: 16),
            const AdminSectionHeader(title: 'بيانات الدخول الجديدة'),
            const SizedBox(height: 4),
            Text(
              'تظهر كلمات المرور المؤقتة الآن فقط ولا تُحفظ. سلّمها لأصحابها؛ سيُطلب تغييرها عند أول دخول. عند فقدانها استخدم إعادة تعيين كلمة المرور من إدارة الحسابات.',
              style: AppTextStyles.labelMedium.copyWith(color: AppColors.warning),
            ),
            const SizedBox(height: 8),
            for (final c in _credentials)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${c.row.name} · ${c.row.kind.label}'),
                subtitle: SelectableText(
                  'اسم المستخدم: ${c.username}\nكلمة المرور المؤقتة: ${c.temporaryPassword}',
                  textDirection: TextDirection.rtl,
                ),
              ),
            OutlinedButton.icon(
              key: const Key('import-copy-credentials'),
              onPressed: _copyCredentials,
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text('نسخ بيانات الدخول'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.plan});
  final ImportPlan plan;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          for (final k in ImportRowKind.values)
            Text('${k.label}: ${plan.count(k)}', style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues});
  final List<ImportIssue> issues;

  @override
  Widget build(BuildContext context) {
    final errors = issues.where((i) => i.isError).length;
    return AppCard(
      key: const Key('import-issues'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'أخطاء: $errors · تنبيهات: ${issues.length - errors}',
            style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          for (final i in issues)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    i.isError ? Icons.error_outline : Icons.warning_amber_rounded,
                    size: 18,
                    color: i.isError ? AppColors.error : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      i.line > 0 ? 'السطر ${i.line}: ${i.message}' : i.message,
                      style: AppTextStyles.labelMedium,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
