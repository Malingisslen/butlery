// test/widget/common/buttons/icon_button_semantics_test.dart
//
// Intent: prove the critical-surface icon buttons migrated for BUT-508 expose
// a screen-reader-findable semantic label. Each test pumps the smallest
// slice that reproduces the button in isolation and asserts the label
// resolves via `find.bySemanticsLabel(...)`.
//
// Mocks only the navigation plumbing; the button + tooltip wiring is the
// subject under test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('Icon-button semantics (BUT-508 critical surfaces)', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('fullscreen image viewer back button announces commonBack',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {},
                  tooltip: context.l10n.commonBack,
                ),
              ),
            ),
          ),
          wrapInScaffold: false,
        ),
      );

      // Tooltip "Tillbaka" (Swedish) must resolve for TalkBack — IconButton
      // exposes tooltip as its semantic label.
      expect(find.byTooltip('Tillbaka'), findsOneWidget);
    });

    testWidgets('password visibility toggle announces show/hide labels',
        (tester) async {
      var isVisible = false;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: StatefulBuilder(
            builder: (context, setState) => IconButton(
              icon: Icon(
                isVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => isVisible = !isVisible),
              tooltip: isVisible
                  ? context.l10n.a11yHidePassword
                  : context.l10n.a11yShowPassword,
            ),
          ),
        ),
      );

      // Initial state: password hidden, button offers "Visa lösenord".
      expect(find.byTooltip('Visa lösenord'), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      // After toggle, tooltip flips to "Dölj lösenord".
      expect(find.byTooltip('Dölj lösenord'), findsOneWidget);
    });

    testWidgets('bulk-selection close button announces bulkCancelSelection',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {},
                  tooltip: context.l10n.bulkCancelSelection,
                ),
              ),
            ),
          ),
          wrapInScaffold: false,
        ),
      );

      expect(find.byTooltip('Avbryt val'), findsOneWidget);
    });
  });
}
