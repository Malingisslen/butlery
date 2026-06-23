/// Widget tests for [RateLimitDialog] — the dialog shown when a user hits
/// an import rate limit. Verifies title/message rendering for every
/// `LimitType` branch, the retry-info copy across each duration bucket, the
/// alternative-action tiles (Try without AI / Manual import), and that the
/// future returned by `RateLimitDialog.show` resolves to the chosen
/// `FallbackAction`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/dialogs/rate_limit_dialog.dart';

/// Wraps a child in MaterialApp with the project's l10n delegates so the
/// dialog can resolve `context.l10n.*` keys.
Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

/// Trigger pattern lifted from confirmation_dialogs_test.dart — opens the
/// dialog from the surrounding BuildContext and pushes the result through
/// [onResult] so the test can assert on the resolved future value.
Widget _triggerButton({
  required Future<FallbackAction?> Function(BuildContext) openDialog,
  required void Function(FallbackAction?) onResult,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () async {
        final result = await openDialog(ctx);
        onResult(result);
      },
      child: const Text('Show'),
    ),
  );
}

RateLimitDenied _denied({
  required LimitType limitType,
  Duration retryAfter = const Duration(minutes: 5),
  FallbackAction suggestedAction = FallbackAction.retryLater,
}) {
  return RateLimitDenied(
    message: 'irrelevant — swedishMessage is what the dialog renders',
    retryAfter: retryAfter,
    limitType: limitType,
    suggestedAction: suggestedAction,
  );
}

void main() {
  group('RateLimitDialog title + icon per LimitType', () {
    testWidgets('perMinute renders rateLimitSlowDown title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.perMinute),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // sv: rateLimitSlowDown = "Sakta ner lite"
      expect(find.text('Sakta ner lite'), findsOneWidget);
      expect(find.byIcon(Icons.speed_outlined), findsOneWidget);
    });

    testWidgets('perDay renders rateLimitDailyQuota title with today icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.perDay),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Dagskvot uppnådd'), findsOneWidget);
      expect(find.byIcon(Icons.today_outlined), findsOneWidget);
    });

    testWidgets('llmDaily renders rateLimitAiLimit title with smart_toy icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.llmDaily),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('AI-gräns nådd'), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });

    testWidgets('costMonthly renders rateLimitAiBudget title with money icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.costMonthly),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('AI-budget förbrukad'), findsOneWidget);
      expect(find.byIcon(Icons.attach_money_outlined), findsOneWidget);
    });
  });

  group('retry info text per duration bucket', () {
    testWidgets('days bucket renders dialogRetryTomorrow', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(
                limitType: LimitType.perDay,
                retryAfter: const Duration(days: 1, hours: 2),
              ),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Försök igen imorgon'), findsOneWidget);
    });

    testWidgets('hours bucket renders dialogRetryInHours with count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(
                limitType: LimitType.perHour,
                retryAfter: const Duration(hours: 3),
              ),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // sv: dialogRetryInHours = "Försök igen om {hours} timme(ar)"
      expect(find.text('Försök igen om 3 timme(ar)'), findsOneWidget);
    });

    testWidgets('minutes bucket renders dialogRetryInMinutes with count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(
                limitType: LimitType.perMinute,
                retryAfter: const Duration(minutes: 7),
              ),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Försök igen om 7 minut(er)'), findsOneWidget);
    });

    testWidgets('seconds bucket renders dialogRetryInSeconds with count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(
                limitType: LimitType.perMinute,
                retryAfter: const Duration(seconds: 42),
              ),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Försök igen om 42 sekund(er)'), findsOneWidget);
    });
  });

  group('action buttons', () {
    testWidgets('always renders the localized Avbryt button', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.perMinute),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Avbryt'), findsOneWidget);
    });

    testWidgets(
      'shows the dialogRetryLater button only when suggestedAction is retryLater',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(
                  limitType: LimitType.perMinute,
                  suggestedAction: FallbackAction.retryLater,
                ),
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Försök senare'), findsOneWidget);
      },
    );

    testWidgets('hides the retry-later button for other suggested actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(
                limitType: LimitType.perMinute,
                suggestedAction: FallbackAction.skipLlm,
              ),
            ),
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Försök senare'), findsNothing);
    });

    testWidgets('tapping Avbryt resolves the future with null', (tester) async {
      FallbackAction? result = FallbackAction.retryLater; // sentinel
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _triggerButton(
            openDialog: (ctx) => RateLimitDialog.show(
              ctx,
              rateLimitResult: _denied(limitType: LimitType.perMinute),
            ),
            onResult: (v) {
              result = v;
              resolved = true;
            },
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(result, isNull);
    });

    testWidgets(
      'tapping the retry-later button resolves the future with FallbackAction.retryLater',
      (tester) async {
        FallbackAction? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.perMinute),
              ),
              onResult: (v) => result = v,
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Försök senare'));
        await tester.pumpAndSettle();

        expect(result, FallbackAction.retryLater);
      },
    );
  });

  group('alternative-action tiles', () {
    testWidgets(
      '"Try without AI" tile is shown for LLM limits when callback is provided',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.llmDaily),
                onTryWithoutAi: () {},
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Importera utan AI'), findsOneWidget);
        expect(find.text('Använder enklare extrahering'), findsOneWidget);
        expect(find.text('Alternativ:'), findsOneWidget);
      },
    );

    testWidgets(
      '"Try without AI" tile is hidden for non-LLM limits (perMinute)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.perMinute),
                onTryWithoutAi: () {},
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Importera utan AI'), findsNothing);
      },
    );

    testWidgets(
      '"Try without AI" tile is hidden when no callback is provided',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.llmDaily),
                // onTryWithoutAi omitted on purpose
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Importera utan AI'), findsNothing);
      },
    );

    testWidgets(
      'tapping "Try without AI" resolves with skipLlm AND fires the callback',
      (tester) async {
        var tryWithoutAiCalled = false;
        FallbackAction? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.llmDaily),
                onTryWithoutAi: () => tryWithoutAiCalled = true,
              ),
              onResult: (v) => result = v,
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Importera utan AI'));
        await tester.pumpAndSettle();

        expect(result, FallbackAction.skipLlm);
        expect(tryWithoutAiCalled, isTrue);
      },
    );

    testWidgets(
      '"Manual import" tile is shown whenever onManualImport is set',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.perMinute),
                onManualImport: () {},
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Manuell import'), findsOneWidget);
        expect(find.text('Markera ingredienser själv'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping "Manual import" resolves with useUserAssisted AND fires the callback',
      (tester) async {
        var manualImportCalled = false;
        FallbackAction? result;
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.perMinute),
                onManualImport: () => manualImportCalled = true,
              ),
              onResult: (v) => result = v,
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Manuell import'));
        await tester.pumpAndSettle();

        expect(result, FallbackAction.useUserAssisted);
        expect(manualImportCalled, isTrue);
      },
    );

    testWidgets(
      'when no alternative callbacks are provided, the Alternativ heading is hidden',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            _triggerButton(
              openDialog: (ctx) => RateLimitDialog.show(
                ctx,
                rateLimitResult: _denied(limitType: LimitType.perMinute),
              ),
              onResult: (_) {},
            ),
          ),
        );
        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(find.text('Alternativ:'), findsNothing);
        expect(find.text('Importera utan AI'), findsNothing);
        expect(find.text('Manuell import'), findsNothing);
      },
    );
  });
}
