import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/achievement_entity.dart';
import 'package:rafiq_academy/shared/domain/merge_student_achievements.dart';

AchievementEntity _a(String id, DateTime date, {String title = 't'}) =>
    AchievementEntity(
      id: id,
      studentId: 's1',
      type: AchievementType.star,
      title: title,
      issuedBy: 'teacher1',
      date: date,
    );

const _readModel = [
  'lib/shared/domain/achievement_entity.dart',
  'lib/shared/data/models/achievement_model.dart',
  'lib/shared/domain/merge_student_achievements.dart',
];

Iterable<File> _dartFiles(String dir) => Directory(dir)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

void main() {
  group('mergeStudentAchievements (shared read model)', () {
    test('de-duplicates by id, later list wins', () {
      final day = DateTime(2026, 10, 1);
      final merged = mergeStudentAchievements(
        [_a('a1', day, title: 'by studentId')],
        [_a('a1', day, title: 'by recipients')],
      );
      expect(merged, hasLength(1));
      expect(merged.single.title, 'by recipients');
    });

    test('drops entries with an empty id', () {
      final merged = mergeStudentAchievements(
        [_a('', DateTime(2026, 10, 1))],
        [_a('a2', DateTime(2026, 10, 2))],
      );
      expect(merged.map((a) => a.id), ['a2']);
    });

    test('sorts newest first', () {
      final merged = mergeStudentAchievements(
        [_a('old', DateTime(2026, 1, 1)), _a('new', DateTime(2026, 9, 1))],
        [_a('mid', DateTime(2026, 5, 1))],
      );
      expect(merged.map((a) => a.id), ['new', 'mid', 'old']);
    });

    test('empty inputs give an empty list', () {
      expect(mergeStudentAchievements(const [], const []), isEmpty);
    });
  });

  group('achievement read model ownership', () {
    test('lives only in lib/shared', () {
      const moved = {
        'lib/features/student/domain/entities/achievement_entity.dart':
            'lib/shared/domain/achievement_entity.dart',
        'lib/features/student/data/models/achievement_model.dart':
            'lib/shared/data/models/achievement_model.dart',
        'lib/features/student/domain/merge_student_achievements.dart':
            'lib/shared/domain/merge_student_achievements.dart',
      };
      moved.forEach((oldPath, newPath) {
        expect(File(oldPath).existsSync(), isFalse, reason: oldPath);
        expect(File(newPath).existsSync(), isTrue, reason: newPath);
      });
    });

    test('read model holds no write or callable operations', () {
      final write = RegExp(
        r'\.(set|add|update|delete)\(|httpsCallable|grantAward|issueAchievement|runTransaction|batch\(',
      );
      for (final path in _readModel) {
        expect(
          write.hasMatch(File(path).readAsStringSync()),
          isFalse,
          reason: path,
        );
      }
    });

    test('lib/shared reaches awards only through its pure entities', () {
      final awardsImports = <String>{};
      final directive = RegExp(r"^import '([^']+)'", multiLine: true);
      for (final file in _dartFiles('lib/shared')) {
        for (final m in directive.allMatches(file.readAsStringSync())) {
          final uri = m.group(1)!;
          if (uri.contains('features/awards/')) {
            awardsImports.add(uri.substring(uri.indexOf('features/awards/')));
          }
        }
      }
      expect(awardsImports, {
        'features/awards/domain/entities/award_entities.dart',
      });
      final entities = File(
        'lib/features/awards/domain/entities/award_entities.dart',
      ).readAsStringSync();
      expect(directive.allMatches(entities).map((m) => m.group(1)), [
        'package:equatable/equatable.dart',
      ]);
    });
  });

  group('parent achievements keep the callable read path', () {
    test('parent data source reads through getParentAchievements only', () {
      final source = File(
        'lib/features/parent/data/data_source/parent_remote_datasource_impl.dart',
      ).readAsStringSync();
      expect(source, contains("httpsCallable('getParentAchievements')"));
      expect(source, isNot(contains('FirestoreCollections.achievements')));
      expect(source, isNot(contains("collection('achievements')")));
    });

    test('parent pages read achievements through GetChildAchievementsUseCase', () {
      for (final page in [
        'lib/features/parent/presentation/pages/parent_child_profile_page.dart',
        'lib/features/parent/presentation/pages/parent_achievements_page.dart',
      ]) {
        final source = File(page).readAsStringSync();
        expect(source, contains('GetChildAchievementsUseCase'), reason: page);
        expect(
          source,
          isNot(contains('GetAchievementsUseCase>')),
          reason: page,
        );
      }
    });

    test('no parent file resolves the student achievements use case', () {
      final offenders = [
        for (final file in _dartFiles('lib/features/parent'))
          if (file.readAsStringSync().contains('GetAchievementsUseCase'))
            file.path,
      ];
      expect(offenders, isEmpty);
    });
  });
}
