import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/auth/data/models/user_model.dart';

// ignore: subtype_of_sealed_class
class _Doc extends Fake implements DocumentSnapshot<Map<String, dynamic>> {
  _Doc(this.id, this._data);

  @override
  final String id;
  final Map<String, dynamic> _data;

  @override
  Map<String, dynamic> data() => _data;
}

/// Personal phone numbers are never stored anywhere in the application.
void main() {
  Iterable<File> dartFiles(String dir) => Directory(dir)
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  String withoutComments(String source) => source
      .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
      .replaceAll(RegExp(r'//.*$', multiLine: true), '');

  test('Dart emulator seeders never generate phone fields or values', () {
    final files = dartFiles('tool').toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      final code = withoutComments(file.readAsStringSync());
      expect(
        code,
        isNot(matches(RegExp('phone', caseSensitive: false))),
        reason: file.path,
      );
      expect(code, isNot(contains('userPrivate')), reason: file.path);
      expect(
        code,
        isNot(matches(RegExp(r'\b05\d{8}\b|\b01[0125]\d{8}\b'))),
        reason: file.path,
      );
    }
  });

  test('app code never reads or writes userPrivate or a phone field', () {
    const denyLists = {
      'contact_info_policy.dart',
      'student_search_contract.dart',
    };
    // The only app file allowed to touch userPrivate: the Admin email reader.
    const privateEmailReader = 'admin_private_email_reader.dart';
    for (final file in dartFiles('lib')) {
      final name = file.uri.pathSegments.last;
      if (denyLists.contains(name)) continue;
      final code = withoutComments(file.readAsStringSync());
      if (name != privateEmailReader) {
        expect(code, isNot(contains('userPrivate')), reason: file.path);
      }
      expect(
        code,
        isNot(matches(RegExp(r'''['"]phone(Number)?['"]'''))),
        reason: file.path,
      );
      expect(code, isNot(matches(RegExp(r'\bphone\s*:'))), reason: file.path);
    }
  });

  test('UserModel ignores a legacy users.phone and never writes one', () {
    final model = UserModel.fromFirestore(
      _Doc('u1', {
        'name': 'أحمد',
        'role': 'student',
        'email': 'a@x.test',
        'phone': '0501234567',
        'isActive': true,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      }),
    );
    expect(model.props, isNot(contains('0501234567')));
    expect(model.toFirestore().containsKey('phone'), isFalse);
    expect(model.toFirestore().values, isNot(contains('0501234567')));
  });

  test('the Admin private email reader reads only email, never a phone', () {
    final code = withoutComments(
      File(
        'lib/features/admin/data/admin_private_email_reader.dart',
      ).readAsStringSync(),
    );
    expect(code, contains('userPrivate'));
    expect(
      code,
      isNot(matches(RegExp('phone|whatsapp|mobile', caseSensitive: false))),
    );
    expect(code, isNot(contains('.set(')));
    expect(code, isNot(contains('.update(')));
    expect(code, isNot(contains('.delete(')));
  });

  test('UserModel never writes email onto users/{uid}', () {
    final model = UserModel.fromFirestore(
      _Doc('u1', {
        'name': 'أحمد',
        'role': 'student',
        'email': 'a@x.test',
        'isActive': true,
        'createdAt': Timestamp.fromDate(DateTime(2026)),
      }),
    );
    expect(model.toFirestore().containsKey('email'), isFalse);
    expect(
      model.withAuthEmail('b@x.test').toFirestore().containsKey('email'),
      isFalse,
    );
  });
}
