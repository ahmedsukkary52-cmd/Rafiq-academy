import '../../awards/domain/award_grant_scope.dart';
import '../../awards/domain/award_recipient_selection.dart';
import 'bloc/teacher_bloc.dart';
import 'bloc/teacher_state.dart';

AwardGrantScope teacherAwardGrantScope(TeacherState state) => AwardGrantScope(
  halaqat: state.halaqat
      .map((halaqa) => AwardHalaqaOption(id: halaqa.id, name: halaqa.name))
      .toList(growable: false),
  rosterHalaqaId: state.studentsHalaqaId,
  roster: state.students
      .map(
        (student) => AwardRecipientStudent(
          uid: student.uid,
          name: student.name,
          imageUrl: student.profileImageUrl,
        ),
      )
      .toList(growable: false),
);

/// Projects the app-wide [TeacherBloc] without holding state of its own.
class TeacherAwardGrantScopeSource implements AwardGrantScopeSource {
  final TeacherBloc _bloc;

  const TeacherAwardGrantScopeSource(this._bloc);

  @override
  AwardGrantScope get state => teacherAwardGrantScope(_bloc.state);

  @override
  Stream<AwardGrantScope> get stream =>
      _bloc.stream.map(teacherAwardGrantScope);
}
