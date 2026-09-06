import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/router_app.dart';
import '../../chat/presentation/pages/chat_room.dart';
import 'pages/parent_achievements_page.dart';
import 'pages/parent_attendance_page.dart';
import 'pages/parent_child_profile_page.dart';
import 'pages/parent_evaluations_page.dart';
import 'pages/parent_reports_page.dart';
import 'pages/parent_schedule_page.dart';
import 'pages/parent_subscriptions_page.dart';

/// In-feature navigation for Parent (chat uses [ChatRoomPage] via Navigator).
class ParentDestinations {
  ParentDestinations._();

  static Future<void> _push(BuildContext context, Widget page) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  static Future<void> childProfile(
    BuildContext context, {
    required String studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentChildProfilePage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> reports(
    BuildContext context, {
    String? studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentReportsPage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> schedule(
    BuildContext context, {
    String? studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentSchedulePage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> attendance(
    BuildContext context, {
    required String studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentAttendancePage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> evaluations(
    BuildContext context, {
    required String studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentEvaluationsPage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> achievements(
    BuildContext context, {
    String? studentId,
    String? studentName,
  }) {
    return _push(
      context,
      ParentAchievementsPage(studentId: studentId, studentName: studentName),
    );
  }

  static Future<void> subscriptions(BuildContext context) {
    return _push(context, const ParentSubscriptionsPage());
  }

  static Future<void> absenceRequests(BuildContext context) {
    return context.push(AppRoutes.parentAbsence);
  }

  static Future<void> notifications(BuildContext context) {
    return context.push(AppRoutes.parentNotifs);
  }

  static Future<void> chat(
    BuildContext context, {
    required String conversationId,
    required String title,
    String? imageUrl,
  }) {
    return _push(
      context,
      ChatRoomPage(
        conversationId: conversationId,
        otherUserName: title,
        otherUserImage: imageUrl,
      ),
    );
  }
}
