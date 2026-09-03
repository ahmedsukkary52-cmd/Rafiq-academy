import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/supervisor_roster.dart';
import '../bloc/supervisor_bloc.dart';
import '../bloc/supervisor_event.dart';
import '../bloc/supervisor_state.dart';

class SupervisorRegisterPage extends StatefulWidget {
  final String? preselectedHalaqaId;

  const SupervisorRegisterPage({super.key, this.preselectedHalaqaId});

  @override
  State<SupervisorRegisterPage> createState() => _SupervisorRegisterPageState();
}

class _SupervisorRegisterPageState extends State<SupervisorRegisterPage> {
  int _step = 0;
  final _pageCtrl = PageController();

  // Step 1 — student
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _memorizationCtrl = TextEditingController();
  String _gender = 'male';
  String _quranLevel = 'intermediate';
  String _preferredTime = 'after_asr';

  // Step 2 — parent
  final _parentNameCtrl = TextEditingController();
  final _parentPhoneCtrl = TextEditingController();
  final _parentEmailCtrl = TextEditingController();

  // Step 3 — assignment
  final _studentIdCtrl = TextEditingController();
  String? _halaqaId;
  String? _fieldError;

  static const _steps = ['بيانات الطالب', 'بيانات ولي الأمر', 'التعيين'];

