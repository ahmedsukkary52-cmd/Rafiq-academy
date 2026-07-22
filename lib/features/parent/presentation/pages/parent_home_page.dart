import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/usecases/get_student_profile_usecase.dart';
import '../../../student/domain/usecases/watch_latest_assignment_usecase.dart';
import '../bloc/parent_bloc.dart';
import '../bloc/parent_event.dart';
import '../bloc/parent_state.dart';

/// Sprint 1 — minimal parent dashboard (children list only).
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  /// Resolved display names keyed by student uid (ParentBloc only stores ids).
  final Map<String, String> _childNames = {};
  List<String> _namesRequestIds = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadChildren());
  }

  void _loadChildren() {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) return;
    context.read<ParentBloc>().add(LoadChildrenEvent(authState.user.uid));
  }

  Future<void> _resolveChildNames(List<String> childrenIds) async {
    if (childrenIds.isEmpty) {
      if (_childNames.isNotEmpty) {
        setState(() => _childNames.clear());
      }
      _namesRequestIds = const [];
      return;
    }

    // Avoid re-fetching the same set while a request is in flight / already done.
    if (_listEquals(_namesRequestIds, childrenIds) &&
        _childNames.keys.toSet().containsAll(childrenIds)) {
      return;
    }
    _namesRequestIds = List<String>.from(childrenIds);

    final getProfile = sl<GetStudentProfileUseCase>();
    final resolved = <String, String>{};

    await Future.wait(
      childrenIds.map((id) async {
        final result = await getProfile(StudentUidParams(id));
        result.fold(
          (_) => resolved[id] = 'طالب',
          (profile) => resolved[id] =
              profile.name.trim().isEmpty ? 'طالب' : profile.name.trim(),
        );
      }),
    );

    if (!mounted) return;
    if (!_listEquals(_namesRequestIds, childrenIds)) return;

    setState(() {
      _childNames
        ..clear()
        ..addAll(resolved);
    });
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final parentName = authState is AuthAuthenticated
        ? authState.user.name
        : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('نافذة ولي الأمر')),
      body: BlocConsumer<ParentBloc, ParentState>(
        listenWhen: (prev, curr) =>
            prev.childrenIds != curr.childrenIds ||
            prev.childrenStatus != curr.childrenStatus,
        listener: (context, state) {
          if (state.childrenStatus == SectionStatus.loaded) {
            _resolveChildNames(state.childrenIds);
          }
        },
        buildWhen: (prev, curr) =>
            prev.childrenStatus != curr.childrenStatus ||
            prev.childrenIds != curr.childrenIds ||
            prev.childrenError != curr.childrenError,
        builder: (context, state) {
          if (state.childrenStatus == SectionStatus.initial ||
              state.childrenStatus == SectionStatus.loading) {
            return const AppLoadingWidget();
          }

          if (state.childrenStatus == SectionStatus.error) {
            return AppErrorWidget(
              message: state.childrenError ?? 'حدث خطأ',
              onRetry: _loadChildren,
            );
          }

          if (state.childrenIds.isEmpty) {
            return const _EmptyChildren();
          }

          return _ChildrenDashboard(
            parentName: parentName,
            childrenIds: state.childrenIds,
            childNames: _childNames,
            onChildTap: () => AppSnackBar.showInfo(context, 'قريبًا'),
          );
        },
      ),
    );
  }
}

class _ChildrenDashboard extends StatelessWidget {
  final String parentName;
  final List<String> childrenIds;
  final Map<String, String> childNames;
  final VoidCallback onChildTap;

  const _ChildrenDashboard({
    required this.parentName,
    required this.childrenIds,
    required this.childNames,
    required this.onChildTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingM),
      children: [
        Text(
          parentName.isEmpty ? 'ولي الأمر' : parentName,
          style: AppTextStyles.headlineLarge,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: 4),
        Text(
          'الأبناء المرتبطون: ${childrenIds.length}',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.right,
        ),
        const SizedBox(height: AppSizes.paddingM),
        ...childrenIds.map(
          (id) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChildCard(
              name: childNames[id] ?? 'طالب',
              onTap: onChildTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final String name;
  final VoidCallback onTap;

  const _ChildCard({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.chevron_left_rounded,
            color: AppColors.textHint,
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(name, style: AppTextStyles.titleLarge),
              const SizedBox(height: 2),
              Text(
                'طالب',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyChildren extends StatelessWidget {
  const _EmptyChildren();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'لا يوجد طلاب مرتبطون بهذا الحساب بعد',
              style: AppTextStyles.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'عند ربط أبنائك بحسابك من قِبل الأكاديمية ستظهر أسماؤهم هنا.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textHint,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
