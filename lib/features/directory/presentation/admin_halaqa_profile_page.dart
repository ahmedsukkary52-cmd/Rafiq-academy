import 'package:flutter/material.dart';

import '../../../core/error/exception.dart';
import '../../../core/presentation/academy_data_revision.dart';
import '../../../shared/theme/app_theme.dart';
import '../../admin/presentation/widgets/admin_subpage_scaffold.dart';
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';
import 'admin_directory_page.dart' show defaultDirectoryRepository;
import 'directory_navigation.dart';
import 'directory_pickers.dart';
import 'directory_widgets.dart';

/// Halaqa profile: schedule, primary teacher, supervisor, assistants, the
/// active temporary cover, students with their parents, cover periods and
/// relationship history. Assignment changes go through audited callables.
class AdminHalaqaProfilePage extends StatefulWidget {
  final String halaqaId;
  final AcademyDirectoryRepository? repository;
  final DirectoryNavigator navigator;

  const AdminHalaqaProfilePage({
    super.key,
    required this.halaqaId,
    this.repository,
    this.navigator = const DirectoryNavigator(),
  });

  @override
  State<AdminHalaqaProfilePage> createState() => _AdminHalaqaProfilePageState();
}

class _AdminHalaqaProfilePageState extends State<AdminHalaqaProfilePage> {
  late final AcademyDirectoryRepository _repo =
      widget.repository ?? defaultDirectoryRepository();
  HalaqaProfile? _profile;
  String? _error;
  bool _busy = false;

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
      final profile = await _repo.loadHalaqa(widget.halaqaId);
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

