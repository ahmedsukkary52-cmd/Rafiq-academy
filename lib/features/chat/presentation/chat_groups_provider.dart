import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/di/injection_container.dart';
import '../data/chat_groups_repository.dart';

/// Built from the registered Firebase singletons (not itself registered).
ChatGroupsRepository resolveChatGroupsRepository() => ChatGroupsRepository(
  firestore: sl<FirebaseFirestore>(),
  functions: sl<FirebaseFunctions>(),
  storage: sl<FirebaseStorage>(),
);
