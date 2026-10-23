import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_destinations.dart';
import '../repositories/admin_repository.dart';

@lazySingleton
class GetAdminPaymentPublicSettingsUseCase
    extends UseCase<PaymentPublicSettingsEntity, NoParams> {
  final AdminRepository repository;
  GetAdminPaymentPublicSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, PaymentPublicSettingsEntity>> call(NoParams params) =>
      repository.getPaymentPublicSettings();
}

/// Updates one payment method's destination. An empty [value] clears it.
class UpdatePaymentPublicParams extends Equatable {
  final AcademyPaymentMethod method;
  final String value;
  const UpdatePaymentPublicParams({required this.method, required this.value});
  @override
  List<Object?> get props => [method, value];
}

@lazySingleton
class UpdatePaymentPublicSettingsUseCase
    extends UseCase<Unit, UpdatePaymentPublicParams> {
  final AdminRepository repository;
  UpdatePaymentPublicSettingsUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdatePaymentPublicParams params) async {
    final error = AcademyPaymentDestinations.validate(
      params.method,
      params.value,
      allowEmpty: true,
    );
    if (error != null) return Left(ValidationFailure(error));
    final value = params.value.trim().isEmpty
        ? ''
        : AcademyPaymentDestinations.normalize(params.method, params.value);
    return switch (params.method) {
      AcademyPaymentMethod.vodafoneCash =>
        repository.updatePaymentPublicSettings(vodafoneCashDestination: value),
      AcademyPaymentMethod.instapay => repository.updatePaymentPublicSettings(
        instapayDestination: value,
      ),
    };
  }
}

@lazySingleton
class GetPricingDefaultsUseCase
    extends UseCase<PricingDefaultsEntity, NoParams> {
  final AdminRepository repository;
  GetPricingDefaultsUseCase(this.repository);

  @override
  Future<Either<Failure, PricingDefaultsEntity>> call(NoParams params) =>
      repository.getPricingDefaults();
}

class UpdatePricingDefaultsParams extends Equatable {
  final int gracePeriodDays;
  final String defaultCurrency;
  final String defaultBillingPeriod;
  const UpdatePricingDefaultsParams({
    required this.gracePeriodDays,
    required this.defaultCurrency,
    required this.defaultBillingPeriod,
  });
  @override
  List<Object?> get props => [
    gracePeriodDays,
    defaultCurrency,
    defaultBillingPeriod,
  ];
}

@lazySingleton
class UpdatePricingDefaultsUseCase
    extends UseCase<Unit, UpdatePricingDefaultsParams> {
  final AdminRepository repository;
  UpdatePricingDefaultsUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(UpdatePricingDefaultsParams params) =>
      repository.updatePricingDefaults(
        gracePeriodDays: params.gracePeriodDays,
        defaultCurrency: params.defaultCurrency,
        defaultBillingPeriod: params.defaultBillingPeriod,
      );
}

@lazySingleton
class ListPricingRulesUseCase
    extends UseCase<List<PricingRuleEntity>, NoParams> {
  final AdminRepository repository;
  ListPricingRulesUseCase(this.repository);

  @override
  Future<Either<Failure, List<PricingRuleEntity>>> call(NoParams params) =>
      repository.listPricingRules();
}

@lazySingleton
class UpsertPricingRuleUseCase extends UseCase<Unit, PricingRuleEntity> {
  final AdminRepository repository;
  UpsertPricingRuleUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(PricingRuleEntity params) =>
      repository.upsertPricingRule(params);
}

class GenerateInvoiceParams extends Equatable {
  final String studentId;
  final String? parentId;
  final String? periodKey;
  final String? pricingRuleId;
  const GenerateInvoiceParams({
    required this.studentId,
    this.parentId,
    this.periodKey,
    this.pricingRuleId,
  });
  @override
  List<Object?> get props => [studentId, parentId, periodKey, pricingRuleId];
}

@lazySingleton
class GenerateInvoiceUseCase extends UseCase<String, GenerateInvoiceParams> {
  final AdminRepository repository;
  GenerateInvoiceUseCase(this.repository);

  @override
  Future<Either<Failure, String>> call(GenerateInvoiceParams params) =>
      repository.generateInvoice(
        studentId: params.studentId,
        parentId: params.parentId,
        periodKey: params.periodKey,
        pricingRuleId: params.pricingRuleId,
      );
}

class ReinstatePaymentAccessParams extends Equatable {
  final String parentId;
  final String? reason;
  const ReinstatePaymentAccessParams({required this.parentId, this.reason});
  @override
  List<Object?> get props => [parentId, reason];
}

@lazySingleton
class ReinstatePaymentAccessUseCase
    extends UseCase<Unit, ReinstatePaymentAccessParams> {
  final AdminRepository repository;
  ReinstatePaymentAccessUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(ReinstatePaymentAccessParams params) =>
      repository.reinstatePaymentAccess(
        parentId: params.parentId,
        reason: params.reason,
      );
}
