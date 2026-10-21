import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/schedule/domain/entities/class_session_entity.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/services/halaqa_meeting_joiner.dart';
import 'package:rafiq_academy/features/student/presentation/widgets/halaqa_meeting_join.dart';
import 'package:rafiq_academy/shared/widgets/student_session_card_widget.dart';

class _Harness {
  String link;
  Failure? loadFailure;
  bool openResult = true;
  Object? openError;
  Completer<void>? openGate;
  final loads = <String>[];
  final opened = <Uri>[];

  _Harness(this.link);

  late final joiner = HalaqaMeetingJoiner(
    loadLink: (id) async {
      loads.add(id);
      if (loadFailure != null) return Left(loadFailure!);
      return Right(link);
    },
    open: (uri) async {
      opened.add(uri);
      if (openGate != null) await openGate!.future;
      if (openError != null) throw openError!;
      return openResult;
    },
  );
}

HalaqaEntity _halaqa(String link) => HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: const ['s1'],
  schedule: const [
    HalaqaScheduleEntity(day: 'السبت', startTime: '17:00', endTime: '18:00'),
  ],
  meetingLink: link,
  status: 'active',
);

Future<void> _pumpHomeCard(
  WidgetTester tester, {
  required HalaqaEntity halaqa,
  required HalaqaMeetingJoiner joiner,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            child: StudentSessionCardWidget(
              halaqa: halaqa,
              onJoinTap: () =>
                  joinHalaqaMeeting(context, halaqa.id, joiner: joiner),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('B14 HalaqaMeetingJoiner', () {
    test('opens the freshly loaded, valid link', () async {
      final h = _Harness('https://meet.example.com/room');
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.opened);
      expect(h.loads, ['h1']);
      expect(h.opened.single.toString(), 'https://meet.example.com/room');

      h.link = 'https://meet.example.com/updated';
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.opened);
      expect(h.opened.last.toString(), 'https://meet.example.com/updated');
    });

    test('missing link reports "not configured" and opens nothing', () async {
      final h = _Harness('  ');
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.missing);
      expect(await h.joiner.join(''), MeetingJoinOutcome.missing);
      expect(h.opened, isEmpty);
      expect(
        kMeetingJoinMessages[MeetingJoinOutcome.missing],
        contains('لم يُضبط رابط الاجتماع'),
      );
      expect(
        kMeetingJoinMessages.values.join(),
        isNot(contains('لسه ما بدأتش')),
      );
    });

    test('an invalid stored link is never opened', () async {
      for (final bad in [
        'http://meet.example.com/x',
        'meet.example.com',
        'https://u:p@meet.example.com',
        'javascript:alert(1)',
      ]) {
        final h = _Harness(bad);
        expect(await h.joiner.join('h1'), MeetingJoinOutcome.invalid);
        expect(h.opened, isEmpty, reason: bad);
      }
    });

    test('launch false or a thrown launch error is a launch failure', () async {
      final h = _Harness('https://meet.example.com/room')..openResult = false;
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.launchFailed);
      h
        ..openResult = true
        ..openError = StateError('no handler');
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.launchFailed);
      expect(h.joiner.isBusy, isFalse);
    });

    test(
      'load failure (network/permission) never opens a stale link',
      () async {
        final h = _Harness('https://meet.example.com/room')
          ..loadFailure = const ServerFailure('denied');
        expect(await h.joiner.join('h1'), MeetingJoinOutcome.loadFailed);
        expect(h.opened, isEmpty);
      },
    );

    test('duplicate taps while a join is in flight are ignored', () async {
      final h = _Harness('https://meet.example.com/room')
        ..openGate = Completer<void>();
      final first = h.joiner.join('h1');
      await Future<void>.delayed(Duration.zero);
      expect(h.joiner.isBusy, isTrue);
      expect(await h.joiner.join('h1'), isNull);
      expect(await h.joiner.join('h1'), isNull);
      h.openGate!.complete();
      expect(await first, MeetingJoinOutcome.opened);
      expect(h.opened, hasLength(1));
      expect(h.joiner.isBusy, isFalse);
    });

    test('canJoin uses the same rule with no time window', () {
      ClassSessionEntity session(String link, ClassSessionStatus status) =>
          ClassSessionEntity(
            id: 's',
            title: 't',
            type: ClassSessionType.memorization,
            startAt: DateTime(2026, 1, 1, 17),
            endAt: DateTime(2026, 1, 1, 18),
            teacherName: 'n',
            meetingLink: link,
            status: status,
          );
      for (final status in ClassSessionStatus.values) {
        expect(session('https://meet.example.com/r', status).canJoin, isTrue);
        expect(session('http://meet.example.com/r', status).canJoin, isFalse);
        expect(session('', status).canJoin, isFalse);
      }
    });
  });

  group('B14 student Join entry points', () {
    testWidgets('home card: missing link shows the not-configured message', (
      tester,
    ) async {
      final h = _Harness('');
      await _pumpHomeCard(tester, halaqa: _halaqa(''), joiner: h.joiner);
      expect(find.byKey(const Key('sessionCardLinkStatus')), findsOneWidget);
      await tester.tap(find.text('انضم للحصة'));
      await tester.pumpAndSettle();
      expect(
        find.text(kMeetingJoinMessages[MeetingJoinOutcome.missing]!),
        findsOneWidget,
      );
      expect(h.opened, isEmpty);
    });

    testWidgets('home card: valid link opens with no snackbar', (tester) async {
      final h = _Harness('https://meet.example.com/room');
      await _pumpHomeCard(
        tester,
        halaqa: _halaqa('https://meet.example.com/room'),
        joiner: h.joiner,
      );
      expect(find.byKey(const Key('sessionCardLinkStatus')), findsNothing);
      await tester.tap(find.text('انضم للحصة'));
      await tester.pumpAndSettle();
      expect(h.opened, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('home card: invalid, launch and load failures show errors', (
      tester,
    ) async {
      final h = _Harness('http://meet.example.com/x');
      await _pumpHomeCard(
        tester,
        halaqa: _halaqa('http://meet.example.com/x'),
        joiner: h.joiner,
      );
      expect(find.text('رابط الاجتماع المحفوظ غير صالح'), findsOneWidget);

      Future<void> tapAndExpect(MeetingJoinOutcome outcome) async {
        ScaffoldMessenger.of(
          tester.element(find.byType(Scaffold)),
        ).clearSnackBars();
        await tester.pumpAndSettle();
        await tester.tap(find.text('انضم للحصة'));
        await tester.pumpAndSettle();
        expect(find.text(kMeetingJoinMessages[outcome]!), findsOneWidget);
      }

      await tapAndExpect(MeetingJoinOutcome.invalid);
      h
        ..link = 'https://meet.example.com/room'
        ..openResult = false;
      await tapAndExpect(MeetingJoinOutcome.launchFailed);
      h.loadFailure = const ServerFailure('offline');
      await tapAndExpect(MeetingJoinOutcome.loadFailed);
    });

    test('home and schedule share joinHalaqaMeeting, without canLaunchUrl', () {
      final home = File(
        'lib/features/student/presentation/pages/student_home_page.dart',
      ).readAsStringSync();
      final schedule = File(
        'lib/features/schedule/presentation/pages/student_schedule_page.dart',
      ).readAsStringSync();
      final opener = File(
        'lib/features/student/presentation/widgets/halaqa_meeting_join.dart',
      ).readAsStringSync();
      for (final source in [home, schedule]) {
        expect(source, contains('joinHalaqaMeeting(context'));
        expect(source, isNot(contains('url_launcher')));
        expect(source, isNot(contains('canLaunchUrl')));
        expect(source, isNot(contains('لسه ما بدأتش')));
      }
      expect(opener, isNot(contains('canLaunchUrl(')));
      expect(opener, contains('LaunchMode.externalApplication'));
    });
  });
}
