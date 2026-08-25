import 'package:flutter/material.dart';

import '../../student/presentation/pages/student_profile_page.dart';
import 'pages/supervisor_admin_request_page.dart';
import 'pages/supervisor_attendance_page.dart';
import 'pages/supervisor_awards_hub_page.dart';
import 'pages/supervisor_excuses_page.dart';
import 'pages/supervisor_follow_up_page.dart';
import 'pages/supervisor_grant_award_page.dart';
import 'pages/supervisor_halaqa_detail_page.dart';
import 'pages/supervisor_halaqat_page.dart';
import 'pages/supervisor_register_page.dart';
import 'pages/supervisor_reports_page.dart';
import 'pages/supervisor_teachers_page.dart';
import 'pages/supervisor_transfer_page.dart';

/// In-feature navigation for Supervisor (Navigator — no new GoRouter paths).
class SupervisorDestinations {
  SupervisorDestinations._();

  static Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static Future<void> studentProfile(
    BuildContext context, {
    required String studentId,
    String? halaqaId,
  }) {
    return _push(
      context,
      StudentProfilePage(studentId: studentId, halaqaId: halaqaId),
    );
  }

  static Future<void> register(
    BuildContext context, {
    String? preselectedHalaqaId,
  }) {
    return _push(
      context,
      SupervisorRegisterPage(preselectedHalaqaId: preselectedHalaqaId),
    );
  }

  static Future<void> transfer(
    BuildContext context, {
    String? studentId,
    String? sourceHalaqaId,
  }) {
    return _push(
      context,
      SupervisorTransferPage(
        preselectedStudentId: studentId,
        preselectedSourceHalaqaId: sourceHalaqaId,
      ),
    );
  }

  static Future<void> halaqat(BuildContext context) {
    return _push(context, const SupervisorHalaqatPage());
  }

  static Future<void> halaqaDetail(
    BuildContext context, {
    required String halaqaId,
  }) {
    return _push(context, SupervisorHalaqaDetailPage(halaqaId: halaqaId));
  }

  static Future<void> attendance(BuildContext context, {String? halaqaId}) {
    return _push(context, SupervisorAttendancePage(initialHalaqaId: halaqaId));
  }

  static Future<void> followUp(BuildContext context) {
    return _push(context, const SupervisorFollowUpPage());
  }

  static Future<void> excuses(BuildContext context) {
    return _push(context, const SupervisorExcusesPage());
  }

  static Future<void> awardsHub(BuildContext context) {
    return _push(context, const SupervisorAwardsHubPage());
  }

  static Future<void> grantAward(
    BuildContext context, {
    String? preselectedStudentId,
    String? preselectedHalaqaId,
  }) {
    return _push(
      context,
      SupervisorGrantAwardPage(
        preselectedStudentId: preselectedStudentId,
        preselectedHalaqaId: preselectedHalaqaId,
      ),
    );
  }

  static Future<void> teachers(BuildContext context) {
    return _push(context, const SupervisorTeachersPage());
  }

  static Future<void> reportsQuick(BuildContext context) {
    return _push(context, const SupervisorReportsPage(quickCompose: true));
  }

  static Future<void> adminRequest(
    BuildContext context, {
    required String halaqaId,
    required String halaqaName,
  }) {
    return _push(
      context,
      SupervisorAdminRequestPage(halaqaId: halaqaId, halaqaName: halaqaName),
    );
  }
}
