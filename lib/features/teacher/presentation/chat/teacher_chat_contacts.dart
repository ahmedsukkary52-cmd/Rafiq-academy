import 'package:fpdart/fpdart.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../shared/domain/halaqa_entity.dart';
import '../../../../shared/domain/student_parent_links.dart';
import '../../../chat/domain/entities/chat_entities.dart';
import '../../../chat/domain/policies/chat_permission_policy.dart';
import '../../../chat/domain/usecases/chat_usecases.dart';

/// One row in the teacher “new chat” related-people list.
class TeacherChatContactCandidate {
  final ChatParticipantEntity participant;

  /// e.g. «ولي أمر · أحمد» or «مشرف».
  final String caption;

  const TeacherChatContactCandidate({
    required this.participant,
    required this.caption,
  });
}

/// Builds the teacher Plus picker roster from assigned halaqat:
/// students, halaqa supervisors, and linked parents (via [StudentParentLinkReader]).
///
/// UX pre-filter only — `createDirectConversation` enforces relationships.
Future<Either<Failure, List<TeacherChatContactCandidate>>>
loadTeacherChatContacts({
  required List<HalaqaEntity> halaqat,
  required String teacherUid,
  required String teacherRole,
  required GetChatParticipantUseCase getParticipant,
  required StudentParentLinkReader parentLinks,
}) async {
  final studentIds = <String>{};
  final supervisorIds = <String>{};
  for (final h in halaqat) {
    studentIds.addAll(h.studentIds.where((id) => id.trim().isNotEmpty));
    final sid = h.supervisorId.trim();
    if (sid.isNotEmpty) supervisorIds.add(sid);
  }
  studentIds.remove(teacherUid);
  supervisorIds.remove(teacherUid);

  final parentToStudents = <String, Set<String>>{};
  if (studentIds.isNotEmpty) {
    final parentsResult = await parentLinks.getParentIdsByStudentIds(
      studentIds.toList(),
    );
    final failed = parentsResult.fold<Failure?>((f) => f, (_) => null);
    if (failed != null) return Left(failed);
    parentsResult.fold((_) {}, (map) {
      map.forEach((studentId, parents) {
        for (final raw in parents) {
          final pid = raw.trim();
          if (pid.isEmpty || pid == teacherUid) continue;
          parentToStudents.putIfAbsent(pid, () => <String>{}).add(studentId);
        }
      });
    });
  }

  final uids = <String>{
    ...studentIds,
    ...supervisorIds,
    ...parentToStudents.keys,
  };
  if (uids.isEmpty) {
    return const Right(<TeacherChatContactCandidate>[]);
  }

  final results = await Future.wait(
    uids.map((uid) => getParticipant(ChatUidParams(uid))),
  );

  // Best-effort student display names for parent captions.
  final studentNames = <String, String>{};
  for (final either in results) {
    either.fold((_) {}, (p) {
      if (p.role == AppRoles.student) {
        studentNames[p.uid] = p.name.trim().isEmpty ? 'طالب' : p.name.trim();
      }
    });
  }

  final contacts = <TeacherChatContactCandidate>[];
  final seen = <String>{};
  for (final either in results) {
    either.fold((_) {}, (p) {
      if (!seen.add(p.uid)) return;
      if (!ChatPermissionPolicy.canChat(teacherRole, p.role)) return;
      contacts.add(
        TeacherChatContactCandidate(
          participant: p,
          caption: _caption(
            participant: p,
            linkedStudentIds: parentToStudents[p.uid] ?? const {},
            studentNames: studentNames,
          ),
        ),
      );
    });
  }

  contacts.sort((a, b) {
    final roleCmp = _roleOrder(a.participant.role).compareTo(
      _roleOrder(b.participant.role),
    );
    if (roleCmp != 0) return roleCmp;
    return a.participant.name.compareTo(b.participant.name);
  });
  return Right(contacts);
}

List<TeacherChatContactCandidate> filterTeacherChatContacts(
  List<TeacherChatContactCandidate> all,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where((c) {
        final hay =
            '${c.participant.name} ${c.caption} ${c.participant.role}'
                .toLowerCase();
        return hay.contains(q);
      })
      .toList();
}

int _roleOrder(String role) => switch (role) {
  AppRoles.student => 0,
  AppRoles.parent => 1,
  AppRoles.supervisor => 2,
  AppRoles.admin => 3,
  _ => 9,
};

String _caption({
  required ChatParticipantEntity participant,
  required Set<String> linkedStudentIds,
  required Map<String, String> studentNames,
}) {
  final role = switch (participant.role) {
    AppRoles.student => 'طالب',
    AppRoles.parent => 'ولي أمر',
    AppRoles.supervisor => 'مشرف',
    AppRoles.admin => 'إدارة',
    AppRoles.teacher => 'معلم',
    _ => participant.role,
  };
  if (participant.role != AppRoles.parent || linkedStudentIds.isEmpty) {
    return role;
  }
  final names = linkedStudentIds
      .map((id) => studentNames[id] ?? 'طالب')
      .toList()
    ..sort();
  if (names.isEmpty) return role;
  if (names.length == 1) return '$role · ${names.first}';
  return '$role · ${names.take(2).join('، ')}'
      '${names.length > 2 ? '…' : ''}';
}
