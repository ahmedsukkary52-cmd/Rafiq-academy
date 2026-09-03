import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';
import '../../../chat/presentation/bloc/chat_conversations_bloc.dart';
import '../../../chat/presentation/bloc/chat_conversations_event.dart';
import '../../../chat/presentation/pages/chat_room.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';
import '../../../teacher/domain/entities/halaqa_students_summary_entity.dart';
import '../../../teacher/domain/repositories/teacher_repository.dart';
import '../../../teacher/domain/usecases/get_halaqa_students_usecase.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../supervisor_destinations.dart';
import '../widgets/supervisor_subpage_scaffold.dart';
import '../widgets/supervisor_loading_skeletons.dart';

class SupervisorFollowUpPage extends StatefulWidget {
  const SupervisorFollowUpPage({super.key});

  @override
  State<SupervisorFollowUpPage> createState() => _SupervisorFollowUpPageState();
}

class _SupervisorFollowUpPageState extends State<SupervisorFollowUpPage> {
  bool _loading = true;
  String? _error;
  List<SupervisorStudentRow> _atRisk = const [];
  bool _startingChat = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final halaqat = context.read<SupervisorBloc>().state.halaqat;
    setState(() {
      _loading = true;
      _error = null;
    });

    final byHalaqa = <String, List<HalaqaStudentSummaryEntity>>{};
    String? firstError;
    for (final h in halaqat) {
      final result = await sl<GetHalaqaStudentsUseCase>()(
        HalaqaStudentsParams(h.id),
      );
      if (!mounted) return;
      result.fold(
        (f) => firstError ??= f.message,
        (list) => byHalaqa[h.id] = list,
      );
    }

    if (!mounted) return;
    final merged = SupervisorRoster.mergeSummaries(
      halaqat: halaqat,
      byHalaqaId: byHalaqa,
    );
    setState(() {
      _loading = false;
      _error = byHalaqa.isEmpty && halaqat.isNotEmpty ? firstError : null;
      _atRisk = merged.where((r) => r.isAtRisk).toList();
    });
  }

  Future<void> _openParentChat(SupervisorStudentRow row) async {
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated || _startingChat) return;

    setState(() => _startingChat = true);
    try {
      final parentsEither = await sl<ParentRepository>()
          .getParentIdsByStudentIds([row.studentId]);
      if (!mounted) return;
      final parentIds = parentsEither.fold<List<String>?>((_) {
        AppSnackBar.showInfo(context, 'تعذر التحقق من ولي الأمر حالياً');
        return null;
      }, (map) => map[row.studentId] ?? const <String>[]);
      if (parentIds == null) return;
      if (parentIds.isEmpty) {
        AppSnackBar.showInfo(context, 'لا يوجد ولي أمر مرتبط بهذا الطالب');
        return;
      }

      final parentEither = await sl<GetChatParticipantUseCase>()(
        ChatUidParams(parentIds.first),
      );
      if (!mounted) return;
      final parent = parentEither.fold<ChatParticipantEntity?>((_) {
        AppSnackBar.showInfo(context, 'تعذر فتح المحادثة');
        return null;
      }, (p) => p);
      if (parent == null) return;

      final chatBloc = sl<ChatConversationsBloc>();
      chatBloc.add(const ResetStartConversationEvent());
      chatBloc.add(
        StartConversationEvent(
          currentUser: ChatParticipantEntity(
            uid: auth.user.uid,
            name: auth.user.name,
            role: AppRoles.supervisor,
            profileImageUrl: auth.user.profileImageUrl,
          ),
          otherUser: parent,
        ),
      );

      final state = await chatBloc.stream.firstWhere(
        (s) =>
            s.startConversationStatus == SubmissionStatus.success ||
            s.startConversationStatus == SubmissionStatus.error,
      );
      if (!mounted) return;
      if (state.startConversationStatus == SubmissionStatus.error ||
          state.startedConversation == null) {
        AppSnackBar.showInfo(context, 'تعذر فتح المحادثة');
        return;
      }

      final conversation = state.startedConversation!;
      chatBloc.add(const ResetStartConversationEvent());
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatRoomPage(
            conversationId: conversation.id,
            otherUserName: parent.name,
            otherUserImage: parent.profileImageUrl,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'متابعة الطلاب',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) => p.halaqat != c.halaqat,
        builder: (context, state) {
          if (_loading) {
            return const SupervisorCenteredListSkeleton();
          }
          if (_error != null) {
            return AppErrorWidget(message: _error!, onRetry: _load);
          }
          if (state.halaqat.isEmpty) {
            return Center(
              child: Text(
                'لا توجد حلقات ضمن إشرافك',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            );
          }
          if (_atRisk.isEmpty) {
            return Center(
              child: Text(
                'لا يوجد طلاب في خطر حالياً',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.textHint,
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: _atRisk.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final row = _atRisk[i];
                final halaqaId = row.halaqaIds.isNotEmpty
                    ? row.halaqaIds.first
                    : null;
                return Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                row.displayName,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.radiusFull,
                                ),
                              ),
                              child: Text(
                                'في خطر',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          row.halaqaLabel,
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            TextButton(
                              onPressed: () =>
                                  SupervisorDestinations.studentProfile(
                                    context,
                                    studentId: row.studentId,
                                    halaqaId: halaqaId,
                                  ),
                              child: const Text('الملف'),
                            ),
                            TextButton(
                              onPressed: _startingChat
                                  ? null
                                  : () => _openParentChat(row),
                              child: const Text('محادثة'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  SupervisorDestinations.grantAward(
                                    context,
                                    preselectedStudentId: row.studentId,
                                    preselectedHalaqaId: halaqaId,
                                  ),
                              child: const Text('منح'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
