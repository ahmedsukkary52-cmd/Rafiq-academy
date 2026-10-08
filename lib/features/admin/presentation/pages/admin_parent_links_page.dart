import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../../domain/usecases/admin_operations_usecases.dart';
import '../bloc/admin_operations_bloc.dart';
import '../widgets/admin_operation_widgets.dart';

/// P0-01 — Admin links / unlinks a Parent and a Student through
/// `adminLinkParentChild` (parentProfiles.childrenIds is the D12 graph).
class AdminParentLinksPage extends StatelessWidget {
  const AdminParentLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOperationsScaffold(
      title: 'ربط ولي أمر بطالب',
      builder: (context, state) => _ParentLinkBody(state: state),
    );
  }
}

class _ParentLinkBody extends StatefulWidget {
  final AdminOperationsState state;
  const _ParentLinkBody({required this.state});

  @override
  State<_ParentLinkBody> createState() => _ParentLinkBodyState();
}

class _ParentLinkBodyState extends State<_ParentLinkBody> {
  String? _studentId;

  void _dispatch(String parentId, String studentId, ParentLinkOperation op) {
    context.read<AdminOperationsBloc>().add(
      LinkParentChildEvent(
        LinkParentChildParams(
          parentId: parentId,
          studentId: studentId,
          operation: op,
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(String parentId, String studentId) async {
    final state = widget.state;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('فك الربط'),
        content: Text(
          'سيتوقف وصول ${state.nameOf(parentId)} إلى بيانات '
          '${state.nameOf(studentId)}. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('فك الربط'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _dispatch(parentId, studentId, ParentLinkOperation.unlink);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final parentId = state.selectedParentId;
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
        AdminSectionCard(
          title: 'ولي الأمر',
          children: [
            AdminUserDropdown(
              label: 'اختر ولي الأمر',
              users: state.parents,
              value: parentId,
              onChanged: (v) {
                if (v == null) return;
                context.read<AdminOperationsBloc>().add(SelectParentEvent(v));
              },
            ),
          ],
        ),
        if (parentId != null) ...[
          const SizedBox(height: 12),
          AdminSectionCard(
            title: 'الأبناء المرتبطون',
            children: [
              if (state.selectedParentChildren.isEmpty)
                Text(
                  'لا يوجد أبناء مرتبطون بعد',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                for (final childId in state.selectedParentChildren)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.child_care_rounded),
                    title: Text(state.nameOf(childId)),
                    trailing: TextButton(
                      onPressed: () => _confirmUnlink(parentId, childId),
                      child: const Text('فك الربط'),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          AdminSectionCard(
            title: 'ربط طالب جديد',
            subtitle: 'الربط يمنح ولي الأمر صلاحية متابعة الطالب ومدفوعاته',
            children: [
              AdminUserDropdown(
                label: 'اختر الطالب',
                users: state.students
                    .where((s) => !state.selectedParentChildren.contains(s.uid))
                    .toList(),
                value: _studentId,
                onChanged: (v) => setState(() => _studentId = v),
              ),
              const SizedBox(height: 16),
              AdminSubmitButton(
                label: 'ربط',
                onPressed: _studentId == null
                    ? null
                    : () => _dispatch(
                        parentId,
                        _studentId!,
                        ParentLinkOperation.link,
                      ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
