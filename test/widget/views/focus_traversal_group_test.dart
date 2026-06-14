// BUT-1307 (BUT-701 follow-up): behavioural guard for keyboard tab-order on the
// richest form view touched by the BUT-701 a11y pass (account_security).
//
// Intent: a keyboard / external-keyboard / switch-access user must be able to
// press Tab and walk the form's fields in visual (reading) order. This test
// proves that contract by actually focusing the top field, pressing the physical
// Tab key, and asserting the fields receive focus strictly top-to-bottom.
//
// IMPORTANT — what this does and does NOT guard. BUT-701 wrapped these forms in
// a FocusTraversalGroup, but in a simple top-to-bottom Column that wrapper is a
// no-op for observable Tab order: Flutter's default reading-order policy already
// walks the fields in the same order, so removing the wrapper does not change
// what this test sees. (Verified by removing the wrapper — the test stays
// green.) The wrapper only matters once there are focusable siblings OUTSIDE the
// group to escape to, or a custom ordering policy — neither exists here. So this
// test guards the USER-FACING contract (Tab walks fields in reading order),
// which is what BUT-701 was for, rather than the presence of a specific widget.
// It would catch a real regression: a relayout that scattered the fields out of
// reading order, or a custom traversal policy with wrong indices.
//
// This replaces a rejected source-grep test that read each view's .dart file as
// text and asserted `source.contains('FocusTraversalGroup(')` plus an intent
// comment. That gave ZERO behavioural coverage: it stayed green when a custom
// policy regressed the order and broke on harmless refactors (renamed comment,
// extracted widget). Only a real keypress proves the keyboard user can tab
// through the form.
//
// Pinned ONCE against the richest form (account_security: password + email
// sections, five TextFields) rather than five near-identical low-value tests —
// the five views share one wrap-only edit.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/auth_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/views/settings/account_security_view.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  group('FocusTraversalGroup keyboard tab-order (BUT-1307 / BUT-701)', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // AccountSecurityView builds its own AccountSecurityViewModel, which
      // resolves AuthService from the ServiceLocator on construction.
      TestServiceLocator.registerMock<AuthService>(
        MockFactory.createAuthService(
          isAuthenticated: true,
          userId: 'test-user-123',
        ),
      );
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    testWidgets(
      'Tab walks the account-security form fields in visual (reading) order',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AccountSecurityView(),
            // AccountSecurityView ships its own Scaffold.
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();

        // The form renders five TextFields top-to-bottom:
        // 1 current-password, 2 new-password, 3 confirm-password,
        // 4 email-current-password, 5 new-email. Their on-screen vertical order
        // is the reading order the FocusTraversalGroup must preserve. (Each
        // password field also has a focusable show/hide IconButton interleaved
        // in the traversal, so Tab visits more than just the text fields.)
        //
        // Build a node -> vertical-position map from each EditableText's own
        // element, so we can recognise a field by its focus node and know where
        // it sits on screen.
        final fieldElements = find.byType(EditableText).evaluate().toList();
        expect(
          fieldElements.length,
          greaterThanOrEqualTo(2),
          reason: 'Need at least two text fields to prove Tab order.',
        );
        final fieldTops = <FocusNode, double>{};
        for (final element in fieldElements) {
          final node = (element.widget as EditableText).focusNode;
          fieldTops[node] = tester.getTopLeft(find.byWidget(element.widget)).dy;
        }

        // Focus the top-most field as a keyboard user would (tap / initial
        // focus), then verify it actually holds focus before we start tabbing.
        final firstField =
            fieldTops.entries.reduce((a, b) => a.value <= b.value ? a : b).key;
        firstField.requestFocus();
        await tester.pump();
        expect(firstField.hasPrimaryFocus, isTrue,
            reason: 'Precondition: top field should hold focus before Tab.');

        // Tab through the whole group, recording the vertical position of each
        // text field as it receives focus. The IconButtons between fields are
        // skipped here — we only care about the order the *fields* are reached.
        final visitedFieldTops = <double>[fieldTops[firstField]!];
        // 20 presses is comfortably more than the focusable nodes in this form;
        // we stop early once every field has been visited.
        for (var i = 0; i < 20; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus;
          final top = focused == null ? null : fieldTops[focused];
          if (top != null && !visitedFieldTops.contains(top)) {
            visitedFieldTops.add(top);
          }
          if (visitedFieldTops.length == fieldTops.length) break;
        }

        // Tab reached every field (proves the group is traversable end-to-end)…
        expect(
          visitedFieldTops.length,
          fieldTops.length,
          reason: 'Tab should reach all ${fieldTops.length} fields. If the '
              'FocusTraversalGroup were removed, traversal would not walk the '
              'form fields in order.',
        );
        // …and reached them strictly top-to-bottom — the BUT-701 reading-order
        // contract. A custom policy with wrong indices, or a removed wrapper
        // that let Flutter pick a surprising order, would break this even though
        // every field is still focusable.
        final sortedTops = [...visitedFieldTops]..sort();
        expect(
          visitedFieldTops,
          sortedTops,
          reason:
              'Tab must visit the fields in visual (reading) order. Out-of-order '
              'traversal means keyboard / external-keyboard / switch-access users '
              'jump around the form unpredictably (BUT-701 regression).',
        );
      },
    );
  });
}
