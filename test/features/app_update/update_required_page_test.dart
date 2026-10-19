import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/features/app_update/domain/client_version_config.dart';
import 'package:rafiq_academy/features/app_update/presentation/bloc/client_version_gate_bloc.dart';
import 'package:rafiq_academy/features/app_update/presentation/pages/update_required_page.dart';

class _FakeGate extends Fake implements ClientVersionGateBloc {
  _FakeGate(this.state);

  @override
  final ClientVersionGateState state;

  final _controller = StreamController<ClientVersionGateState>.broadcast();
  int checks = 0;

  @override
  Stream<ClientVersionGateState> get stream => _controller.stream;

  @override
  void add(ClientVersionCheckRequested event) => checks++;

  @override
  Future<void> close() => _controller.close();
}

final _androidUrl = Uri.parse('https://play.example.com/app');

ClientVersionGateState _blocked({
  Uri? android,
  Uri? ios,
  bool rechecking = false,
}) => ClientVersionGateState(
  status: ClientVersionGateStatus.updateRequired,
  config: ClientVersionConfig(
    minimumBuildNumber: 9,
    androidUpdateUrl: android,
    iosUpdateUrl: ios,
  ),
  isRechecking: rechecking,
);

Future<_FakeGate> _pump(
  WidgetTester tester,
  ClientVersionGateState state, {
  UpdateUrlOpener? opener,
}) async {
  final gate = _FakeGate(state);
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: BlocProvider<ClientVersionGateBloc>.value(
          value: gate,
          child: opener == null
              ? const UpdateRequiredPage()
              : UpdateRequiredPage(openUrl: opener),
        ),
      ),
    ),
  );
  return gate;
}

const _store = Key('updateRequiredOpenStore');
const _retry = Key('updateRequiredRetry');

final _android = TargetPlatformVariant.only(TargetPlatform.android);

void main() {
  testWidgets('shows the Arabic message and retry, without a store button '
      'when no URL is configured', (tester) async {
    final gate = await _pump(tester, _blocked());

    expect(find.text('يلزم تحديث التطبيق'), findsOneWidget);
    expect(find.byKey(_store), findsNothing);

    await tester.tap(find.byKey(_retry));
    expect(gate.checks, 1);
  }, variant: _android);

  testWidgets(
    'shows the store button only for the current platform URL',
    (tester) async {
      await _pump(tester, _blocked(android: _androidUrl));
      expect(find.byKey(_store), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets('opens the configured URL; failure shows a message', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(
      tester,
      _blocked(android: _androidUrl),
      opener: (uri) async {
        opened.add(uri);
        return false;
      },
    );

    await tester.tap(find.byKey(_store));
    await tester.pump();
    expect(opened, [_androidUrl]);
    expect(find.text('تعذّر فتح رابط التحديث'), findsOneWidget);
  }, variant: _android);

  testWidgets('retry is disabled while a re-check is in flight', (
    tester,
  ) async {
    final gate = await _pump(tester, _blocked(rechecking: true));
    await tester.tap(find.byKey(_retry), warnIfMissed: false);
    expect(gate.checks, 0);
  }, variant: _android);

  testWidgets('back navigation is blocked', (tester) async {
    await _pump(tester, _blocked());
    final popScope = tester.widget<PopScope<dynamic>>(
      find.descendant(
        of: find.byType(UpdateRequiredPage),
        matching: find.byWidgetPredicate((widget) => widget is PopScope),
      ),
    );
    expect(popScope.canPop, isFalse);
  }, variant: _android);
}
