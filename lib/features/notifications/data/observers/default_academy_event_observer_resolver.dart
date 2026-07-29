import 'package:injectable/injectable.dart';

import '../../../../core/error/exception.dart';
import '../../../../shared/domain/academy_event.dart';
import '../../../../shared/domain/academy_event_observation.dart';
import '../../../../shared/domain/academy_event_observer_resolver.dart';
import '../../../parent/domain/repositories/parent_repositories.dart';

/// Expands [AcademyEventObservation] specs using parent relationship data.
///
/// New observer kinds (supervisor, audit, …) extend the observation policy and
/// this resolver — emitters stay unchanged.
@LazySingleton(as: AcademyEventObserverResolver)
class DefaultAcademyEventObserverResolver
    implements AcademyEventObserverResolver {
  final ParentRepository parentRepository;

  const DefaultAcademyEventObserverResolver({required this.parentRepository});

  @override
  Future<Map<String, List<String>>> resolve(
    Iterable<AcademyEvent> events,
  ) async {
    final pending = events.toList();
    if (pending.isEmpty) return const {};

    final parentLookupStudentIds = <String>{};
    for (final event in pending) {
      for (final spec in AcademyEventObservation.specsFor(event)) {
        if (spec is LinkedParentsObserver) {
          parentLookupStudentIds.add(spec.studentId);
        }
      }
    }

    Map<String, List<String>> parentsByStudent = const {};
    if (parentLookupStudentIds.isNotEmpty) {
      final result = await parentRepository.getParentIdsByStudentIds(
        parentLookupStudentIds.toList(),
      );
      parentsByStudent = result.fold(
        (failure) => throw ServerException(failure.message),
        (map) => map,
      );
    }

    final observersByEventId = <String, List<String>>{};
    for (final event in pending) {
      final ids = <String>{};
      for (final spec in AcademyEventObservation.specsFor(event)) {
        switch (spec) {
          case SubjectStudentObserver(:final studentId):
            if (studentId.trim().isNotEmpty) ids.add(studentId);
          case LinkedParentsObserver(:final studentId):
            ids.addAll(parentsByStudent[studentId] ?? const []);
        }
      }
      observersByEventId[event.eventId] = ids.toList();
    }

    return observersByEventId;
  }
}
