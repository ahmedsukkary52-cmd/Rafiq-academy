import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads the server-written first-login flag for the signed-in account.
/// Only `mustChangePassword` is read; nothing is ever written here.
Future<bool> readMustChangePassword(
  FirebaseFirestore firestore,
  String uid, {
  required Duration timeout,
}) async {
  final private = await firestore
      .collection('userPrivate')
      .doc(uid)
      .get()
      .timeout(timeout);
  return private.data()?['mustChangePassword'] == true;
}
