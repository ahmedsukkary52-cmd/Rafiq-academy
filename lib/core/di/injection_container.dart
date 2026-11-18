import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import '../../features/accounts/data/academy_accounts_repository.dart';
import '../../features/admin/data/admin_reports_repository.dart';
import '../../features/assistant/data/cover_duty_repository.dart';
import '../../features/chat/data/chat_groups_repository.dart';
import '../../features/complaints/data/complaints_repository.dart';
import '../../features/directory/data/academy_directory_repository.dart';
import 'injection_container.config.dart';

final sl = GetIt.instance;

@InjectableInit()
Future<void> initDependencies() async {
  // Generated init is synchronous GetIt wiring (analyzer: await_only_futures).
  sl.init();
  registerDirectoryAndAccountsRepositories();
  registerChatGroupsRepository();
  registerComplaintsAndAssistantRepositories();
  registerAdminReportsRepository();
}

/// EQ-P1-05 — directory/accounts were never on the generated injectable graph.
///
/// Registers the existing concrete repositories once against GetIt so
/// presentation resolves `sl<AcademyDirectoryRepository>()` /
/// `sl<AcademyAccountsRepository>()` instead of constructing them with
/// Firebase clients. Idempotent for tests that call [initDependencies] twice
/// or register fakes first.
void registerDirectoryAndAccountsRepositories() {
  if (!sl.isRegistered<AcademyDirectoryRepository>()) {
    sl.registerLazySingleton<AcademyDirectoryRepository>(
      () => FirestoreAcademyDirectoryRepository(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
      ),
    );
  }
  if (!sl.isRegistered<AcademyAccountsRepository>()) {
    sl.registerLazySingleton<AcademyAccountsRepository>(
      () => AcademyAccountsRepository(
        functions: sl<FirebaseFunctions>(),
        firestore: sl<FirebaseFirestore>(),
      ),
    );
  }
}

/// EQ-P1-06 — group/oversight chat repo was built in presentation from
/// Storage/Functions singletons. Main [ChatRepository] already owns message
/// Storage/Functions via injectable; this registers the sibling groups repo.
void registerChatGroupsRepository() {
  if (!sl.isRegistered<ChatGroupsRepository>()) {
    // People search depends on the accounts member-prefix query.
    registerDirectoryAndAccountsRepositories();
    sl.registerLazySingleton<ChatGroupsRepository>(
      () => ChatGroupsRepository(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
        storage: sl<FirebaseStorage>(),
        accounts: sl<AcademyAccountsRepository>(),
      ),
    );
  }
}

/// EQ-3 — complaints + assistant cover-duty repos were built in presentation
/// from Firebase clients. Manual GetIt registration (same pattern as B4/B5);
/// avoids regenerating staged injectable config.
void registerComplaintsAndAssistantRepositories() {
  if (!sl.isRegistered<ComplaintsRepository>()) {
    sl.registerLazySingleton<ComplaintsRepository>(
      () => ComplaintsRepository(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
      ),
    );
  }
  if (!sl.isRegistered<CoverDutyRepository>()) {
    sl.registerLazySingleton<CoverDutyRepository>(
      () => FirestoreCoverDutyRepository(
        firestore: sl<FirebaseFirestore>(),
        functions: sl<FirebaseFunctions>(),
      ),
    );
  }
}

/// EQ-4 — Admin reports data access was constructed in the page from
/// `sl<FirebaseFirestore>()`. PDF/export and AdminBloc roster/teachers
/// coupling stay in presentation (deferred; higher blast radius).
void registerAdminReportsRepository() {
  if (!sl.isRegistered<AdminReportsRepository>()) {
    sl.registerLazySingleton<AdminReportsRepository>(
      () => AdminReportsRepository(firestore: sl<FirebaseFirestore>()),
    );
  }
}
