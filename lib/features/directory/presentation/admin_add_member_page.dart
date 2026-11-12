import 'package:flutter/material.dart';

import '../../../core/error/exception.dart';
import '../../../core/presentation/academy_data_revision.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../accounts/domain/onboarding_models.dart';
import '../../accounts/presentation/admin_onboard_student_page.dart' show CredentialCard;
import '../../../shared/widgets/admin_subpage_scaffold.dart';
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';
import 'admin_directory_page.dart' show defaultDirectoryRepository;
import 'directory_navigation.dart';

/// Adds one parent, teacher, supervisor or assistant teacher through
/// `adminCreateMemberAccount` — the same server provisioning as bulk import:
/// academy username, next free academy code, one-time temporary password and
/// a mandatory change at first sign-in. Students are added through the
/// onboarding wizard (always with a guardian); Admins through the Admin
/// accounts page.
class AdminAddMemberPage extends StatefulWidget {
  final DirectoryRole? initialRole;
  final AcademyDirectoryRepository? repository;
  final DirectoryNavigator navigator;

  const AdminAddMemberPage({
    super.key,
    this.initialRole,
    this.repository,
    this.navigator = const DirectoryNavigator(),
  });

  static const roles = [
    DirectoryRole.parent,
    DirectoryRole.teacher,
    DirectoryRole.assistant,
    DirectoryRole.supervisor,
  ];

  @override
  State<AdminAddMemberPage> createState() => _AdminAddMemberPageState();
}

class _AdminAddMemberPageState extends State<AdminAddMemberPage> {
  late final AcademyDirectoryRepository _repo =
      widget.repository ?? defaultDirectoryRepository();
  late DirectoryRole _role = AdminAddMemberPage.roles.contains(widget.initialRole)
      ? widget.initialRole!
      : DirectoryRole.parent;
  final _name = TextEditingController();
  bool _busy = false;
  String? _error;
  IssuedCredential? _issued;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) {
      setState(() => _error = 'اكتب الاسم كاملاً');
      return;
    }
    if (RegExp(r'@|\d{7,}').hasMatch(name)) {
      setState(() => _error = 'لا يُكتب في الاسم بريد أو رقم هاتف');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final issued = await _repo.createMember(role: _role, name: name);
      AcademyDataRevision.bumpStructure();
      if (mounted) setState(() => _issued = issued);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _another() => setState(() {
    _issued = null;
    _name.clear();
  });

  @override
  Widget build(BuildContext context) {
    final issued = _issued;
    return AdminSubpageScaffold(
      title: 'إضافة شخص',
      subtitle: 'حساب جديد بدون إعادة الاستيراد',
      body: ListView(
        padding: const EdgeInsets.all(AppSizes.paddingL),
        children: issued != null
            ? [
                const Icon(Icons.check_circle, size: 56, color: AppColors.primary),
                const SizedBox(height: 8),
                Text(
                  'تم إنشاء الحساب',
                  key: const Key('add-member-done'),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium,
                ),
                Text(
                  'كلمة المرور المؤقتة تظهر مرة واحدة فقط ولا تُحفظ. انسخها أو أرسلها الآن.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelMedium,
                ),
                CredentialCard(credential: issued),
                const SizedBox(height: 16),
                AppButton(
                  key: const Key('add-member-open'),
                  label: 'فتح الملف لإكمال العلاقات',
                  onPressed: () => widget.navigator.openPerson(context, issued.uid),
                ),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: _another, child: const Text('إضافة شخص آخر')),
              ]
            : [
                Text('النوع', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in AdminAddMemberPage.roles)
                      ChoiceChip(
                        key: Key('add-member-role-${r.wire}'),
                        label: Text(r.label),
                        selected: _role == r,
                        onSelected: _busy ? null : (_) => setState(() => _role = r),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      key: const Key('add-member-student'),
                      onPressed: () => widget.navigator.addStudent(context),
                      child: const Text('طالب؟ سجّله مع ولي أمره'),
                    ),
                    TextButton(
                      key: const Key('add-member-admin'),
                      onPressed: () => widget.navigator.addAdmin(context),
                      child: const Text('مسؤول؟ من صفحة حسابات المسؤولين'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('الاسم', style: AppTextStyles.titleMedium),
                const SizedBox(height: 8),
                AppTextField(
                  key: const Key('add-member-name'),
                  hint: 'الاسم كما سيظهر في التطبيق',
                  controller: _name,
                  enabled: !_busy,
                ),
                const SizedBox(height: 8),
                Text(
                  'يُولَّد اسم المستخدم ورقم الأكاديمية وكلمة المرور المؤقتة تلقائياً، '
                  'ويُطلب تغيير كلمة المرور عند أول دخول. لا يلزم بريد إلكتروني.',
                  style: AppTextStyles.labelMedium,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('add-member-error'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  key: const Key('add-member-submit'),
                  label: 'إنشاء حساب ${_role.label}',
                  isLoading: _busy,
                  onPressed: _busy ? null : _submit,
                ),
              ],
      ),
    );
  }
}
