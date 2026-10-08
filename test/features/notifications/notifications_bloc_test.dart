import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/notifications/domain/entities/notification_entity.dart';
import 'package:rafiq_academy/features/notifications/domain/usecases/notification_usecase.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_bloc.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_event.dart';
import 'package:rafiq_academy/features/notifications/presentation/bloc/notifications_state.dart';

typedef _Feed = Either<Failure, List<NotificationEntity>>;

NotificationEntity _n(String id, {bool read = false}) => NotificationEntity(
  id: id,
  title: 't',
  body: 'b',
  type: 'attendance',
  hasAudioAlert: false,
  createdAt: DateTime(2026, 9, 1),
  isRead: read,
);

class _Watch extends Fake implements WatchNotificationsUseCase {
  final params = <WatchNotificationsParams>[];
  final streams = <StreamController<_Feed>>[];

  StreamController<_Feed> get latest => streams.last;

  @override
  Stream<_Feed> call(WatchNotificationsParams p) {
    params.add(p);
    final c = StreamController<_Feed>();
    streams.add(c);
    return c.stream;
  }
}

class _MarkOne extends Fake implements MarkNotificationAsReadUseCase {
  final params = <MarkNotificationReadParams>[];
  @override
  Future<Either<Failure, Unit>> call(MarkNotificationReadParams p) async {
    params.add(p);
    return const Right(unit);
  }
}

class _MarkAll extends Fake implements MarkAllNotificationsAsReadUseCase {
  final params = <MarkAllNotificationsReadParams>[];
  @override
  Future<Either<Failure, Unit>> call(MarkAllNotificationsReadParams p) async {
    params.add(p);
    return const Right(unit);
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _Watch watch;
  late _MarkOne markOne;
  late _MarkAll markAll;
  late NotificationsBloc bloc;

  setUp(() {
    watch = _Watch();
    markOne = _MarkOne();
    markAll = _MarkAll();
    bloc = NotificationsBloc(
      watchNotifications: watch,
      markNotificationAsRead: markOne,
      markAllNotificationsAsRead: markAll,
    );
  });

  tearDown(() => bloc.close());

  test('initial state is idle', () {
    expect(bloc.state, NotificationsState.initial());
    expect(bloc.state.status, SectionStatus.initial);
  });

  test('watch passes uid + role; loading, loaded, empty, error', () async {
    bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
    await _settle();
    expect(watch.params.single, const WatchNotificationsParams(uid: 'u1', role: 'parent'));
    expect(bloc.state.status, SectionStatus.loading);

    watch.latest.add(Right([_n('n1')]));
    await _settle();
    expect(bloc.state.status, SectionStatus.loaded);
    expect(bloc.state.notifications.single.id, 'n1');

    watch.latest.add(const Right([]));
    await _settle();
    expect(bloc.state.status, SectionStatus.loaded);
    expect(bloc.state.notifications, isEmpty);

    watch.latest.add(const Left(ServerFailure('تعذر')));
    await _settle();
    expect(bloc.state.status, SectionStatus.error);
    expect(bloc.state.error, 'تعذر');
  });

  test('re-watching (retry) replaces the old subscription', () async {
    bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
    await _settle();
    final first = watch.latest;
    bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
    await _settle();

    expect(first.hasListener, isFalse);
    expect(watch.latest.hasListener, isTrue);
  });

  test('account switch does not inherit the previous list', () async {
    bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
    await _settle();
    watch.latest.add(Right([_n('n1')]));
    await _settle();

    bloc.add(const StartWatchingNotificationsEvent(uid: 'u2', role: 'teacher'));
    await _settle();

    expect(bloc.state.status, SectionStatus.loading);
    expect(bloc.state.notifications, isEmpty);
  });

  test('stop clears state and ignores late snapshots', () async {
    bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
    await _settle();
    final stream = watch.latest;

    bloc.add(const StopWatchingNotificationsEvent());
    await _settle();
    stream.add(Right([_n('n1')]));
    await _settle();

    expect(bloc.state, NotificationsState.initial());
  });

  group('mark as read', () {
    test('single mark uses the watched uid', () async {
      bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
      await _settle();
      bloc.add(const MarkNotificationAsReadEvent('n1'));
      await _settle();

      expect(
        markOne.params.single,
        const MarkNotificationReadParams(notificationId: 'n1', uid: 'u1'),
      );
    });

    test('mark all sends only unread ids', () async {
      bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
      await _settle();
      watch.latest.add(Right([_n('n1'), _n('n2', read: true), _n('n3')]));
      await _settle();

      bloc.add(const MarkAllNotificationsAsReadEvent());
      await _settle();

      expect(markAll.params.single.notificationIds, ['n1', 'n3']);
      expect(markAll.params.single.uid, 'u1');
    });

    test('mark all with nothing unread does not call the server', () async {
      bloc.add(const StartWatchingNotificationsEvent(uid: 'u1', role: 'parent'));
      await _settle();
      watch.latest.add(Right([_n('n1', read: true)]));
      await _settle();

      bloc.add(const MarkAllNotificationsAsReadEvent());
      await _settle();
      expect(markAll.params, isEmpty);
    });

    test('marks are ignored when signed out', () async {
      bloc
        ..add(const MarkNotificationAsReadEvent('n1'))
        ..add(const MarkAllNotificationsAsReadEvent());
      await _settle();

      expect(markOne.params, isEmpty);
      expect(markAll.params, isEmpty);
    });
  });
}
