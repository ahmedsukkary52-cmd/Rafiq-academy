import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../auth/presentation/bloc/auth_bloc.dart';
import '../../auth/presentation/bloc/auth_state.dart';
import '../data/complaints_repository.dart';
import 'complaint_widgets.dart';
import 'pages/complaint_details_page.dart';
import 'pages/complaints_list_page.dart';

/// Built on demand from the existing Firebase registrations (no generated
/// DI entry for the repository).
ComplaintsRepository defaultComplaintsRepository() => ComplaintsRepository(
  firestore: sl<FirebaseFirestore>(),
  functions: sl<FirebaseFunctions>(),
);

ComplaintViewer? complaintViewerOf(BuildContext context) {
  final auth = context.read<AuthBloc>().state;
  if (auth is! AuthAuthenticated) return null;
  return ComplaintViewer(uid: auth.user.uid, role: auth.user.role);
}

/// Admin queue or the signed-in user's own complaints.
Widget buildComplaintsPage(BuildContext context) {
  final viewer = complaintViewerOf(context);
  if (viewer == null) return const SizedBox.shrink();
  return ComplaintsListPage(
    viewer: viewer,
    repository: defaultComplaintsRepository(),
  );
}

/// Opens one complaint thread (dashboard preview, notifications).
Future<void> openComplaintDetails(BuildContext context, String complaintId) {
  final viewer = complaintViewerOf(context);
  if (viewer == null) return Future.value();
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ComplaintDetailsPage(
        complaintId: complaintId,
        viewer: viewer,
        repository: defaultComplaintsRepository(),
      ),
    ),
  );
}

/// Entry from Parent / Teacher / Supervisor profile and settings screens.
Future<void> openMyComplaints(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: buildComplaintsPage));
}
