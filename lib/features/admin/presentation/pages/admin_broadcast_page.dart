import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/admin_broadcast_form.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';

class AdminBroadcastPage extends StatefulWidget {
  const AdminBroadcastPage({super.key});

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetRole = 'all';
  String? _fieldError;

  static const _audienceTiles = [
    (AppRoles.parent, Icons.groups_outlined, 'أولياء الأمور'),
    (AppRoles.student, Icons.school_outlined, 'الطلاب'),
    (AppRoles.teacher, Icons.menu_book_outlined, 'المعلمون'),
    (AppRoles.supervisor, Icons.shield_outlined, 'المشرفون'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final submitting =
        context.read<AdminBloc>().state.broadcastStatus ==
        SubmissionStatus.submitting;
    if (submitting) return;

    final error = AdminBroadcastFormValidation.error(
      title: _titleCtrl.text,
      body: _bodyCtrl.text,
      targetRole: _targetRole,
    );
    setState(() => _fieldError = error);
    if (error != null) return;

    context.read<AdminBloc>().add(
      SendBroadcastNotificationEvent(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        targetRole: _targetRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminBloc, AdminState>(
      listenWhen: (p, c) => p.broadcastStatus != c.broadcastStatus,
      listener: (context, state) {
        if (state.broadcastStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم إرسال البث');
          context.read<AdminBloc>().add(const ResetBroadcastEvent());
          _titleCtrl.clear();
          _bodyCtrl.clear();
          setState(() {
            _targetRole = 'all';
            _fieldError = null;
          });
        } else if (state.broadcastStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.broadcastError ?? 'تعذر إرسال البث',
          );
          context.read<AdminBloc>().add(const ResetBroadcastEvent());
        }
      },
      child: AdminSubpageScaffold(
        title: 'مركز البث الجماعي',
        subtitle: 'بث جديد',
        body: BlocBuilder<AdminBloc, AdminState>(
          buildWhen: (p, c) => p.broadcastStatus != c.broadcastStatus,
          builder: (context, state) {
            final submitting =
                state.broadcastStatus == SubmissionStatus.submitting;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                Text(
                  'اختر الجمهور المستهدف',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: [
                    for (final t in _audienceTiles)
                      AdminAudienceTile(
                        icon: t.$2,
                        label: t.$3,
                        selected: _targetRole == t.$1,
                        onTap: submitting
                            ? null
                            : () => setState(() => _targetRole = t.$1),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                AdminAudienceTile(
                  icon: Icons.flag_outlined,
                  label: 'الأكاديمية بالكامل',
                  selected: _targetRole == 'all',
                  selectedColor: AppColors.secondary,
                  fullWidth: true,
                  onTap: submitting
                      ? null
                      : () => setState(() => _targetRole = 'all'),
                ),
                const SizedBox(height: 20),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'محتوى البث',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _titleCtrl,
                        enabled: !submitting,
                        decoration: const InputDecoration(
                          labelText: 'عنوان البث',
                          hintText: 'مثال: تذكير باختبار الحفظ',
                        ),
                        onChanged: (_) {
                          if (_fieldError != null) {
                            setState(() => _fieldError = null);
                          }
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _bodyCtrl,
                        enabled: !submitting,
                        minLines: 4,
                        maxLines: 6,
                        decoration: const InputDecoration(
                          labelText: 'نص الرسالة',
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) {
                          if (_fieldError != null) {
                            setState(() => _fieldError = null);
                          }
                          setState(() {});
                        },
                      ),
                      if (_fieldError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _fieldError!,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'معاينة الرسالة',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _titleCtrl.text.isEmpty ? '—' : _titleCtrl.text,
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'إلى: ${AdminBroadcastFormValidation.roleLabels[_targetRole] ?? _targetRole}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.secondaryBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.notifications_active_outlined,
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppButton(
                  label: 'إرسال البث الآن',
                  isLoading: submitting,
                  leading: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: _submit,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
