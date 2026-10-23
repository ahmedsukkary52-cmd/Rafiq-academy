import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/calendar/data/datasources/calendar_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/calendar/data/models/calendar_model.dart';
import 'package:rafiq_academy/features/calendar/domain/entities/calendar_event_entity.dart';
import 'package:rafiq_academy/features/calendar/domain/repositories/calendar_repository.dart';
import 'package:rafiq_academy/features/calendar/domain/usecases/calendar_usecases.dart';
import 'package:rafiq_academy/features/calendar/presentation/bloc/calendar_bloc.dart';
import 'package:rafiq_academy/features/calendar/presentation/bloc/calendar_event.dart';
import 'package:rafiq_academy/features/calendar/presentation/widgets/add_calendar_event_sheet.dart';

class _FakeCalendarRepository implements CalendarRepository {
  final List<CalendarEventEntity> added = [];
  Completer<Either<Failure, Unit>>? pending;

  @override
  Future<Either<Failure, Unit>> addEvent(CalendarEventEntity event) {
    added.add(event);
    final completer = Completer<Either<Failure, Unit>>();
    pending = completer;
    return completer.future;
  }

  @override
  Future<Either<Failure, List<CalendarEventEntity>>> getMonthEvents({
    required DateTime month,
    String? halaqaId,
  }) async => const Right([]);

  @override
  Future<Either<Failure, Unit>> deleteEvent(String eventId) async =>
      const Right(unit);
}

CalendarBloc _bloc(CalendarRepository repo) => CalendarBloc(
  getMonthEvents: GetMonthEventsUseCase(repo),
  addCalendarEvent: AddCalendarEventUseCase(repo),
  deleteCalendarEvent: DeleteCalendarEventUseCase(repo),
);

CalendarEventEntity _event(String title) => CalendarEventEntity(
  id: '',
  title: title,
  type: CalendarEventType.exam,
  date: DateTime(2026, 11, 3),
  halaqaId: 'h1',
  createdBy: '',
);

const _title = 'اختبار شهري';
const _description = 'وصف الحدث';

Future<void> _openSheet(WidgetTester tester, CalendarBloc bloc) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BlocProvider.value(
                value: bloc,
                child: const AddCalendarEventSheet(halaqaId: 'h1'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _settle(tester);
  await tester.enterText(find.byType(TextField).first, _title);
  await tester.enterText(find.byType(TextField).last, _description);
  // A focused field's blinking cursor keeps scheduling frames.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
}

final _submit = find.byKey(const Key('add-calendar-event-submit'));

/// Bounded: a spinner never settles, and pumpAndSettle would then spin for
/// ten fake minutes instead of failing on the next assertion.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Awaiting a real Bloc's close() inside testWidgets never completes under
/// the fake clock, so it is started and pumped but not awaited.
Future<void> _close(WidgetTester tester, Bloc<Object?, Object?> bloc) async {
  unawaited(bloc.close());
  await tester.pump();
}

void main() {
  group('creator identity', () {
    test('create data carries the signed-in uid, not the entity value', () {
      final model = CalendarEventModel(
        id: '',
        title: 't',
        type: CalendarEventType.session,
        date: DateTime(2026, 11, 3),
        createdBy: 'spoofed-or-empty',
      );
      final data = model.toCreateData(creatorUid: 'uid-123');
      expect(data['createdBy'], 'uid-123');
    });
  });

  group('error messages', () {
    test('Firestore codes map to user-facing Arabic text', () {
      for (final code in [
        'permission-denied',
        'unauthenticated',
        'unavailable',
        'deadline-exceeded',
        'internal',
      ]) {
        final message = calendarAddEventErrorMessage(code);
        expect(message, isNot(contains(code)));
        expect(message, isNot(contains('cloud_firestore')));
      }
      expect(
        calendarAddEventErrorMessage('unauthenticated'),
        kCalendarSignedOutMessage,
      );
      expect(
        calendarAddEventErrorMessage('something-new'),
        kCalendarAddEventFailedMessage,
      );
    });
  });

  group('CalendarBloc add', () {
    test('a second add while one is in flight is dropped', () async {
      final repo = _FakeCalendarRepository();
      final bloc = _bloc(repo);
      addTearDown(bloc.close);
      bloc
        ..add(AddEventEvent(_event('a')))
        ..add(AddEventEvent(_event('b')));
      await Future<void>.delayed(Duration.zero);
      expect(repo.added, hasLength(1));
      repo.pending!.complete(const Right(unit));
      await bloc.stream.firstWhere(
        (s) => s.addEventStatus == SubmissionStatus.success,
      );
    });
  });

  group('AddCalendarEventSheet', () {
    testWidgets('failure keeps the sheet open with inputs and a friendly '
        'error, and the retry is allowed', (tester) async {
      final repo = _FakeCalendarRepository();
      final bloc = _bloc(repo);
      await _openSheet(tester, bloc);

      await tester.tap(_submit);
      await tester.pump();
      repo.pending!.complete(
        const Left(ServerFailure(kCalendarAddEventFailedMessage)),
      );
      await _settle(tester);

      expect(find.byType(AddCalendarEventSheet), findsOneWidget);
      expect(find.text(_title), findsOneWidget);
      expect(find.text(_description), findsOneWidget);
      expect(find.byKey(const Key('add-calendar-event-error')), findsOneWidget);
      expect(find.text(kCalendarAddEventFailedMessage), findsOneWidget);

      await tester.tap(_submit);
      await tester.pump();
      expect(repo.added, hasLength(2));
      expect(repo.added.last.title, _title);
      expect(repo.added.last.description, _description);
      repo.pending!.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });

    testWidgets('success closes the sheet only after confirmation', (
      tester,
    ) async {
      final repo = _FakeCalendarRepository();
      final bloc = _bloc(repo);
      await _openSheet(tester, bloc);

      await tester.tap(_submit);
      await tester.pump();
      expect(find.byType(AddCalendarEventSheet), findsOneWidget);

      repo.pending!.complete(const Right(unit));
      await _settle(tester);
      expect(find.byType(AddCalendarEventSheet), findsNothing);
      expect(repo.added.single.halaqaId, 'h1');
      await _close(tester, bloc);
    });

    testWidgets('repeated taps while submitting send one create', (
      tester,
    ) async {
      final repo = _FakeCalendarRepository();
      final bloc = _bloc(repo);
      await _openSheet(tester, bloc);

      await tester.tap(_submit);
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pump();
      await tester.tap(_submit, warnIfMissed: false);
      await tester.pump();
      expect(repo.added, hasLength(1));

      repo.pending!.complete(const Right(unit));
      await _settle(tester);
      await _close(tester, bloc);
    });
  });
}
