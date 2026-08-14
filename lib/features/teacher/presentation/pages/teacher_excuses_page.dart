import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hijri/hijri_calendar.dart';

import '../../../../shared/theme/app_theme.dart';
import '../widgets/excuses/teacher_excuse_list_item_data.dart';
import '../widgets/excuses/teacher_excuse_request_card.dart';
import '../widgets/excuses/teacher_excuses_form_section.dart';
import '../widgets/excuses/teacher_excuses_history_skeleton.dart';

/// Teacher Excuses / Absence Requests — Figma B1 (`1:2155`).
///
/// Phase 1: presentation only. No TeacherBloc / use-case / Firestore wiring.
/// Optional [previewItems] / [previewHalaqaOptions] / [previewLoading] are for
/// the isolated preview layer only — production route leaves them unset.
class TeacherExcusesPage extends StatefulWidget {
  /// Preview-only history rows. Production must pass `null` (empty list).
  final List<TeacherExcuseListItemData>? previewItems;

  /// Preview-only halaqa names for the form dropdown.
  final List<String>? previewHalaqaOptions;

  /// Preview-only: force history skeleton.
  final bool previewLoading;

  const TeacherExcusesPage({
    super.key,
    this.previewItems,
    this.previewHalaqaOptions,
    this.previewLoading = false,
  });

  @override
  State<TeacherExcusesPage> createState() => _TeacherExcusesPageState();
}

class _TeacherExcusesPageState extends State<TeacherExcusesPage> {
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey();
  late DateTime _selectedDate;
  String? _selectedHalaqa;
  bool _formVisible = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    final options = widget.previewHalaqaOptions ?? const <String>[];
    if (options.isNotEmpty) {
      _selectedHalaqa = options.first;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  List<String> get _halaqaOptions =>
      widget.previewHalaqaOptions ?? const <String>[];

  List<TeacherExcuseListItemData> get _items =>
      widget.previewItems ?? const <TeacherExcuseListItemData>[];

  bool get _isLoading => widget.previewLoading;

  String _hijriLabel(DateTime date, {bool withYear = false}) {
    HijriCalendar.setLocal('ar');
    final h = HijriCalendar.fromDate(date);
    return withYear ? h.toFormat('dd MMMM yyyy') : h.toFormat('dd MMMM');
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _onNewRequest() {
    setState(() => _formVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _formKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
          alignment: 0,
        );
      }
    });
  }

  void _onSubmit() {
    // Phase 1: UI only — no domain / Firestore submit.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('واجهة فقط — ربط الإرسال في المرحلة التالية'),
      ),
    );
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/teacher');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5FAFB),
        body: Column(
          children: [
            _ExcusesHeader(onBack: _onBack, onNewRequest: _onNewRequest),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxW = constraints.maxWidth > 600
                      ? 560.0
                      : constraints.maxWidth;
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: maxW,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          if (_formVisible)
                            SliverToBoxAdapter(
                              child: KeyedSubtree(
                                key: _formKey,
                                child: TeacherExcusesFormSection(
                                  halaqaOptions: _halaqaOptions,
                                  selectedHalaqa: _selectedHalaqa,
                                  dateLabel: _hijriLabel(_selectedDate),
                                  reasonController: _reasonController,
                                  onHalaqaChanged: (v) =>
                                      setState(() => _selectedHalaqa = v),
                                  onDateTap: _pickDate,
                                  onSubmit: _onSubmit,
                                  submitEnabled: true,
                                ),
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    'السجل السابق',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (_isLoading)
                                  const TeacherExcusesHistorySkeleton()
                                else if (_items.isEmpty)
                                  const _EmptyHistory()
                                else
                                  for (var i = 0; i < _items.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 10),
                                    TeacherExcuseRequestCard(item: _items[i]),
                                  ],
                              ]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExcusesHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onNewRequest;

  const _ExcusesHeader({required this.onBack, required this.onNewRequest});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Material(
      color: AppColors.surface,
      child: Container(
        padding: EdgeInsets.fromLTRB(18, top + 12, 18, 13),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE8EEF0), width: 0.8),
          ),
        ),
        // RTL Row: first child sits on the right (back), last on the left (+).
        child: Row(
          children: [
            Material(
              color: const Color(0xFFF5FAFB),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                'طلبات الاعتذار',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.32),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onNewRequest,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: Text(
                      '+ طلب جديد',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_busy_outlined,
            size: 40,
            color: AppColors.textHint.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            'لا توجد طلبات بعد',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
