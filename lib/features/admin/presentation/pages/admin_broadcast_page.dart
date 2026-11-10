import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/admin_broadcast_form.dart';
import '../../domain/entities/admin_operations_entities.dart'
    show newHalaqaRequestId;
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_subpage_scaffold.dart';

typedef BroadcastAudienceCounter = Future<int> Function(String targetRole);

Future<int> countBroadcastAudience(String targetRole) async {
  Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection(
    FirestoreCollections.users,
  );
  if (targetRole != 'all') q = q.where('role', isEqualTo: targetRole);
  final snap = await q.count().get();
  return snap.count ?? 0;
}

class AdminBroadcastPage extends StatefulWidget {
  final BroadcastAudienceCounter countAudience;

  const AdminBroadcastPage({
    super.key,
    this.countAudience = countBroadcastAudience,
  });

  @override
  State<AdminBroadcastPage> createState() => _AdminBroadcastPageState();
}

class _AdminBroadcastPageState extends State<AdminBroadcastPage> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _targetRole = 'all';
  String? _fieldError;

  /// Kept across retries of the same message so an unconfirmed send is never
  /// delivered twice; cleared when the message or audience changes.
  String? _requestId;
  final _audienceCounts = <String, int?>{};
  final _audienceCountFailed = <String>{};

  @override
  void initState() {
    super.initState();
    _loadCount(_targetRole);
  }

  Future<void> _loadCount(String role) async {
    if (_audienceCounts.containsKey(role)) return;
    _audienceCounts[role] = null;
    _audienceCountFailed.remove(role);
    try {
      final n = await widget.countAudience(role);
      if (!mounted) return;
      setState(() => _audienceCounts[role] = n);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audienceCounts.remove(role);
        _audienceCountFailed.add(role);
      });
    }
  }

  void _selectAudience(String role) {
    setState(() {
      _targetRole = role;
      _requestId = null;
    });
    _loadCount(role);
  }

  String _audienceCountText() {
    if (_audienceCountFailed.contains(_targetRole)) {
      return 'تعذر حساب عدد الحسابات المستلمة';
    }
    final n = _audienceCounts[_targetRole];
    if (n == null) return 'جارٍ حساب عدد الحسابات المستلمة…';
    return 'عدد الحسابات المسجلة في هذه الفئة الآن: $n';
  }

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

    final requestId = _requestId ??= newHalaqaRequestId();
    context.read<AdminBloc>().add(
      SendBroadcastNotificationEvent(
        title: _titleCtrl.text.trim(),
        body: _bodyCtrl.text.trim(),
        targetRole: _targetRole,
        requestId: requestId,
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
            _requestId = null;
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
                            : () => _selectAudience(t.$1),
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
                  onTap: submitting ? null : () => _selectAudience('all'),
                ),
                const SizedBox(height: 12),
                AppCard(
                  key: const Key('broadcast-audience-explanation'),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'من سيستلم الرسالة؟',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AdminBroadcastFormValidation.audienceExplanation(
                          _targetRole,
                        ),
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _audienceCountText(),
                        key: const Key('broadcast-audience-count'),
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AdminBroadcastFormValidation.deliveryNote,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
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
                          setState(() => _requestId = null);
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
                          setState(() => _requestId = null);
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
