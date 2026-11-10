import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/error/exception.dart';
import 'package:rafiq_academy/features/admin/data/datasources/admin_operations_remote_datasource.dart';
import 'package:rafiq_academy/features/parent/data/data_source/parent_remote_datasource_impl.dart';
import 'package:rafiq_academy/features/parent/data/models/parent_model.dart';
import 'package:rafiq_academy/shared/domain/parent_payment_proof.dart';

import '../../support/fake_callables.dart';
import '../auth/auth_fakes.dart';

const _cycle = 'pc_AAAAAAAAAAAAAAAAAAAAAAAA';

class _FakeTaskSnapshot extends Fake implements TaskSnapshot {}

class _DoneUpload extends Fake implements UploadTask {
  final Future<TaskSnapshot> _done = Future.value(_FakeTaskSnapshot());

  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot value) onValue, {
    Function? onError,
  }) => _done.then(onValue, onError: onError);
}

class _FakeRef extends Fake implements Reference {
  final _FakeStorage owner;
  @override
  final String fullPath;

  _FakeRef(this.owner, this.fullPath);

  @override
  UploadTask putFile(File file, [SettableMetadata? metadata]) {
    owner.uploads.add((fullPath, metadata?.contentType));
    return _DoneUpload();
  }
}

class _FakeStorage extends Fake implements FirebaseStorage {
  final uploads = <(String, String?)>[];

  @override
  Reference ref([String? path]) => _FakeRef(this, path ?? '');
}

void main() {
  late Directory tmp;
  late File proof;
  late File otherProof;
  late FakeFunctions functions;
  late _FakeStorage storage;
  late FakeFirestore firestore;
  late ParentRemoteDatasourceImpl ds;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('proof_cycle_');
    final jpeg = [0xFF, 0xD8, 0xFF, 0xE0, ...List.filled(60, 1)];
    proof = File('${tmp.path}/proof.jpg')..writeAsBytesSync(jpeg);
    otherProof = File('${tmp.path}/other.jpg')..writeAsBytesSync(jpeg);
    functions = FakeFunctions();
    storage = _FakeStorage();
    // FakeFirestore has no write API: any direct payment write would throw.
    firestore = FakeFirestore({
      'payments/pay1': {'parentId': 'parent1', 'status': 'due', 'amount': 200},
      'payments/paid': {'parentId': 'parent1', 'status': 'paid', 'amount': 200},
    });
    ds = ParentRemoteDatasourceImpl(
      firestore: firestore,
      storage: storage,
      functions: functions,
    );
  });

  tearDown(() => tmp.delete(recursive: true));

  Future<void> submit([File? file]) => ds.submitPaymentProof(
    parentId: 'parent1',
    paymentId: 'pay1',
    localFilePath: (file ?? proof).path,
  );

  String uploadedName(int i) => storage.uploads[i].$1.split('/').last;

  test('uploads, then only the callable makes it the current proof', () async {
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) => {
      'proofCycleId': _cycle,
      'replayed': false,
    };
    await submit();

    expect(storage.uploads, hasLength(1));
    final (path, contentType) = storage.uploads.single;
    expect(path, startsWith('payment_proofs/parent1/pay1/'));
    expect(contentType, 'image/jpeg');
    expect(functions.calledNames, [ParentPaymentProofContract.submitCallable]);
    expect(functions.payloadOf(ParentPaymentProofContract.submitCallable), {
      'paymentId': 'pay1',
      'fileName': uploadedName(0),
    });
  });

  test('a server refusal is surfaced and never shown as submitted', () async {
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) =>
        throw FakeFunctionsError(
          'failed-precondition',
          'هذا الإيصال مستخدم سابقاً — ارفع صورة جديدة',
        );
    await expectLater(
      submit(),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          'هذا الإيصال مستخدم سابقاً — ارفع صورة جديدة',
        ),
      ),
    );
    // Definitive answer: the next attempt is a fresh upload.
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) => {
      'proofCycleId': _cycle,
    };
    await submit();
    expect(storage.uploads, hasLength(2));
  });

  test(
    'retry after a lost response reuses the uploaded name (server replays)',
    () async {
      functions.handlers[ParentPaymentProofContract.submitCallable] = (_) =>
          throw FakeFunctionsError('deadline-exceeded', 'timeout');
      await expectLater(submit(), throwsA(isA<ServerException>()));

      functions.handlers[ParentPaymentProofContract.submitCallable] = (_) => {
        'proofCycleId': _cycle,
        'replayed': true,
      };
      await submit();
      expect(
        storage.uploads,
        hasLength(1),
        reason: 'stored proofs are never re-uploaded',
      );
      final names = [
        for (final c in functions.calls) (c.$2 as Map)['fileName'] as String,
      ];
      expect(names, [uploadedName(0), uploadedName(0)]);

      // Settled: a later submission uploads a new object.
      await submit();
      expect(storage.uploads, hasLength(2));
    },
  );

  test('a different file after an unknown outcome is a new upload', () async {
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) =>
        throw FakeFunctionsError('unavailable', 'offline');
    await expectLater(submit(), throwsA(isA<ServerException>()));
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) => {
      'proofCycleId': _cycle,
    };
    await submit(otherProof);
    expect(storage.uploads, hasLength(2));
  });

  test('a reply without a server cycle is not treated as submitted', () async {
    functions.handlers[ParentPaymentProofContract.submitCallable] = (_) => {
      'proofCycleId': 'client-made',
    };
    await expectLater(submit(), throwsA(isA<ServerException>()));
  });

  test('paid invoice: nothing uploaded, nothing called', () async {
    await expectLater(
      ds.submitPaymentProof(
        parentId: 'parent1',
        paymentId: 'paid',
        localFilePath: proof.path,
      ),
      throwsA(isA<ServerException>()),
    );
    expect(storage.uploads, isEmpty);
    expect(functions.calls, isEmpty);
  });

  group('cycle mapping', () {
    test('only a server-shaped proofCycleId is read', () {
      final item = paymentReviewItemFromMap('p1', {
        'parentId': 'parent1',
        'proofFileName': 'A.jpg',
        'proofCycleId': _cycle,
      });
      expect(item.proofCycleId, _cycle);
      expect(
        paymentReviewItemFromMap('p1', {'proofCycleId': 'forged'}).proofCycleId,
        isNull,
      );
      expect(paymentReviewItemFromMap('p1', const {}).proofCycleId, isNull);
      expect(
        item.withStudentName('S').proofCycleId,
        _cycle,
        reason: 'enrichment keeps the cycle',
      );
    });

    test('parent payment model reads the cycle', () {
      final model = PaymentModel.fromFirestore(
        FakeSnapshot('p1', {
          'parentId': 'parent1',
          'amount': 200,
          'proofCycleId': _cycle,
          'dueDate': Timestamp.fromMillisecondsSinceEpoch(0),
        }),
      );
      expect(model.proofCycleId, _cycle);
      expect(
        PaymentModel.fromFirestore(
          FakeSnapshot('p2', {'proofCycleId': 'bad'}),
        ).proofCycleId,
        isNull,
      );
    });
  });
}
