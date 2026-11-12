import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_academy/core/presentation/bloc_status.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_bloc.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_event.dart';
import 'package:rafiq_academy/features/admin/presentation/bloc/admin_state.dart';
import 'package:rafiq_academy/features/admin/presentation/pages/admin_broadcast_page.dart';

class _AdminStub extends Cubit<AdminState> implements AdminBloc {
  _AdminStub() : super(const AdminState());

  final sent = <SendBroadcastNotificationEvent>[];

  @override
  void add(AdminEvent event) {
    if (event is SendBroadcastNotificationEvent) {
      sent.add(event);
      emit(state.copyWith(broadcastStatus: SubmissionStatus.submitting));
    } else if (event is ResetBroadcastEvent) {
      emit(state.copyWith(broadcastStatus: SubmissionStatus.idle));
    }
  }

  void finish({String? error}) => emit(
    state.copyWith(
      broadcastStatus: error == null
          ? SubmissionStatus.success
          : SubmissionStatus.error,
      broadcastError: error,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_AdminStub> _pump(
  WidgetTester tester,
  Future<int> Function(String) count,
) async {
  await tester.binding.setSurfaceSize(const Size(800, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final bloc = _AdminStub();
  await tester.pumpWidget(
    BlocProvider<AdminBloc>.value(
      value: bloc,
      child: MaterialApp(home: AdminBroadcastPage(countAudience: count)),
    ),
  );
  await tester.pumpAndSettle();
  return bloc;
}

Future<void> _fill(WidgetTester tester, String title) async {
  await tester.enterText(find.widgetWithText(TextField, 'عنوان البث'), title);
  await tester.enterText(find.widgetWithText(TextField, 'نص الرسالة'), 'نص');
  await tester.pump();
}

Future<void> _send(WidgetTester tester) async {
  await tester.tap(find.text('إرسال البث الآن'));
  await tester.pump();
}

void main() {
  testWidgets('explains who receives the message with a live account count', (
    tester,
  ) async {
    final asked = <String>[];
    await _pump(tester, (role) async {
      asked.add(role);
      if (role == 'teacher') throw StateError('offline');
      return role == 'all' ? 120 : 45;
    });

    expect(find.textContaining('كل حسابات الأكاديمية'), findsOneWidget);
    expect(
      find.text('عدد الحسابات المسجلة في هذه الفئة الآن: 120'),
      findsOneWidget,
    );
    expect(find.textContaining('لا يُرسل إشعار فوري'), findsOneWidget);

    await tester.tap(find.text('أولياء الأمور'));
    await tester.pumpAndSettle();
    expect(find.text('يصل إلى حسابات أولياء الأمور فقط.'), findsOneWidget);
    expect(
      find.text('عدد الحسابات المسجلة في هذه الفئة الآن: 45'),
      findsOneWidget,
    );

    await tester.tap(find.text('المعلمون'));
    await tester.pumpAndSettle();
    expect(find.text('تعذر حساب عدد الحسابات المستلمة'), findsOneWidget);
    expect(asked, ['all', 'parent', 'teacher']);
  });

  testWidgets('a retry after a failed send reuses the request id; an edited '
      'message gets a new one', (tester) async {
    final bloc = await _pump(tester, (_) async => 3);
    await _fill(tester, 'تذكير');
    await _send(tester);
    bloc.finish(error: 'تعذر الاتصال');
    await tester.pumpAndSettle();

    await _send(tester);
    expect(bloc.sent, hasLength(2));
    expect(bloc.sent[0].requestId, isNotNull);
    expect(bloc.sent[1].requestId, bloc.sent[0].requestId);
    bloc.finish(error: 'تعذر الاتصال');
    await tester.pumpAndSettle();

    await _fill(tester, 'تذكير معدل');
    await _send(tester);
    expect(bloc.sent[2].requestId, isNot(bloc.sent[0].requestId));
    bloc.finish();
    await tester.pumpAndSettle();
    expect(find.text('تذكير معدل'), findsNothing, reason: 'form cleared');

    await _fill(tester, 'رسالة جديدة');
    await _send(tester);
    expect(bloc.sent[3].requestId, isNot(bloc.sent[2].requestId));
  });
}
