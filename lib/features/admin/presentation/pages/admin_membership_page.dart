import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../domain/usecases/admin_operations_usecases.dart';
import '../bloc/admin_operations_bloc.dart';
import '../widgets/admin_operation_widgets.dart';

/// PH-02 membership callables from the Admin UI (P0-02): admission via
/// `admitStudentToHalaqa` (max-2 cap) and transfer via `adminTransferStudent`.
class AdminMembershipPage extends StatelessWidget {
  const AdminMembershipPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminOperationsScaffold(
      title: 'قبول ونقل الطلاب',
      builder: (context, state) => _MembershipBody(state: state),
    );
  }
}

class _MembershipBody extends StatefulWidget {
  final AdminOperationsState state;
  const _MembershipBody({required this.state});

  @override
  State<_MembershipBody> createState() => _MembershipBodyState();
}

class _MembershipBodyState extends State<_MembershipBody> {
  String? _admitStudent;
  String? _admitHalaqa;
  String? _moveStudent;
  String? _fromHalaqa;
  String? _toHalaqa;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final current = _moveStudent == null
        ? const []
        : state.halaqatOf(_moveStudent!);
    final admitMemberships = _admitStudent == null
        ? const []
        : state.halaqatOf(_admitStudent!);

    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        AdminSectionCard(
          title: 'إضافة طالب إلى حلقة',
          subtitle: 'الحد الأقصى حلقتان لكل طالب (يتحقق منه الخادم)',
          children: [
            AdminUserDropdown(
              label: 'الطالب',
              users: state.students,
              value: _admitStudent,
              onChanged: (v) => setState(() => _admitStudent = v),
            ),
            if (admitMemberships.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'عضو حالياً في: ${admitMemberships.map((h) => h.name).join('، ')}',
                style: AppTextStyles.labelSmall,
              ),
            ],
            const SizedBox(height: 12),
            AdminHalaqaDropdown(
              label: 'الحلقة',
              halaqat: state.halaqat,
              value: _admitHalaqa,
              onChanged: (v) => setState(() => _admitHalaqa = v),
            ),
            const SizedBox(height: 16),
            AdminSubmitButton(
              label: 'إضافة',
              onPressed: _admitStudent == null || _admitHalaqa == null
                  ? null
                  : () => context.read<AdminOperationsBloc>().add(
                      AdmitStudentEvent(
                        studentId: _admitStudent!,
                        halaqaId: _admitHalaqa!,
                      ),
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AdminSectionCard(
          title: 'نقل طالب بين الحلقات',
          children: [
            AdminUserDropdown(
              label: 'الطالب',
              users: state.students,
              value: _moveStudent,
              onChanged: (v) => setState(() {
                _moveStudent = v;
                _fromHalaqa = null;
              }),
            ),
            const SizedBox(height: 12),
            AdminHalaqaDropdown(
              label: 'من حلقة',
              halaqat: [...current],
              value: _fromHalaqa,
              onChanged: (v) => setState(() => _fromHalaqa = v),
            ),
            const SizedBox(height: 12),
            AdminHalaqaDropdown(
              label: 'إلى حلقة',
              halaqat: state.halaqat.where((h) => h.id != _fromHalaqa).toList(),
              value: _toHalaqa,
              onChanged: (v) => setState(() => _toHalaqa = v),
            ),
            const SizedBox(height: 16),
            AdminSubmitButton(
              label: 'نقل',
              onPressed:
                  _moveStudent == null ||
                      _fromHalaqa == null ||
                      _toHalaqa == null
                  ? null
                  : () => context.read<AdminOperationsBloc>().add(
                      TransferStudentEvent(
                        TransferStudentParams(
                          studentId: _moveStudent!,
                          fromHalaqaId: _fromHalaqa!,
                          toHalaqaId: _toHalaqa!,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
