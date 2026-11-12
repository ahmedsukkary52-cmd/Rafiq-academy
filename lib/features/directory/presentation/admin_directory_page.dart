import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/error/exception.dart';
import '../../../core/presentation/academy_data_revision.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/admin_subpage_scaffold.dart';
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';
import 'directory_navigation.dart';
import 'directory_pickers.dart';

AcademyDirectoryRepository defaultDirectoryRepository() =>
    FirestoreAcademyDirectoryRepository(
      firestore: sl<FirebaseFirestore>(),
      functions: sl<FirebaseFunctions>(),
    );

/// Admin-only academy directory: every person and halaqa, searchable by name
/// or academy code, filtered by role, status, halaqa and relationship, and
/// loaded one page at a time.
class AdminDirectoryPage extends StatefulWidget {
  final AcademyDirectoryRepository? repository;
  final DirectoryNavigator navigator;

  const AdminDirectoryPage({
    super.key,
    this.repository,
    this.navigator = const DirectoryNavigator(),
  });

  @override
  State<AdminDirectoryPage> createState() => _AdminDirectoryPageState();
}

class _AdminDirectoryPageState extends State<AdminDirectoryPage>
    with SingleTickerProviderStateMixin {
  late final AcademyDirectoryRepository _repo =
      widget.repository ?? defaultDirectoryRepository();

  // Tab 0 is the overview, 1..6 the roles, 7 the halaqat.
  late final TabController _tabs = TabController(
    length: DirectoryRole.values.length + 2,
    vsync: this,
  );
  final Map<DirectoryRole, StructureCount> _presets = {};
  HalaqaListFilter _halaqaPreset = HalaqaListFilter.all;
  int _presetVersion = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _openFromOverview(StructureCount c) {
    setState(() {
      _presetVersion++;
      if (c.halaqaFilter != null) {
        _halaqaPreset = c.halaqaFilter!;
        _tabs.animateTo(DirectoryRole.values.length + 1);
      } else if (c.role != null) {
        _presets[c.role!] = c;
        _tabs.animateTo(c.role!.index + 1);
      } else if (c.status == DirectoryStatusFilter.inactive) {
        for (final r in DirectoryRole.values) {
          _presets[r] = StructureCount(label: c.label, count: 0, role: r, status: c.status);
        }
        _tabs.animateTo(1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AdminSubpageScaffold(
      title: 'دليل الأكاديمية',
      subtitle: 'الطلاب وأولياء الأمور والطاقم والحلقات وعلاقاتهم',
      body: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                const Tab(key: Key('dir-tab-overview'), text: 'نظرة عامة'),
                for (final r in DirectoryRole.values)
                  Tab(key: Key('dir-tab-${r.wire}'), text: r.plural),
                const Tab(key: Key('dir-tab-halaqat'), text: 'الحلقات'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _OverviewTab(repository: _repo, onOpen: _openFromOverview),
                for (final r in DirectoryRole.values)
                  _PeopleTab(
                    key: ValueKey('people-${r.wire}-$_presetVersion'),
                    role: r,
                    preset: _presets[r],
                    repository: _repo,
                    navigator: widget.navigator,
                  ),
                _HalaqatTab(
                  key: ValueKey('halaqat-$_presetVersion'),
                  initialFilter: _halaqaPreset,
                  repository: _repo,
                  navigator: widget.navigator,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reloads whenever an academy structure change is committed anywhere.
mixin _RevisionReload<T extends StatefulWidget> on State<T> {
  void reload();

  @override
  void initState() {
    super.initState();
    AcademyDataRevision.structure.addListener(reload);
  }

  @override
  void dispose() {
    AcademyDataRevision.structure.removeListener(reload);
    super.dispose();
  }
}

class _OverviewTab extends StatefulWidget {
  final AcademyDirectoryRepository repository;
  final void Function(StructureCount) onOpen;

  const _OverviewTab({required this.repository, required this.onOpen});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> with _RevisionReload {
  List<StructureCount>? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void reload() async {
    setState(() => _error = null);
    try {
      final counts = await widget.repository.structureOverview();
      if (mounted) setState(() => _counts = counts);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    if (_error != null) return _Retry(message: _error!, onRetry: reload);
    if (counts == null) return const Center(child: CircularProgressIndicator());
    final navigable = counts.where(
      (c) => c.role != null || c.halaqaFilter != null || c.status != DirectoryStatusFilter.all,
    );
    final info = counts.where((c) => !navigable.contains(c));
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Text(
          'أعداد فعلية من قاعدة البيانات. اضغط على أي بند لفتح القائمة المقابلة.',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: 8),
        for (final c in navigable)
          Card(
            child: ListTile(
              key: Key('overview-${c.label}'),
              title: Text(c.label),
              trailing: Text('${c.count}', style: AppTextStyles.titleMedium),
              onTap: () => widget.onOpen(c),
            ),
          ),
        for (final c in info)
          Card(
            child: ListTile(
              key: Key('overview-${c.label}'),
              title: Text(c.label),
              subtitle: const Text('تظهر الحالة في ملف كل حساب'),
              trailing: Text('${c.count}', style: AppTextStyles.titleMedium),
            ),
          ),
      ],
    );
  }
}

class _PeopleTab extends StatefulWidget {
  final DirectoryRole role;
  final StructureCount? preset;
  final AcademyDirectoryRepository repository;
  final DirectoryNavigator navigator;

  const _PeopleTab({
    super.key,
    required this.role,
    required this.preset,
    required this.repository,
    required this.navigator,
  });

  @override
  State<_PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<_PeopleTab>
    with AutomaticKeepAliveClientMixin, _RevisionReload {
  final _query = TextEditingController();
  Timer? _debounce;
  late DirectoryStatusFilter _status = widget.preset?.status ?? DirectoryStatusFilter.all;
  late DirectoryRelationFilter _relation =
      widget.preset?.relation ?? DirectoryRelationFilter.none;
  DirectoryHalaqa? _halaqa;

  final List<DirectoryPerson> _items = [];
  Object? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;
  bool _searchMode = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  @override
  void reload() {
    final q = _query.text.trim();
    q.isEmpty ? _loadPage(reset: true) : _search(q);
  }

  int _generation = 0;

  Future<void> _loadPage({required bool reset}) async {
    if (_loading && !reset) return;
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _searchMode = false;
      if (reset) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      final page = await widget.repository.browsePeople(
        role: widget.role,
        status: _status,
        relation: _relation,
        halaqaId: _halaqa?.id,
        cursor: _cursor,
      );
      if (!mounted || gen != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
      });
    } on ServerException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _search(String q) async {
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _searchMode = true;
    });
    try {
      final hits = await widget.repository.searchPeople(role: widget.role, query: q);
      if (!mounted || gen != _generation) return;
      setState(() {
        _items
          ..clear()
          ..addAll(hits.where((p) => _status == DirectoryStatusFilter.all ||
              p.isActive == (_status == DirectoryStatusFilter.active)));
        _hasMore = false;
      });
    } on ServerException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), reload);
  }

  Future<void> _pickHalaqa() async {
    final h = await showHalaqaPicker(
      context,
      repository: widget.repository,
      title: 'عرض طلاب حلقة',
    );
    if (h == null) return;
    setState(() {
      _halaqa = h;
      _relation = DirectoryRelationFilter.none;
    });
    reload();
  }

  void _add() => switch (widget.role) {
    DirectoryRole.student => widget.navigator.addStudent(context),
    DirectoryRole.admin => widget.navigator.addAdmin(context),
    _ => widget.navigator.addMember(context, widget.role),
  };

  List<DirectoryRelationFilter> get _relations => switch (widget.role) {
    DirectoryRole.student => const [DirectoryRelationFilter.studentsWithoutHalaqa],
    DirectoryRole.parent => const [DirectoryRelationFilter.parentsWithoutChildren],
    _ => const [],
  };

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final role = widget.role;
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('dir-search-${role.wire}'),
                controller: _query,
                onChanged: _onQuery,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الأكاديمية',
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: Key('dir-add-${role.wire}'),
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text('إضافة ${role.label}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in DirectoryStatusFilter.values)
              ChoiceChip(
                key: Key('dir-status-${role.wire}-${s.name}'),
                label: Text(s.label),
                selected: _status == s,
                onSelected: (_) {
                  setState(() => _status = s);
                  reload();
                },
              ),
            for (final r in _relations)
              FilterChip(
                key: Key('dir-relation-${r.name}'),
                label: Text(r.label),
                selected: _relation == r,
                onSelected: (on) {
                  setState(() {
                    _relation = on ? r : DirectoryRelationFilter.none;
                    if (on) _halaqa = null;
                  });
                  reload();
                },
              ),
            if (role == DirectoryRole.student)
              InputChip(
                key: const Key('dir-halaqa-filter'),
                avatar: const Icon(Icons.groups_outlined, size: 18),
                label: Text(_halaqa == null ? 'حسب الحلقة' : _halaqa!.displayName),
                selected: _halaqa != null,
                onPressed: _pickHalaqa,
                onDeleted: _halaqa == null
                    ? null
                    : () {
                        setState(() => _halaqa = null);
                        reload();
                      },
              ),
          ],
        ),
        if (_searchMode && (_relation != DirectoryRelationFilter.none || _halaqa != null))
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'البحث يشمل كل ${role.plural}؛ امسح البحث لتطبيق تصفية العلاقة أو الحلقة.',
              style: AppTextStyles.labelMedium,
            ),
          ),
        const SizedBox(height: 8),
        if (_error != null) _Retry(message: _error!, onRetry: reload),
        if (!_loading && _error == null && _items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSizes.paddingL),
            child: Text(
              _searchMode ? 'لا توجد نتائج مطابقة' : 'لا يوجد ${role.plural} ضمن هذه التصفية',
              textAlign: TextAlign.center,
            ),
          ),
        for (final p in _items)
          Card(
            child: ListTile(
              key: Key('dir-person-${p.academyRef.isEmpty ? p.name : p.academyRef}'),
              leading: CircleAvatar(child: Text(p.displayName.characters.first)),
              title: Text(p.displayName),
              subtitle: Text(p.caption),
              trailing: p.isActive
                  ? const Icon(Icons.chevron_left)
                  : const Chip(label: Text('غير نشط')),
              onTap: () => widget.navigator.openPerson(context, p.uid),
            ),
          ),
        if (_loading) const Padding(
          padding: EdgeInsets.all(AppSizes.paddingM),
          child: Center(child: CircularProgressIndicator()),
        ),
        if (!_loading && _hasMore && !_searchMode)
          TextButton(
            key: Key('dir-more-${role.wire}'),
            onPressed: () => _loadPage(reset: false),
            child: const Text('تحميل المزيد'),
          ),
      ],
    );
  }
}

