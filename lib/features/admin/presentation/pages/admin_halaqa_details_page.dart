import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../../../shared/domain/halaqa_roster.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/admin_halaqa_document_loader.dart';
import '../../domain/entities/admin_directory_entity.dart';
import '../admin_format.dart';
import '../widgets/admin_subpage_scaffold.dart';

typedef HalaqaRosterEntry = ({String uid, String name});

class AdminHalaqaDetails {
  final List<HalaqaScheduleEntity> schedule;
  final List<HalaqaRosterEntry> students;

  const AdminHalaqaDetails({required this.schedule, required this.students});
}

typedef AdminHalaqaDetailsLoader =
    Future<AdminHalaqaDetails> Function(String halaqaId);

Future<AdminHalaqaDetails> loadAdminHalaqaDetails(String halaqaId) async {
  final halaqa = await loadAdminHalaqaDocument(
    firestore: sl<FirebaseFirestore>(),
    halaqaId: halaqaId,
  );
  final roster = await sl<GetHalaqaStudentsUseCase>()(
    HalaqaStudentsParams(halaqaId),
  );
  final students = roster.fold<List<HalaqaRosterEntry>>(
    (f) => throw f.message,
    (list) => [for (final s in list) (uid: s.uid, name: s.name)],
  );
  students.sort((a, b) => a.name.compareTo(b.name));
  return AdminHalaqaDetails(schedule: halaqa.schedule, students: students);
}

/// Read-only halaqa view opened from the academy halaqat directory.
class AdminHalaqaDetailsPage extends StatefulWidget {
  final AdminHalaqaSummaryEntity halaqa;
  final AdminHalaqaDetailsLoader loader;
  final void Function(BuildContext context, String studentId)? onOpenStudent;

  const AdminHalaqaDetailsPage({
    super.key,
    required this.halaqa,
    this.loader = loadAdminHalaqaDetails,
    this.onOpenStudent,
  });

  @override
  State<AdminHalaqaDetailsPage> createState() => _AdminHalaqaDetailsPageState();
}

class _AdminHalaqaDetailsPageState extends State<AdminHalaqaDetailsPage> {
  late Future<AdminHalaqaDetails> _details;

  @override
  void initState() {
    super.initState();
    _details = widget.loader(widget.halaqa.id);
  }

  void _reload() {
    setState(() {
      _details = widget.loader(widget.halaqa.id);
    });
  }

  void _openStudent(String uid) {
    final custom = widget.onOpenStudent;
    if (custom != null) return custom(context, uid);
    context.push(
      AppRoutes.adminStudentProfile(uid, halaqaId: widget.halaqa.id),
    );
  }

  static String _person(String id, String name) {
    if (id.isEmpty) return 'غير معيّن';
    return name.isEmpty ? 'بدون اسم' : name;
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.halaqa;
    final title = h.name.isEmpty ? 'حلقة بدون اسم' : h.name;
    return AdminSubpageScaffold(
      title: title,
      subtitle: 'تفاصيل الحلقة',
      body: FutureBuilder<AdminHalaqaDetails>(
        future: _details,
        builder: (context, snap) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'المعلم: ${_person(h.teacherId, h.teacherName)}',
                      key: const Key('halaqa-details-teacher'),
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المشرف: ${_person(h.supervisorId, h.supervisorName)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'عدد الطلاب: ${formatAdminCount(h.studentCount)}',
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (snap.connectionState != ConnectionState.done)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snap.hasError)
                AppErrorWidget(
                  key: const Key('halaqa-details-error'),
                  message: snap.error is String
                      ? snap.error! as String
                      : 'تعذر تحميل تفاصيل الحلقة',
                  onRetry: _reload,
                )
              else
                ..._content(snap.requireData),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _content(AdminHalaqaDetails d) {
    return [
      Text('المواعيد الأسبوعية', style: AppTextStyles.titleMedium),
      const SizedBox(height: 8),
      if (d.schedule.isEmpty)
        Text(
          'لا توجد مواعيد',
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in d.schedule)
              Chip(label: Text('${s.day} ${s.startTime}–${s.endTime}')),
          ],
        ),
      const SizedBox(height: 16),
      Text(
        'الطلاب (${formatAdminCount(d.students.length)})',
        style: AppTextStyles.titleMedium,
      ),
      const SizedBox(height: 8),
      if (d.students.isEmpty)
        Text(
          'لا يوجد طلاب في هذه الحلقة',
          key: const Key('halaqa-details-no-students'),
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
        )
      else
        for (final s in d.students)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              key: Key('halaqa-student-${s.uid}'),
              onTap: () => _openStudent(s.uid),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.name.isEmpty ? 'طالب بدون اسم' : s.name,
                      style: AppTextStyles.bodyLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: AppColors.textHint),
                ],
              ),
            ),
          ),
    ];
  }
}
