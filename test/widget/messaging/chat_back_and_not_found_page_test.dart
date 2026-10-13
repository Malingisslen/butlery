// BUT-2146: the chat's back arrow names the view it returns to when the
// caller knows it, and the page for an unknown route speaks Swedish.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/services/feature_flags/feature_flag_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/service_mocks.dart';
import '../../test_support/base_unit_test.dart';

class _MockFeatureFlags extends Mock implements FeatureFlagService {}

void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  tearDown(() async => TestServiceLocator.reset());

  Future<void> openChat(WidgetTester tester, {String? backTo}) async {
    final flags = _MockFeatureFlags();
    when(() => flags.isEnabled(any())).thenReturn(true);
    TestServiceLocator.registerMock<FeatureFlagService>(flags);
    final messaging = MockMessagingService();
    when(
      () => messaging.getConversation(any()),
    ).thenAnswer((_) async => null);
    when(
      () => messaging.markConversationAsRead(any()),
    ).thenAnswer((_) async {});
    when(
      () => messaging.getConversationMessagesPage(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
        startAfter: any(named: 'startAfter'),
      ),
    ).thenAnswer((_) async => const <Message>[]);
    when(
      () => messaging.getConversationMessages(
        conversationId: any(named: 'conversationId'),
        historyStart: any(named: 'historyStart'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) => const Stream<List<Message>>.empty());
    TestServiceLocator.registerMock<MessagingService>(messaging);
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    ChatViewFacade(conversationId: 'conv-1', backTo: backTo),
              ),
            ),
            child: const Text('öppna'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
  }

  testWidgets('the chat back arrow names the conversation list', (
    tester,
  ) async {
    await openChat(tester, backTo: sv.messagingTitle);
    expect(find.byTooltip(sv.commonBackTo(sv.messagingTitle)), findsOneWidget);
  });

  testWidgets('without a known way back the arrow stays "Tillbaka"', (
    tester,
  ) async {
    await openChat(tester);
    expect(find.byTooltip(sv.commonBack), findsOneWidget);
  });

  Future<void> openUnknownRoute(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        onGenerateRoute: AppRouter.generateRoute,
        initialRoute: '/finns-inte',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an unknown route shows the Swedish not-found page', (
    tester,
  ) async {
    await openUnknownRoute(tester, const Locale('sv'));
    expect(find.text(sv.errorPageNotFound), findsOneWidget);
    expect(find.text(sv.errorBackToStart), findsOneWidget);
    expect(find.textContaining('Unknown route'), findsNothing);
  });

  // The Swedish texts equal the literals they replaced, so only another
  // locale shows that the page reads them from the app's texts.
  testWidgets('the not-found page follows the app language', (tester) async {
    final en = lookupAppLocalizations(const Locale('en'));
    await openUnknownRoute(tester, const Locale('en'));
    expect(find.text(en.errorPageNotFound), findsOneWidget);
    expect(find.text(en.errorBackToStart), findsOneWidget);
  });
}
