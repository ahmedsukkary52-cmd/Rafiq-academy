import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/staff_lifecycle_repository.dart';
import 'admin_figma_widgets.dart';

Color staffStatusColor(StaffStatus s) => switch (s) {
  StaffStatus.active => AppColors.success,
  StaffStatus.deactivated => AppColors.error,
  StaffStatus.archived => AppColors.textSecondary,
  StaffStatus.deleted => AppColors.textSecondary,
};

class StaffStatusBadge extends StatelessWidget {
  const StaffStatusBadge({super.key, required this.status});
  final StaffStatus status;

  @override
  Widget build(BuildContext context) {
    final c = staffStatusColor(status);
    return AdminStatusBadge(
      label: status.label,
      color: c,
      bg: c.withValues(alpha: 0.12),
    );
  }
}

/// Opens the account-management sheet; resolves `true` when the account or
/// any of its halaqat changed, so the caller reloads.
Future<bool> showStaffLifecycleSheet(
  BuildContext context, {
  required StaffMember member,
  required StaffLifecycleRepository repository,
}) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Directionality(
      textDirection: TextDirection.rtl,
      child: StaffLifecycleSheet(member: member, repository: repository),
    ),
  );
  return changed ?? false;
}

class StaffLifecycleSheet extends StatefulWidget {
  const StaffLifecycleSheet({
    super.key,
    required this.member,
    required this.repository,
  });

  final StaffMember member;
  final StaffLifecycleRepository repository;

  @override
  State<StaffLifecycleSheet> createState() => _StaffLifecycleSheetState();
}

class _StaffLifecycleSheetState extends State<StaffLifecycleSheet> {
  static const _noSupervisor = '';

  List<StaffHalaqa>? _halaqat;
  List<StaffMember> _replacements = const [];
  final Map<String, String> _choice = {};
  String? _error;
  String? _progress;
  bool _busy = false;
  bool _changed = false;

  StaffMember get _m => widget.member;
  bool get _isTeacher => _m.role == AppRoles.teacher;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final halaqat = await widget.repository.assignedHalaqat(_m.uid, _m.role);
      final replacements = halaqat.isEmpty
          ? const <StaffMember>[]
          : await widget.repository.replacements(_m.role, excludeUid: _m.uid);
      if (!mounted) return;
      setState(() {
        _halaqat = halaqat;
        _replacements = replacements;
        _choice.removeWhere((id, _) => !halaqat.any((h) => h.id == id));
      });
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  bool get _allReplaced =>
      _halaqat != null && _halaqat!.every((h) => _choice.containsKey(h.id));

  Future<bool> _confirm(String title, String body, String action, {bool destructive = false}) async {
    var acknowledged = !destructive;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(body),
                if (destructive)
                  CheckboxListTile(
                    key: const Key('confirm-delete-check'),
                    contentPadding: EdgeInsets.zero,
                    value: acknowledged,
                    onChanged: (v) => setLocal(() => acknowledged = v ?? false),
                    title: const Text('أفهم أن الحذف نهائي ولا يمكن التراجع عنه'),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء'),
              ),
              TextButton(
                key: const Key('staff-confirm'),
                onPressed: acknowledged ? () => Navigator.pop(ctx, true) : null,
                child: Text(action),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _run(StaffAction action) async {
    final (title, body, label) = switch (action) {
      StaffAction.deactivate => (
        'تعطيل الحساب',
        _halaqat!.isEmpty
            ? 'لن يتمكن ${_m.name} من تسجيل الدخول، ويبقى ملفه وسجله كما هما.'
            : 'ستُنقل ${_halaqat!.length} حلقة إلى البدلاء المختارين ثم يُعطَّل الحساب.',
        'تعطيل',
      ),
      StaffAction.reactivate => (
        'إعادة التفعيل',
        'سيتمكن ${_m.name} من تسجيل الدخول مجدداً.',
        'إعادة التفعيل',
      ),
      StaffAction.archive => (
        'أرشفة الملف',
        'يُنقل الملف إلى الأرشيف ويبقى سجله التاريخي. يمكن إعادة تفعيله لاحقاً.',
        'أرشفة',
      ),
      StaffAction.delete => (
        'حذف نهائي',
        'يُحذف حساب الدخول وبيانات التواصل الخاصة نهائياً. يبقى الاسم في السجلات التاريخية فقط.',
        'حذف نهائياً',
      ),
    };
    if (!await _confirm(title, body, label, destructive: action == StaffAction.delete)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (action == StaffAction.deactivate) {
        for (final h in List.of(_halaqat!)) {
          setState(() => _progress = 'جارٍ نقل ${h.name}…');
          await widget.repository.reassign(
            halaqaId: h.id,
            role: _m.role,
            newStaffId: _choice[h.id]!,
          );
          _changed = true;
        }
      }
      setState(() => _progress = 'جارٍ تحديث الحساب…');
      await widget.repository.setStatus(uid: _m.uid, action: action);
      if (mounted) Navigator.pop(context, true);
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _progress = null;
        _error = e.message;
      });
      // Some halaqat may have moved before the failure; the error stays shown.
      await _load();
    }
  }

