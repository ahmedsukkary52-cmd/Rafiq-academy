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

void main() {
  test('a server-set passwordChangeRequired forces the first-login change', () {
    final user = UserModel.fromFirestore(
      _Doc('a2', {'name': 'x', 'role': 'admin', 'passwordChangeRequired': true}),
    );
    expect(user.mustChangePassword, isTrue);
  });

  test('existing profiles without the flag are not forced', () {
    for (final data in [
      {'name': 'x', 'role': 'admin'},
      {'name': 'x', 'role': 'admin', 'passwordChangeRequired': false},
      {'name': 'x', 'role': 'admin', 'passwordChangeRequired': 'true'},
    ]) {
      expect(UserModel.fromFirestore(_Doc('a1', data)).mustChangePassword, isFalse);
    }
  });

  test('the client never writes the flag back', () {
    final user = UserModel.fromFirestore(
      _Doc('a2', {'name': 'x', 'role': 'admin', 'passwordChangeRequired': true}),
    );
    expect(user.toFirestore().containsKey('passwordChangeRequired'), isFalse);
    expect(user.toFirestore().containsKey('mustChangePassword'), isFalse);
  });
}
