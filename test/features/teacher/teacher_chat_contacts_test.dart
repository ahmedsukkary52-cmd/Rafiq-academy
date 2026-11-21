import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/chat/domain/entities/chat_entities.dart';
import 'package:rafiq_academy/features/chat/domain/usecases/chat_usecases.dart';
import 'package:rafiq_academy/features/teacher/presentation/chat/teacher_chat_contacts.dart';
import 'package:rafiq_academy/shared/domain/halaqa_entity.dart';
import 'package:rafiq_academy/shared/domain/student_parent_links.dart';

class _ParentLinks extends Fake implements StudentParentLinkReader {
  _ParentLinks(this.map);
  final Map<String, List<String>> map;

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    final out = <String, List<String>>{};
    for (final id in studentIds) {
      if (map.containsKey(id)) out[id] = map[id]!;
    }
    return Right(out);
  }
}

class _Participants extends Fake implements GetChatParticipantUseCase {
  _Participants(this.byUid);
  final Map<String, ChatParticipantEntity> byUid;

  @override
  Future<Either<Failure, ChatParticipantEntity>> call(
    ChatUidParams params,
  ) async {
    final p = byUid[params.uid];
    if (p == null) {
      return const Left(ServerFailure('missing'));
    }
    return Right(p);
  }
}

ChatParticipantEntity _p(String uid, String name, String role) =>
    ChatParticipantEntity(uid: uid, name: name, role: role);

void main() {
  const halaqa = HalaqaEntity(
    id: 'h1',
    name: 'حلقة',
    teacherId: 't1',
    supervisorId: 'sup1',
    studentIds: ['s1', 's2'],
    schedule: [],
    status: 'active',
  );

  test('includes students, linked parents, and supervisor with captions', () async {
    final result = await loadTeacherChatContacts(
      halaqat: const [halaqa],
      teacherUid: 't1',
      teacherRole: AppRoles.teacher,
      getParticipant: _Participants({
        's1': _p('s1', 'أحمد', AppRoles.student),
        's2': _p('s2', 'سارة', AppRoles.student),
        'sup1': _p('sup1', 'مشرف الحلقات', AppRoles.supervisor),
        'p1': _p('p1', 'أبو أحمد', AppRoles.parent),
        'p2': _p('p2', 'أم سارة', AppRoles.parent),
      }),
      parentLinks: _ParentLinks({
        's1': ['p1'],
        's2': ['p2'],
      }),
    );

    final contacts = result.getOrElse((_) => throw StateError('failed'));
    expect(contacts.map((c) => c.participant.uid), containsAll(['s1', 's2', 'sup1', 'p1', 'p2']));
    expect(
      contacts.firstWhere((c) => c.participant.uid == 'p1').caption,
      'ولي أمر · أحمد',
    );
    expect(
      contacts.firstWhere((c) => c.participant.uid == 'sup1').caption,
      'مشرف',
    );
  });

  test('filters disallowed roles and self uid', () async {
    final result = await loadTeacherChatContacts(
      halaqat: const [
        HalaqaEntity(
          id: 'h1',
          name: 'حلقة',
          teacherId: 't1',
          supervisorId: 't1',
          studentIds: ['s1', 'admin1'],
          schedule: [],
          status: 'active',
        ),
      ],
      teacherUid: 't1',
      teacherRole: AppRoles.teacher,
      getParticipant: _Participants({
        's1': _p('s1', 'أحمد', AppRoles.student),
        // Mis-tagged uid in roster — policy must drop teacher↔teacher self already,
        // and student role for admin1 is wrong on purpose; use admin role.
        'admin1': _p('admin1', 'إدارة', AppRoles.admin),
      }),
      parentLinks: _ParentLinks(const {}),
    );

    final contacts = result.getOrElse((_) => throw StateError('failed'));
    expect(
      contacts.map((c) => c.participant.uid).toList(),
      ['s1', 'admin1'],
    );
    expect(contacts.first.participant.role, AppRoles.student);
    expect(contacts.last.participant.role, AppRoles.admin);
  });

  test('search filters by name and caption', () {
    final all = [
      TeacherChatContactCandidate(
        participant: _p('p1', 'أبو أحمد', AppRoles.parent),
        caption: 'ولي أمر · أحمد',
      ),
      TeacherChatContactCandidate(
        participant: _p('s1', 'أحمد', AppRoles.student),
        caption: 'طالب',
      ),
    ];
    expect(filterTeacherChatContacts(all, 'ولي').single.participant.uid, 'p1');
    expect(filterTeacherChatContacts(all, 'أحمد').length, 2);
    expect(filterTeacherChatContacts(all, 'xyz'), isEmpty);
  });

  test('empty halaqat yields empty roster without parent reads', () async {
    var parentCalls = 0;
    final links = _CountingLinks(() => parentCalls++);
    final result = await loadTeacherChatContacts(
      halaqat: const [],
      teacherUid: 't1',
      teacherRole: AppRoles.teacher,
      getParticipant: _Participants(const {}),
      parentLinks: links,
    );
    expect(result.getOrElse((_) => throw StateError('failed')), isEmpty);
    expect(parentCalls, 0);
  });
}

class _CountingLinks extends Fake implements StudentParentLinkReader {
  _CountingLinks(this.onCall);
  final void Function() onCall;

  @override
  Future<Either<Failure, Map<String, List<String>>>> getParentIdsByStudentIds(
    List<String> studentIds,
  ) async {
    onCall();
    return const Right({});
  }
}
