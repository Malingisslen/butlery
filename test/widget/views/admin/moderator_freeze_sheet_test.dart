// BUT-2329: the reason sheet and the snackbar that answers a freeze.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/report_evidence.dart';
import 'package:butlery/services/moderation/moderation_appeals_service.dart';
import 'package:butlery/viewmodels/admin/freeze_result.dart';
import 'package:butlery/views/admin/moderator_freeze_sheet.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

final _sv = AppLocalizationsSv();

void main() {
  group('ModeratorFreezeSheet', () {
    Future<void> openSheet(
      WidgetTester tester, {
      FreezeReason? initial,
      void Function(FreezeReason?)? onResult,
    }) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final r = await showModeratorFreezeSheet(
                  context,
                  confirmLabel: 'Bekräfta',
                  initial: initial,
                );
                onResult?.call(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    ButtonStyleButton confirm(WidgetTester tester) =>
        tester.widget<ButtonStyleButton>(
          find.byKey(const ValueKey('freeze-confirm')),
        );

    testWidgets('confirm is disabled until a reason is picked', (
      tester,
    ) async {
      FreezeReason? result;
      var closed = false;
      await openSheet(
        tester,
        onResult: (r) {
          result = r;
          closed = true;
        },
      );

      expect(confirm(tester).onPressed, isNull);

      await tester.tap(find.text(_sv.moderatorFreezeReasonThreat));
      await tester.pumpAndSettle();
      expect(confirm(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const ValueKey('freeze-confirm')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, FreezeReason.threat);
    });

    testWidgets('an extension opens with the current reason preselected', (
      tester,
    ) async {
      FreezeReason? result;
      await openSheet(
        tester,
        initial: FreezeReason.legalClaim,
        onResult: (r) => result = r,
      );

      expect(confirm(tester).onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('freeze-confirm')));
      await tester.pumpAndSettle();
      expect(result, FreezeReason.legalClaim);
    });
  });

  group('showFreezeResult', () {
    Future<void> show(
      WidgetTester tester,
      FreezeResult result, {
      VoidCallback? retry,
    }) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showFreezeResult(context, result, retry: retry ?? () {}),
              child: const Text('go'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('a failure shows its text and retry calls back', (
      tester,
    ) async {
      var retried = 0;
      await show(tester, const FreezeFailed(), retry: () => retried++);

      expect(find.textContaining(_sv.moderatorFreezeFailed), findsOneWidget);
      await tester.tap(find.text(_sv.commonRetry));
      await tester.pump();
      expect(retried, 1);
    });

    testWidgets('an extension says until when', (tester) async {
      final until = DateTime(2028, 10, 9);
      await show(tester, FreezeSucceeded(FreezeOutcome(until: until)));

      expect(
        find.text(
          _sv.moderatorFreezeSaved(
            DateFormat.yMMMd(_sv.localeName).format(until),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a release that kept the copy says it follows the rules', (
      tester,
    ) async {
      await show(tester, const FreezeSucceeded(FreezeOutcome()));

      expect(find.text(_sv.moderatorFrozenReleasedKept), findsOneWidget);
    });

    testWidgets('a release that deleted the copy says so', (tester) async {
      await show(
        tester,
        const FreezeSucceeded(FreezeOutcome(deleted: true)),
      );

      expect(find.text(_sv.moderatorFrozenReleasedDeleted), findsOneWidget);
    });
  });
}
