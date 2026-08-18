import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/student/data/models/student_profile_model.dart';
import 'package:rafiq_academy/features/student/domain/entities/recitation_record_entity.dart';
import 'package:rafiq_academy/features/student/domain/student_profile_content.dart';
import 'package:rafiq_academy/features/student/domain/student_profile_latest_evaluation.dart';

RecitationRecordEntity _record({
  required String id,
  required RecitationType type,
  required DateTime date,
  RecitationGrade? grade,
  RecitationGrade? behaviorGrade,
  String reviewStatus = 'reviewed',
  String? notes,
}) {
  return RecitationRecordEntity(
    id: id,
    studentId: 's1',
    studentName: 'أحمد',
    teacherId: 't1',
    halaqaId: 'h1',
    date: date,
    type: type,
    versesRange: '1-5',
    grade: grade,
    behaviorGrade: behaviorGrade,
    notes: notes,
    reviewStatus: reviewStatus,
  );
}

void main() {
  group('StudentProfileModel.fromMaps', () {
    test('maps phone from users.phone when present', () {
      final model = StudentProfileModel.fromMaps(
        uid: 's1',
        user: {
          'name': 'أحمد',
          'phone': '0501234567',
          'createdAt': DateTime(2026, 1, 10),
        },
        profile: {
          'currentPlanName': 'الخطة أ',
          'overallProgressPercent': 40,
          'totalStars': 0,
          'badges': const <String>[],
          'level': 3,
          'streakDays': 12,
          'totalVersesMemorized': 80,
        },
      );
      expect(model.phone, '0501234567');
      expect(model.streakDays, 12);
      expect(model.totalVersesMemorized, 80);
      expect(model.level, 3);
    });

    test('treats blank users.phone as unavailable', () {
      final model = StudentProfileModel.fromMaps(
        uid: 's1',
        user: {'name': 'أحمد', 'phone': '  '},
        profile: {
          'currentPlanName': '',
          'overallProgressPercent': 0,
          'totalStars': 0,
          'badges': const <String>[],
        },
      );
      expect(model.phone, isNull);
    });

    test('prefers profile createdAt then users.createdAt', () {
      final fromProfile = StudentProfileModel.fromMaps(
        uid: 's1',
        user: {'name': 'أحمد', 'createdAt': DateTime(2025, 1, 1)},
        profile: {
          'currentPlanName': '',
          'overallProgressPercent': 0,
          'totalStars': 0,
          'badges': const <String>[],
          'createdAt': DateTime(2026, 8, 14),
        },
      );
      expect(fromProfile.createdAt, DateTime(2026, 8, 14));

      final fromUser = StudentProfileModel.fromMaps(
        uid: 's1',
        user: {'name': 'أحمد', 'createdAt': DateTime(2025, 6, 2)},
        profile: {
          'currentPlanName': '',
          'overallProgressPercent': 0,
          'totalStars': 0,
          'badges': const <String>[],
        },
      );
      expect(fromUser.createdAt, DateTime(2025, 6, 2));
    });
  });

  group('formatStudentProfileJoinDate', () {
    test('formats createdAt with Arabic month names', () {
      expect(
        formatStudentProfileJoinDate(DateTime(2026, 8, 14)),
        '14 أغسطس 2026',
      );
    });

    test('returns null when createdAt is missing', () {
      expect(formatStudentProfileJoinDate(null), isNull);
    });
  });

  group('studentProfileEvaluationsPath', () {
    test('uses the profile grant/class halaqa and studentId', () {
      expect(
        studentProfileEvaluationsPath(halaqaId: 'h-class', studentId: 's1'),
        '/teacher/halaqa/h-class/evaluations?studentId=s1',
      );
    });

    test('returns null when halaqa is missing so no history page is invented', () {
      expect(
        studentProfileEvaluationsPath(halaqaId: null, studentId: 's1'),
        isNull,
      );
      expect(
        studentProfileEvaluationsPath(halaqaId: '  ', studentId: 's1'),
        isNull,
      );
    });
  });

  group('pickLatestStudentProfileEvaluation', () {
    test('skips pending reviews', () {
      final picked = pickLatestStudentProfileEvaluation([
        _record(
          id: 'pending',
          type: RecitationType.memorization,
          date: DateTime(2026, 8, 14),
          grade: RecitationGrade.excellent,
          behaviorGrade: RecitationGrade.excellent,
          reviewStatus: 'pending',
        ),
        _record(
          id: 'reviewed',
          type: RecitationType.memorization,
          date: DateTime(2026, 8, 10),
          grade: RecitationGrade.good,
          behaviorGrade: RecitationGrade.veryGood,
        ),
      ]);
      expect(picked, isNotNull);
      expect(picked!.latestRecord.id, 'reviewed');
      expect(picked.memorizationGrade, RecitationGrade.good);
      expect(picked.behaviorGrade, RecitationGrade.veryGood);
    });

    test('composes حفظ / مراجعة / سلوك from existing records without inventing', () {
      final picked = pickLatestStudentProfileEvaluation([
        _record(
          id: 'mem',
          type: RecitationType.memorization,
          date: DateTime(2026, 8, 12),
          grade: RecitationGrade.excellent,
          behaviorGrade: RecitationGrade.good,
          notes: 'أداء قوي',
        ),
        _record(
          id: 'rev',
          type: RecitationType.review,
          date: DateTime(2026, 8, 8),
          grade: RecitationGrade.veryGood,
        ),
      ]);
      expect(picked!.memorizationGrade, RecitationGrade.excellent);
      expect(picked.reviewGrade, RecitationGrade.veryGood);
      expect(picked.behaviorGrade, RecitationGrade.good);
      expect(picked.notes, 'أداء قوي');
      expect(picked.date, DateTime(2026, 8, 12));
    });

    test('leaves an axis unavailable when no matching reviewed grade exists', () {
      final picked = pickLatestStudentProfileEvaluation([
        _record(
          id: 'mem-only',
          type: RecitationType.memorization,
          date: DateTime(2026, 8, 1),
          grade: RecitationGrade.good,
        ),
      ]);
      expect(picked!.memorizationGrade, RecitationGrade.good);
      expect(picked.reviewGrade, isNull);
      expect(picked.behaviorGrade, isNull);
    });

    test('returns null when there are no reviewed records', () {
      expect(
        pickLatestStudentProfileEvaluation([
          _record(
            id: 'pending',
            type: RecitationType.review,
            date: DateTime(2026, 8, 14),
            grade: RecitationGrade.excellent,
            reviewStatus: 'pending',
          ),
        ]),
        isNull,
      );
      expect(pickLatestStudentProfileEvaluation(const []), isNull);
    });
  });
}
