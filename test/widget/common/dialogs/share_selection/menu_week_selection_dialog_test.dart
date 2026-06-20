import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/utils/iso_week_utils.dart';
import 'package:butlery/widgets/common/dialogs/share_selection/menu_week_selection_dialog.dart';

import '../../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  // A fixed Wednesday so "today" sits unambiguously inside one ISO week.
  final fixedNow = DateTime(2026, 6, 17, 12);

  Future<DateTime?> openDialog(WidgetTester tester) async {
    DateTime? result;
    await tester.pumpWidget(createLocalizedTestApp(
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await showDialog<DateTime>(
              context: context,
              builder: (_) => const MenuWeekSelectionDialog(),
            );
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('renders four week options with the current week marked',
      (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      await openDialog(tester);

      expect(find.byType(RadioListTile<DateTime>), findsNWidgets(4));
      // Exactly one option carries the "(denna vecka)" suffix.
      expect(find.textContaining('denna vecka'), findsOneWidget);
    });
  });

  testWidgets('returns the current week start when shared without changing',
      (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      // Capture the dialog result by reopening after the pop completes.
      DateTime? captured;
      await tester.pumpWidget(createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showDialog<DateTime>(
                context: context,
                builder: (_) => const MenuWeekSelectionDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dela'));
      await tester.pumpAndSettle();

      expect(captured, equals(IsoWeekUtils.weekStartOf(fixedNow)));
    });
  });

  testWidgets('returns the chosen week when a different option is selected',
      (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      DateTime? captured;
      await tester.pumpWidget(createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showDialog<DateTime>(
                context: context,
                builder: (_) => const MenuWeekSelectionDialog(),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // First option = last week (today - 7d).
      await tester.tap(find.byType(RadioListTile<DateTime>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dela'));
      await tester.pumpAndSettle();

      expect(
        captured,
        equals(IsoWeekUtils.weekStartOf(
            fixedNow.subtract(const Duration(days: 7)))),
      );
    });
  });

  testWidgets('returns null when cancelled', (tester) async {
    await withClock(Clock.fixed(fixedNow), () async {
      bool closed = false;
      DateTime? captured;
      await tester.pumpWidget(createLocalizedTestApp(
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await showDialog<DateTime>(
                context: context,
                builder: (_) => const MenuWeekSelectionDialog(),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Avbryt'));
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(captured, isNull);
    });
  });
}
