import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/di/injection_container.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/features/student/domain/entities/halaqa_entity.dart';
import 'package:rafiq_academy/features/student/domain/services/halaqa_meeting_joiner.dart';
import 'package:rafiq_academy/features/student/presentation/widgets/halaqa_meeting_join.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';
import 'package:rafiq_academy/shared/widgets/student_session_card_widget.dart';

import '../../support/fake_halaqa_meeting_link_repository.dart';

/// Joiner over an in-memory canonical document: a null [link] is a missing
/// `halaqaMeetingLinks/{id}` document.
class _Harness {
  String? link;
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
      final value = link;
      return Right(
        value == null ? null : HalaqaMeetingLink(halaqaId: id, meetingLink: value),
      );
    },
    open: (uri) async {
      opened.add(uri);
      if (openGate != null) await openGate!.future;
      if (openError != null) throw openError!;
      return openResult;
    },
  );
}

const _halaqa = HalaqaEntity(
  id: 'h1',
  name: 'حلقة الفجر',
  teacherId: 't1',
  supervisorId: 'sup1',
  studentIds: ['s1'],
  schedule: [
    HalaqaScheduleEntity(day: 'السبت', startTime: '17:00', endTime: '18:00'),
  ],
  status: 'active',
);

Future<void> _pumpHomeCard(
  WidgetTester tester, {
  required FakeHalaqaMeetingLinkRepository links,
  required HalaqaMeetingJoiner joiner,
}) async {
  registerFakeMeetingLinks(links);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => SingleChildScrollView(
            child: StudentSessionCardWidget(
              halaqa: _halaqa,
              onJoinTap: () =>
                  joinHalaqaMeeting(context, _halaqa.id, joiner: joiner),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => sl.reset());

  group('B14 HalaqaMeetingJoiner (canonical halaqaMeetingLinks)', () {
    test('opens the freshly loaded, valid link', () async {
      final h = _Harness('https://meet.example.com/room');
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.opened);
      expect(h.loads, ['h1']);
      expect(h.opened.single.toString(), 'https://meet.example.com/room');

      h.link = 'https://meet.example.com/updated';
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.opened);
      expect(h.opened.last.toString(), 'https://meet.example.com/updated');
    });

    test('a missing document reports "not configured" and opens nothing',
        () async {
      final h = _Harness(null);
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

    test('an existing document with an empty or invalid link is never opened',
        () async {
      for (final bad in [
        '',
        '  ',
        'http://meet.example.com/x',
        'meet.example.com',
        'https://u:p@meet.example.com',
        'javascript:alert(1)',
      ]) {
        final h = _Harness(bad);
        expect(await h.joiner.join('h1'), MeetingJoinOutcome.invalid);
        expect(h.opened, isEmpty, reason: bad);
      }
      for (final message in kMeetingJoinMessages.values) {
        expect(message, isNot(contains('http')));
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

    test('permission denied is its own outcome and opens nothing', () async {
      final h = _Harness('https://meet.example.com/room')
        ..loadFailure = const MeetingLinkAccessDeniedFailure();
      expect(await h.joiner.join('h1'), MeetingJoinOutcome.accessDenied);
      expect(h.opened, isEmpty);
      expect(
        kMeetingJoinMessages[MeetingJoinOutcome.accessDenied],
        isNot(kMeetingJoinMessages[MeetingJoinOutcome.loadFailed]),
      );
    });

    test('connection/load failure never opens a stale or legacy link',
        () async {
      for (final failure in const <Failure>[
        NetworkFailure(),
        ServerFailure('offline'),
      ]) {
        final h = _Harness('https://meet.example.com/room')
          ..loadFailure = failure;
        expect(await h.joiner.join('h1'), MeetingJoinOutcome.loadFailed);
        expect(h.opened, isEmpty);
      }
    });

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
  });

  group('B14 student Join entry points', () {
    testWidgets('home card: missing document shows not-configured, no join', (
      tester,
    ) async {
      final h = _Harness(null);
      final links = FakeHalaqaMeetingLinkRepository();
      await _pumpHomeCard(tester, links: links, joiner: h.joiner);
      expect(links.reads, ['h1']);
      expect(
        find.text('لم يُضبط رابط الاجتماع لهذه الحلقة بعد'),
        findsOneWidget,
      );
      await tester.tap(find.text('انضم للحصة'));
      await tester.pumpAndSettle();
      expect(
        find.text(kMeetingJoinMessages[MeetingJoinOutcome.missing]!),
        findsOneWidget,
      );
      expect(h.opened, isEmpty);
    });

    testWidgets('home card: valid link opens with no snackbar', (tester) async {
      const link = 'https://meet.example.com/room';
      final h = _Harness(link);
      await _pumpHomeCard(
        tester,
        links: FakeHalaqaMeetingLinkRepository({'h1': link}),
        joiner: h.joiner,
      );
      expect(find.byKey(const Key('sessionCardLinkStatus')), findsNothing);
      expect(find.text(link), findsNothing);
      await tester.tap(find.text('انضم للحصة'));
      await tester.pumpAndSettle();
      expect(h.opened, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('home card: invalid, launch and load failures show errors', (
      tester,
    ) async {
      const bad = 'http://meet.example.com/x';
      final h = _Harness(bad);
      await _pumpHomeCard(
        tester,
        links: FakeHalaqaMeetingLinkRepository({'h1': bad}),
        joiner: h.joiner,
      );
      expect(find.text('رابط الاجتماع المحفوظ غير صالح'), findsOneWidget);
      expect(find.text(bad), findsNothing);

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
      h.loadFailure = const MeetingLinkAccessDeniedFailure();
      await tapAndExpect(MeetingJoinOutcome.accessDenied);
      expect(h.opened, hasLength(1));
    });

    testWidgets('home card: permission denied has its own hint', (
      tester,
    ) async {
      final h = _Harness(null)
        ..loadFailure = const MeetingLinkAccessDeniedFailure();
      final links = FakeHalaqaMeetingLinkRepository()
        ..failure = const MeetingLinkAccessDeniedFailure();
      await _pumpHomeCard(tester, links: links, joiner: h.joiner);
      expect(find.text('لا تملك صلاحية الوصول إلى رابط الاجتماع'), findsOneWidget);
      expect(find.byKey(const Key('sessionCardLinkRetry')), findsNothing);
      await tester.tap(find.text('انضم للحصة'));
      await tester.pumpAndSettle();
      expect(
        find.text(kMeetingJoinMessages[MeetingJoinOutcome.accessDenied]!),
        findsOneWidget,
      );
      expect(h.opened, isEmpty);
    });

    testWidgets('home card: load failure offers retry, which re-reads', (
      tester,
    ) async {
      final links = FakeHalaqaMeetingLinkRepository()
        ..failure = const NetworkFailure();
      await _pumpHomeCard(tester, links: links, joiner: _Harness(null).joiner);
      expect(find.text('تعذر التحقق من رابط الاجتماع الآن'), findsOneWidget);

      links
        ..failure = null
        ..links['h1'] = 'https://meet.example.com/room';
      await tester.tap(find.byKey(const Key('sessionCardLinkRetry')));
      await tester.pumpAndSettle();
      expect(links.reads, ['h1', 'h1']);
      expect(find.byKey(const Key('sessionCardLinkStatus')), findsNothing);
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
      expect(opener, contains('sl<GetHalaqaMeetingLinkUseCase>()'));
    });
  });
}
