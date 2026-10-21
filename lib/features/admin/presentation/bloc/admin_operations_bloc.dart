import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/presentation/bloc_status.dart';
import '../../../../core/usecases/usecases.dart';
import '../../../student/domain/entities/halaqa_entity.dart';
import '../../domain/entities/admin_operations_entities.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/usecases/admin_billing_usecases.dart';
import '../../domain/usecases/admin_operations_usecases.dart';
import '../../domain/usecases/approve_new_student_usecase.dart';
import '../../domain/usecases/provision_user_usecase.dart';

part 'admin_operations_event.dart';
part 'admin_operations_state.dart';

/// P0-02 Admin operational subpages (provisioning, parent linking, Halaqa +
/// schedule creation, admission, transfer, access reinstatement).
///
/// Every mutation goes through an existing authoritative callable via its
/// use case; this Bloc only sequences them and refreshes the directory.
@injectable
class AdminOperationsBloc
    extends Bloc<AdminOperationsEvent, AdminOperationsState> {
  final ListUsersByRoleUseCase listUsersByRole;
  final ListAdminHalaqatUseCase listHalaqat;
  final GetParentChildrenUseCase getParentChildren;
  final ProvisionUserUseCase provisionUser;
  final LinkParentChildUseCase linkParentChild;
  final CreateHalaqaUseCase createHalaqa;
  final AddHalaqaSlotUseCase addHalaqaSlot;
  final SetHalaqaMeetingLinkUseCase setMeetingLink;
  final ApproveNewStudentUseCase admitStudent;
  final TransferStudentUseCase transferStudent;
  final ReinstatePaymentAccessUseCase reinstatePaymentAccess;

  AdminOperationsBloc({
    required this.listUsersByRole,
    required this.listHalaqat,
    required this.getParentChildren,
    required this.provisionUser,
    required this.linkParentChild,
    required this.createHalaqa,
    required this.addHalaqaSlot,
    required this.setMeetingLink,
    required this.admitStudent,
    required this.transferStudent,
    required this.reinstatePaymentAccess,
  }) : super(const AdminOperationsState()) {
    on<LoadAdminDirectoryEvent>(_onLoadDirectory, transformer: restartable());
    on<SelectParentEvent>(_onLoadParentChildren, transformer: restartable());
    on<ProvisionAccountEvent>(_onProvision, transformer: droppable());
    on<LinkParentChildEvent>(_onLink, transformer: droppable());
    on<CreateHalaqaEvent>(_onCreateHalaqa, transformer: droppable());
    on<AddHalaqaSlotEvent>(_onAddSlot, transformer: droppable());
    on<SetHalaqaMeetingLinkEvent>(_onSetMeetingLink, transformer: droppable());
    on<AdmitStudentEvent>(_onAdmit, transformer: droppable());
    on<TransferStudentEvent>(_onTransfer, transformer: droppable());
    on<ReinstateParentAccessEvent>(_onReinstate, transformer: droppable());
    on<ClearAdminOperationMessageEvent>(_onClearMessage);
  }

  Future<void> _onLoadDirectory(
    LoadAdminDirectoryEvent event,
    Emitter<AdminOperationsState> emit,
  ) async {
    emit(state.copyWith(directoryStatus: SectionStatus.loading));
    final results = await Future.wait([
      listUsersByRole(AppRoles.student),
      listUsersByRole(AppRoles.parent),
      listUsersByRole(AppRoles.teacher),
      listUsersByRole(AppRoles.supervisor),
    ]);
    final halaqatResult = await listHalaqat(const NoParams());

    Failure? failure;
    List<AdminDirectoryUser> unwrap(
      Either<Failure, List<AdminDirectoryUser>> r,
    ) => r.fold((f) {
      failure ??= f;
      return const <AdminDirectoryUser>[];
    }, (v) => v);

    final students = unwrap(results[0]);
    final parents = unwrap(results[1]);
    final teachers = unwrap(results[2]);
    final supervisors = unwrap(results[3]);
    final halaqat = halaqatResult.fold((f) {
      failure ??= f;
      return const <HalaqaEntity>[];
    }, (v) => v);

    emit(
      state.copyWith(
        directoryStatus: failure == null
            ? SectionStatus.loaded
            : SectionStatus.error,
        directoryError: failure?.message,
        students: students,
        parents: parents,
        teachers: teachers,
        supervisors: supervisors,
        halaqat: halaqat,
      ),
    );
  }

  Future<void> _onLoadParentChildren(
    SelectParentEvent event,
    Emitter<AdminOperationsState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedParentId: event.parentId,
        selectedParentChildren: [],
      ),
    );
    final result = await getParentChildren(event.parentId);
    result.fold((f) => emit(state.copyWith(actionError: f.message)), (ids) {
      if (state.selectedParentId == event.parentId) {
        emit(state.copyWith(selectedParentChildren: ids));
      }
    });
  }

  Future<void> _runAction<T>(
    Emitter<AdminOperationsState> emit, {
    required Future<Either<Failure, T>> Function() action,
    required String Function(T value) successMessage,
    void Function(T value)? onSuccess,
    bool reloadDirectory = false,
  }) async {
    emit(
      state.copyWith(
        actionStatus: SubmissionStatus.submitting,
        actionError: null,
        actionMessage: null,
      ),
    );
    final result = await action();
    result.fold(
      (f) => emit(
        state.copyWith(
          actionStatus: SubmissionStatus.error,
          actionError: f.message,
        ),
      ),
      (value) {
        onSuccess?.call(value);
        emit(
          state.copyWith(
            actionStatus: SubmissionStatus.success,
            actionMessage: successMessage(value),
          ),
        );
      },
    );
    if (reloadDirectory && result.isRight()) {
      add(const LoadAdminDirectoryEvent());
    }
  }

  Future<void> _onProvision(
    ProvisionAccountEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<String>(
    emit,
    action: () => provisionUser(event.params),
    successMessage: (_) => 'تم إنشاء الحساب بنجاح',
    reloadDirectory: true,
  );

  Future<void> _onLink(
    LinkParentChildEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<ParentLinkResult>(
    emit,
    action: () => linkParentChild(event.params),
    successMessage: (r) {
      if (!r.changed) {
        return event.params.operation == ParentLinkOperation.link
            ? 'الطالب مرتبط بولي الأمر بالفعل'
            : 'الطالب غير مرتبط بولي الأمر أصلاً';
      }
      return event.params.operation == ParentLinkOperation.link
          ? 'تم ربط الطالب بولي الأمر'
          : 'تم فك ربط الطالب';
    },
    onSuccess: (r) {
      if (state.selectedParentId == event.params.parentId) {
        emit(state.copyWith(selectedParentChildren: r.childrenIds));
      }
    },
  );

  Future<void> _onCreateHalaqa(
    CreateHalaqaEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<String>(
    emit,
    action: () => createHalaqa(event.params),
    successMessage: (_) => 'تم إنشاء الحلقة ومواعيدها',
    reloadDirectory: true,
  );

  Future<void> _onAddSlot(
    AddHalaqaSlotEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<String>(
    emit,
    action: () => addHalaqaSlot(event.params),
    successMessage: (_) => 'تمت إضافة الموعد',
    reloadDirectory: true,
  );

  Future<void> _onSetMeetingLink(
    SetHalaqaMeetingLinkEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<MeetingLinkChange>(
    emit,
    action: () => setMeetingLink(event.params),
    successMessage: meetingLinkChangeMessage,
    reloadDirectory: true,
  );

  Future<void> _onAdmit(
    AdmitStudentEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<Unit>(
    emit,
    action: () => admitStudent(
      ApproveStudentParams(
        studentId: event.studentId,
        halaqaId: event.halaqaId,
      ),
    ),
    successMessage: (_) => 'تمت إضافة الطالب للحلقة',
    reloadDirectory: true,
  );

  Future<void> _onTransfer(
    TransferStudentEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<Unit>(
    emit,
    action: () => transferStudent(event.params),
    successMessage: (_) => 'تم نقل الطالب',
    reloadDirectory: true,
  );

  Future<void> _onReinstate(
    ReinstateParentAccessEvent event,
    Emitter<AdminOperationsState> emit,
  ) => _runAction<Unit>(
    emit,
    action: () => reinstatePaymentAccess(
      ReinstatePaymentAccessParams(
        parentId: event.parentId,
        reason: event.reason,
      ),
    ),
    successMessage: (_) => 'تمت إعادة تفعيل وصول ولي الأمر',
  );

  void _onClearMessage(
    ClearAdminOperationMessageEvent event,
    Emitter<AdminOperationsState> emit,
  ) {
    emit(
      state.copyWith(
        actionStatus: SubmissionStatus.idle,
        actionError: null,
        actionMessage: null,
      ),
    );
  }
}
