import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../shared/domain/academy_payment_destinations.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../data/payment_destination_errors.dart';
import '../bloc/admin_payment_destinations_bloc.dart';
import '../widgets/admin_subpage_scaffold.dart';

abstract final class AdminPaymentDestinationsText {
  static const String title = 'وسائل الدفع';
  static const String subtitle = 'وجهات الدفع الرسمية التي يراها أولياء الأمور';
  static const String businessNotice =
      'أدخل وجهات الدفع الرسمية الخاصة بالأكاديمية فقط. لا تُدخل أرقاماً أو '
      'حسابات شخصية. كل طريقة مستقلة عن الأخرى ولا تُستخدم قيمة إحداهما للأخرى.';
  static const String vodafoneCashTitle = 'فودافون كاش';
  static const String vodafoneCashLabel = 'رقم محفظة فودافون كاش';
  static const String vodafoneCashHint = '010XXXXXXXX';
  static const String instapayTitle = 'إنستاباي';
  static const String instapayLabel = 'عنوان إنستاباي أو رابط الدفع';
  static const String instapayHint = 'name@instapay أو https://…';
  static const String clearHelper =
      'اترك الحقل فارغاً ثم احفظ لإيقاف إظهار هذه الطريقة لأولياء الأمور.';
  static const String confirmBusiness =
      'أؤكد أن هذه وجهة دفع رسمية للأكاديمية وليست بيانات شخصية';
  static const String confirmRequired =
      'يرجى تأكيد أن الوجهة رسمية للأكاديمية قبل الحفظ';
  static const String configured = 'مضبوطة';
  static const String notConfigured = 'غير مضبوطة — لن تظهر لأولياء الأمور';
  static const String storedInvalid =
      'القيمة المحفوظة غير صالحة — يراها ولي الأمر كخطأ. صحّحها واحفظ.';
  static const String save = 'حفظ';
  static const String saved = 'تم حفظ وسيلة الدفع';
}

/// Route entry: provides a fresh [AdminPaymentDestinationsBloc] per visit.
class AdminPaymentDestinationsRoute extends StatelessWidget {
  const AdminPaymentDestinationsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminPaymentDestinationsBloc>(
      create: (_) => sl<AdminPaymentDestinationsBloc>(),
      child: const AdminPaymentDestinationsPage(),
    );
  }
}

/// Expects an [AdminPaymentDestinationsBloc] above it.
class AdminPaymentDestinationsPage extends StatefulWidget {
  const AdminPaymentDestinationsPage({super.key});

  @override
  State<AdminPaymentDestinationsPage> createState() =>
      _AdminPaymentDestinationsPageState();
}

