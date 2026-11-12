import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../data/chat_groups_repository.dart';

typedef ChatPeopleSearch = Future<List<ChatPersonHit>> Function(String query);

String chatRoleLabel(String role) => switch (role) {
  AppRoles.teacher => 'معلم',
  AppRoles.parent => 'ولي أمر',
  AppRoles.supervisor => 'مشرف',
  AppRoles.admin => 'إدارة',
  AppRoles.student => 'طالب',
  _ => role,
};

/// Debounced name search over staff and parents (students are never listed).
/// Single mode returns the tapped person; multi mode toggles [selected].
class ChatPersonSearch extends StatefulWidget {
  final ChatPeopleSearch search;
  final ValueChanged<ChatPersonHit> onTap;
  final Set<String> selected;
  final Set<String> disabled;
  final String hint;

  const ChatPersonSearch({
    super.key,
    required this.search,
    required this.onTap,
    this.selected = const {},
    this.disabled = const {},
    this.hint = 'ابحث بالاسم (حرفان على الأقل)',
  });

  @override
  State<ChatPersonSearch> createState() => _ChatPersonSearchState();
}

class _ChatPersonSearchState extends State<ChatPersonSearch> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<ChatPersonHit> _hits = const [];
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(value));
  }

  Future<void> _run(String value) async {
    final q = value.trim();
    final generation = ++_generation;
    if (q.length < 2) {
      setState(() {
        _hits = const [];
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hits = await widget.search(q);
      if (!mounted || generation != _generation) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'تعذر البحث الآن، أعد المحاولة';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _ctrl.text.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('chat-person-search'),
          controller: _ctrl,
          onChanged: _onChanged,
          textAlign: TextAlign.right,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.search_rounded),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
          )
        else if (query.length >= 2 && _hits.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              'لا توجد نتائج مطابقة',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          for (final hit in _hits)
            ListTile(
              key: Key('chat-person-${hit.uid}'),
              enabled: !widget.disabled.contains(hit.uid),
              leading: CircleAvatar(
                backgroundColor: AppColors.primaryLight,
                child: Text(
                  hit.name.trim().isEmpty ? '؟' : hit.name.trim()[0],
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
              title: Text(hit.name.isEmpty ? 'بدون اسم' : hit.name),
              subtitle: Text(
                widget.disabled.contains(hit.uid)
                    ? '${chatRoleLabel(hit.role)} · عضو بالفعل'
                    : chatRoleLabel(hit.role),
              ),
              trailing: widget.selected.contains(hit.uid)
                  ? const Icon(Icons.check_circle, color: AppColors.primary)
                  : null,
              onTap: () => widget.onTap(hit),
            ),
      ],
    );
  }
}
