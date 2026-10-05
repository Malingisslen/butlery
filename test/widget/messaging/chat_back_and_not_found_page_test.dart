// BUT-2146: the chat's back arrow names the view it returns to when the
// caller knows it, and the page for an unknown route speaks Swedish.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/router/app_router.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/messaging/chat_app_bar.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  final sv = lookupAppLocalizations(const Locale('sv'));

  Future<void> openChatBar(WidgetTester tester, {String? backTo}) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  appBar: ChatAppBar(backTo: backTo, onMenuAction: (_) {}),
                ),
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
    await openChatBar(tester, backTo: sv.messagingTitle);
    expect(find.byTooltip(sv.commonBackTo(sv.messagingTitle)), findsOneWidget);
  });

  testWidgets('without a known way back the arrow stays "Tillbaka"', (
    tester,
  ) async {
    await openChatBar(tester);
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
