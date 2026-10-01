// Q6-12 = B (produktbeslut 2026-09-27b): when a member edits again while a
// suggestion waits, the new one replaces it, and the owner is told in the
// suggestion line of recipe detail that it was updated. Which suggestions
// were replaced comes from the stored `replacedAt`, never from their text or
// position.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/realtime/recipe_suggestion_notice.dart';

import '../../infrastructure/di/test_service_locator.dart';

class _MockService extends Mock implements RecipeSuggestionService {}

RecipeSuggestion _pending(String id, String suggester) => RecipeSuggestion(
  id: id,
  recipeId: 'r1',
  ownerId: 'owner',
  suggesterId: suggester,
  suggestion: const {'title': 'Pannkakor med sylt'},
  status: RecipeSuggestionStatus.pending,
  // Far ahead, so the rows are still kept whatever the test clock says.
  createdAt: DateTime.utc(2099, 1, 1),
  expiresAt: DateTime.utc(2099, 1, 8),
);

void main() {
  final l10n = AppLocalizationsSv();
  late _MockService service;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    service = _MockService();
    TestServiceLocator.registerMock<RecipeSuggestionService>(service);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  Future<void> pump(
    WidgetTester tester,
    List<RecipeSuggestion> rows, {
    ThemeData? theme,
  }) async {
    when(
      () => service.watchPendingToMe('r1'),
    ).thenAnswer((_) => Stream.value(rows));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? AppTheme.lightTheme,
        home: const Scaffold(
          body: RecipeSuggestionNotice(recipeId: 'r1', isOwner: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  final at = DateTime.utc(2099, 1, 2);

  testWidgets('one waiting suggestion that was replaced says it was updated', (
    tester,
  ) async {
    await pump(tester, [
      _pending('s1', 'member').replacedWith(const {}, at: at),
    ]);
    // No friends service: the name is unknown.
    expect(
      find.text(l10n.recipeSuggestionFromOneUpdatedUnnamed),
      findsOneWidget,
    );
    expect(find.text(l10n.recipeSuggestionFromOneUnnamed), findsNothing);
  });

  testWidgets('one that was never replaced says nothing about an update', (
    tester,
  ) async {
    await pump(tester, [_pending('s1', 'member')]);
    expect(find.text(l10n.recipeSuggestionFromOneUnnamed), findsOneWidget);
    expect(
      find.text(l10n.recipeSuggestionFromOneUpdatedUnnamed),
      findsNothing,
    );
  });

  testWidgets('"N förslag" counts how many of them were updated', (
    tester,
  ) async {
    await pump(tester, [
      _pending('s1', 'member').replacedWith(const {}, at: at),
      _pending('s2', 'member2'),
      _pending('s3', 'member3'),
    ]);
    expect(
      find.text(l10n.recipeSuggestionFromManyUpdated(3, 1)),
      findsOneWidget,
    );
  });

  testWidgets('"N förslag" without updates keeps its plain text', (
    tester,
  ) async {
    await pump(tester, [_pending('s1', 'member'), _pending('s2', 'member2')]);
    expect(find.text(l10n.recipeSuggestionFromMany(2)), findsOneWidget);
  });

  for (final (name, theme, tint, textColor) in [
    (
      'light',
      AppTheme.lightTheme,
      const Color(0xFFF0EEE2),
      const Color(0xFF37453A),
    ),
    (
      'dark',
      AppTheme.darkTheme,
      const Color(0xFF2F4437),
      const Color(0xFFF5F4ED),
    ),
  ]) {
    testWidgets('$name: surface.tint.warning fill, no border, text.body', (
      tester,
    ) async {
      await pump(tester, [_pending('s1', 'member')], theme: theme);

      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.text(l10n.recipeSuggestionFromOneUnnamed),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, tint);
      final shape = material.shape! as RoundedRectangleBorder;
      expect(shape.side, BorderSide.none);
      expect(
        tester
            .widget<Text>(find.text(l10n.recipeSuggestionFromOneUnnamed))
            .style!
            .color,
        textColor,
      );
    });
  }

  testWidgets('renders in dark mode too', (tester) async {
    await pump(tester, [
      _pending('s1', 'member').replacedWith(const {}, at: at),
    ], theme: AppTheme.darkTheme);
    expect(
      find.text(l10n.recipeSuggestionFromOneUpdatedUnnamed),
      findsOneWidget,
    );
  });
}
