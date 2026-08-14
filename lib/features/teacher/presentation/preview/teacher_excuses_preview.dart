import 'package:flutter/material.dart';

import '../../../../shared/domain/absence_request.dart';
import '../../../../shared/theme/app_theme.dart';
import '../pages/teacher_excuses_page.dart';
import '../widgets/excuses/teacher_excuse_list_item_data.dart';

/// Isolated UI preview for Teacher Excuses (Figma B1).
///
/// Mock data lives **only** here — never in domain, repositories, or the
/// production route builder. Open via Flutter DevTools / a temporary entry,
/// or wrap in a short-lived debug route during design review.
///
/// Usage (e.g. from a debug button or `flutter run` harness):
/// ```dart
/// runApp(const TeacherExcusesPreviewApp());
/// ```
class TeacherExcusesPreviewApp extends StatelessWidget {
  const TeacherExcusesPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const TeacherExcusesPreviewPage(),
    );
  }
}

/// Preview host with toggle for skeleton vs filled mock history.
class TeacherExcusesPreviewPage extends StatefulWidget {
  const TeacherExcusesPreviewPage({super.key});

  @override
  State<TeacherExcusesPreviewPage> createState() =>
      _TeacherExcusesPreviewPageState();
}

class _TeacherExcusesPreviewPageState extends State<TeacherExcusesPreviewPage> {
  bool _showSkeleton = false;

  static const _mockHalaqat = ['حلقة المتقدمين', 'حلقة المبتدئين'];

  static const _mockItems = [
    TeacherExcuseListItemData(
      id: 'preview-1',
      title: 'اعتذار عن حضور الحلقة',
      dateLabel: '٢٠ ذو القعدة ١٤٤٦',
      reason: 'ظرف طارئ في الأسرة. تم إبلاغ الإدارة مسبقاً.',
      status: AbsenceRequestStatus.approved,
    ),
    TeacherExcuseListItemData(
      id: 'preview-2',
      title: 'طلب تأجيل التقييم',
      dateLabel: '١٤ ذو القعدة ١٤٤٦',
      reason: 'مرض مفاجئ. مرفق تقرير طبي.',
      status: AbsenceRequestStatus.pending,
    ),
    TeacherExcuseListItemData(
      id: 'preview-3',
      title: 'غياب طارئ',
      dateLabel: '٥ ذو القعدة ١٤٤٦',
      reason: 'لم يتم تقديم مستندات داعمة في الوقت المناسب.',
      status: AbsenceRequestStatus.rejected,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          TeacherExcusesPage(
            previewHalaqaOptions: _mockHalaqat,
            previewItems: _showSkeleton ? null : _mockItems,
            previewLoading: _showSkeleton,
          ),
          Positioned(
            left: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(AppSizes.radiusFull),
              color: AppColors.dark,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSizes.radiusFull),
                onTap: () => setState(() => _showSkeleton = !_showSkeleton),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Text(
                    _showSkeleton ? 'عرض البيانات' : 'عرض الهيكل',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
