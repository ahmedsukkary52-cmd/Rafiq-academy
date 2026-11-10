import '../../../core/di/injection_container.dart';
import '../../../shared/domain/current_student_profile.dart';
import '../domain/entities/student_profile_entity.dart';
import 'bloc/student_bloc.dart';

/// Reads the app-wide [StudentBloc] singleton's loaded profile.
class StudentBlocCurrentProfile implements CurrentStudentProfile {
  const StudentBlocCurrentProfile();

  StudentProfileEntity? get _profile => sl<StudentBloc>().state.profile;

  @override
  String? get name => _profile?.name;

  @override
  String? get halaqaId => _profile?.halaqaId;
}
