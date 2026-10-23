import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource.dart';
import 'package:rafiq_academy/features/parent/data/repositories/parent_repository_impl.dart';
import 'package:rafiq_academy/features/parent/domain/usecases/get_child_achievements_usecase.dart';
import 'package:rafiq_academy/features/student/data/models/achievement_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/achievement_entity.dart';
import 'package:rafiq_academy/features/student/domain/usecases/watch_latest_assignment_usecase.dart';

import '../../support/fake_callables.dart';

class _ParentDs extends Fake implements ParentRemoteDatasource {
  final List<String> requested = [];
  List<AchievementModel> items = const [];
  ServerException? error;

  @override
  Future<List<AchievementModel>> getChildAchievements(String studentId) async {
    requested.add(studentId);
    if (error != null) throw error!;
    return items;
  }
}

AchievementModel _item(String id, int millis) =>
    AchievementModel.fromParentCallable({
      'id': id,
      'studentId': 's1',
      'type': 'star',
      'title': id,
      'dateMillis': millis,
      'recipientStudentIds': const ['s1'],
    });

void main() {
  group('AchievementModel.fromParentCallable', () {
    test('maps the server projection through the shared contract', () {
      final model = AchievementModel.fromParentCallable(const {
        'id': 'a1',
        'studentId': 's1',
        'type': 'custom',
        'title': '',
        'note': 'حفظ جزء',
        'description': 'سبب',
        'imageUrl': 'https://example.test/a.png',
        'issuedBy': 'teacher1',
        'dateMillis': 1790000000000,
        'recipientStudentIds': ['s1', 's2'],
      });
      expect(model.id, 'a1');
      expect(model.studentId, 's1');
      expect(model.type, AchievementType.custom);
      expect(model.title, 'حفظ جزء');
      expect(model.description, 'سبب');
      expect(model.imageUrl, 'https://example.test/a.png');
      expect(model.issuedBy, 'teacher1');
      expect(model.date, DateTime.fromMillisecondsSinceEpoch(1790000000000));
      expect(model.recipientStudentIds, ['s1', 's2']);
    });

    test('legacy single-recipient entry and missing optional fields', () {
      final model = AchievementModel.fromParentCallable(const {
        'id': 'a2',
        'studentId': '',
        'type': 'star',
        'title': 'نجمة',
        'imageUrl': null,
        'dateMillis': null,
        'recipientStudentIds': ['s1'],
      });
      expect(model.studentId, 's1');
      expect(model.imageUrl, isNull);
      expect(model.description, '');
      expect(model.date, DateTime.fromMillisecondsSinceEpoch(0));
      expect(model.type, AchievementType.star);
    });
  });

  group('GetChildAchievementsUseCase via ParentRepositoryImpl', () {
    late _ParentDs ds;
    late GetChildAchievementsUseCase useCase;

    setUp(() {
      ds = _ParentDs();
      useCase = GetChildAchievementsUseCase(
        ParentRepositoryImpl(
          remoteDatasource: ds,
          networkInfo: FakeNetworkInfo(),
        ),
      );
    });

    test(
      'empty student id fails validation without calling the server',
      () async {
        final result = await useCase(const StudentUidParams('  '));
        expect(result.getLeft().toNullable(), isA<ValidationFailure>());
        expect(ds.requested, isEmpty);
      },
    );

    test(
      'calls the callable path with the trimmed id; newest first, deduplicated',
      () async {
        ds.items = [
          _item('old', 1000),
          _item('new', 3000),
          _item('new', 3000),
          _item('mid', 2000),
        ];
        final result = await useCase(const StudentUidParams(' s1 '));
        expect(ds.requested, ['s1']);
        expect(result.getOrElse((_) => const []).map((a) => a.id).toList(), [
          'new',
          'mid',
          'old',
        ]);
      },
    );

    test('server denial maps to ServerFailure', () async {
      ds.error = const ServerException('هذا الطالب غير مرتبط بحسابك');
      final result = await useCase(const StudentUidParams('s9'));
      final failure = result.getLeft().toNullable();
      expect(failure, isA<ServerFailure>());
      expect(failure!.message, 'هذا الطالب غير مرتبط بحسابك');
    });

    test('offline returns NetworkFailure', () async {
      final offline = GetChildAchievementsUseCase(
        ParentRepositoryImpl(
          remoteDatasource: ds,
          networkInfo: FakeNetworkInfo(connected: false),
        ),
      );
      final result = await offline(const StudentUidParams('s1'));
      expect(result.getLeft().toNullable(), isA<NetworkFailure>());
      expect(ds.requested, isEmpty);
    });
  });

  test(
    'parent pages read achievements only through the parent callable path',
    () {
      for (final path in [
        'lib/features/parent/presentation/pages/parent_achievements_page.dart',
        'lib/features/parent/presentation/pages/parent_child_profile_page.dart',
      ]) {
        final src = File(path).readAsStringSync();
        expect(src, contains('GetChildAchievementsUseCase'), reason: path);
        expect(src, isNot(contains('GetAchievementsUseCase')), reason: path);
      }
      final ds = File(
        'lib/features/parent/data/data_source/parent_remote_datasource_impl.dart',
      ).readAsStringSync();
      expect(ds, contains("httpsCallable('getParentAchievements')"));
    },
  );
}
