import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/constants/app_build_number.dart';

void main() {
  test('kAppBuildNumber matches the pubspec.yaml build number', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);
    expect(match, isNotNull, reason: 'pubspec version must be X.Y.Z+N');
    expect(
      kAppBuildNumber,
      int.parse(match!.group(1)!),
      reason: 'Bump kAppBuildNumber together with the pubspec +N',
    );
  });

  test('kAppBuildNumber is above every build made before J.10', () {
    // Builds before J.10 shipped build 1; appConfig/clientVersion
    // .minimumBuildNumber can only block them if this build is higher.
    expect(kAppBuildNumber, greaterThanOrEqualTo(2));
  });
}
