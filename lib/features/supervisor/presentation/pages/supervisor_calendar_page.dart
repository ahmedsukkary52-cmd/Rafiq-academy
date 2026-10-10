import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../calendar/presentation/pages/calendar_page.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_state.dart';
import '../widgets/supervisor_subpage_scaffold.dart';

/// Picks an assigned halaqa, then opens the existing [CalendarPage] scoped to it.
class SupervisorCalendarPage extends StatelessWidget {
  const SupervisorCalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SupervisorSubpageScaffold(
      title: 'التقويم',
      body: BlocBuilder<SupervisorBloc, SupervisorState>(
        buildWhen: (p, c) => p.halaqat != c.halaqat,
        builder: (context, state) {
          final halaqat = state.halaqat;
          if (halaqat.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: AppCard(
                child: Text(
                  'لا توجد حلقات مسندة لعرض التقويم',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              Text(
                'اختر حلقة لعرض أحداثها فقط (بدون أحداث عامة على مستوى الأكاديمية)',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              for (final h in halaqat)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CalendarPage(halaqaId: h.id),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.secondaryBg,
                          child: Icon(
                            Icons.calendar_month_rounded,
                            color: AppColors.secondaryDeep,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                h.name,
                                style: AppTextStyles.titleMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${h.studentIds.length} طالب',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_left_rounded),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
