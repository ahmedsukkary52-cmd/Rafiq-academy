import 'package:flutter/material.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// UI-only admin request (halaqa freeze / stop). No Firestore writes.
class SupervisorAdminRequestPage extends StatefulWidget {
  final String halaqaId;
  final String halaqaName;

  const SupervisorAdminRequestPage({
    super.key,
    required this.halaqaId,
    required this.halaqaName,
  });

  @override
  State<SupervisorAdminRequestPage> createState() =>
      _SupervisorAdminRequestPageState();
}

class _SupervisorAdminRequestPageState
    extends State<SupervisorAdminRequestPage> {
  final _reasonCtrl = TextEditingController();
  String _requestType = 'freeze';

  static const _types = <String, String>{
    'freeze': 'إيقاف / تجميد الحلقة',
    'reassign': 'إعادة تعيين معلم',
    'other': 'طلب آخر',
  };

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      AppSnackBar.showError(context, 'أدخل سبب الطلب');
      return;
    }
    AppSnackBar.showInfo(
      context,
      'سيتم إرسال الطلب للإدارة عند تفعيل مسار الإدارة',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'طلب للإدارة',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            widget.halaqaName,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'معرّف الحلقة: ${widget.halaqaId}',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'نوع الطلب',
            style: AppTextStyles.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in _types.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _requestType == entry.key,
                  onSelected: (_) => setState(() => _requestType = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'السبب',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: const Text('إرسال الطلب')),
        ],
      ),
    );
  }
}
