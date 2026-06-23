/// Widget tests for DraftRecoveryDialog.
///
/// Covers:
/// - The static `show()` helper short-circuits and returns null for empty input.
/// - Rendering: localized title/subtitle, one tile per draft, restore icon.
/// - Tapping a tile pops with that draft's id.
/// - Tapping the primary "Återställ" button pops with the FIRST draft id
///   (per production source: `availableDrafts.first.draftId`).
/// - Tapping "Börja om" pops with null.
/// - Unnamed drafts (empty title) show the localized fallback "Namnlöst recept".
/// - The DraftRecoveryDialogExtension forwards to the static helper.
///
/// Pattern: Builder + trigger button + future-resolution, lifted from
/// `confirmation_dialogs_test.dart`. l10n delegates are wired so
/// `context.l10n` resolves Swedish strings.
library;

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_auto_save_manager.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

DraftMetadata _draft({
  String id = 'd1',
  String title = 'Pannkakor',
  int fields = 3,
  DateTime? created,
  DateTime? modified,
}) {
  final now = DateTime(2026, 1, 1, 12);
  return DraftMetadata(
    draftId: id,
    createdAt: created ?? now,
    lastModifiedAt: modified ?? now,
    title: title,
    fieldCount: fields,
  );
}

Widget _trigger({
  required List<DraftMetadata> drafts,
  required void Function(String?) onResult,
}) {
  return Builder(
    builder: (ctx) => ElevatedButton(
      onPressed: () async {
        final r = await DraftRecoveryDialog.show(ctx, drafts);
        onResult(r);
      },
      child: const Text('Show'),
    ),
  );
}

void main() {
  group('DraftRecoveryDialog.show', () {
    testWidgets(
      'returns null immediately for empty draft list without showing',
      (tester) async {
        String? result = 'sentinel';
        var resolved = false;
        await tester.pumpWidget(
          _wrap(
            _trigger(
              drafts: const [],
              onResult: (v) {
                result = v;
                resolved = true;
              },
            ),
          ),
        );

        await tester.tap(find.text('Show'));
        await tester.pumpAndSettle();

        expect(resolved, isTrue);
        expect(result, isNull);
        // No dialog was pushed.
        expect(find.byType(AlertDialog), findsNothing);
      },
    );

    testWidgets('renders localized title and subtitle (Swedish)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [_draft()],
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Återställ utkast'), findsOneWidget);
      expect(
        find.text(
          'Du har osparade receptutkast. Vill du fortsätta där du slutade?',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders one tile per draft with title and field count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [
              _draft(id: 'a', title: 'Pannkakor', fields: 5),
              _draft(id: 'b', title: 'Köttbullar', fields: 2),
            ],
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(find.text('Köttbullar'), findsOneWidget);
      // Localized field count strings ("5 fält ifyllda", "2 fält ifyllda")
      // appear inside a composed `${timeAgo} • ${draftFieldsFilledCount}`
      // string — assert via predicate, not strict text equality.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('5 fält ifyllda'),
        ),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').contains('2 fält ifyllda'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('action buttons show the localized labels', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [_draft()],
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Börja om'), findsOneWidget);
      expect(find.text('Återställ'), findsOneWidget);
    });

    testWidgets('tapping "Börja om" resolves the future with null', (
      tester,
    ) async {
      String? result = 'sentinel';
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [_draft(id: 'a')],
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Börja om'));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });

    testWidgets('tapping "Återställ" pops with the FIRST draft id', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [
              _draft(id: 'first-id'),
              _draft(id: 'second-id'),
            ],
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Återställ'));
      await tester.pumpAndSettle();

      expect(result, 'first-id');
    });

    testWidgets('tapping a specific tile pops with that draft id', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [
              _draft(id: 'first-id', title: 'Pannkakor'),
              _draft(id: 'second-id', title: 'Köttbullar'),
            ],
            onResult: (v) => result = v,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap the second tile via its title text.
      await tester.tap(find.text('Köttbullar'));
      await tester.pumpAndSettle();

      expect(result, 'second-id');
    });

    testWidgets('empty title falls back to localized "Namnlöst recept"', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [_draft(id: 'a', title: '')],
            onResult: (_) {},
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Namnlöst recept'), findsOneWidget);
    });

    testWidgets('barrier is non-dismissible (tap outside does not close)', (
      tester,
    ) async {
      var resolved = false;
      await tester.pumpWidget(
        _wrap(
          _trigger(
            drafts: [_draft()],
            onResult: (_) => resolved = true,
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Tap a corner of the barrier (top-left).
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(resolved, isFalse);
    });
  });

  group('DraftRecoveryDialogExtension', () {
    testWidgets('context.showDraftRecovery delegates to the static helper', (
      tester,
    ) async {
      String? result;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () async {
                // Goes through the extension surface intentionally.
                final r = await ctx.showDraftRecovery([_draft(id: 'ext-id')]);
                result = r;
              },
              child: const Text('Show'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Same dialog, same primary action.
      await tester.tap(find.text('Återställ'));
      await tester.pumpAndSettle();

      expect(result, 'ext-id');
    });
  });
}
