import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/router/app_routes.dart';
import '../../../shared/theme/app_theme.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../data/cover_duty_repository.dart';
import 'assistant_home_page.dart';

/// Shown on the teacher home only while the teacher covers another halaqa.
class TeacherCoverBanner extends StatefulWidget {
  final CoverDutyRepository? repository;

  const TeacherCoverBanner({super.key, this.repository});

  @override
  State<TeacherCoverBanner> createState() => _TeacherCoverBannerState();
}

class _TeacherCoverBannerState extends State<TeacherCoverBanner> {
  int _covers = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final s = context.read<AuthBloc>().state;
    if (s is! AuthAuthenticated) return;
    if (widget.repository == null && !sl.isRegistered<FirebaseFirestore>()) return;
    try {
      final repo = widget.repository ?? defaultCoverDutyRepository();
      final list = await repo.myHalaqat(s.user.uid, assistant: false);
      if (mounted) setState(() => _covers = list.where((h) => h.isCover).length);
    } catch (_) {
      // The banner is informational; the teacher home works without it.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_covers == 0) return const SizedBox.shrink();
    return SafeArea(
      bottom: false,
      child: Material(
        color: AppColors.primary.withValues(alpha: 0.12),
        child: ListTile(
          key: const Key('teacher-cover-banner'),
          leading: const Icon(Icons.swap_horiz),
          title: Text(_covers == 1 ? 'لديك تغطية مؤقتة لحلقة' : 'لديك تغطية مؤقتة لـ$_covers حلقات'),
          subtitle: const Text('اضغط لتسجيل الحضور'),
          onTap: () => context.push(AppRoutes.teacherCover),
        ),
      ),
    );
  }
}
