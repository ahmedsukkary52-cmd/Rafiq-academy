import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/error/exception.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../chat/data/chat_groups_repository.dart';
import '../../../chat/presentation/widgets/chat_person_search.dart';

/// `grp_` + 24 hex chars; one per page so a retried submit is idempotent.
String newChatGroupRequestId([Random? random]) {
  final r = random ?? Random.secure();
  final hex = List.generate(24, (_) => r.nextInt(16).toRadixString(16)).join();
  return 'grp_$hex';
}

typedef CreateChatGroup =
    Future<String> Function({
      required String requestId,
      required String title,
      required String description,
      required List<String> memberIds,
    });

/// Admin creates a custom group of staff and parents (students are never
/// listed). Returns the new conversation id via [Navigator.pop].
class AdminCreateChatGroupPage extends StatefulWidget {
  final CreateChatGroup create;
  final ChatPeopleSearch search;

  const AdminCreateChatGroupPage({
    super.key,
    required this.create,
    required this.search,
  });

  @override
  State<AdminCreateChatGroupPage> createState() =>
      _AdminCreateChatGroupPageState();
}

class _AdminCreateChatGroupPageState extends State<AdminCreateChatGroupPage> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final Map<String, ChatPersonHit> _members = {};
  final String _requestId = newChatGroupRequestId();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  String? get _problem {
    if (_title.text.trim().length < 2) return 'اكتب اسماً للمجموعة (حرفان على الأقل)';
    if (_members.isEmpty) return 'أضف عضواً واحداً على الأقل';
    return null;
  }

  Future<void> _submit() async {
    final problem = _problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = await widget.create(
        requestId: _requestId,
        title: _title.text,
        description: _description.text,
        memberIds: _members.keys.toList(),
      );
      if (!mounted) return;
      AppSnackBar.showSuccess(context, 'تم إنشاء المجموعة');
      Navigator.pop(context, id);
    } on ServerException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('مجموعة جديدة')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              key: const Key('group-title'),
              controller: _title,
              maxLength: 60,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'اسم المجموعة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('group-description'),
              controller: _description,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'الوصف (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'الأعضاء (${_members.length})',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in _members.values)
                  InputChip(
                    key: Key('group-member-chip-${m.uid}'),
                    label: Text('${m.name} · ${chatRoleLabel(m.role)}'),
                    onDeleted: _submitting
                        ? null
                        : () => setState(() => _members.remove(m.uid)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ChatPersonSearch(
              search: widget.search,
              selected: _members.keys.toSet(),
              onTap: (hit) => setState(() {
                if (_members.remove(hit.uid) == null) _members[hit.uid] = hit;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('group-error'),
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('group-create'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('إنشاء المجموعة'),
            ),
          ],
        ),
      ),
    );
  }
}
