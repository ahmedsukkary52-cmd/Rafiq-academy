import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/error/exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../data/academy_accounts_repository.dart';
import '../domain/onboarding_models.dart';
import 'admin_onboard_student_page.dart' show CredentialCard;

typedef CredentialReset =
    Future<IssuedCredential> Function({
      required String userId,
      required String name,
      required String role,
    });

/// Admin-only recovery on a student profile: issue a new temporary password
/// for the student or a linked parent (shown once, must be changed on login).
class AdminAccountAccessCard extends StatefulWidget {
  final String studentId;
  final String studentName;
  final CredentialReset? reset;
  final Future<List<MemberSearchHit>> Function(String studentId)? loadParents;

  const AdminAccountAccessCard({
    super.key,
    required this.studentId,
    required this.studentName,
    this.reset,
    this.loadParents,
  });

  @override
  State<AdminAccountAccessCard> createState() => _AdminAccountAccessCardState();
}

class _AdminAccountAccessCardState extends State<AdminAccountAccessCard> {
  List<MemberSearchHit> _parents = const [];
  String? _busyFor;
  IssuedCredential? _issued;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    try {
      final load =
          widget.loadParents ??
          (id) => sl<AcademyAccountsRepository>().listLinkedParentsForStudent(
            id,
          );
      final parents = await load(widget.studentId);
      if (mounted) setState(() => _parents = parents);
    } catch (_) {
      // The student's own reset stays available.
    }
  }

  Future<void> _reset(String userId, String name, String role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إصدار كلمة مرور مؤقتة'),
        content: Text(
          'ستتوقف كلمة المرور الحالية لـ ${name.isEmpty ? 'هذا الحساب' : name} '
          'فوراً، وسيُطلب تغيير المؤقتة عند أول دخول.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إصدار'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyFor = userId);
    try {
      final reset =
          widget.reset ?? sl<AcademyAccountsRepository>().resetMemberPassword;
      final issued = await reset(userId: userId, name: name, role: role);
      if (mounted) setState(() => _issued = issued);
    } on ServerException catch (e) {
      if (mounted) AppSnackBar.showError(context, e.message);
    } finally {
      if (mounted) setState(() => _busyFor = null);
    }
  }

  Widget _row(String userId, String name, String role, String roleLabel) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.key_outlined),
      title: Text(name.isEmpty ? roleLabel : name),
      subtitle: Text(roleLabel),
      trailing: _busyFor == userId
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              key: Key('reset-password-$userId'),
              onPressed: _busyFor == null
                  ? () => _reset(userId, name, role)
                  : null,
              child: const Text('كلمة مرور مؤقتة'),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('الدخول إلى التطبيق', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'عند نسيان كلمة المرور يصدر المسؤول كلمة مرور مؤقتة جديدة.',
            style: AppTextStyles.labelMedium,
          ),
          _row(widget.studentId, widget.studentName, 'student', 'الطالب'),
          for (final p in _parents) _row(p.uid, p.name, 'parent', 'ولي الأمر'),
          if (_issued != null) CredentialCard(credential: _issued!),
        ],
      ),
    );
  }
}