  Future<void> _changeTeacher(HalaqaProfile p) async {
    final current = p.staff.teacher;
    final next = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.teacher,
      title: 'المعلم الأساسي لـ${p.halaqa.displayName}',
      exclude: {?current?.uid},
    );
    if (next == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'تغيير المعلم الأساسي',
      message: 'سيصبح ${next.displayName} المعلم الأساسي بدلاً من '
          '${current?.displayName ?? 'المعلم الحالي'}، وتنتقل إليه الجلسات القادمة. '
          'السجلات السابقة تبقى كما هي.',
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.reassignStaff(halaqaId: p.halaqa.id, role: DirectoryRole.teacher, newStaffId: next.uid),
      'تم تغيير المعلم',
    );
  }

  Future<void> _changeSupervisor(HalaqaProfile p, {required bool remove}) async {
    final current = p.staff.supervisor;
    DirectoryPerson? next;
    if (!remove) {
      next = await showPersonPicker(
        context,
        repository: _repo,
        role: DirectoryRole.supervisor,
        title: 'مشرف ${p.halaqa.displayName}',
        exclude: {?current?.uid},
      );
      if (next == null || !mounted) return;
    }
    final c = await confirmRelationshipChange(
      context,
      title: remove ? 'إزالة المشرف' : 'تعيين المشرف',
      message: remove
          ? 'ستبقى ${p.halaqa.displayName} بلا مشرف حتى يُعيَّن مشرف جديد.'
          : 'سيصبح ${next!.displayName} مشرف ${p.halaqa.displayName}'
                '${current == null ? '' : ' بدلاً من ${current.displayName}'}.',
      destructive: remove,
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.reassignStaff(
        halaqaId: p.halaqa.id,
        role: DirectoryRole.supervisor,
        newStaffId: next?.uid ?? '',
      ),
      remove ? 'تمت إزالة المشرف' : 'تم تعيين المشرف',
    );
  }

  Future<void> _addAssistant(HalaqaProfile p) async {
    final a = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.assistant,
      title: 'إضافة مساعد مدرس إلى ${p.halaqa.displayName}',
      exclude: {for (final x in p.staff.assistants) x.uid},
    );
    if (a == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'إضافة مساعد',
      message: 'سيُعيَّن ${a.displayName} مساعداً في ${p.halaqa.displayName}. '
          'يبقى ${p.staff.teacher?.displayName ?? 'المعلم الأساسي'} المعلم الأساسي، '
          'والمساعد يطّلع على الحلقة فقط ما لم تُفعَّل له تغطية مؤقتة.',
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.setAssistant(halaqaId: p.halaqa.id, assistantId: a.uid, assign: true),
      'تمت إضافة المساعد',
    );
  }

  Future<void> _removeAssistant(HalaqaProfile p, DirectoryPerson a) async {
    final c = await confirmRelationshipChange(
      context,
      title: 'إلغاء تعيين المساعد',
      message: 'سيُلغى تعيين ${a.displayName} في ${p.halaqa.displayName}. يبقى السجل محفوظاً.',
      destructive: true,
    );
    if (!c.confirmed) return;
    await _change(
      () => _repo.setAssistant(halaqaId: p.halaqa.id, assistantId: a.uid, assign: false),
      'تم إلغاء التعيين',
    );
  }

  Future<void> _startCover(HalaqaProfile p) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('من يتولى الحلقة مؤقتاً؟')),
              for (final a in p.staff.assistants)
                ListTile(
                  key: Key('cover-assistant-${a.name}'),
                  leading: const Icon(Icons.support_agent),
                  title: Text(a.displayName),
                  subtitle: const Text('مساعد معيّن في هذه الحلقة'),
                  onTap: () => Navigator.pop(ctx, a.uid),
                ),
              ListTile(
                key: const Key('cover-other-teacher'),
                leading: const Icon(Icons.person_search),
                title: const Text('معلم آخر'),
                subtitle: const Text('يُتحقق من تعارض مواعيده'),
                onTap: () => Navigator.pop(ctx, '__teacher__'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    DirectoryPerson? cover;
    if (choice == '__teacher__') {
      cover = await showPersonPicker(
        context,
        repository: _repo,
        role: DirectoryRole.teacher,
        title: 'المعلم البديل مؤقتاً',
        exclude: {?p.staff.teacher?.uid},
      );
    } else {
      cover = p.staff.assistants.where((a) => a.uid == choice).firstOrNull;
    }
    if (cover == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'بدء تغطية مؤقتة',
      message: 'سيتولى ${cover.displayName} تسجيل الحضور والتقييم في ${p.halaqa.displayName} '
          'حتى إنهاء التغطية. يبقى ${p.staff.teacher?.displayName ?? 'المعلم الأساسي'} '
          'المعلم الأساسي، وتُسجَّل كل جلسة باسم من تولاها فعلاً.',
      askReason: true,
      confirmLabel: 'بدء التغطية',
    );
    if (!c.confirmed) return;
    final coverId = cover.uid;
    await _change(
      () => _repo.startCover(halaqaId: p.halaqa.id, coverTeacherId: coverId, reason: c.reason),
      'بدأت التغطية المؤقتة',
    );
  }

  Future<void> _endCover(HalaqaProfile p) async {
    final c = await confirmRelationshipChange(
      context,
      title: 'إنهاء التغطية',
      message: 'تعود ${p.halaqa.displayName} إلى وضعها الطبيعي مع '
          '${p.staff.teacher?.displayName ?? 'المعلم الأساسي'}، وتُحفظ فترة التغطية في السجل.',
      confirmLabel: 'إنهاء التغطية',
    );
    if (!c.confirmed) return;
    await _change(() => _repo.endCover(halaqaId: p.halaqa.id), 'انتهت التغطية المؤقتة');
  }

  Future<void> _admitStudent(HalaqaProfile p) async {
    final s = await showPersonPicker(
      context,
      repository: _repo,
      role: DirectoryRole.student,
      title: 'إضافة طالب إلى ${p.halaqa.displayName}',
      exclude: {for (final x in p.students) x.student.uid},
    );
    if (s == null || !mounted) return;
    final c = await confirmRelationshipChange(
      context,
      title: 'إضافة طالب',
      message: 'سيُضاف ${s.displayName} إلى ${p.halaqa.displayName}.',
    );
    if (!c.confirmed) return;
    await _change(() => _repo.admitStudent(halaqaId: p.halaqa.id, studentId: s.uid), 'تمت الإضافة');
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    return AdminSubpageScaffold(
      title: p?.halaqa.displayName ?? 'ملف الحلقة',
      subtitle: p == null || p.halaqa.academyRef.isEmpty ? null : p.halaqa.academyRef,
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
          : RefreshIndicator(onRefresh: _load, child: _body(p)),
    );
  }

  Widget _body(HalaqaProfile p) {
    final staff = p.staff;
    final open = p.halaqa.isOpen;
    final activeCover = p.coverPeriods.where((c) => c.isActive).firstOrNull;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Card(
          child: ListTile(
            key: const Key('halaqa-header'),
            leading: const Icon(Icons.groups_outlined),
            title: Text(p.halaqa.displayName, style: AppTextStyles.titleMedium),
            subtitle: Text(
              '${p.halaqa.studentCount} طالب — ${open ? 'نشطة' : 'مغلقة'}',
            ),
          ),
        ),
        if (_busy) const LinearProgressIndicator(),
        DirectorySection(
          title: 'المواعيد',
          emptyText: 'لا توجد مواعيد مسجلة.',
          children: [
            Wrap(spacing: 6, children: [for (final s in p.schedule) Chip(label: Text(s))]),
          ],
        ),
        DirectorySection(
          title: 'الطاقم',
          children: [
            if (staff.teacher != null)
              PersonTile(
                person: staff.teacher!,
                detail: 'المعلم الأساسي',
                onTap: () => _open(staff.teacher!),
              ),
            if (staff.supervisor != null)
              PersonTile(
                person: staff.supervisor!,
                detail: 'المشرف',
                onTap: () => _open(staff.supervisor!),
                trailing: open
                    ? IconButton(
                        key: const Key('action-remove-supervisor'),
                        tooltip: 'إزالة المشرف',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: _busy ? null : () => _changeSupervisor(p, remove: true),
                      )
                    : null,
              )
            else
              const ListTile(contentPadding: EdgeInsets.zero, title: Text('لا يوجد مشرف')),
            for (final a in staff.assistants)
              PersonTile(
                person: a,
                detail: 'مساعد مدرس',
                onTap: () => _open(a),
                trailing: open
                    ? IconButton(
                        key: Key('action-remove-assistant-${a.name}'),
                        tooltip: 'إلغاء التعيين',
                        icon: const Icon(Icons.person_remove_outlined),
                        onPressed: _busy || staff.cover?.uid == a.uid
                            ? null
                            : () => _removeAssistant(p, a),
                      )
                    : null,
              ),
          ],
          actions: [
            if (open) ...[
              TextButton.icon(
                key: const Key('action-change-teacher'),
                onPressed: _busy ? null : () => _changeTeacher(p),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('تغيير المعلم'),
              ),
              TextButton.icon(
                key: const Key('action-set-supervisor'),
                onPressed: _busy ? null : () => _changeSupervisor(p, remove: false),
                icon: const Icon(Icons.manage_accounts_outlined),
                label: Text(staff.supervisor == null ? 'تعيين مشرف' : 'تغيير المشرف'),
              ),
              TextButton.icon(
                key: const Key('action-add-assistant'),
                onPressed: _busy ? null : () => _addAssistant(p),
                icon: const Icon(Icons.person_add_alt),
                label: const Text('إضافة مساعد'),
              ),
            ],
          ],
        ),
        DirectorySection(
          title: 'التغطية المؤقتة',
          children: [
            if (staff.cover != null)
              PersonTile(
                person: staff.cover!,
                detail: activeCover == null
                    ? 'يتولى الحلقة الآن'
                    : 'منذ ${formatDirectoryDate(activeCover.startedAt)}'
                          '${activeCover.reason.isEmpty ? '' : ' — ${activeCover.reason}'}',
                onTap: () => _open(staff.cover!),
              )
            else
              Text(
                'لا توجد تغطية نشطة؛ ${staff.teacher?.displayName ?? 'المعلم الأساسي'} يتولى الحلقة.',
                style: AppTextStyles.labelMedium,
              ),
          ],
          actions: [
            if (open && staff.cover == null)
              TextButton.icon(
                key: const Key('action-start-cover'),
                onPressed: _busy ? null : () => _startCover(p),
                icon: const Icon(Icons.play_circle_outline),
                label: const Text('بدء تغطية مؤقتة'),
              ),
            if (staff.cover != null)
              TextButton.icon(
                key: const Key('action-end-cover'),
                onPressed: _busy ? null : () => _endCover(p),
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('إنهاء التغطية والعودة للوضع الطبيعي'),
              ),
          ],
        ),
        DirectorySection(
          title: 'الطلاب وأولياء أمورهم',
          emptyText: 'لا يوجد طلاب في الحلقة.',
          children: [
            for (final s in p.students) ...[
              PersonTile(
                person: s.student,
                detail: s.parents.isEmpty ? 'بلا ولي أمر مرتبط' : null,
                onTap: () => _open(s.student),
              ),
              if (s.parents.isNotEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 40, bottom: 4),
                  child: Wrap(
                    spacing: 6,
                    children: [
                      for (final parent in s.parents)
                        ActionChip(
                          key: Key('parent-chip-${parent.name}'),
                          label: Text('ولي الأمر: ${parent.displayName}'),
                          onPressed: () => _open(parent),
                        ),
                    ],
                  ),
                ),
            ],
          ],
          actions: [
            if (open)
              TextButton.icon(
                key: const Key('action-admit-student'),
                onPressed: _busy ? null : () => _admitStudent(p),
                icon: const Icon(Icons.group_add_outlined),
                label: const Text('إضافة طالب'),
              ),
          ],
        ),
        if (p.coverPeriods.isNotEmpty)
          DirectorySection(
            title: 'فترات التغطية',
            children: [
              for (final c in p.coverPeriods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(c.isActive ? Icons.play_circle_outline : Icons.check_circle_outline),
                  title: Text(
                    '${c.cover.displayName} (${c.coverRole == 'assistant_teacher' ? 'مساعد' : 'معلم'})',
                  ),
                  subtitle: Text(
                    '${formatDirectoryDate(c.startedAt)} ← '
                    '${c.isActive ? 'مستمرة' : formatDirectoryDate(c.endedAt)}'
                    '${c.reason.isEmpty ? '' : ' — ${c.reason}'}',
                  ),
                  onTap: () => _open(c.cover),
                ),
            ],
          ),
        RelationshipHistoryList(events: p.history),
      ],
    );
  }
}
