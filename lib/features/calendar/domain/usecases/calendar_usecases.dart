import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/usecases/usecases.dart';
import '../entities/calendar_event_entity.dart';
import '../repositories/calendar_repository.dart';

@lazySingleton
class GetMonthEventsUseCase
    extends UseCase<List<CalendarEventEntity>, GetMonthEventsParams> {
  final CalendarRepository repository;

  GetMonthEventsUseCase(this.repository);

  @override
  Future<Either<Failure, List<CalendarEventEntity>>> call(
    GetMonthEventsParams params,
  ) =>
      repository.getMonthEvents(month: params.month, halaqaId: params.halaqaId);
}

@lazySingleton
class AddCalendarEventUseCase extends UseCase<Unit, CalendarEventEntity> {
  final CalendarRepository repository;

  AddCalendarEventUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(CalendarEventEntity params) =>
      repository.addEvent(params);
}

@lazySingleton
class DeleteCalendarEventUseCase extends UseCase<Unit, DeleteEventParams> {
  final CalendarRepository repository;

  DeleteCalendarEventUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(DeleteEventParams params) =>
      repository.deleteEvent(params.eventId);
}

// ── Params ────────────────────────────────────────────────────────────────────

class GetMonthEventsParams extends Equatable {
  final DateTime month;
  final String? halaqaId;

  const GetMonthEventsParams({required this.month, this.halaqaId});

  @override
  List<Object?> get props => [month, halaqaId];
}

class DeleteEventParams extends Equatable {
  final String eventId;

  const DeleteEventParams(this.eventId);

  @override
  List<Object?> get props => [eventId];
}
