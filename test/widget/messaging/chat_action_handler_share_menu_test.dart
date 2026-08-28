// test/widget/messaging/chat_action_handler_share_menu_test.dart
//
// BUT-1962: sharing a weekly menu into a chat has to tell a week with nothing
// planned apart from a week that could not be read. Both used to land on
// "Ingen meny för den veckan", because `getWeek` reported a failed read as an
// empty plan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_action_handler.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

class _MockPlanService extends Mock implements WeeklyMenuPlanService {}

class _MockMessagingService extends Mock implements MessagingService {}

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late _MockPlanService planService;
  late _MockMessagingService messagingService;

  const conversationId = 'conv-1';

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    planService = _MockPlanService();
    messagingService = _MockMessagingService();

    when(
      () => messagingService.sendMenuShare(
        conversationId: any(named: 'conversationId'),
        menuId: any(named: 'menuId'),
        menuTitle: any(named: 'menuTitle'),
        message: any(named: 'message'),
      ),
    ).thenAnswer((_) async {});

    TestServiceLocator.registerMock<WeeklyMenuPlanService>(planService);
    TestServiceLocator.registerMock<MessagingService>(messagingService);
    TestServiceLocator.registerMock<AuthRepository>(_MockAuthRepository());
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  /// Opens the share-menu flow and confirms the pre-selected current week.
  Future<void> shareCurrentWeek(WidgetTester tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => ChatActionHandler(
                conversationId: conversationId,
                context: context,
              ).handleAttachment('menu'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The dialog pre-selects the current week, so confirming is enough.
    await tester.tap(find.text('Dela'));
    await tester.pumpAndSettle();
  }

  WeeklyMenuPlan emptyWeek() => WeeklyMenuPlan.empty(
    userId: 'u',
    date: IsoWeekUtils.weekStartOf(DateTime(2026, 8, 28)),
  );

  testWidgets('a week that could not be READ shows the retryable refusal, not '
      '"ingen meny"', (tester) async {
    when(() => planService.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: emptyWeek(), readFailed: true),
    );

    await shareCurrentWeek(tester);

    expect(find.text(weeklyPlanReadFailedMessage), findsOneWidget);
    expect(find.text('Ingen meny för den veckan'), findsNothing);
    verifyNever(
      () => messagingService.sendMenuShare(
        conversationId: any(named: 'conversationId'),
        menuId: any(named: 'menuId'),
        menuTitle: any(named: 'menuTitle'),
        message: any(named: 'message'),
      ),
    );
  });

  testWidgets('the control: a week that genuinely holds nothing still says '
      '"ingen meny"', (tester) async {
    // Same stubs, same empty plan — only `readFailed` differs. That pair is
    // what the fix is: one message is a fact about the user's menu, the other
    // is a fault they can retry.
    when(() => planService.readWeek(any())).thenAnswer(
      (_) async => WeeklyMenuPlanRead(plan: emptyWeek(), readFailed: false),
    );

    await shareCurrentWeek(tester);

    expect(find.text('Ingen meny för den veckan'), findsOneWidget);
    expect(find.text(weeklyPlanReadFailedMessage), findsNothing);
    verifyNever(
      () => messagingService.sendMenuShare(
        conversationId: any(named: 'conversationId'),
        menuId: any(named: 'menuId'),
        menuTitle: any(named: 'menuTitle'),
        message: any(named: 'message'),
      ),
    );
  });
}
