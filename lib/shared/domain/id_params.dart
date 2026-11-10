import 'package:equatable/equatable.dart';

/// Single-ID params shared by student, parent, supervisor, chat, homework
/// and progress-report use cases.
class StudentUidParams extends Equatable {
  final String uid;

  const StudentUidParams(this.uid);

  @override
  List<Object?> get props => [uid];
}

class HalaqaIdParams extends Equatable {
  final String halaqaId;

  const HalaqaIdParams(this.halaqaId);

  @override
  List<Object?> get props => [halaqaId];
}