class _HalaqatTab extends StatefulWidget {
  final HalaqaListFilter initialFilter;
  final AcademyDirectoryRepository repository;
  final DirectoryNavigator navigator;

  const _HalaqatTab({
    super.key,
    required this.initialFilter,
    required this.repository,
    required this.navigator,
  });

  @override
  State<_HalaqatTab> createState() => _HalaqatTabState();
}

class _HalaqatTabState extends State<_HalaqatTab>
    with AutomaticKeepAliveClientMixin, _RevisionReload {
  final _query = TextEditingController();
  Timer? _debounce;
  late HalaqaListFilter _filter = widget.initialFilter;
  final List<DirectoryHalaqa> _items = [];
  Object? _cursor;
  bool _hasMore = false;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  int _generation = 0;

  @override
  void reload() => _load(reset: true);

  Future<void> _load({required bool reset}) async {
    final q = _query.text.trim();
    final gen = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items.clear();
        _cursor = null;
      }
    });
    try {
      if (q.isNotEmpty) {
        final hits = await widget.repository.searchHalaqat(q);
        if (!mounted || gen != _generation) return;
        setState(() {
          _items.addAll(hits);
          _hasMore = false;
        });
      } else {
        final page = await widget.repository.browseHalaqat(filter: _filter, cursor: _cursor);
        if (!mounted || gen != _generation) return;
        setState(() {
          _items.addAll(page.items);
          _cursor = page.cursor;
          _hasMore = page.hasMore;
        });
      }
    } on ServerException catch (e) {
      if (mounted && gen == _generation) setState(() => _error = e.message);
    } finally {
      if (mounted && gen == _generation) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        TextField(
          key: const Key('dir-search-halaqat'),
          controller: _query,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), reload);
          },
          textDirection: TextDirection.rtl,
          decoration: const InputDecoration(
            hintText: 'ابحث باسم الحلقة أو رمزها',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in HalaqaListFilter.values)
              ChoiceChip(
                key: Key('dir-halaqa-filter-${f.name}'),
                label: Text(f.label),
                selected: _filter == f,
                onSelected: (_) {
                  setState(() => _filter = f);
                  reload();
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_error != null) _Retry(message: _error!, onRetry: reload),
        if (!_loading && _error == null && _items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(AppSizes.paddingL),
            child: Text('لا توجد حلقات ضمن هذه التصفية', textAlign: TextAlign.center),
          ),
        for (final h in _items)
          Card(
            child: ListTile(
              key: Key('dir-halaqa-${h.name}'),
              leading: const Icon(Icons.groups_outlined),
              title: Text(h.academyRef.isEmpty ? h.displayName : '${h.displayName} · ${h.academyRef}'),
              subtitle: Text(
                'المعلم: ${h.teacherName.isEmpty ? 'غير معيّن' : h.teacherName}'
                ' — المشرف: ${h.supervisorName.isEmpty ? 'غير معيّن' : h.supervisorName}'
                ' — ${h.studentCount} طالب'
                '${h.assistantCount > 0 ? ' — ${h.assistantCount} مساعد' : ''}'
                '${h.hasActiveCover ? ' — تغطية مؤقتة نشطة' : ''}'
                '${h.isOpen ? '' : ' — مغلقة'}',
              ),
              onTap: () => widget.navigator.openHalaqa(context, h.id),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSizes.paddingM),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (!_loading && _hasMore)
          TextButton(
            key: const Key('dir-more-halaqat'),
            onPressed: () => _load(reset: false),
            child: const Text('تحميل المزيد'),
          ),
      ],
    );
  }
}

class _Retry extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _Retry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSizes.paddingL),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
      ],
    ),
  );
}
