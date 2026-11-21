import 'package:flutter/material.dart';

import '../../../core/error/exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../accounts/domain/onboarding_models.dart';
import '../../accounts/presentation/admin_onboard_student_page.dart' show CredentialCard;
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';

String formatDirectoryDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)} – ${two(l.hour)}:${two(l.minute)}';
}

class DirectorySection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final String? emptyText;

  const DirectorySection({
    super.key,
    required this.title,
    required this.children,
    this.actions = const [],
    this.emptyText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              if (children.isEmpty && emptyText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(emptyText!, style: AppTextStyles.labelMedium),
                ),
              ...children,
              if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 4, children: actions),
            ],
          ),
        ),
      ),
    );
  }
}

/// A related person: name and readable identity, tappable to their profile.
class PersonTile extends StatelessWidget {
  final DirectoryPerson person;
  final String? detail;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PersonTile({
    super.key,
    required this.person,
    this.detail,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final caption = [
      person.caption,
      if (!person.isActive) 'غير نشط',
      if (detail != null && detail!.isNotEmpty) detail!,
    ].join(' — ');
    return ListTile(
      key: Key('person-${person.academyRef.isEmpty ? person.name : person.academyRef}'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.person_outline),
      title: Text(person.displayName),
      subtitle: Text(caption),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );
  }
}

class RelationshipHistoryList extends StatelessWidget {
  final List<RelationshipEvent> events;

  const RelationshipHistoryList({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return DirectorySection(
      title: 'سجل العلاقات',
      emptyText: 'لا توجد تغييرات مسجلة بعد. السجل يبدأ من أول تغيير يتم عبر النظام.',
      children: [
        for (final e in events)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.history, size: 20),
            title: Text(e.description),
            subtitle: Text('${formatDirectoryDate(e.at)} — بواسطة ${e.actorName}'),
          ),
      ],
    );
  }
}

/// Account status and password recovery. The current password is never
/// readable by anyone: recovery issues a new one-time temporary password
/// that the user must replace at the next sign-in.
class AccountRecoveryCard extends StatefulWidget {
  final DirectoryPerson person;
  final AcademyDirectoryRepository repository;

  const AccountRecoveryCard({super.key, required this.person, required this.repository});

  @override
  State<AccountRecoveryCard> createState() => _AccountRecoveryCardState();
}

class _AccountRecoveryCardState extends State<AccountRecoveryCard> {
  MemberAccount? _account;
  String? _error;
  bool _busy = false;
  IssuedCredential? _issued;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final account = await widget.repository.loadAccount(widget.person.uid);
      if (mounted) setState(() => _account = account);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _reset() async {
    final name = widget.person.displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('إصدار كلمة مرور مؤقتة'),
          content: Text(
            'ستتوقف كلمة المرور الحالية لـ $name فوراً، وتظهر كلمة مؤقتة جديدة '
            'مرة واحدة فقط، ويُطلب تغييرها عند أول دخول. لا يمكن عرض كلمة المرور الحالية.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(
              key: const Key('confirm-reset'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('إصدار'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final issued = await widget.repository.resetPassword(widget.person);
      if (!mounted) return;
      setState(() => _issued = issued);
      await _load();
    } on ServerException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _row(String label, String value, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label, style: AppTextStyles.labelMedium)),
        Expanded(child: Text(value)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final a = _account;
    return DirectorySection(
      title: 'الحساب والدخول',
      children: [
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
        ] else if (a == null)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          _row('طريقة الدخول', a.loginLabel),
          if (a.username.isNotEmpty) _row('اسم المستخدم', a.username, key: const Key('account-username')),
          _row('حالة الحساب', a.isActive && a.authDisabled != true ? 'نشط' : 'معطّل'),
          _row(
            'كلمة المرور المؤقتة',
            a.mustChangePassword ? 'لم تُغيَّر بعد — مطلوب تغييرها عند الدخول' : 'تم تغييرها',
            key: const Key('account-first-login'),
          ),
          _row(
            'آخر تسجيل دخول',
            a.lastSignInAt == null ? 'لم يسجّل الدخول بعد' : formatDirectoryDate(a.lastSignInAt),
          ),
          if (a.credentialsIssuedAt != null)
            _row('آخر إصدار لبيانات الدخول', formatDirectoryDate(a.credentialsIssuedAt)),
          if (a.passwordChangedAt != null)
            _row('آخر تغيير لكلمة المرور', formatDirectoryDate(a.passwordChangedAt)),
          const Divider(),
          Text(
            'لا يمكن لأحد — ولا المسؤول — رؤية كلمة المرور الحالية. عند النسيان تُصدر '
            'كلمة مرور مؤقتة جديدة تظهر مرة واحدة ويجب تغييرها عند الدخول.',
            style: AppTextStyles.labelMedium,
          ),
          if (a.canResetPassword)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('account-reset'),
                onPressed: _busy ? null : _reset,
                icon: _busy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key_outlined),
                label: const Text('إصدار كلمة مرور مؤقتة'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                a.loginKind == 'email' || widget.person.role == 'admin'
                    ? 'هذا الحساب يدخل بالبريد الإلكتروني؛ الاستعادة عبر «نسيت كلمة المرور» في شاشة الدخول.'
                    : 'لا يمكن إصدار كلمة مرور لهذا الحساب في حالته الحالية.',
                style: AppTextStyles.labelMedium,
              ),
            ),
          if (_issued != null) CredentialCard(credential: _issued!),
          if (a.recoveries.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('سجل الاستعادة', style: AppTextStyles.labelMedium),
            for (final r in a.recoveries)
              Text(
                '${formatDirectoryDate(r.at)} — بواسطة ${r.actorName.isEmpty ? 'مسؤول' : r.actorName}',
                key: const Key('account-recovery'),
              ),
          ],
        ],
      ],
    );
  }
}

/// Runs one audited relationship change and announces it to every open
/// directory view.
Future<bool> runDirectoryChange(
  BuildContext context,
  Future<void> Function() change, {
  required String success,
  required void Function() onCommitted,
}) async {
  try {
    await change();
    onCommitted();
    if (context.mounted) AppSnackBar.showSuccess(context, success);
    return true;
  } on ServerException catch (e) {
    if (context.mounted) AppSnackBar.showError(context, e.message);
    return false;
  }
}
