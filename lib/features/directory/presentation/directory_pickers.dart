import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/error/exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../data/academy_directory_repository.dart';
import '../domain/directory_models.dart';

/// Searchable person selection by name or academy code; no free-text ids.
Future<DirectoryPerson?> showPersonPicker(
  BuildContext context, {
  required AcademyDirectoryRepository repository,
  required DirectoryRole role,
  required String title,
  Set<String> exclude = const {},
  bool activeOnly = true,
}) => showModalBottomSheet<DirectoryPerson>(
  context: context,
  isScrollControlled: true,
  builder: (_) => Directionality(
    textDirection: TextDirection.rtl,
    child: _PickerSheet<DirectoryPerson>(
      title: title,
      hint: 'ابحث بالاسم أو رقم الأكاديمية (${role.label})',
      browse: () async => (await repository.browsePeople(
        role: role,
        status: activeOnly ? DirectoryStatusFilter.active : DirectoryStatusFilter.all,
      )).items,
      search: (q) => repository.searchPeople(role: role, query: q),
      accept: (p) =>
          p.role == role.wire && !exclude.contains(p.uid) && (!activeOnly || p.isActive),
      keyOf: (p) => 'pick-person-${p.academyRef.isEmpty ? p.name : p.academyRef}',
      titleOf: (p) => p.displayName,
      subtitleOf: (p) => p.caption,
      icon: Icons.person_outline,
    ),
  ),
);

Future<DirectoryHalaqa?> showHalaqaPicker(
  BuildContext context, {
  required AcademyDirectoryRepository repository,
  required String title,
  Set<String> exclude = const {},
}) => showModalBottomSheet<DirectoryHalaqa>(
  context: context,
  isScrollControlled: true,
  builder: (_) => Directionality(
    textDirection: TextDirection.rtl,
    child: _PickerSheet<DirectoryHalaqa>(
      title: title,
      hint: 'ابحث باسم الحلقة',
      browse: () async =>
          (await repository.browseHalaqat(filter: HalaqaListFilter.active)).items,
      search: repository.searchHalaqat,
      accept: (h) => h.isOpen && !exclude.contains(h.id),
      keyOf: (h) => 'pick-halaqa-${h.name}',
      titleOf: (h) => h.displayName,
      subtitleOf: (h) =>
          'المعلم: ${h.teacherName.isEmpty ? 'غير معيّن' : h.teacherName} — ${h.studentCount} طالب',
      icon: Icons.groups_outlined,
    ),
  ),
);

class _PickerSheet<T> extends StatefulWidget {
  final String title;
  final String hint;
  final Future<List<T>> Function() browse;
  final Future<List<T>> Function(String query) search;
  final bool Function(T) accept;
  final String Function(T) keyOf;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final IconData icon;

  const _PickerSheet({
    required this.title,
    required this.hint,
    required this.browse,
    required this.search,
    required this.accept,
    required this.keyOf,
    required this.titleOf,
    required this.subtitleOf,
    required this.icon,
  });

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<T>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run(widget.browse);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _run(Future<List<T>> Function() load) async {
    setState(() => _error = null);
    try {
      final items = await load();
      if (mounted) setState(() => _items = items.where(widget.accept).toList());
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = value.trim();
      _run(q.isEmpty ? widget.browse : () => widget.search(q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingM),
              child: Text(widget.title, style: AppTextStyles.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
              child: TextField(
                key: const Key('picker-search'),
                controller: _query,
                onChanged: _onChanged,
                textDirection: TextDirection.rtl,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!))
                  : items == null
                  ? const Center(child: CircularProgressIndicator())
                  : items.isEmpty
                  ? const Center(child: Text('لا توجد نتائج مطابقة'))
                  : ListView(
                      children: [
                        for (final item in items)
                          ListTile(
                            key: Key(widget.keyOf(item)),
                            leading: Icon(widget.icon),
                            title: Text(widget.titleOf(item)),
                            subtitle: Text(widget.subtitleOf(item)),
                            onTap: () => Navigator.of(context).pop(item),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmation for a relationship change, with an optional reason.
Future<({bool confirmed, String reason})> confirmRelationshipChange(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
  bool askReason = false,
  bool destructive = false,
}) async {
  final reason = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message),
            if (askReason) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('change-reason'),
                controller: reason,
                maxLength: 200,
                decoration: const InputDecoration(hintText: 'السبب (اختياري)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(
            key: const Key('confirm-change'),
            style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    ),
  );
  return (confirmed: ok == true, reason: reason.text);
}
