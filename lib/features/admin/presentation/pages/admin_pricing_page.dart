import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_settings_contract.dart';
import '../../../../shared/domain/pricing_rules_contract.dart';
import '../../../../shared/presentation/academy_currency_label.dart';
import '../../../../shared/theme/app_theme.dart';
import '../../../../shared/widgets/app_back_button.dart';
import '../../../../shared/widgets/shared_widgets.dart';
import '../../domain/usecases/admin_billing_usecases.dart';

/// Admin UI to set monthly halaqa / student / academy default prices.
class AdminPricingPage extends StatefulWidget {
  const AdminPricingPage({super.key});

  @override
  State<AdminPricingPage> createState() => _AdminPricingPageState();
}

class _AdminPricingPageState extends State<AdminPricingPage> {
  List<PricingRuleEntity> _rules = const [];
  String? _error;
  bool _loading = true;
  bool _saving = false;

  static const _academyDocId = 'pricing_academy_default';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await sl<ListPricingRulesUseCase>()(NoParams());
      if (!mounted) return;
      result.fold(
        (f) => setState(() {
          _loading = false;
          _error = f.message;
        }),
        (rules) => setState(() {
          _loading = false;
          _rules = rules;
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل قواعد التسعير';
      });
    }
  }

  PricingRuleEntity? _existingForScope(String scope, String? scopeId) {
    final sid = (scopeId ?? '').trim();
    for (final r in _rules) {
      if (r.scope != scope) continue;
      if (scope == PricingRulesContract.scopeAcademyDefault) return r;
      if ((r.scopeId ?? '').trim() == sid) return r;
    }
    return null;
  }

  Future<void> _upsert({
    required String scope,
    String? scopeId,
    required double amount,
    PricingRuleEntity? existing,
  }) async {
    setState(() => _saving = true);
    try {
      final matched = existing ?? _existingForScope(scope, scopeId);
      final id = matched?.id.trim().isNotEmpty == true
          ? matched!.id.trim()
          : (scope == PricingRulesContract.scopeAcademyDefault
                ? _academyDocId
                : '');
      final entity = PricingRuleEntity(
        id: id,
        scope: scope,
        scopeId: scope == PricingRulesContract.scopeAcademyDefault
            ? null
            : scopeId,
        amount: amount,
        currency: matched?.currency ??
            AcademyPaymentSettingsContract.defaultCurrency,
        billingPeriod: matched?.billingPeriod ??
            AcademyPaymentSettingsContract.defaultBillingPeriod,
        active: true,
        version: (matched?.version ?? 0) + 1,
      );
      final result = await sl<UpsertPricingRuleUseCase>()(entity);
      if (!mounted) return;
      setState(() => _saving = false);
      result.fold(
        (Failure f) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(f.message)),
          );
        },
        (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حفظ التسعير')),
          );
          _load();
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حفظ التسعير. حاول مرة أخرى.')),
      );
    }
  }

  Future<void> _showEditor({PricingRuleEntity? existing}) async {
    var selectedScope =
        existing?.scope ?? PricingRulesContract.scopeAcademyDefault;
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );
    final scopeIdCtrl = TextEditingController(text: existing?.scopeId ?? '');

    try {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: StatefulBuilder(
                builder: (context, setModal) {
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          existing == null ? 'تسعير جديد' : 'تعديل التسعير',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'النطاق',
                            border: OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedScope,
                              items: const [
                                DropdownMenuItem(
                                  value:
                                      PricingRulesContract.scopeAcademyDefault,
                                  child: Text('افتراضي الأكاديمية'),
                                ),
                                DropdownMenuItem(
                                  value: PricingRulesContract.scopeHalaqa,
                                  child: Text('حلقة معيّنة'),
                                ),
                                DropdownMenuItem(
                                  value: PricingRulesContract.scopeStudent,
                                  child: Text('طالب معيّن (مخصص)'),
                                ),
                              ],
                              onChanged: existing != null
                                  ? null
                                  : (v) {
                                      if (v == null) return;
                                      setModal(() => selectedScope = v);
                                    },
                            ),
                          ),
                        ),
                        if (selectedScope !=
                            PricingRulesContract.scopeAcademyDefault) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: scopeIdCtrl,
                            decoration: InputDecoration(
                              labelText: selectedScope ==
                                      PricingRulesContract.scopeHalaqa
                                  ? 'معرّف الحلقة'
                                  : 'معرّف الطالب',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: amountCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText:
                                'المبلغ الشهري (${AcademyPaymentSettingsContract.defaultCurrency})',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppButton(
                          label: 'حفظ',
                          isLoading: _saving,
                          onPressed: _saving
                              ? null
                              : () {
                                  final amount = double.tryParse(
                                    amountCtrl.text.trim(),
                                  );
                                  if (amount == null || amount <= 0) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('أدخل مبلغاً صالحاً'),
                                      ),
                                    );
                                    return;
                                  }
                                  if (selectedScope !=
                                          PricingRulesContract
                                              .scopeAcademyDefault &&
                                      scopeIdCtrl.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                        content: Text('أدخل المعرّف'),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.pop(ctx, true);
                                  _upsert(
                                    scope: selectedScope,
                                    scopeId: selectedScope ==
                                            PricingRulesContract
                                                .scopeAcademyDefault
                                        ? null
                                        : scopeIdCtrl.text.trim(),
                                    amount: amount,
                                    existing: existing,
                                  );
                                },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      );
      if (saved != true) return;
    } finally {
      amountCtrl.dispose();
      scopeIdCtrl.dispose();
    }
  }

  String _scopeLabel(PricingRuleEntity rule) {
    switch (rule.scope) {
      case PricingRulesContract.scopeAcademyDefault:
        return 'افتراضي الأكاديمية';
      case PricingRulesContract.scopeHalaqa:
        return 'حلقة: ${rule.scopeId ?? '—'}';
      case PricingRulesContract.scopeStudent:
        return 'طالب: ${rule.scopeId ?? '—'}';
      default:
        return rule.scope;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('تسعير الاشتراكات'),
          leading: const AppBackButton(),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _saving ? null : () => _showEditor(),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('سعر جديد'),
        ),
        body: _loading
            ? const AppLoadingWidget()
            : _error != null
            ? AppErrorWidget(message: _error!, onRetry: _load)
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'الأسعار الشهرية',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'حدّد سعر الأكاديمية أو حلقة معيّنة أو سعر مخصص لطالب. يظهر المبلغ لولي الأمر عند إصدار الفاتورة.',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_rules.isEmpty)
                      const _EmptyPricing()
                    else
                      for (final rule in _rules) ...[
                        Material(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            onTap: () => _showEditor(existing: rule),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            title: Text(
                              _scopeLabel(rule),
                              style: AppTextStyles.titleMedium.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(
                              rule.active ? 'نشط · شهري' : 'غير نشط',
                              style: AppTextStyles.labelSmall,
                            ),
                            trailing: Text(
                              academyMoneyText(rule.amount.round().toString()),
                              style: AppTextStyles.titleLarge.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _EmptyPricing extends StatelessWidget {
  const _EmptyPricing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.payments_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('لا توجد قواعد تسعير بعد', style: AppTextStyles.titleMedium),
          const SizedBox(height: 6),
          Text(
            'أضف سعراً افتراضياً أو سعراً لحلقة.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
