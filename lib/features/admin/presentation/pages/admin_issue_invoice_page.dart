import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/admin_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../directory/data/academy_directory_repository.dart';
import '../../../directory/domain/directory_models.dart';
import '../../../directory/presentation/directory_pickers.dart';
import '../../domain/usecases/admin_billing_usecases.dart';

/// Admin issues a monthly invoice for one student via `adminGenerateInvoice`.
///
/// Requires an existing parent link and applicable pricing rule (callable).
class AdminIssueInvoicePage extends StatefulWidget {
  final AcademyDirectoryRepository? directoryRepository;
  final GenerateInvoiceUseCase? generateInvoice;

  const AdminIssueInvoicePage({
    super.key,
    this.directoryRepository,
    this.generateInvoice,
  });

  @override
  State<AdminIssueInvoicePage> createState() => _AdminIssueInvoicePageState();
}

class _AdminIssueInvoicePageState extends State<AdminIssueInvoicePage> {
  late final AcademyDirectoryRepository _directory =
      widget.directoryRepository ?? sl<AcademyDirectoryRepository>();
  late final GenerateInvoiceUseCase _generate =
      widget.generateInvoice ?? sl<GenerateInvoiceUseCase>();

  DirectoryPerson? _student;
  final _periodCtrl = TextEditingController();
  bool _submitting = false;
  String? _lastPaymentId;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodCtrl.text =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _periodCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStudent() async {
    final picked = await showPersonPicker(
      context,
      repository: _directory,
      role: DirectoryRole.student,
      title: 'اختر الطالب',
    );
    if (!mounted || picked == null) return;
    setState(() {
      _student = picked;
      _lastPaymentId = null;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final student = _student;
    if (student == null) {
      setState(() => _error = 'اختر طالباً أولاً');
      return;
    }
    final period = _periodCtrl.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(period)) {
      setState(() => _error = 'صيغة الفترة غير صحيحة (YYYY-MM)');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _lastPaymentId = null;
    });

    final result = await _generate(
      GenerateInvoiceParams(
        studentId: student.uid,
        periodKey: period,
      ),
    );
    if (!mounted) return;

    result.fold(
      (f) => setState(() {
        _submitting = false;
        _error = f.message;
      }),
      (paymentId) {
        setState(() {
          _submitting = false;
          _lastPaymentId = paymentId;
        });
        AppSnackBar.showSuccess(context, 'تم إصدار الفاتورة');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final student = _student;

    return AdminSubpageScaffold(
      title: 'إصدار فاتورة',
      subtitle: 'فاتورة شهرية لطالب مرتبط بولي أمر',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(
            'يُنشأ مستند دفع للفترة المحددة وفق قاعدة التسعير السارية. '
            'يجب أن يكون للطالب ولي أمر مرتبط.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 20),
          Text('الطالب', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('issue-invoice-pick-student'),
            onPressed: _submitting ? null : _pickStudent,
            icon: const Icon(Icons.person_search_outlined),
            label: Text(
              student == null
                  ? 'اختيار طالب من الدليل'
                  : student.displayName,
            ),
          ),
          if (student != null) ...[
            const SizedBox(height: 6),
            Text(
              student.caption,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.right,
            ),
          ],
          const SizedBox(height: 20),
          Text('فترة الفاتورة (YYYY-MM)', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          TextField(
            key: const Key('issue-invoice-period'),
            controller: _periodCtrl,
            enabled: !_submitting,
            textAlign: TextAlign.right,
            keyboardType: TextInputType.datetime,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\-]')),
              LengthLimitingTextInputFormatter(7),
            ],
            decoration: const InputDecoration(
              hintText: '2026-11',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            key: const Key('issue-invoice-submit'),
            label: _submitting ? 'جاري الإصدار...' : 'إصدار الفاتورة',
            onPressed: _submitting ? null : _submit,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Text(
                _error!,
                key: const Key('issue-invoice-error'),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.error,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
          if (_lastPaymentId != null) ...[
            const SizedBox(height: 16),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'تم الإنشاء بنجاح',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.success,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'معرّف الدفع: $_lastPaymentId',
                    key: const Key('issue-invoice-payment-id'),
                    style: AppTextStyles.labelSmall,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
