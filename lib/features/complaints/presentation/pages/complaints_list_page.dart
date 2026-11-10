import 'package:flutter/material.dart';

import '../../../../core/error/user_facing_error.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_subpage_scaffold.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../admin/presentation/widgets/admin_figma_widgets.dart';
import '../../data/complaints_repository.dart';
import '../../domain/complaint.dart';
import '../complaint_widgets.dart';
import 'complaint_details_page.dart';
import 'submit_complaint_page.dart';

/// Admin: every complaint, filterable by status. Others: their own threads
/// (history) with a "new complaint" action. Cursor-paginated.
class ComplaintsListPage extends StatefulWidget {
  const ComplaintsListPage({
    super.key,
    required this.viewer,
    required this.repository,
  });

  final ComplaintViewer viewer;
  final ComplaintsRepository repository;

  @override
  State<ComplaintsListPage> createState() => _ComplaintsListPageState();
}

class _ComplaintsListPageState extends State<ComplaintsListPage> {
  final _scroll = ScrollController();
  final List<Complaint> _items = [];
  ComplaintStatus? _filter;
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _error = null;
      _loading = false;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() => _loading = true);
    try {
      final page = await widget.repository.fetchPage(
        senderId: widget.viewer.isAdmin ? null : widget.viewer.uid,
        status: widget.viewer.isAdmin ? _filter : null,
        cursor: _cursor,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.cursor != null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = userFacingErrorText(e.toString());
        _loading = false;
      });
    }
  }

  Future<void> _open(Complaint c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ComplaintDetailsPage(
          complaintId: c.id,
          viewer: widget.viewer,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) _reload();
  }

  Future<void> _create() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SubmitComplaintPage(
          viewer: widget.viewer,
          repository: widget.repository,
        ),
      ),
    );
    if (id != null && mounted) _reload();
  }

  void _setFilter(ComplaintStatus? s) {
    if (_filter == s) return;
    _filter = s;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final admin = widget.viewer.isAdmin;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: widget.viewer.canSubmit
            ? FloatingActionButton.extended(
                key: const Key('complaints-new'),
                onPressed: _create,
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('شكوى جديدة'),
              )
            : null,
        body: AppSubpageScaffold(
          title: admin ? 'الشكاوى' : 'شكاواي',
          body: Column(
            children: [
              if (admin)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      AdminFilterChip(
                        label: 'الكل',
                        selected: _filter == null,
                        onTap: () => _setFilter(null),
                      ),
                      for (final s in ComplaintStatus.values)
                        AdminFilterChip(
                          label: s.label,
                          selected: _filter == s,
                          onTap: () => _setFilter(s),
                        ),
                    ],
                  ),
                ),
              Expanded(child: _body(admin)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(bool admin) {
    if (_items.isEmpty && _loading) return const AppLoadingWidget();
    if (_items.isEmpty && _error != null) {
      return AppErrorWidget(message: _error!, onRetry: _reload);
    }
    if (_items.isEmpty) {
      return AppEmptyState(
        icon: Icons.mark_chat_read_outlined,
        title: admin ? 'لا توجد شكاوى' : 'لم ترسل أي شكوى بعد',
        message: admin
            ? 'ستظهر هنا الشكاوى المرسلة من أولياء الأمور والمعلمين والمشرفين.'
            : 'يمكنك إرسال شكوى إلى إدارة الأكاديمية ومتابعة الرد هنا.',
      );
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          if (i == _items.length) {
            if (_error != null) {
              return TextButton(
                onPressed: _loadMore,
                child: const Text('تعذر تحميل المزيد — إعادة المحاولة'),
              );
            }
            return _hasMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const SizedBox.shrink();
          }
          final c = _items[i];
          return ComplaintCard(
            key: Key('complaint-${c.id}'),
            complaint: c,
            showSender: admin,
            onTap: () => _open(c),
          );
        },
      ),
    );
  }
}
