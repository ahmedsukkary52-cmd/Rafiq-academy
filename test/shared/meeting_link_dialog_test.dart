import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/shared/theme/app_theme.dart';
import 'package:rafiq_academy/shared/widgets/meeting_link_dialog.dart';

class _Probe {
  bool closed = false;
  MeetingLinkDialogResult? result;
}

Future<_Probe> _open(
  WidgetTester tester, {
  required String current,
  required bool canClear,
}) async {
  final probe = _Probe();
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              probe.result = await showMeetingLinkDialog(
                context,
                currentLink: current,
                canClear: canClear,
              );
              probe.closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return probe;
}

TextField _field(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('meetingLinkField')));

void main() {
  group('B14 meeting link dialog', () {
    testWidgets('prefills the current link; unchanged save keeps it', (
      tester,
    ) async {
      final probe = await _open(
        tester,
        current: 'https://meet.example.com/a',
        canClear: true,
      );
      expect(_field(tester).controller!.text, 'https://meet.example.com/a');
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(probe.closed, isTrue);
      expect(probe.result, isNull);
    });

    testWidgets('invalid input shows an inline error and stays open', (
      tester,
    ) async {
      final probe = await _open(tester, current: '', canClear: true);
      expect(find.byKey(const Key('meetingLinkClear')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        'http://meet.example.com/x',
      );
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(probe.closed, isFalse);
      expect(
        find.text('رابط الاجتماع يجب أن يبدأ بـ https://'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('meetingLinkField')), '');
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(probe.closed, isFalse);

      await tester.enterText(
        find.byKey(const Key('meetingLinkField')),
        ' https://meet.example.com/new ',
      );
      await tester.tap(find.byKey(const Key('meetingLinkSave')));
      await tester.pumpAndSettle();
      expect(probe.result?.clear, isFalse);
      expect(probe.result?.link, 'https://meet.example.com/new');
    });

    testWidgets('clear needs a second confirming tap', (tester) async {
      final probe = await _open(
        tester,
        current: 'https://meet.example.com/a',
        canClear: true,
      );
      await tester.tap(find.byKey(const Key('meetingLinkClear')));
      await tester.pumpAndSettle();
      expect(probe.closed, isFalse);
      expect(find.text('تأكيد الحذف'), findsOneWidget);
      await tester.tap(find.byKey(const Key('meetingLinkClear')));
      await tester.pumpAndSettle();
      expect(probe.result?.clear, isTrue);
      expect(probe.result?.link, isNull);
    });

    testWidgets('clear is hidden when not allowed', (tester) async {
      await _open(
        tester,
        current: 'https://meet.example.com/a',
        canClear: false,
      );
      expect(find.byKey(const Key('meetingLinkClear')), findsNothing);
    });
  });
}