class _AdminPaymentDestinationsPageState
    extends State<AdminPaymentDestinationsPage> {
  bool _awaitingLoad = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    setState(() => _awaitingLoad = true);
    context.read<AdminPaymentDestinationsBloc>().add(
      const LoadPaymentDestinationsSettingsEvent(),
    );
  }

  void _onStateChanged(
    BuildContext context,
    AdminPaymentDestinationsState state,
  ) {
    if (_awaitingLoad &&
        (state.loadStatus == SectionStatus.loaded ||
            state.loadStatus == SectionStatus.error)) {
      setState(() => _awaitingLoad = false);
    }
    final bloc = context.read<AdminPaymentDestinationsBloc>();
    if (state.saveStatus == SubmissionStatus.success) {
      AppSnackBar.showSuccess(context, AdminPaymentDestinationsText.saved);
      bloc.add(const ResetPaymentDestinationSaveEvent());
    } else if (state.saveStatus == SubmissionStatus.error) {
      AppSnackBar.showError(
        context,
        state.saveError ?? kPaymentDestinationsSaveFailedMessage,
      );
      bloc.add(const ResetPaymentDestinationSaveEvent());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<
      AdminPaymentDestinationsBloc,
      AdminPaymentDestinationsState
    >(
      listenWhen: (p, c) =>
          p.loadStatus != c.loadStatus || p.saveStatus != c.saveStatus,
      listener: _onStateChanged,
      builder: (context, state) {
        if (state.loadStatus == SectionStatus.error && !_awaitingLoad) {
          return AdminSubpageScaffold(
            title: AdminPaymentDestinationsText.title,
            body: AppErrorWidget(
              key: const Key('payment-destinations-load-error'),
              message: state.loadError ?? kPaymentDestinationsLoadFailedMessage,
              onRetry: _load,
            ),
          );
        }
        final settings = state.settings;
        if (_awaitingLoad ||
            state.loadStatus != SectionStatus.loaded ||
            settings == null) {
          return const AdminSubpageScaffold(
            title: AdminPaymentDestinationsText.title,
            body: Center(
              key: Key('payment-destinations-loading'),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final busy = state.saveStatus == SubmissionStatus.submitting;
        return AdminSubpageScaffold(
          title: AdminPaymentDestinationsText.title,
          subtitle: AdminPaymentDestinationsText.subtitle,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              Text(
                AdminPaymentDestinationsText.businessNotice,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _DestinationEditor(
                key: ValueKey(
                  'vodafone-cash-editor:${settings.vodafoneCashDestination}',
                ),
                method: AcademyPaymentMethod.vodafoneCash,
                saved: settings.vodafoneCashDestination,
                busy: busy,
                saving:
                    busy &&
                    state.savingMethod == AcademyPaymentMethod.vodafoneCash,
              ),
              const SizedBox(height: 16),
              _DestinationEditor(
                key: ValueKey(
                  'instapay-editor:${settings.instapayDestination}',
                ),
                method: AcademyPaymentMethod.instapay,
                saved: settings.instapayDestination,
                busy: busy,
                saving:
                    busy && state.savingMethod == AcademyPaymentMethod.instapay,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DestinationEditor extends StatefulWidget {
  final AcademyPaymentMethod method;
  final String saved;
  final bool busy;
  final bool saving;

  const _DestinationEditor({
    super.key,
    required this.method,
    required this.saved,
    required this.busy,
    required this.saving,
  });

  @override
  State<_DestinationEditor> createState() => _DestinationEditorState();
}

class _DestinationEditorState extends State<_DestinationEditor> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.saved,
  );
  bool _confirmed = false;
  String? _error;

  bool get _isVodafone => widget.method == AcademyPaymentMethod.vodafoneCash;
  String get _prefix => _isVodafone ? 'vodafone-cash' : 'instapay';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text;
    final error = AcademyPaymentDestinations.validate(
      widget.method,
      value,
      allowEmpty: true,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (value.trim().isNotEmpty && !_confirmed) {
      setState(() => _error = AdminPaymentDestinationsText.confirmRequired);
      return;
    }
    setState(() => _error = null);
    context.read<AdminPaymentDestinationsBloc>().add(
      SavePaymentDestinationEvent(method: widget.method, value: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.saved.trim();
    final savedValid =
        saved.isEmpty ||
        AcademyPaymentDestinations.validate(widget.method, saved) == null;
    final status = saved.isEmpty
        ? AdminPaymentDestinationsText.notConfigured
        : savedValid
        ? AdminPaymentDestinationsText.configured
        : AdminPaymentDestinationsText.storedInvalid;
    final statusColor = saved.isEmpty
        ? AppColors.textSecondary
        : savedValid
        ? AppColors.success
        : AppColors.error;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isVodafone
                ? AdminPaymentDestinationsText.vodafoneCashTitle
                : AdminPaymentDestinationsText.instapayTitle,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            key: Key('$_prefix-status'),
            style: AppTextStyles.labelMedium.copyWith(color: statusColor),
          ),
          const SizedBox(height: 12),
          TextField(
            key: Key('$_prefix-field'),
            controller: _controller,
            enabled: !widget.busy,
            textDirection: TextDirection.ltr,
            keyboardType: _isVodafone
                ? TextInputType.number
                : TextInputType.url,
            maxLength: _isVodafone
                ? AcademyPaymentDestinations.vodafoneCashMaxLength
                : AcademyPaymentDestinations.instapayMaxLength,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: _isVodafone
                  ? AdminPaymentDestinationsText.vodafoneCashLabel
                  : AdminPaymentDestinationsText.instapayLabel,
              hintText: _isVodafone
                  ? AdminPaymentDestinationsText.vodafoneCashHint
                  : AdminPaymentDestinationsText.instapayHint,
              helperText: AdminPaymentDestinationsText.clearHelper,
              helperMaxLines: 2,
              errorText: _error,
              errorMaxLines: 3,
              counterText: '',
            ),
          ),
          // ListTiles paint ink on the nearest Material, not on the card.
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: Key('$_prefix-confirm'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: widget.busy
                  ? null
                  : (v) => setState(() {
                      _confirmed = v ?? false;
                      if (_confirmed &&
                          _error ==
                              AdminPaymentDestinationsText.confirmRequired) {
                        _error = null;
                      }
                    }),
              title: const Text(AdminPaymentDestinationsText.confirmBusiness),
            ),
          ),
          const SizedBox(height: 8),
          AppButton(
            key: Key('$_prefix-save'),
            label: AdminPaymentDestinationsText.save,
            isLoading: widget.saving,
            onPressed: widget.busy ? null : _save,
          ),
        ],
      ),
    );
  }
}
