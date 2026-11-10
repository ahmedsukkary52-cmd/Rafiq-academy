import '../../../core/di/injection_container.dart';
import '../../../shared/domain/id_params.dart';
import '../../chat/domain/student_chat_teacher.dart';
import '../domain/usecases/get_student_halaqa_usecase.dart';
import 'bloc/student_bloc.dart';

/// مصدر المعلم: `studentProfiles.halaqaId` → `halaqat.teacherId`
/// (fallback: `assignments.assignedBy` لو الحلقة بدون teacherId).
///
/// Reads the app-wide [StudentBloc] singleton when asked, so a retry sees
/// the latest student state.
class StudentBlocChatTeacherResolver implements StudentChatTeacherResolver {
  const StudentBlocChatTeacherResolver();

  @override
  Future<StudentChatTeacher> resolveTeacher() async {
    final studentState = sl<StudentBloc>().state;
    final halaqaId = studentState.profile?.halaqaId;

    String? teacherUid = studentState.halaqa?.teacherId;
    if (teacherUid == null || teacherUid.isEmpty) {
      if (halaqaId != null && halaqaId.isNotEmpty) {
        final halaqaResult = await sl<GetStudentHalaqaUseCase>()(
          HalaqaIdParams(halaqaId),
        );
        halaqaResult.fold((f) => null, (h) => teacherUid = h.teacherId);
      }
    }

    // Fallback أضعف: آخر تكليف
    if (teacherUid == null || teacherUid!.isEmpty) {
      final assignedBy = studentState.latestAssignment?.assignedBy;
      if (assignedBy != null && assignedBy.isNotEmpty) {
        teacherUid = assignedBy;
      }
    }

    return StudentChatTeacher(
      teacherUid: teacherUid,
      hasHalaqa: halaqaId != null && halaqaId.isNotEmpty,
    );
  }
}