  @override
  void initState() {
    super.initState();
    _halaqaId = widget.preselectedHalaqaId?.trim();
    if (_halaqaId != null && _halaqaId!.isEmpty) _halaqaId = null;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _memorizationCtrl.dispose();
    _parentNameCtrl.dispose();
    _parentPhoneCtrl.dispose();
    _parentEmailCtrl.dispose();
    _studentIdCtrl.dispose();
    super.dispose();
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty) {
          setState(() => _fieldError = 'أدخل الاسم الرباعي');
          return false;
        }
        if (_ageCtrl.text.trim().isEmpty) {
          setState(() => _fieldError = 'أدخل العمر');
          return false;
        }
        return true;
      case 1:
        if (_parentNameCtrl.text.trim().isEmpty) {
          setState(() => _fieldError = 'أدخل اسم ولي الأمر');
          return false;
        }
        if (_parentPhoneCtrl.text.trim().isEmpty) {
          setState(() => _fieldError = 'أدخل رقم الجوال');
          return false;
        }
        return true;
      case 2:
        final halaqat = context.read<SupervisorBloc>().state.halaqat;
        final error = SupervisorMembershipFormValidation.registerError(
          studentId: _studentIdCtrl.text,
          targetHalaqaId: _halaqaId,
          assignedHalaqat: halaqat,
        );
        setState(() => _fieldError = error);
        return error == null;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep(_step)) return;
    setState(() => _fieldError = null);
    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() {
        _step--;
        _fieldError = null;
      });
      _pageCtrl.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _submit(List<HalaqaEntity> halaqat) {
    if (!_validateStep(2)) return;
    final auth = context.read<AuthBloc>().state;
    if (auth is! AuthAuthenticated) {
      AppSnackBar.showInfo(context, 'يجب تسجيل الدخول أولاً');
      return;
    }

    context.read<SupervisorBloc>().add(
      AdmitStudentToHalaqaEvent(
        supervisorId: auth.user.uid,
        halaqaId: _halaqaId!,
        studentId: _studentIdCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SupervisorBloc, SupervisorState>(
      listenWhen: (p, c) => p.admitStudentStatus != c.admitStudentStatus,
      listener: (context, state) {
        if (state.admitStudentStatus == SubmissionStatus.success) {
          AppSnackBar.showSuccess(context, 'تم تسجيل الطالب في الحلقة');
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
          Navigator.of(context).maybePop();
        } else if (state.admitStudentStatus == SubmissionStatus.error) {
          AppSnackBar.showError(
            context,
            state.admitStudentError ?? 'تعذر تسجيل الطالب',
          );
          context.read<SupervisorBloc>().add(const ResetAdmitStudentEvent());
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: BlocBuilder<SupervisorBloc, SupervisorState>(
            buildWhen: (p, c) =>
                p.halaqat != c.halaqat ||
                p.admitStudentStatus != c.admitStudentStatus,
            builder: (context, state) {
              final halaqat = state.halaqat;
              final submitting =
                  state.admitStudentStatus == SubmissionStatus.submitting;

              if (_halaqaId != null && !halaqat.any((h) => h.id == _halaqaId)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _halaqaId = null);
                });
              }

              return Column(
                children: [
                  _buildHeader(context),
                  _StepperBar(current: _step, labels: _steps),
                  Expanded(
                    child: PageView(
                      controller: _pageCtrl,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _Step1Student(
                          nameCtrl: _nameCtrl,
                          ageCtrl: _ageCtrl,
                          memorizationCtrl: _memorizationCtrl,
                          gender: _gender,
                          quranLevel: _quranLevel,
                          preferredTime: _preferredTime,
                          onGender: (v) => setState(() => _gender = v),
                          onQuranLevel: (v) => setState(() => _quranLevel = v),
                          onPreferredTime: (v) =>
                              setState(() => _preferredTime = v),
                          onChanged: () {
                            if (_fieldError != null) {
                              setState(() => _fieldError = null);
                            }
                          },
                        ),
                        _Step2Parent(
                          nameCtrl: _parentNameCtrl,
                          phoneCtrl: _parentPhoneCtrl,
                          emailCtrl: _parentEmailCtrl,
                          onChanged: () {
                            if (_fieldError != null) {
                              setState(() => _fieldError = null);
                            }
                          },
                        ),
                        _Step3Assignment(
                          studentIdCtrl: _studentIdCtrl,
                          halaqaId: _halaqaId,
                          halaqat: halaqat,
                          name: _nameCtrl.text.trim(),
                          parentName: _parentNameCtrl.text.trim(),
                          onHalaqaChanged: halaqat.isEmpty || submitting
                              ? null
                              : (v) => setState(() {
                                  _halaqaId = v;
                                  _fieldError = null;
                                }),
                          onChanged: () {
                            if (_fieldError != null) {
                              setState(() => _fieldError = null);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_fieldError != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        _fieldError!,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      MediaQuery.paddingOf(context).bottom + 16,
                    ),
                    child: FilledButton(
                      onPressed: submitting
                          ? null
                          : _step < 2
                          ? _next
                          : () => _submit(halaqat),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size.fromHeight(52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSizes.radiusFull,
                          ),
                        ),
                      ),
                      child: submitting
                          ? const Text('جاري…')
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _step < 2
                                      ? 'التالي — ${_steps[_step + 1]}'
                                      : 'تسجيل الطالب',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (_step < 2) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 12),
      child: Row(
        children: [
          Text(
            '${_step + 1}/3',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              'تسجيل طالب جديد',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: _back,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGrey,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperBar extends StatelessWidget {
  final int current;
  final List<String> labels;

  const _StepperBar({required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= current ? AppColors.primary : AppColors.border,
                ),
              ),
            Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= current
                      ? AppColors.primary
                      : AppColors.surfaceGrey,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: i <= current
                          ? AppColors.onPrimary
                          : AppColors.textHint,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: AppTextStyles.labelSmall.copyWith(
                    color: i == current
                        ? AppColors.primary
                        : AppColors.textHint,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Step1Student extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController ageCtrl;
  final TextEditingController memorizationCtrl;
  final String gender;
  final String quranLevel;
  final String preferredTime;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onQuranLevel;
  final ValueChanged<String> onPreferredTime;
  final VoidCallback onChanged;

  const _Step1Student({
    required this.nameCtrl,
    required this.ageCtrl,
    required this.memorizationCtrl,
    required this.gender,
    required this.quranLevel,
    required this.preferredTime,
    required this.onGender,
    required this.onQuranLevel,
    required this.onPreferredTime,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _FormCard(
          title: 'بيانات الطالب',
          icon: Icons.person_outline_rounded,
          children: [
            _LabeledField(
              label: 'الاسم الرباعي',
              child: TextField(
                controller: nameCtrl,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(
                  hintText: 'ادخل الاسم بالكامل',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledField(
                    label: 'العمر',
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LabeledField(
                    label: 'الجنس',
                    child: _SegmentedChoices(
                      options: const {'male': 'ذكر', 'female': 'أنثى'},
                      selected: gender,
                      onChanged: onGender,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'المستوى الحالي في القرآن',
              child: _SegmentedChoices(
                options: const {
                  'beginner': 'مبتدئ',
                  'intermediate': 'متوسط',
                  'advanced': 'متقدم',
                },
                selected: quranLevel,
                onChanged: onQuranLevel,
              ),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'مقدار الحفظ الحالي',
              child: TextField(
                controller: memorizationCtrl,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(hintText: 'مثال: جزء عم'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FormCard(
          title: 'الأوقات المفضلة',
          icon: Icons.calendar_month_outlined,
          children: [
            _SegmentedChoices(
              options: const {
                'after_asr': 'بعد العصر',
                'after_maghrib': 'بعد المغرب',
                'after_isha': 'بعد العشاء',
              },
              selected: preferredTime,
              onChanged: onPreferredTime,
            ),
          ],
        ),
      ],
    );
  }
}

class _Step2Parent extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final VoidCallback onChanged;

  const _Step2Parent({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _FormCard(
          title: 'بيانات ولي الأمر',
          icon: Icons.family_restroom_rounded,
          children: [
            _LabeledField(
              label: 'اسم ولي الأمر',
              child: TextField(
                controller: nameCtrl,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(hintText: 'الاسم الكامل'),
              ),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'رقم الجوال',
              child: TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(hintText: '05xxxxxxxx'),
              ),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'البريد الإلكتروني (اختياري)',
              child: TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                onChanged: (_) => onChanged(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step3Assignment extends StatelessWidget {
  final TextEditingController studentIdCtrl;
  final String? halaqaId;
  final List<HalaqaEntity> halaqat;
  final String name;
  final String parentName;
  final ValueChanged<String?>? onHalaqaChanged;
  final VoidCallback onChanged;

  const _Step3Assignment({
    required this.studentIdCtrl,
    required this.halaqaId,
    required this.halaqat,
    required this.name,
    required this.parentName,
    required this.onHalaqaChanged,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        _FormCard(
          title: 'التعيين',
          icon: Icons.assignment_ind_outlined,
          children: [
            Text(
              'أدخل معرّف الطالب الموجود في النظام واختر الحلقة المناسبة.',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            if (name.isNotEmpty || parentName.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        'الطالب: $name',
                        style: AppTextStyles.labelLarge.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (parentName.isNotEmpty)
                      Text(
                        'ولي الأمر: $parentName',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'معرّف الطالب',
              child: TextField(
                controller: studentIdCtrl,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                onChanged: (_) => onChanged(),
                decoration: const InputDecoration(hintText: 'studentId'),
              ),
            ),
            const SizedBox(height: 12),
            _LabeledField(
              label: 'الحلقة',
              child: DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: halaqaId,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: [
                  for (final h in halaqat)
                    DropdownMenuItem(
                      value: h.id,
                      child: Text(h.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: onHalaqaChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _SegmentedChoices extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _SegmentedChoices({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: options.entries.map((e) {
        final isSelected = selected == e.key;
        return GestureDetector(
          onTap: () => onChanged(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              e.value,
              style: AppTextStyles.labelMedium.copyWith(
                color: isSelected
                    ? AppColors.primaryDark
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
