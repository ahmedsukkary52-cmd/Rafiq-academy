import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/domain/academy_event_publication.dart';
import 'package:rafiq_academy/shared/domain/academy_event_sink.dart';

void main() {
  group('AcademyEventPublication observability', () {
    test(
      'exposes published flag and handler outcomes without channel types',
      () {
        const publication = AcademyEventPublication(
          eventCount: 2,
          eventsPublished: true,
          handlerReports: [
            AcademyEventHandlerReport(handlerName: 'in_app', succeeded: true),
            AcademyEventHandlerReport(
              handlerName: 'analytics',
              succeeded: false,
              error: 'down',
            ),
          ],
        );

        expect(publication.eventsPublished, isTrue);
        expect(publication.hasUnpublishedEvents, isFalse);
        expect(publication.succeededHandlerNames, ['in_app']);
        expect(publication.failedHandlerNames, ['analytics']);
      },
    );

    test('all-failed publish is measurable as unpublished', () {
      const publication = AcademyEventPublication(
        eventCount: 1,
        eventsPublished: false,
        handlerReports: [
          AcademyEventHandlerReport(handlerName: 'in_app', succeeded: false),
        ],
      );

      expect(publication.hasUnpublishedEvents, isTrue);
      expect(publication.succeededHandlerNames, isEmpty);
      expect(publication.failedHandlerNames, ['in_app']);
    });
  });
}
