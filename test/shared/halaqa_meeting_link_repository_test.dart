import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rafiq_academy/core/error/failure.dart';
import 'package:rafiq_academy/shared/data/halaqa_meeting_link_firestore.dart';
import 'package:rafiq_academy/shared/domain/halaqa_meeting_link.dart';

import '../support/fake_halaqa_meeting_link_repository.dart';

// ignore: subtype_of_sealed_class
class _Snapshot extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic>? _data;
  _Snapshot(this._data);

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;
}

// ignore: subtype_of_sealed_class
class _DocRef extends Fake implements DocumentReference<Map<String, dynamic>> {
  final _Firestore store;
  @override
  final String path;
  _DocRef(this.store, this.path);

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    store.reads.add(path);
    final error = store.error;
    if (error != null) throw error;
    return _Snapshot(store.docs[path]);
  }
}

// ignore: subtype_of_sealed_class
class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final _Firestore store;
  final String name;
  _Collection(this.store, this.name);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _DocRef(store, '$name/$path');
}

class _Firestore extends Fake implements FirebaseFirestore {
  final Map<String, Map<String, dynamic>> docs;
  final reads = <String>[];
  Object? error;
  _Firestore(this.docs);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(this, path);
}

const _canonical = 'https://meet.example.com/canonical';
const _legacy = 'https://meet.example.com/legacy';