  String _actionLabel(StaffAction a) => switch (a) {
    StaffAction.deactivate => 'تعطيل الحساب',
    StaffAction.reactivate => 'إعادة التفعيل',
    StaffAction.archive => 'أرشفة الملف',
    StaffAction.delete => 'حذف نهائي',
  };

  @override
  Widget build(BuildContext context) {
    final actions = StaffAction.availableFor(_m.status);
    final halaqat = _halaqat;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _m.name.isEmpty ? 'بدون اسم' : _m.name,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  StaffStatusBadge(status: _m.status),
                ],
              ),
              Text(
                _isTeacher ? 'معلم' : 'مشرف',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              const _LifecycleExplainer(),
              const SizedBox(height: 12),
              if (halaqat == null && _error == null)
                const Center(child: CircularProgressIndicator(strokeWidth: 2))
              else if (halaqat != null && halaqat.isNotEmpty) ...[
                Text(
                  _m.status == StaffStatus.active
                      ? 'اختر بديلاً لكل حلقة قبل التعطيل'
                      : 'حلقات مسندة',
                  style: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final h in halaqat)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ReplacementRow(
                      halaqa: h,
                      replacements: _replacements,
                      allowNone: !_isTeacher,
                      noneValue: _noSupervisor,
                      value: _choice[h.id],
                      enabled: !_busy && _m.status == StaffStatus.active,
                      onChanged: (v) => setState(() => _choice[h.id] = v),
                    ),
                  ),
                if (_isTeacher && _replacements.isEmpty)
                  Text(
                    'لا يوجد معلم نشط آخر لاستلام الحلقات. أضف معلماً أولاً.',
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
              ] else if (halaqat != null)
                Text(
                  'لا حلقات مسندة حالياً',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('staff-error'),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              if (_progress != null) ...[
                const SizedBox(height: 8),
                Text(_progress!, style: AppTextStyles.labelMedium),
              ],
              const SizedBox(height: 16),
              for (final a in actions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    key: Key('staff-action-${a.wire}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: a == StaffAction.reactivate
                          ? AppColors.success
                          : AppColors.error,
                    ),
                    onPressed: _busy ||
                            halaqat == null ||
                            (a == StaffAction.deactivate && !_allReplaced)
                        ? null
                        : () => _run(a),
                    child: Text(_actionLabel(a)),
                  ),
                ),
              if (_changed && !_busy)
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('إغلاق'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LifecycleExplainer extends StatelessWidget {
  const _LifecycleExplainer();

  @override
  Widget build(BuildContext context) {
    Widget line(String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$title: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: body),
          ],
        ),
        style: AppTextStyles.labelMedium,
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line('التعطيل', 'يمنع تسجيل الدخول مع بقاء الملف والسجل.'),
          line('الأرشفة', 'تنقل الملف المعطّل إلى الأرشيف، ويمكن استعادته.'),
          line('الحذف النهائي', 'يزيل حساب الدخول نهائياً بعد الأرشفة.'),
        ],
      ),
    );
  }
}

class _ReplacementRow extends StatelessWidget {
  const _ReplacementRow({
    required this.halaqa,
    required this.replacements,
    required this.allowNone,
    required this.noneValue,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final StaffHalaqa halaqa;
  final List<StaffMember> replacements;
  final bool allowNone;
  final String noneValue;
  final String? value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            halaqa.name.isEmpty ? 'حلقة بدون اسم' : halaqa.name,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButton<String>(
            key: Key('replace-${halaqa.id}'),
            isExpanded: true,
            value: value,
            hint: const Text('اختر البديل'),
            onChanged: enabled ? (v) => v == null ? null : onChanged(v) : null,
            items: [
              if (allowNone)
                DropdownMenuItem(value: noneValue, child: const Text('بدون مشرف')),
              for (final r in replacements)
                DropdownMenuItem(
                  value: r.uid,
                  child: Text(r.name.isEmpty ? 'بدون اسم' : r.name),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
