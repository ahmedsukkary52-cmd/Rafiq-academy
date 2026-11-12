import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exception.dart';
import '../../../core/presentation/academy_data_revision.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/admin_subpage_scaffold.dart';
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';
import 'admin_directory_page.dart' show defaultDirectoryRepository;
import 'directory_navigation.dart';
import 'directory_pickers.dart';
import 'directory_widgets.dart';

/// Role-adaptive profile: identity, account and recovery, every relationship
/// (each one a link to the related profile) and the relationship history.
/// Changes go through audited callables; every open directory view reloads
/// after a committed change.
class AdminPersonProfilePage extends StatefulWidget {
  final String uid;
  final AcademyDirectoryRepository? repository;
  final DirectoryNavigator navigator;

  const AdminPersonProfilePage({
    super.key,
    required this.uid,
    this.repository,
    this.navigator = const DirectoryNavigator(),
  });

  @override
  State<AdminPersonProfilePage> createState() => _AdminPersonProfilePageState();
}

class _AdminPersonProfilePageState extends State<AdminPersonProfilePage> {
  late final AcademyDirectoryRepository _repo =
      widget.repository ?? defaultDirectoryRepository();
  PersonProfile? _profile;
  String? _error;
  bool _busy = false;
  int _accountVersion = 0;

  @override
  void initState() {
    super.initState();
    AcademyDataRevision.structure.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    AcademyDataRevision.structure.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final profile = await _repo.loadPerson(widget.uid);
      if (mounted) setState(() => _profile = profile);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _change(Future<void> Function() op, String success) async {
    if (_busy) return;
    setState(() => _busy = true);
    await runDirectoryChange(
      context,
      op,
      success: success,
      onCommitted: AcademyDataRevision.bumpStructure,
    );
    if (mounted) setState(() => _busy = false);
  }

  void _open(DirectoryPerson p) => widget.navigator.openPerson(context, p.uid);

  // ── student actions ─────────────────────────────────────────────────────

  Future<void> _linkParent(DirectoryPerson student, List<DirectoryPerson> current) async {
    final parent = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.parent,
      title: 'ربط ولي أمر بـ${student.displayName}',
      exclude: {for (final p in current) p.uid},
    );
    if (parent == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'ربط ولي أمر',
      message: 'سيُربط ${student.displayName} بولي الأمر ${parent.displayName}'
          '${current.isEmpty ? '' : ' إضافةً إلى ولي الأمر الحالي'}.',
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.linkParent(parentId: parent.uid, studentId: student.uid),
      'تم الربط',
    );
  }