void main() {
  group('B14 FirestoreHalaqaMeetingLinkRepository', () {
    test('reads the valid canonical link and its updatedAt', () async {
      final at = DateTime.utc(2026, 10, 1, 8);
      final store = _Firestore({
        'halaqaMeetingLinks/h1': {
          'meetingLink': '  $_canonical  ',
          'updatedAt': Timestamp.fromDate(at),
        },
        'halaqat/h1': {'meetingLink': _legacy},
      });
      final result = await FirestoreHalaqaMeetingLinkRepository(
        store,
      ).getMeetingLink('h1');

      final link = result.getOrElse((_) => throw StateError('left'))!;
      expect(link.meetingLink, _canonical);
      expect(link.updatedAt!.isAtSameMomentAs(at), isTrue);
      expect(link.joinUri.toString(), _canonical);
      expect(meetingLinkAvailability(link), MeetingLinkAvailability.joinable);
      expect(store.reads, ['halaqaMeetingLinks/h1']);
    });

    test('a missing document means no link, never the legacy mirror', () async {
      final store = _Firestore({
        'halaqat/h1': {'meetingLink': _legacy},
      });
      final result = await FirestoreHalaqaMeetingLinkRepository(
        store,
      ).getMeetingLink('h1');

      expect(result, const Right<Failure, HalaqaMeetingLink?>(null));
      expect(meetingLinkAvailability(null), MeetingLinkAvailability.missing);
      expect(store.reads, ['halaqaMeetingLinks/h1']);
    });

    test('permission-denied maps to MeetingLinkAccessDeniedFailure', () async {
      final store = _Firestore({
        'halaqat/h1': {'meetingLink': _legacy},
      })..error = FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      final result = await FirestoreHalaqaMeetingLinkRepository(
        store,
      ).getMeetingLink('h1');

      expect(result, const Left<Failure, HalaqaMeetingLink?>(
        MeetingLinkAccessDeniedFailure(),
      ));
      expect(store.reads, ['halaqaMeetingLinks/h1']);
    });

    test('connection failures map to NetworkFailure, others to a generic '
        'ServerFailure, and no legacy value is returned', () async {
      for (final code in ['unavailable', 'deadline-exceeded']) {
        final store = _Firestore({
          'halaqat/h1': {'meetingLink': _legacy},
        })..error = FirebaseException(plugin: 'cloud_firestore', code: code);
        final result = await FirestoreHalaqaMeetingLinkRepository(
          store,
        ).getMeetingLink('h1');
        expect(result, const Left<Failure, HalaqaMeetingLink?>(
          NetworkFailure(),
        ), reason: code);
        expect(store.reads, ['halaqaMeetingLinks/h1'], reason: code);
      }

      for (final error in <Object>[
        FirebaseException(plugin: 'cloud_firestore', code: 'internal'),
        StateError('boom'),
      ]) {
        final store = _Firestore({})..error = error;
        final result = await FirestoreHalaqaMeetingLinkRepository(
          store,
        ).getMeetingLink('h1');
        expect(result, const Left<Failure, HalaqaMeetingLink?>(
          ServerFailure(kMeetingLinkLoadFailedMessage),
        ));
      }
    });

    test('an empty, non-string or invalid stored value is not joinable',
        () async {
      for (final raw in <Object?>[
        '',
        '   ',
        42,
        null,
        'http://meet.example.com/x',
        'javascript:alert(1)',
        'https://u:p@meet.example.com',
      ]) {
        final store = _Firestore({
          'halaqaMeetingLinks/h1': {'meetingLink': raw},
        });
        final result = await FirestoreHalaqaMeetingLinkRepository(
          store,
        ).getMeetingLink('h1');
        final link = result.getOrElse((_) => throw StateError('left'));
        expect(link, isNotNull, reason: '$raw');
        expect(link!.joinUri, isNull, reason: '$raw');
        expect(
          meetingLinkAvailability(link),
          MeetingLinkAvailability.invalid,
          reason: '$raw',
        );
      }
    });
  });

  group('B14 GetHalaqaMeetingLinkUseCase', () {
    test('trims the id and skips the read for an empty id', () async {
      final repo = FakeHalaqaMeetingLinkRepository({'h1': _canonical});
      final useCase = GetHalaqaMeetingLinkUseCase(repo);

      expect(await useCase('   '), const Right<Failure, HalaqaMeetingLink?>(
        null,
      ));
      expect(repo.reads, isEmpty);

      final result = await useCase(' h1 ');
      expect(result.getOrElse((_) => null)?.meetingLink, _canonical);
      expect(repo.reads, ['h1']);
    });
  });

  group('B14 canonical wiring (no legacy halaqat.meetingLink read)', () {
    Iterable<File> dartFiles() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    test('only the canonical parser reads a meetingLink field', () {
      final readers = [
        for (final f in dartFiles())
          if (f.readAsStringSync().contains("['meetingLink']"))
            f.path.replaceAll('\\', '/'),
      ];
      expect(readers, ['lib/shared/data/halaqa_meeting_link_firestore.dart']);
    });

    test('DI registrations match the injectable annotations', () {
      String flat(String path) =>
          File(path).readAsStringSync().replaceAll(RegExp(r'\s+'), '');
      final config = flat('lib/core/di/injection_container.config.dart');
      expect(
        RegExp(
          r'gh\.lazySingleton<_i(\d+)\.HalaqaMeetingLinkRepository>\(\(\)=>'
          r'_i\d+\.FirestoreHalaqaMeetingLinkRepository\('
          r'gh<_i\d+\.FirebaseFirestore>\(\),?\),?\);',
        ).hasMatch(config),
        isTrue,
      );
      expect(
        RegExp(
          r'gh\.lazySingleton<_i(\d+)\.GetHalaqaMeetingLinkUseCase>\(\(\)=>'
          r'_i\1\.GetHalaqaMeetingLinkUseCase\('
          r'gh<_i\1\.HalaqaMeetingLinkRepository>\(\),?\),?\);',
        ).hasMatch(config),
        isTrue,
      );
      expect(
        flat('lib/shared/data/halaqa_meeting_link_firestore.dart'),
        contains(
          '@LazySingleton(as:HalaqaMeetingLinkRepository)'
          'classFirestoreHalaqaMeetingLinkRepository',
        ),
      );
      expect(
        flat('lib/shared/domain/halaqa_meeting_link.dart'),
        contains('@lazySingletonclassGetHalaqaMeetingLinkUseCase'),
      );
    });

    test('halaqa read models no longer carry a meetingLink', () {
      for (final path in [
        'lib/shared/domain/halaqa_entity.dart',
        'lib/shared/data/models/halaqa_model.dart',
        'lib/features/schedule/domain/entities/halaqa_schedule_source.dart',
        'lib/features/schedule/domain/entities/class_session_entity.dart',
        'lib/features/schedule/data/datasources/schedule_remote_datasource_impl.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('final String meetingLink')), reason: path);
        expect(source, isNot(contains("'meetingLink'")), reason: path);
      }
    });

    test('every link consumer goes through the canonical read layer', () {
      final consumers = {
        'lib/shared/widgets/student_session_card_widget.dart':
            'HalaqaMeetingLinkBuilder(',
        'lib/features/supervisor/presentation/pages/supervisor_halaqa_detail_page.dart':
            'HalaqaMeetingLinkBuilder(',
        'lib/features/admin/presentation/pages/admin_halaqat_page.dart':
            'HalaqaMeetingLinkBuilder(',
        'lib/features/student/presentation/widgets/halaqa_meeting_join.dart':
            'sl<GetHalaqaMeetingLinkUseCase>()',
        'lib/shared/widgets/halaqa_meeting_link_builder.dart':
            'widget.getMeetingLink(widget.halaqaId)',
      };
      consumers.forEach((path, marker) {
        final source = File(path).readAsStringSync();
        expect(source, contains(marker), reason: path);
        expect(source, isNot(contains('halaqa.meetingLink')), reason: path);
        expect(source, isNot(contains('h.meetingLink')), reason: path);
        expect(source, isNot(contains('GetStudentHalaqaUseCase')), reason: path);
      });
      final schedule = File(
        'lib/features/schedule/presentation/pages/student_schedule_page.dart',
      ).readAsStringSync();
      expect(schedule, contains('joinHalaqaMeeting(context'));
    });

    test('the shared builder only accepts the canonical use case', () {
      final builder = File(
        'lib/shared/widgets/halaqa_meeting_link_builder.dart',
      ).readAsStringSync();
      expect(builder, contains('final GetHalaqaMeetingLinkUseCase getMeetingLink;'));
      expect(builder, isNot(contains('injection_container')));

      final card = File(
        'lib/shared/widgets/student_session_card_widget.dart',
      ).readAsStringSync();
      expect(card, contains('final GetHalaqaMeetingLinkUseCase getMeetingLink;'));
      expect(card, contains('getMeetingLink: getMeetingLink,'));

      for (final path in [
        'lib/features/student/presentation/pages/student_home_page.dart',
        'lib/features/supervisor/presentation/pages/supervisor_halaqa_detail_page.dart',
        'lib/features/admin/presentation/pages/admin_halaqat_page.dart',
      ]) {
        expect(
          File(path).readAsStringSync(),
          contains('getMeetingLink: sl<GetHalaqaMeetingLinkUseCase>(),'),
          reason: path,
        );
      }
    });
  });
}
