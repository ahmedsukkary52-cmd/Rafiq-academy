import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/error/exception.dart';
import '../../../core/presentation/academy_data_revision.dart';
import '../../../shared/theme/app_theme.dart';
import '../../../shared/widgets/app_back_button.dart';
import '../../../shared/widgets/shared_widgets.dart';
import '../data/academy_accounts_repository.dart';
import '../domain/onboarding_models.dart';

typedef OnboardSubmit =
    Future<OnboardingResult> Function(OnboardStudentRequest request);
typedef ParentSearch = Future<List<MemberSearchHit>> Function(String query);
typedef HalaqatLoader = Future<List<OnboardingHalaqaOption>> Function();

String newOnboardingRequestId([Random? random]) {
  final r = random ?? Random.secure();
  const hex = '0123456789abcdef';
  return 'onb_${List.generate(24, (_) => hex[r.nextInt(16)]).join()}';
}

/// Admin student onboarding wizard: parent → student → halaqa → review →
/// results (step outcomes + one-time credentials). All writes happen in the
/// `adminOnboardStudent` callable; a retry reuses the same request id so
/// nothing is created twice.
class AdminOnboardStudentPage extends StatefulWidget {
  final OnboardSubmit? submit;
  final ParentSearch? searchParents;
  /// Supplied by the router: this module stays outside the Admin module.
  final HalaqatLoader loadHalaqat;

  /// Pre-selected guardian when adding another child from a parent profile.
  final MemberSearchHit? initialParent;

  /// AppBar title (Admin vs Supervisor wording).
  final String title;

  /// When true, a halaqa must be selected before submit (supervisor scope).
  final bool requireHalaqa;

  const AdminOnboardStudentPage({
    super.key,
    this.submit,
    this.searchParents,
    required this.loadHalaqat,
    this.initialParent,
    this.title = 'تسجيل طالب جديد',
    this.requireHalaqa = false,
  });

  @override
  State<AdminOnboardStudentPage> createState() =>
      _AdminOnboardStudentPageState();
}

enum _ParentMode { existing, create }

class _AdminOnboardStudentPageState extends State<AdminOnboardStudentPage> {
  static const _stepTitles = ['ولي الأمر', 'الطالب', 'الحلقة', 'المراجعة'];

  /// Lazily resolved so widget tests that inject [submit]/[searchParents]
  /// never touch GetIt.
  AcademyAccountsRepository get _repo => sl<AcademyAccountsRepository>();

  int _step = 0;
  String _requestId = newOnboardingRequestId();

  _ParentMode _parentMode = _ParentMode.existing;
  final _parentQuery = TextEditingController();
  final _parentName = TextEditingController();
  final _studentName = TextEditingController();
  Timer? _debounce;
  List<MemberSearchHit> _parentHits = const [];
  bool _searching = false;
  String? _searchError;
  MemberSearchHit? _parent;

  List<OnboardingHalaqaOption>? _halaqat;
  String? _halaqatError;
  OnboardingHalaqaOption? _halaqa;

  bool _submitting = false;
  String? _submitError;
  OnboardingResult? _result;

  @override
  void initState() {
    super.initState();
    _parent = widget.initialParent;
    _loadHalaqat();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _parentQuery.dispose();
    _parentName.dispose();
    _studentName.dispose();
    super.dispose();
  }

  Future<void> _loadHalaqat() async {
    setState(() => _halaqatError = null);
    try {
      final list = await widget.loadHalaqat();
      if (mounted) setState(() => _halaqat = list);
    } catch (_) {
      if (mounted) setState(() => _halaqatError = 'تعذر تحميل الحلقات');
    }
  }

