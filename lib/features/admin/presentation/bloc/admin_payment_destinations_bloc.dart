import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../../shared/domain/academy_billing_entities.dart';
import '../../../../shared/domain/academy_payment_destinations.dart';
import '../../data/payment_destination_errors.dart';
import '../../domain/usecases/admin_billing_usecases.dart';

sealed class AdminPaymentDestinationsEvent extends Equatable {
  const AdminPaymentDestinationsEvent();
  @override
  List<Object?> get props => [];
}

class LoadPaymentDestinationsSettingsEvent
    extends AdminPaymentDestinationsEvent {
  const LoadPaymentDestinationsSettingsEvent();
}

class SavePaymentDestinationEvent extends AdminPaymentDestinationsEvent {
  final AcademyPaymentMethod method;
  final String value;
  const SavePaymentDestinationEvent({
    required this.method,
    required this.value,
  });
  @override
  List<Object?> get props => [method, value];
}

class ResetPaymentDestinationSaveEvent extends AdminPaymentDestinationsEvent {
  const ResetPaymentDestinationSaveEvent();
}

class AdminPaymentDestinationsState extends Equatable {
  final SectionStatus loadStatus;
  final PaymentPublicSettingsEntity? settings;
  final String? loadError;
  final SubmissionStatus saveStatus;
  final AcademyPaymentMethod? savingMethod;
  final String? saveError;

  const AdminPaymentDestinationsState({
    this.loadStatus = SectionStatus.initial,
    this.settings,
    this.loadError,
    this.saveStatus = SubmissionStatus.idle,
    this.savingMethod,
    this.saveError,
  });

  AdminPaymentDestinationsState copyWith({
    SectionStatus? loadStatus,
    PaymentPublicSettingsEntity? settings,
    String? loadError,
    bool clearLoadError = false,
    SubmissionStatus? saveStatus,
    AcademyPaymentMethod? savingMethod,
    bool clearSavingMethod = false,
    String? saveError,
    bool clearSaveError = false,
  }) => AdminPaymentDestinationsState(
    loadStatus: loadStatus ?? this.loadStatus,
    settings: settings ?? this.settings,
    loadError: clearLoadError ? null : loadError ?? this.loadError,
    saveStatus: saveStatus ?? this.saveStatus,
    savingMethod: clearSavingMethod ? null : savingMethod ?? this.savingMethod,
    saveError: clearSaveError ? null : saveError ?? this.saveError,
  );

  @override
  List<Object?> get props => [
    loadStatus,
    settings,
    loadError,
    saveStatus,
    savingMethod,
    saveError,
  ];
}

/// Admin editor for `academySettings/paymentPublic`. Each method is saved on
/// its own so updating one destination never rewrites the other.
@injectable
class AdminPaymentDestinationsBloc
    extends Bloc<AdminPaymentDestinationsEvent, AdminPaymentDestinationsState> {
  final GetAdminPaymentPublicSettingsUseCase getSettings;
  final UpdatePaymentPublicSettingsUseCase updateSettings;

  AdminPaymentDestinationsBloc({
    required this.getSettings,
    required this.updateSettings,
  }) : super(const AdminPaymentDestinationsState()) {
    on<LoadPaymentDestinationsSettingsEvent>(
      _onLoad,
      transformer: restartable(),
    );
    on<SavePaymentDestinationEvent>(_onSave, transformer: droppable());
    on<ResetPaymentDestinationSaveEvent>(_onReset);
  }

  Future<void> _onLoad(
    LoadPaymentDestinationsSettingsEvent event,
    Emitter<AdminPaymentDestinationsState> emit,
  ) async {
    emit(
      state.copyWith(loadStatus: SectionStatus.loading, clearLoadError: true),
    );
    final result = await getSettings(const NoParams());
    result.fold(
      (f) => emit(
        state.copyWith(
          loadStatus: SectionStatus.error,
          loadError: f.message.trim().isEmpty
              ? kPaymentDestinationsLoadFailedMessage
              : f.message,
        ),
      ),
      (s) =>
          emit(state.copyWith(loadStatus: SectionStatus.loaded, settings: s)),
    );
  }

  Future<void> _onSave(
    SavePaymentDestinationEvent event,
    Emitter<AdminPaymentDestinationsState> emit,
  ) async {
    final current = state.settings;
    if (state.loadStatus != SectionStatus.loaded || current == null) return;
    emit(
      state.copyWith(
        saveStatus: SubmissionStatus.submitting,
        savingMethod: event.method,
        clearSaveError: true,
      ),
    );
    final result = await updateSettings(
      UpdatePaymentPublicParams(method: event.method, value: event.value),
    );
    result.fold(
      (f) => emit(
        state.copyWith(
          saveStatus: SubmissionStatus.error,
          saveError: f.message.trim().isEmpty
              ? kPaymentDestinationsSaveFailedMessage
              : f.message,
        ),
      ),
      (_) {
        final saved = event.value.trim().isEmpty
            ? ''
            : AcademyPaymentDestinations.normalize(event.method, event.value);
        emit(
          state.copyWith(
            saveStatus: SubmissionStatus.success,
            settings: PaymentPublicSettingsEntity(
              vodafoneCashDestination:
                  event.method == AcademyPaymentMethod.vodafoneCash
                  ? saved
                  : current.vodafoneCashDestination,
              instapayDestination: event.method == AcademyPaymentMethod.instapay
                  ? saved
                  : current.instapayDestination,
              updatedAt: current.updatedAt,
              updatedBy: current.updatedBy,
            ),
          ),
        );
      },
    );
  }

  void _onReset(
    ResetPaymentDestinationSaveEvent event,
    Emitter<AdminPaymentDestinationsState> emit,
  ) {
    emit(
      state.copyWith(
        saveStatus: SubmissionStatus.idle,
        clearSavingMethod: true,
        clearSaveError: true,
      ),
    );
  }
}