  Future<void> _replaceParent(DirectoryPerson student, DirectoryPerson from, List<DirectoryPerson> current) async {
    final to = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.parent,
      title: 'ولي الأمر الجديد بدلاً من ${from.displayName}',
      exclude: {for (final p in current) p.uid},
    );
    if (to == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'تغيير ولي الأمر',
      message: 'سيُنقل ${student.displayName} من ولي الأمر ${from.displayName} '
          'إلى ${to.displayName} في عملية واحدة، ويُسجَّل التغيير في سجل العلاقات.',
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.replaceParent(studentId: student.uid, fromParentId: from.uid, toParentId: to.uid),
      'تم تغيير ولي الأمر',
    );
  }

  Future<void> _unlinkParent(DirectoryPerson student, DirectoryPerson parent, int count) async {
    final c = await confirmRelationshipChange(
      context,
      title: 'إلغاء الربط',
      message: 'سيُلغى ربط ${student.displayName} بولي الأمر ${parent.displayName}.'
          '${count <= 1 ? ' لن يبقى للطالب ولي أمر مرتبط.' : ''}',
      confirmLabel: 'إلغاء الربط',
      destructive: true,
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.unlinkParent(parentId: parent.uid, studentId: student.uid),
      'تم إلغاء الربط',
    );
  }

  Future<void> _admit(DirectoryPerson student, List<HalaqaLink> current) async {
    final h = await showHalaqaPicker(
      context,
      repository: _repo,
      title: 'إضافة ${student.displayName} إلى حلقة',
      exclude: {for (final l in current) l.halaqa.id},
    );
    if (h == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'إضافة إلى حلقة',
      message: 'سيُضاف ${student.displayName} إلى ${h.displayName} '
          '(المعلم: ${h.teacherName.isEmpty ? 'غير معيّن' : h.teacherName}).',
    );
    if (!c.confirmed) return;
    await _change(() => _repo.admitStudent(halaqaId: h.id, studentId: student.uid), 'تمت الإضافة');
  }

  Future<void> _transfer(DirectoryPerson student, HalaqaLink from, List<HalaqaLink> current) async {
    final h = await showHalaqaPicker(
      context,
      repository: _repo,
      title: 'نقل ${student.displayName} من ${from.halaqa.displayName}',
      exclude: {for (final l in current) l.halaqa.id},
    );
    if (h == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'نقل إلى حلقة أخرى',
      message: 'سيُنقل ${student.displayName} من ${from.halaqa.displayName} إلى ${h.displayName}.',
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.transferStudent(studentId: student.uid, fromHalaqaId: from.halaqa.id, toHalaqaId: h.id),
      'تم النقل',
    );
  }

  // ── parent actions ──────────────────────────────────────────────────────

  Future<void> _linkChild(DirectoryPerson parent, List<ChildSummary> current) async {
    final child = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.student,
      title: 'ربط طالب مسجّل بـ${parent.displayName}',
      exclude: {for (final c in current) c.child.uid},
    );
    if (child == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'ربط طالب',
      message: 'سيُربط ${child.displayName} بولي الأمر ${parent.displayName}.',
    );
    if (!c.confirmed) return;
    await _change(() => _repo.linkParent(parentId: parent.uid, studentId: child.uid), 'تم الربط');
  }

  // ── sections ────────────────────────────────────────────────────────────

  Widget _halaqaTile(HalaqaLink l, {Widget? trailing, bool showRole = true}) {
    final h = l.halaqa;
    final staff = l.staff;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          key: Key('halaqa-link-${h.name}'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.groups_outlined),
          title: Text(h.academyRef.isEmpty ? h.displayName : '${h.displayName} · ${h.academyRef}'),
          subtitle: Text(
            '${showRole ? '${l.role.label} — ' : ''}${h.studentCount} طالب'
            '${h.isOpen ? '' : ' — مغلقة'}',
          ),
          trailing: trailing ?? const Icon(Icons.chevron_left),
          onTap: () => widget.navigator.openHalaqa(context, h.id),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 40, bottom: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 2,
            children: [
              for (final (label, person) in [
                if (staff.teacher != null) ('المعلم', staff.teacher!),
                for (final a in staff.assistants) ('المساعد', a),
                if (staff.cover != null) ('تغطية حالية', staff.cover!),
                if (staff.supervisor != null) ('المشرف', staff.supervisor!),
              ])
                ActionChip(
                  key: Key('staff-chip-$label-${person.name}'),
                  label: Text('$label: ${person.displayName}'),
                  onPressed: () => _open(person),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _studentSections(PersonProfile p) {
    final s = p.person;
    return [
      DirectorySection(
        title: 'أولياء الأمور',
        emptyText: 'لا يوجد ولي أمر مرتبط.',
        children: [
          for (final parent in p.parents)
            PersonTile(
              person: parent,
              onTap: () => _open(parent),
              trailing: PopupMenuButton<String>(
                key: Key('parent-menu-${parent.name}'),
                onSelected: (v) => v == 'replace'
                    ? _replaceParent(s, parent, p.parents)
                    : _unlinkParent(s, parent, p.parents.length),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'replace', child: Text('تغيير ولي الأمر')),
                  PopupMenuItem(value: 'unlink', child: Text('إلغاء الربط')),
                ],
              ),
            ),
        ],
        actions: [
          TextButton.icon(
            key: const Key('action-link-parent'),
            onPressed: _busy ? null : () => _linkParent(s, p.parents),
            icon: const Icon(Icons.link),
            label: Text(p.parents.isEmpty ? 'ربط ولي أمر' : 'ربط ولي أمر إضافي'),
          ),
        ],
      ),
      if (p.siblings.isNotEmpty)
        DirectorySection(
          title: 'الإخوة',
          children: [for (final b in p.siblings) PersonTile(person: b, onTap: () => _open(b))],
        ),
      DirectorySection(
        title: 'الحلقات',
        emptyText: 'غير مسجّل في حلقة.',
        children: [
          for (final l in p.halaqat)
            _halaqaTile(
              l,
              showRole: false,
              trailing: PopupMenuButton<String>(
                key: Key('halaqa-menu-${l.halaqa.name}'),
                onSelected: (_) => _transfer(s, l, p.halaqat),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'transfer', child: Text('نقل إلى حلقة أخرى')),
                ],
              ),
            ),
        ],
        actions: [
          TextButton.icon(
            key: const Key('action-admit'),
            onPressed: _busy ? null : () => _admit(s, p.halaqat),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('إضافة إلى حلقة'),
          ),
        ],
      ),
      _paymentsSection(p),
    ];
  }

  List<Widget> _parentSections(PersonProfile p) => [
    DirectorySection(
      title: 'الأبناء',
      emptyText: 'لا يوجد أبناء مرتبطون.',
      children: [
        for (final c in p.children) ...[
          PersonTile(
            person: c.child,
            detail: c.halaqat.isEmpty ? 'بلا حلقة' : null,
            onTap: () => _open(c.child),
          ),
          for (final l in c.halaqat)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 24),
              child: _halaqaTile(l, showRole: false),
            ),
        ],
      ],
      actions: [
        TextButton.icon(
          key: const Key('action-link-child'),
          onPressed: _busy ? null : () => _linkChild(p.person, p.children),
          icon: const Icon(Icons.link),
          label: const Text('ربط طالب مسجّل'),
        ),
        TextButton.icon(
          key: const Key('action-add-child'),
          onPressed: () => widget.navigator.addChild(context, p.person),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('تسجيل ابن جديد'),
        ),
      ],
    ),
    _paymentsSection(p),
  ];

  Widget _paymentsSection(PersonProfile p) => DirectorySection(
    title: 'المدفوعات',
    emptyText: 'لا توجد مستحقات مسجلة.',
    children: [
      for (final pay in p.payments)
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.receipt_long_outlined),
          title: Text('${pay.amount} — ${pay.statusLabel}'),
          subtitle: Text(
            '${p.person.role == AppRoles.parent ? '${pay.studentName} — ' : ''}'
            'الاستحقاق: ${formatDirectoryDate(pay.dueDate).split(' ').first}',
          ),
        ),
    ],
  );

  List<Widget> _staffSections(PersonProfile p) => [
    DirectorySection(
      title: 'الحلقات',
      emptyText: switch (p.person.role) {
        AppRoles.assistantTeacher => 'غير معيّن مساعداً في أي حلقة.',
        AppRoles.supervisor => 'لا يشرف على أي حلقة.',
        _ => 'لا توجد حلقات مسندة.',
      },
      children: [for (final l in p.halaqat) _halaqaTile(l)],
    ),
    if (p.person.role == AppRoles.supervisor)
      DirectorySection(
        title: 'المعلمون والمساعدون',
        emptyText: 'لا يوجد طاقم في حلقاته.',
        children: [for (final s in p.staff) PersonTile(person: s, onTap: () => _open(s))],
      ),
    DirectorySection(
      title: 'الطلاب',
      emptyText: 'لا يوجد طلاب في حلقاته.',
      children: [
        for (final s in p.students) PersonTile(person: s, onTap: () => _open(s)),
        if (p.studentsTruncated)
          Text('يظهر أول ${p.students.length} طالب؛ افتح الحلقة لعرض قائمتها كاملة.',
              style: AppTextStyles.labelMedium),
      ],
    ),
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        'تغيير المعلم أو المشرف أو المساعد أو التغطية المؤقتة يتم من ملف الحلقة.',
        style: AppTextStyles.labelMedium,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return AdminSubpageScaffold(
      title: p?.person.displayName ?? 'ملف الحساب',
      subtitle: p?.person.caption,
      body: _error != null && p == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                ],
              ),
            )
          : p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() => _accountVersion++);
                await _load();
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSizes.paddingM),
                children: [
                  Card(
                    child: ListTile(
                      key: const Key('profile-header'),
                      leading: CircleAvatar(child: Text(p.person.displayName.characters.first)),
                      title: Text(p.person.displayName, style: AppTextStyles.titleMedium),
                      subtitle: Text(p.person.caption),
                      trailing: Chip(label: Text(p.person.isActive ? 'نشط' : 'غير نشط')),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_busy) const LinearProgressIndicator(),
                  AccountRecoveryCard(
                    key: ValueKey('account-${p.person.uid}-$_accountVersion'),
                    person: p.person,
                    repository: _repo,
                  ),
                  ...switch (p.person.role) {
                    AppRoles.student => _studentSections(p),
                    AppRoles.parent => _parentSections(p),
                    AppRoles.teacher || AppRoles.assistantTeacher || AppRoles.supervisor =>
                      _staffSections(p),
                    _ => const <Widget>[],
                  },
                  RelationshipHistoryList(events: p.history),
                ],
              ),
            ),
    );
  }
}