  void _onParentQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final query = value.trim();
      if (query.length < 2) {
        setState(() => _parentHits = const []);
        return;
      }
      setState(() {
        _searching = true;
        _searchError = null;
      });
      try {
        final search =
            widget.searchParents ??
            (q) => _repo.searchMembers(role: 'parent', query: q);
        final hits = await search(query);
        if (mounted && _parentQuery.text.trim() == query) {
          setState(() => _parentHits = hits);
        }
      } catch (_) {
        if (mounted) setState(() => _searchError = 'تعذر البحث، أعد المحاولة');
      } finally {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  String? get _stepProblem => switch (_step) {
    0 when _parentMode == _ParentMode.existing && _parent == null =>
      'اختر ولي الأمر من نتائج البحث أو أنشئ حساباً جديداً',
    0 when _parentMode == _ParentMode.create &&
        _parentName.text.trim().length < 2 =>
      'اكتب اسم ولي الأمر',
    1 when _studentName.text.trim().length < 2 => 'اكتب اسم الطالب',
    2 when widget.requireHalaqa && _halaqa == null =>
      'اختر الحلقة التي ستُسند إليها الطالب',
    _ => null,
  };

  void _next() {
    final problem = _stepProblem;
    if (problem != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  OnboardStudentRequest get _request => OnboardStudentRequest(
    requestId: _requestId,
    studentName: _studentName.text,
    existingParentId: _parentMode == _ParentMode.existing ? _parent?.uid : null,
    newParentName: _parentMode == _ParentMode.create ? _parentName.text : null,
    halaqaId: _halaqa?.id,
  );

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final submit = widget.submit ?? _repo.onboardStudent;
      final result = await submit(_request);
      AcademyDataRevision.bumpStructure();
      if (mounted) setState(() => _result = result);
    } on ServerException catch (e) {
      if (mounted) setState(() => _submitError = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startOver() {
    setState(() {
      _requestId = newOnboardingRequestId();
      _step = 0;
      _result = null;
      _submitError = null;
      _parent = null;
      _parentHits = const [];
      _parentQuery.clear();
      _parentName.clear();
      _studentName.clear();
      _halaqa = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: result != null
            ? _ResultView(
                result: result,
                retrying: _submitting,
                onRetry: _submit,
                onAnother: _startOver,
                onDone: () => Navigator.of(context).maybePop(),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  _StepHeader(titles: _stepTitles, current: _step),
                  const SizedBox(height: 20),
                  switch (_step) {
                    0 => _parentStep(),
                    1 => _studentStep(),
                    2 => _halaqaStep(),
                    _ => _reviewStep(),
                  },
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (_step > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _step--),
                            child: const Text('السابق'),
                          ),
                        ),
                      if (_step > 0) const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          key: const Key('onboard-next'),
                          label: _step == 3 ? 'إنشاء الحسابات' : 'التالي',
                          isLoading: _submitting,
                          onPressed: _submitting
                              ? null
                              : (_step == 3 ? _submit : _next),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _parentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_ParentMode>(
          segments: const [
            ButtonSegment(
              value: _ParentMode.existing,
              label: Text('ولي أمر مسجّل'),
              icon: Icon(Icons.search),
            ),
            ButtonSegment(
              value: _ParentMode.create,
              label: Text('ولي أمر جديد'),
              icon: Icon(Icons.person_add_alt_1),
            ),
          ],
          selected: {_parentMode},
          onSelectionChanged: (s) => setState(() => _parentMode = s.first),
        ),
        const SizedBox(height: 16),
        if (_parentMode == _ParentMode.create) ...[
          const _FieldLabel('اسم ولي الأمر'),
          AppTextField(
            key: const Key('onboard-parent-name'),
            hint: 'الاسم كما سيظهر في التطبيق',
            controller: _parentName,
          ),
          const SizedBox(height: 8),
          Text(
            'سيُنشأ حساب لولي الأمر باسم مستخدم وكلمة مرور مؤقتة — '
            'لا يلزم بريد إلكتروني.',
            style: AppTextStyles.labelMedium,
          ),
        ] else ...[
          const _FieldLabel('ابحث باسم ولي الأمر'),
          AppTextField(
            key: const Key('onboard-parent-search'),
            hint: 'حرفان على الأقل',
            controller: _parentQuery,
            onChanged: _onParentQuery,
            prefixIcon: const Icon(Icons.search),
          ),
          const SizedBox(height: 12),
          if (_parent != null)
            Card(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: ListTile(
                leading: const Icon(Icons.check_circle, color: AppColors.primary),
                title: Text(_parent!.name.isEmpty ? 'ولي أمر' : _parent!.name),
                subtitle: const Text('ولي الأمر المختار'),
                trailing: TextButton(
                  onPressed: () => setState(() => _parent = null),
                  child: const Text('تغيير'),
                ),
              ),
            ),
          if (_searching) const LinearProgressIndicator(),
          if (_searchError != null)
            Text(_searchError!, style: const TextStyle(color: AppColors.error)),
          if (!_searching &&
              _parent == null &&
              _parentQuery.text.trim().length >= 2 &&
              _parentHits.isEmpty &&
              _searchError == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'لا توجد نتائج. يمكنك إنشاء حساب ولي أمر جديد.',
                textAlign: TextAlign.center,
              ),
            ),
          if (_parent == null)
            for (final hit in _parentHits)
              Card(
                key: Key('onboard-parent-${hit.uid}'),
                child: ListTile(
                  leading: const Icon(Icons.family_restroom),
                  title: Text(hit.name.isEmpty ? 'ولي أمر' : hit.name),
                  onTap: () => setState(() => _parent = hit),
                ),
              ),
        ],
      ],
    );
  }

  Widget _studentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FieldLabel('اسم الطالب'),
        AppTextField(
          key: const Key('onboard-student-name'),
          hint: 'الاسم الثلاثي',
          controller: _studentName,
        ),
        const SizedBox(height: 8),
        Text(
          'سيُنشأ حساب الطالب ويُربط بولي الأمر تلقائياً.',
          style: AppTextStyles.labelMedium,
        ),
      ],
    );
  }

  Widget _halaqaStep() {
    final halaqat = _halaqat;
    if (_halaqatError != null) {
      return Column(
        children: [
          Text(_halaqatError!),
          TextButton(onPressed: _loadHalaqat, child: const Text('إعادة المحاولة')),
        ],
      );
    }
    if (halaqat == null) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.requireHalaqa
              ? 'اختر حلقة من حلقاتك لإسناد الطالب إليها. المعلم يُحدَّد من الحلقة.'
              : 'المعلم والمشرف يُحدَّدان من الحلقة. يمكن تخطي هذه الخطوة وإضافة '
                  'الطالب لاحقاً.',
          style: AppTextStyles.labelMedium,
        ),
        const SizedBox(height: 8),
        RadioGroup<String?>(
          groupValue: _halaqa?.id,
          onChanged: (id) => setState(
            () => _halaqa = id == null
                ? null
                : halaqat.firstWhere((h) => h.id == id),
          ),
          child: Column(
            children: [
              if (!widget.requireHalaqa)
                const RadioListTile<String?>(
                  key: Key('onboard-halaqa-none'),
                  value: null,
                  title: Text('بدون حلقة الآن'),
                ),
              for (final h in halaqat)
                RadioListTile<String?>(
                  key: Key('onboard-halaqa-${h.id}'),
                  value: h.id,
                  title: Text(h.name.isEmpty ? 'حلقة بدون اسم' : h.name),
                  subtitle: Text(
                    'المعلم: ${h.teacherName.isEmpty ? 'غير معيّن' : h.teacherName}'
                    ' — المشرف: ${h.supervisorName.isEmpty ? 'غير معيّن' : h.supervisorName}'
                    ' — ${h.studentCount} طالب',
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewStep() {
    final parentLabel = _parentMode == _ParentMode.existing
        ? '${_parent?.name ?? ''} (حساب موجود)'
        : '${_parentName.text.trim()} (حساب جديد)';
    final h = _halaqa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReviewRow(label: 'ولي الأمر', value: parentLabel),
        _ReviewRow(label: 'الطالب', value: _studentName.text.trim()),
        _ReviewRow(label: 'الحلقة', value: h == null ? 'بدون حلقة الآن' : h.name),
        if (h != null) ...[
          _ReviewRow(
            label: 'المعلم',
            value: h.teacherName.isEmpty ? 'غير معيّن' : h.teacherName,
          ),
          _ReviewRow(
            label: 'المشرف',
            value: h.supervisorName.isEmpty ? 'غير معيّن' : h.supervisorName,
          ),
        ],
        if (_submitError != null) ...[
          const SizedBox(height: 12),
          Text(
            _submitError!,
            key: const Key('onboard-error'),
            style: const TextStyle(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: AppTextStyles.labelLarge),
  );
}

class _StepHeader extends StatelessWidget {
  final List<String> titles;
  final int current;

  const _StepHeader({required this.titles, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < titles.length; i++)
          Expanded(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: i <= current
                      ? AppColors.primary
                      : AppColors.textHint.withValues(alpha: 0.3),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  titles[i],
                  style: AppTextStyles.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;

  const _ReviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: AppTextStyles.labelMedium),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final OnboardingResult result;
  final bool retrying;
  final VoidCallback onRetry;
  final VoidCallback onAnother;
  final VoidCallback onDone;

  const _ResultView({
    required this.result,
    required this.retrying,
    required this.onRetry,
    required this.onAnother,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.paddingL),
      children: [
        Icon(
          result.completed ? Icons.check_circle : Icons.error_outline,
          size: 56,
          color: result.completed ? AppColors.primary : AppColors.warning,
        ),
        const SizedBox(height: 8),
        Text(
          result.completed
              ? 'تم تسجيل الطالب بنجاح'
              : 'اكتمل جزء من التسجيل — أعد المحاولة لإكمال الباقي',
          key: const Key('onboard-result-title'),
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineMedium,
        ),
        const SizedBox(height: 16),
        for (final s in result.steps)
          ListTile(
            dense: true,
            leading: Icon(switch (s.status) {
              OnboardingStepStatus.done => Icons.check,
              OnboardingStepStatus.skipped => Icons.remove,
              OnboardingStepStatus.failed => Icons.close,
            }, color: switch (s.status) {
              OnboardingStepStatus.done => AppColors.primary,
              OnboardingStepStatus.skipped => AppColors.textHint,
              OnboardingStepStatus.failed => AppColors.error,
            }),
            title: Text(s.label),
            subtitle: Text(s.message),
          ),
        if (result.replayed)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'هذا الطلب سُجّل من قبل. كلمات المرور لا تُحفظ، ويمكن إصدار كلمة '
              'مرور مؤقتة جديدة من ملف المستخدم.',
              textAlign: TextAlign.center,
            ),
          ),
        if (result.credentials.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('بيانات الدخول', style: AppTextStyles.titleMedium),
          const SizedBox(height: 4),
          Text(
            'تظهر كلمات المرور المؤقتة مرة واحدة فقط. انسخها أو أرسلها الآن.',
            style: AppTextStyles.labelMedium,
          ),
          for (final c in result.credentials) CredentialCard(credential: c),
        ],
        const SizedBox(height: 24),
        if (!result.completed)
          AppButton(
            key: const Key('onboard-retry'),
            label: 'إعادة المحاولة',
            isLoading: retrying,
            onPressed: retrying ? null : onRetry,
          ),
        if (result.completed) ...[
          AppButton(label: 'تسجيل طالب آخر', onPressed: onAnother),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: onDone, child: const Text('تم')),
        ],
      ],
    );
  }
}

/// One-time credential with copy / WhatsApp share. Never stored on device.
class CredentialCard extends StatelessWidget {
  final IssuedCredential credential;

  const CredentialCard({super.key, required this.credential});

  @override
  Widget build(BuildContext context) {
    final c = credential;
    return Card(
      key: Key('credential-${c.role}'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${c.roleLabel}: ${c.name}', style: AppTextStyles.titleMedium),
            if (c.academyRef.isNotEmpty) Text('رقم الأكاديمية: ${c.academyRef}'),
            const SizedBox(height: 8),
            SelectableText('اسم المستخدم: ${c.username}'),
            SelectableText('كلمة المرور المؤقتة: ${c.temporaryPassword}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('نسخ'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: c.shareText));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تم النسخ')),
                      );
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('إرسال عبر واتساب'),
                  onPressed: () => launchUrl(
                    Uri.https('wa.me', '/', {'text': c.shareText}),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
