part of 'admin_operations_bloc.dart';

sealed class AdminOperationsEvent extends Equatable {
  const AdminOperationsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAdminDirectoryEvent extends AdminOperationsEvent {
  const LoadAdminDirectoryEvent();
}

class SelectParentEvent extends AdminOperationsEvent {
  final String parentId;
  const SelectParentEvent(this.parentId);

  @override
  List<Object?> get props => [parentId];
}

class ProvisionAccountEvent extends AdminOperationsEvent {
  final ProvisionUserParams params;
  const ProvisionAccountEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class LinkParentChildEvent extends AdminOperationsEvent {
  final LinkParentChildParams params;
  const LinkParentChildEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class CreateHalaqaEvent extends AdminOperationsEvent {
  final CreateHalaqaParams params;
  const CreateHalaqaEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class AddHalaqaSlotEvent extends AdminOperationsEvent {
  final AddHalaqaSlotParams params;
  const AddHalaqaSlotEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class AdmitStudentEvent extends AdminOperationsEvent {
  final String studentId;
  final String halaqaId;
  const AdmitStudentEvent({required this.studentId, required this.halaqaId});

  @override
  List<Object?> get props => [studentId, halaqaId];
}

class TransferStudentEvent extends AdminOperationsEvent {
  final TransferStudentParams params;
  const TransferStudentEvent(this.params);

  @override
  List<Object?> get props => [params];
}

class ReinstateParentAccessEvent extends AdminOperationsEvent {
  final String parentId;
  final String? reason;
  const ReinstateParentAccessEvent({required this.parentId, this.reason});

  @override
  List<Object?> get props => [parentId, reason];
}

class ClearAdminOperationMessageEvent extends AdminOperationsEvent {
  const ClearAdminOperationMessageEvent();
}
