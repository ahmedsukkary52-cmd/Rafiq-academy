import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/error/exception.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/confirm_logout.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../data/cover_duty_repository.dart';
import 'cover_attendance_page.dart';

CoverDutyRepository defaultCoverDutyRepository() => FirestoreCoverDutyRepository(
  firestore: sl<FirebaseFirestore>(),
  functions: sl<FirebaseFunctions>(),
);

/// Assistant teacher home: the halaqat the assistant is assigned to (read
/// only) and any halaqa it is covering now (attendance enabled). The primary
/// teacher stays the halaqa's teacher; the server records who handled each
/// session.
class AssistantHomePage extends StatefulWidget {
  final CoverDutyRepository? repository;

  /// Covering teachers reuse this screen without the assistant list.
  final bool assistant;
  final String? uid;
  final String? name;

  const AssistantHomePage({
    super.key,
    this.repository,
    this.assistant = true,
    this.uid,
    this.name,
  });

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  late final CoverDutyRepository _repo = widget.repository ?? defaultCoverDutyRepository();
  List<DutyHalaqa>? _halaqat;
  String? _error;

  String get _uid {
    if (widget.uid != null) return widget.uid!;
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.uid : '';
  }

  String get _name {
    if (widget.name != null) return widget.name!;
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s.user.name : '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _repo.myHalaqat(_uid, assistant: widget.assistant);
      if (mounted) setState(() => _halaqat = list);
    } on ServerException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _halaqat;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(widget.assistant ? 'مساعد المدرس' : 'التغطية المؤقتة'),
          actions: [
            if (widget.assistant)
              IconButton(
                key: const Key('assistant-logout'),
                tooltip: 'تسجيل الخروج',
                icon: const Icon(Icons.logout),
                onPressed: () => confirmAndLogout(context),
              ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.paddingM),
            children: [
              if (widget.assistant && _name.isNotEmpty)
                Text('أهلاً $_name', style: AppTextStyles.titleMedium),
              const SizedBox(height: 4),
              Text(
                widget.assistant
                    ? 'تطّلع على الحلقات المعيّن فيها. تسجيل الحضور يُفعَّل فقط عندما '
                          'يبدأ المسؤول تغطية مؤقتة باسمك.'
                    : 'الحلقات التي تتولاها مؤقتاً بتكليف من المسؤول.',
                style: AppTextStyles.labelMedium,
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(_error!, textAlign: TextAlign.center),
                TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ] else if (list == null)
                const Center(child: CircularProgressIndicator())
              else if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSizes.paddingL),
                  child: Text('لا توجد حلقات معيّنة لك حالياً.', textAlign: TextAlign.center),
                )
              else
                for (final h in list)
                  AppCard(
                    key: Key('duty-${h.name}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(h.displayName, style: AppTextStyles.titleMedium)),
                            Chip(
                              label: Text(h.isCover ? 'تغطية مؤقتة نشطة' : 'مساعد'),
                              backgroundColor: h.isCover
                                  ? AppColors.primary.withValues(alpha: 0.15)
                                  : null,
                            ),
                          ],
                        ),
                        Text(
                          'المعلم الأساسي: ${h.teacherName.isEmpty ? 'غير معروف' : h.teacherName}'
                          ' — ${h.studentIds.length} طالب',
                        ),
                        if (h.schedule.isNotEmpty)
                          Wrap(spacing: 6, children: [for (final s in h.schedule) Chip(label: Text(s))]),
                        if (h.isCover)
                          AppButton(
                            key: Key('duty-attendance-${h.name}'),
                            label: 'تسجيل حضور اليوم',
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CoverAttendancePage(halaqa: h, repository: _repo),
                              ),
                            ),
                          )
                        else
                          Text(
                            'للاطلاع فقط — لا توجد تغطية نشطة باسمك.',
                            key: Key('duty-readonly-${h.name}'),
                            style: AppTextStyles.labelMedium,
                          ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
