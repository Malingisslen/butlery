/// P5-U06 (import-av-recept ERROR): a failed import is three-part and draws
/// the other routes.
///
/// Sources: content-style-guide.md:87-97 (what happened, what was kept, what
/// you can do; never OK), produktregler.md:555-561 (9.2: Fel carries
/// availableStrategies and the list is drawn; Kvot slut draws its suggested
/// action, not "försök senare"), Skarmar v12 etapp 4 import #impinget ("Andra
/// vägar till samma recept").
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';
import 'package:butlery/views/smart_import/import_widgets.dart';
import 'package:butlery/widgets/common/dialogs/rate_limit_dialog.dart';
import 'package:butlery/widgets/common/feedback/inline_error.dart';

import '../../infrastructure/factories/recipe_factory.dart';

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

final _sv = AppLocalizationsSv();

Widget _app(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  routes: {Routes.recipeDetail: (_) => const Text('detail')},
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  setUpAll(() {
    registerFallbackValue(RecipeFactory.build());
  });

  group('the import error', () {
    for (final (mode, theme) in [
      ('light', AppTheme.lightTheme),
      ('dark', AppTheme.darkTheme),
    ]) {
      testWidgets('says what happened, what was kept, and draws the other '
          'routes ($mode)', (tester) async {
        final tapped = <ImportRoute>[];
        await tester.pumpWidget(
          _app(
            ImportErrorMessage(
              message: _sv.importErrorLoginRequired,
              preserved: _sv.importFailurePreservedLink,
              routes: const [
                ImportRoute.photo,
                ImportRoute.pasteText,
                ImportRoute.manual,
              ],
              onRoute: tapped.add,
            ),
            theme: theme,
          ),
        );

        final error = tester.widget<InlineError>(find.byType(InlineError));
        expect(error.what, _sv.importErrorLoginRequired);
        expect(error.preserved, _sv.importFailurePreservedLink);
        expect(
          find.text(_sv.importFailureOtherRoutes.toUpperCase()),
          findsOneWidget,
        );
        // The heading is text.secondary in both modes (tokens.json:62-65).
        final heading = tester.widget<Text>(
          find.text(_sv.importFailureOtherRoutes.toUpperCase()),
        );
        expect(heading.style?.color, theme.colorScheme.onSurfaceVariant);
        expect(find.text(_sv.importRoutePhoto), findsOneWidget);
        expect(find.text(_sv.importRoutePasteText), findsOneWidget);
        expect(find.text(_sv.importAddManually), findsOneWidget);
        expect(find.text('OK'), findsNothing);

        for (final route in ImportRoute.values) {
          await tester.tap(find.byKey(ImportErrorMessage.routeKey(route)));
        }
        expect(tapped, ImportRoute.values);
      });
    }

    testWidgets('without routes there is no heading', (tester) async {
      await tester.pumpWidget(
        _app(
          ImportErrorMessage(
            message: _sv.importSavedForLater,
            routes: const [],
            onRoute: (_) {},
          ),
        ),
      );

      expect(
        find.text(_sv.importFailureOtherRoutes.toUpperCase()),
        findsNothing,
      );
    });
  });

  group('a refused duplicate merge', () {
    testWidgets('says the existing recipe is unchanged, and Försök igen '
        'saves the same merge again', (tester) async {
      final service = _MockRecipeService();
      var calls = 0;
      when(() => service.updateRecipe(any())).thenAnswer((_) async {
        calls++;
        return calls > 1;
      });
      final merged = RecipeFactory.build(title: 'Pannkakor');

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => ImportResultHandler.saveMergeAndOpen(
                context,
                service,
                merged,
              ),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.textContaining(_sv.duplicateMergeFailed), findsOneWidget);
      expect(
        find.textContaining(_sv.duplicateMergeFailedPreserved),
        findsOneWidget,
      );
      expect(find.text('OK'), findsNothing);

      await tester.tap(find.text(_sv.commonRetry));
      await tester.pumpAndSettle();

      expect(calls, 2);
      verify(() => service.updateRecipe(merged)).called(2);
      expect(find.text('detail'), findsOneWidget);
    });
  });

  group('a quota stop', () {
    testWidgets('draws its suggested action, and no "Försök senare" unless '
        'that is the suggestion (produktregler.md:560)', (tester) async {
      await tester.pumpWidget(
        _app(
          RateLimitDialog(
            rateLimitResult: const RateLimitDenied(
              message: 'llm daily',
              retryAfter: Duration(hours: 3),
              limitType: LimitType.llmDaily,
              suggestedAction: FallbackAction.skipLlm,
            ),
            // As the import view passes them.
            onTryWithoutAi: () {},
            onManualImport: () {},
          ),
        ),
      );

      expect(find.text(_sv.dialogImportWithoutAi), findsOneWidget);
      expect(find.text(_sv.dialogRetryLater), findsNothing);
    });
  });
}
