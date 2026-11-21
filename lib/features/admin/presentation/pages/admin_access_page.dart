import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../bloc/admin_operations_bloc.dart';
import '../widgets/admin_operation_widgets.dart';

/// P0-02 — Admin reinstates a parent's app access after a payment block via
/// `adminReinstatePaymentAccess` (server writes the audit entry).
class AdminAccessPage extends StatelessWidget {
  const AdminAccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOperationsScaffold(
      title: 'إعادة تفعيل الوصول',
      builder: (context, state) => _AccessBody(state: state),
    );
  }
}

class _AccessBody extends StatefulWidget {
  final AdminOperationsState state;
  const _AccessBody({required this.state});

  @override
  State<_AccessBody> createState() => _AccessBodyState();
}

class _AccessBodyState extends State<_AccessBody> {
  final _reason = TextEditingController();
  String? _parentId;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parentId = _parentId;
    if (parentId == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تفعيل الوصول'),
        content: Text(
          'إعادة تفعيل وصول ${widget.state.nameOf(parentId)} للتطبيق رغم وجود مستحقات؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة التفعيل'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final reason = _reason.text.trim();
    context.read<AdminOperationsBloc>().add(
      ReinstateParentAccessEvent(
        parentId: parentId,
        reason: reason.isEmpty ? null : reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state.parents.isEmpty) {
      return const AppEmptyState(
        icon: Icons.family_restroom_rounded,
        title: 'لا يوجد أولياء أمور',
        message: 'أنشئ حساب ولي الأمر أولاً من «إنشاء حساب»',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'يُستخدم عندما يُوقف وصول ولي الأمر للتطبيق بسبب تأخر الدفع أو '
            'تعليق مؤقت. إعادة التفعيل تفتح التطبيق دون مسح الفواتير أو '
            'تغيير حالتها.',
            textAlign: TextAlign.right,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ),
        AdminSectionCard(
          title: 'ولي الأمر',
          subtitle: 'يُعاد الوصول دون تعديل الفواتير أو حالتها',
          children: [
            AdminUserDropdown(
              label: 'اختر ولي الأمر',
              users: state.parents,
              value: _parentId,
              onChanged: (v) => setState(() => _parentId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 300,
              decoration: const InputDecoration(labelText: 'السبب (اختياري)'),
            ),
            const SizedBox(height: 16),
            AdminSubmitButton(
              label: 'إعادة التفعيل',
              onPressed: _parentId == null ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}
