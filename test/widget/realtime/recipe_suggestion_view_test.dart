// P5-U27b: one suggestion to a shared recipe, seen by the owner (who decides)
// and by the suggester (who only looks). produktregler.md:103 (kept 7 days),
// :241 (the owner accepts or dismisses); content-style-guide.md:87-97 (a
// failure says what did not happen, what is kept, and what to do).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/realtime/recipe_suggestion_view.dart';

import '../../infrastructure/di/test_service_locator.dart';

class _MockService extends Mock implements RecipeSuggestionService {}

final _suggestion = RecipeSuggestion(
  id: 's1',
  recipeId: 'r1',
  ownerId: 'owner',
  suggesterId: 'member',
  suggestion: const {'title': 'Pannkakor med sylt'},
  status: RecipeSuggestionStatus.pending,
  createdAt: DateTime.utc(2026, 9, 26, 10),
  expiresAt: DateTime.utc(2026, 10, 3, 10),
);

void main() {
  final l10n = AppLocalizationsSv();
  late _MockService service;

  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
    registerFallbackValue(_suggestion);
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    service = _MockService();
    when(() => service.diffAgainstLive(any())).thenAnswer(
      (_) async => const ConflictDiff([
        ConflictFieldDiff(
          fieldKey: 'title',
          localText: 'Pannkakor med sylt',
          remoteText: 'Pannkakor',
        ),
      ]),
    );
    when(() => service.accept(any())).thenAnswer((_) async {});
    when(() => service.dismiss(any())).thenAnswer((_) async {});
    TestServiceLocator.registerMock<RecipeSuggestionService>(service);
  });

  tearDown(() async {
    await TestServiceLocator.reset();
  });

  Future<void> open(
    WidgetTester tester, {
    required bool asOwner,
    ThemeData? theme,
    RecipeSuggestion? suggestion,
  }) async {
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
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => RecipeSuggestionView.show(
                context,
                suggestion ?? _suggestion,
                asOwner: asOwner,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('the owner sees what changes and accepts it', (tester) async {
    await open(tester, asOwner: true);

    expect(find.text(l10n.recipeSuggestionTitle), findsOneWidget);
    expect(find.text('Pannkakor med sylt'), findsOneWidget);
    // The field is named as a person reads it, never by its stored key.
    expect(find.text(l10n.recipeTitle), findsOneWidget);
    expect(find.text('title'), findsNothing);
    expect(find.text(l10n.recipeSuggestionSuggestedLabel), findsOneWidget);
    expect(find.text(l10n.recipeSuggestionCurrentLabel), findsOneWidget);

    await tester.tap(find.byKey(RecipeSuggestionView.acceptKey));
    await tester.pumpAndSettle();

    verify(() => service.accept(_suggestion)).called(1);
    verifyNever(() => service.dismiss(any()));
    expect(find.byType(RecipeSuggestionView), findsNothing);
    expect(find.text(l10n.recipeSuggestionAccepted), findsOneWidget);
  });

  // Q6-12 = B (produktbeslut 2026-09-27b): a suggestion the member replaced
  // with a newer edit says so, to the owner and to the member.
  final replaced = _suggestion.replacedWith(const {
    'title': 'Pannkakor med sylt och grädde',
  }, at: DateTime.utc(2026, 9, 27, 9));

  testWidgets('Q6-12: the owner is told the suggestion was updated', (
    tester,
  ) async {
    await open(tester, asOwner: true, suggestion: replaced);
    expect(
      find.textContaining(
        l10n
            .recipeSuggestionIntroOwnerUpdated(l10n.displayUnknownUser, '')
            .split('.')
            .first,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Q6-12: the member sees that it replaced the earlier one', (
    tester,
  ) async {
    await open(tester, asOwner: false, suggestion: replaced);
    expect(
      find.textContaining(
        l10n.recipeSuggestionIntroMineUpdated('').split('.').first,
      ),
      findsOneWidget,
    );
  });

  testWidgets('Q6-12: a suggestion replaced while open is not decided, and '
      'the owner is told to open it again', (tester) async {
    when(
      () => service.accept(any()),
    ).thenThrow(const RecipeSuggestionChanged('s1'));
    await open(tester, asOwner: true);
    await tester.tap(find.byKey(RecipeSuggestionView.acceptKey));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeSuggestionView), findsOneWidget);
    expect(
      find.textContaining(l10n.recipeSuggestionChangedSinceOpened),
      findsOneWidget,
    );
    // Deciding again here would decide on content the owner has not seen.
    expect(find.text(l10n.commonRetry), findsNothing);
  });

  testWidgets('the owner dismisses it, and the recipe is left alone', (
    tester,
  ) async {
    await open(tester, asOwner: true);
    await tester.tap(find.byKey(RecipeSuggestionView.dismissKey));
    await tester.pumpAndSettle();

    verify(() => service.dismiss(_suggestion)).called(1);
    verifyNever(() => service.accept(any()));
    expect(find.text(l10n.recipeSuggestionDismissed), findsOneWidget);
  });

  testWidgets('a failed accept says what is kept and offers Försök igen', (
    tester,
  ) async {
    when(() => service.accept(any())).thenThrow(StateError('offline'));
    await open(tester, asOwner: true);
    await tester.tap(find.byKey(RecipeSuggestionView.acceptKey));
    await tester.pumpAndSettle();

    expect(find.byType(RecipeSuggestionView), findsOneWidget);
    expect(
      find.textContaining(l10n.recipeSuggestionAcceptFailed),
      findsOneWidget,
    );
    expect(find.text(l10n.commonRetry), findsOneWidget);
  });

  testWidgets('a recipe that is gone gets Stäng, not a retry', (tester) async {
    when(
      () => service.accept(any()),
    ).thenThrow(const RecipeSuggestionTargetMissing('r1'));
    await open(tester, asOwner: true);
    await tester.tap(find.byKey(RecipeSuggestionView.acceptKey));
    await tester.pumpAndSettle();

    expect(find.text(l10n.recipeSuggestionRecipeGone), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsNothing);
    expect(find.text(l10n.commonClose), findsOneWidget);
  });

  testWidgets('the suggester looks but does not decide', (tester) async {
    await open(tester, asOwner: false);

    expect(find.text('Pannkakor med sylt'), findsOneWidget);
    expect(find.byKey(RecipeSuggestionView.acceptKey), findsNothing);
    expect(find.byKey(RecipeSuggestionView.dismissKey), findsNothing);
  });

  testWidgets('renders in dark mode with the dark tokens', (tester) async {
    await open(tester, asOwner: true, theme: AppTheme.darkTheme);
    expect(tester.takeException(), isNull);
    final scaffold = tester.widget<Scaffold>(
      find.descendant(
        of: find.byType(RecipeSuggestionView),
        matching: find.byType(Scaffold),
      ),
    );
    expect(scaffold.backgroundColor, AppTheme.darkTheme.colorScheme.surface);
  });
}
