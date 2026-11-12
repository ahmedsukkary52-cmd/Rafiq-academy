import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/constants/app_constants.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/entities/halaqa_activity_entity.dart';
import 'package:rafiq_academy/features/halaqa_activity/domain/usecases/halaqa_activity_usecases.dart';
import 'package:rafiq_academy/features/homework/presentation/pages/student_activities_page.dart';

class _GetActivity extends Fake implements GetHalaqaActivityUseCase {
  final HalaqaActivityEntity activity;

  _GetActivity(this.activity);

  @override
  Future<Either<Failure, HalaqaActivityEntity>> call(
    GetHalaqaActivityParams params,
  ) async => Right(activity);
}

String _src(String path) => File(path).readAsStringSync();

const _mushafPage =
    'lib/features/student/presentation/pages/student_mushaf_page.dart';
const _recitationPage =
    'lib/features/student/presentation/pages/student_recitation_page.dart';
const _activitiesPage =
    'lib/features/homework/presentation/pages/student_activities_page.dart';

void main() {
  test('audio uploads stay disabled', () {
    expect(AppCapabilities.audioUploadsEnabled, isFalse);
  });

  group('removed student audio-send entries', () {
    tearDown(() async => sl.reset());

    testWidgets('a legacy audio-allowing activity shows no mic or audio label',
        (tester) async {
      await sl.reset();
      sl.registerFactory<GetHalaqaActivityUseCase>(
        () => _GetActivity(
          HalaqaActivityEntity(
            id: 'a1',
            halaqaId: 'h1',
            teacherId: 't1',
            teacherName: 'المعلم',
            prompt: 'اقرأ الآيات',
            createdAt: DateTime(2026),
            allowedResponseTypes: const {
              HalaqaActivityResponseType.text,
              HalaqaActivityResponseType.image,
              HalaqaActivityResponseType.audio,
            },
          ),
        ),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: StudentActivityDetailPage(halaqaId: 'h1', activityId: 'a1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اقرأ الآيات'), findsOneWidget);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
      expect(find.text('صوت'), findsNothing);
      expect(find.byTooltip('صورة'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    test('activities page has no audio picker', () {
      final src = _src(_activitiesPage);
      for (final gone in [
        '_pickAudio',
        'audioFile',
        'غير مفعّل',
        'Icons.mic_none_rounded',
      ]) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
    });

    test('Mushaf recording panel has no send button', () {
      final src = _src(_mushafPage);
      for (final gone in [
        '_submitRecitation',
        'إرسال عبر الواجبات',
        'رفع التسجيل',
        'studentHomework',
      ]) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
      expect(src.contains('إعادة التسجيل'), isTrue);
      expect(src.contains('StudentRecitationPage('), isTrue);
    });

    test('recitation page keeps local recording only', () {
      final src = _src(_recitationPage);
      for (final gone in [
        'HomeworkRecitationContext',
        'SubmitHomeworkRecitationUseCase',
        '_submitRecitation',
        '_performSubmit',
        'حفظ التسجيل محلياً',
        'سيتوفر',
        'المطلوب تسميعه',
      ]) {
        expect(src.contains(gone), isFalse, reason: gone);
      }
      expect(src.contains('_saveRecording('), isTrue);
      expect(src.contains('تسجيلاتي السابقة'), isTrue);
    });
  });

  group('chat voice path is untouched', () {
    test('composer still records through ChatVoiceRecorder', () {
      final recorder = _src(
        'lib/features/chat/presentation/media/chat_voice_recorder.dart',
      );
      expect(recorder.contains('class RecordChatVoiceRecorder'), isTrue);
      expect(recorder.contains("import 'package:record/record.dart';"), isTrue);
      expect(
        _src('lib/features/chat/presentation/widgets/chat_composer.dart')
            .contains("import '../media/chat_voice_recorder.dart';"),
        isTrue,
      );
    });

    test('chat playback still uses just_audio', () {
      final views = _src(
        'lib/features/chat/presentation/widgets/chat_media_views.dart',
      );
      expect(views.contains("import 'package:just_audio/just_audio.dart';"),
          isTrue);
      expect(views.contains('class ChatVoiceView'), isTrue);
    });

    test('audio packages remain declared', () {
      final pubspec = _src('pubspec.yaml');
      for (final pkg in ['record:', 'just_audio:', 'path_provider:']) {
        expect(pubspec.contains(pkg), isTrue, reason: pkg);
      }
    });
  });
}
