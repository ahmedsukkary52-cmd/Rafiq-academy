import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/router/router_app.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../admin_format.dart';
import '../bloc/admin_bloc.dart';
import '../bloc/admin_event.dart';
import '../bloc/admin_state.dart';
import '../widgets/admin_figma_widgets.dart';
import '../widgets/admin_loading_skeletons.dart';

class AdminFinanceTab extends StatefulWidget {
  const AdminFinanceTab({super.key});

  @override
  State<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends State<AdminFinanceTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminBloc>().add(const LoadFinancialSummaryEvent());
    });
  }

  Future<void> _refresh() async {
    final bloc = context.read<AdminBloc>();
    bloc.add(const LoadFinancialSummaryEvent());
    await bloc.stream.firstWhere(
      (s) => s.financialStatus != SectionStatus.loading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = formatAdminCount;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: BlocBuilder<AdminBloc, AdminState>(
            buildWhen: (p, c) =>
                p.financialStatus != c.financialStatus ||
                p.financialSummary != c.financialSummary,
            builder: (context, state) {
              final summary = state.financialSummary;
              final loading = state.financialStatus == SectionStatus.loading;

              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    const AdminPageHeader(
                      title: 'المالية',
                      subtitle: 'ملخص المدفوعات والإيرادات',
                    ),
                    if (loading)
                      const AdminFinanceTabSkeleton()
                    else if (state.financialStatus == SectionStatus.error)
                      AppErrorWidget(
                        message: state.financialError ?? 'تعذر التحميل',
                        onRetry: _refresh,
                      )
                    else if (summary != null) ...[
                      AdminGradientHeroCard(
                        eyebrow: 'إجمالي الإيرادات',
                        headline: '${fmt(summary.totalRevenue.round())} ر.س',
                        metrics: [
                          AdminHeroMetric(
                            value: fmt(summary.paidCount),
                            label: 'عملية مدفوعة',
                          ),
                          AdminHeroMetric(
                            value: fmt(summary.dueCount),
                            label: 'معلقة',
                          ),
                          AdminHeroMetric(
                            value: fmt(summary.overdueCount),
                            label: 'متأخرة',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.25,
                        children: [
                          AdminStatTile(
                            value: '${fmt(summary.totalPending.round())} ر.س',
                            label: 'مدفوعات معلقة',
                            icon: Icons.schedule_outlined,
                            iconBg: const Color(0xFFFFF8E1),
                            iconColor: AppColors.warning,
                            badge: summary.dueCount > 0
                                ? '${summary.dueCount}'
                                : null,
                            badgeColor: AppColors.warning,
                          ),
                          AdminStatTile(
                            value: '${fmt(summary.totalOverdue.round())} ر.س',
                            label: 'مدفوعات متأخرة',
                            icon: Icons.warning_amber_outlined,
                            iconBg: const Color(0xFFFFEBEE),
                            iconColor: AppColors.error,
                            badge: summary.overdueCount > 0
                                ? '${summary.overdueCount}'
                                : null,
                            badgeColor: AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'مراجعة المدفوعات',
                        onPressed: () => context.push(AppRoutes.adminPayments),
                      ),
                      const SizedBox(height: 10),
                      AppButton(
                        label: 'لوحة مالية تفصيلية',
                        onPressed: () =>
                            context.push(AppRoutes.adminFinanceDetail),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
