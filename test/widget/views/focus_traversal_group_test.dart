// BUT-1307 (BUT-701 follow-up) + BUT-1309 (BUT-1307 follow-up): behavioural
// guard for keyboard tab-order on the named form views touched by the BUT-701
// a11y pass (account_security, edit_recipe, email_verification).
//
// Intent: a keyboard / external-keyboard / switch-access user must be able to
// press Tab and walk a form's interactive controls in visual (reading) order.
// These tests prove that contract by actually focusing the top control, pressing
// the physical Tab key, and asserting the controls receive focus strictly
// top-to-bottom.
//
// IMPORTANT — what this does and does NOT guard. BUT-701 wrapped these forms in
// a FocusTraversalGroup, but in a simple top-to-bottom Column that wrapper is a
// no-op for observable Tab order: Flutter's default reading-order policy already
// walks the controls in the same order, so removing the wrapper does not change
// what these tests see. (Verified by removing the wrapper — the test stays
// green.) The wrapper only matters once there are focusable siblings OUTSIDE the
// group to escape to, or a custom ordering policy — neither exists here. So these
// tests guard the USER-FACING contract (Tab walks controls in reading order),
// which is what BUT-701 was for, rather than the presence of a specific widget.
// They would catch a real regression: a relayout that scattered the controls out
// of reading order, or a custom traversal policy with wrong indices.
//
// This replaces a rejected source-grep test that read each view's .dart file as
// text and asserted `source.contains('FocusTraversalGroup(')` plus an intent
// comment. That gave ZERO behavioural coverage: it stayed green when a custom
// policy regressed the order and broke on harmless refactors (renamed comment,
// extracted widget). Only a real keypress proves the keyboard user can tab
// through the form.
//
// BUT-1309 extends the original single-view pin (account_security) to the other
// two named form views BUT-701 touched. The three views differ in control type:
// account_security & edit_recipe are TextField-rich forms; email_verification is
// a button-only screen (resend + continue). Rather than five near-identical
// TextField-only tests, the shared `expectTabWalksControlsTopToBottom` harness
// asserts reading-order over ALL focusable, on-screen controls — so it covers
// text fields AND buttons with one contract.

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/social_recipe_service.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/views/settings/account_security_view.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/views/auth/email_verification_view.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart' as mocks;
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

/// Shared harness: focus the top-most focusable control, press Tab repeatedly,
/// and assert each control is reached strictly top-to-bottom (visual reading
/// order). Works for any view whose group contains focusable controls with a
/// distinct on-screen vertical position — text fields, buttons, or a mix.
///
/// [minControls] guards against the harness silently passing on a view that
/// failed to render its controls (e.g. a setup regression that left the form
/// empty): with too few controls there is no order to prove.
Future<void> expectTabWalksControlsTopToBottom(
  WidgetTester tester, {
  required String viewName,
  int minControls = 2,
}) async {
  // Resolve a focus node's SCROLL-INDEPENDENT vertical position within the
  // document, or null if it is unmounted / unsized.
  //
  // Why not the raw global Y: tabbing into a control below the fold scrolls the
  // viewport (Flutter's ensureVisible), which shifts every control's measured
  // global Y — it can even go negative for controls scrolled above the top fold.
  // Comparing global Y values captured under different scroll offsets is not a
  // stable proxy for reading order: a multi-line field, or a scroll that lands a
  // later field higher on screen than an earlier one, can invert two adjacent
  // measurements and false-fail a perfectly correct order (this bit the
  // scrolling edit_recipe form specifically — see BUT-1307 review).
  //
  // Instead we project the control's position into the enclosing Scrollable's
  // CONTENT coordinate space: contentY = (control global dy) - (viewport global
  // dy) + (current scroll offset). That value is invariant under scrolling, so
  // it reflects the control's true document position regardless of where the
  // viewport happens to be when the control is first focused. For a view with no
  // Scrollable ancestor (the button-only email_verification screen never
  // scrolls) we fall back to the raw global Y, which is already stable there.
  double? topOf(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;
    final globalDy = renderObject.localToGlobal(Offset.zero).dy;

    // Use the nearest VERTICAL Scrollable. A horizontal inner scroller (e.g. a
    // chip row) must not contribute its horizontal offset to a vertical
    // coordinate, so walk up to the first axis-vertical Scrollable.
    final scrollableState = Scrollable.maybeOf(ctx, axis: Axis.vertical);
    if (scrollableState == null) return globalDy;
    final viewportBox =
        scrollableState.context.findRenderObject() as RenderBox?;
    if (viewportBox == null || !viewportBox.hasSize) return globalDy;
    final viewportDy = viewportBox.localToGlobal(Offset.zero).dy;
    return globalDy - viewportDy + scrollableState.position.pixels;
  }

  // We assert reading order over the form's PRIMARY controls. For the text-field
  // forms (account_security, edit_recipe) those are the TextFields: each
  // password field also carries a same-row show/hide IconButton whose render box
  // sits at a different vertical centre than the field, so including buttons
  // would create spurious up/down zig-zags that say nothing about reading order.
  // For the button-only screen (email_verification) there are no text fields, so
  // the primary controls ARE the buttons — we fall back to every focusable node.
  //
  // Build the set of primary-control focus nodes by walking the live element
  // tree for EditableText (the inner widget of every TextField/TextFormField);
  // its enclosing Focus node is what traversal actually lands on.
  final textFieldNodes = <FocusNode>{};
  for (final element in find.byType(EditableText).evaluate()) {
    textFieldNodes.add((element.widget as EditableText).focusNode);
  }
  final trackTextFieldsOnly = textFieldNodes.isNotEmpty;

  bool isPrimary(FocusNode? node) {
    if (node == null) return false;
    if (trackTextFieldsOnly) return textFieldNodes.contains(node);
    return node.canRequestFocus && !node.skipTraversal;
  }

  // Sanity-check there are enough on-screen primary controls to prove an order
  // (guards against a setup regression that left the form empty / unrendered).
  final onScreenPrimary = trackTextFieldsOnly
      ? textFieldNodes.where((n) => topOf(n) != null).length
      : FocusManager.instance.rootScope.traversalDescendants
            .where((n) => isPrimary(n) && topOf(n) != null)
            .length;
  expect(
    onScreenPrimary,
    greaterThanOrEqualTo(minControls),
    reason:
        '$viewName: need at least $minControls focusable primary controls '
        'to prove Tab order; found $onScreenPrimary.',
  );

  // Press Tab and record each PRIMARY control's document position the FIRST time
  // focus lands on it, for exactly ONE traversal cycle. We key cycle detection
  // and de-duplication on focus-node IDENTITY, not on position. Each control's
  // position comes from topOf(), which projects into the Scrollable's content
  // space and is therefore invariant under the viewport scrolling that Tab
  // triggers when it focuses a control below the fold — so the recorded sequence
  // reflects true document order, not where the viewport happened to be. We stop
  // as soon as focus returns to the first primary control we saw — one full
  // loop. The cap (80) is a safety net against a stuck traversal.
  final visitedTops = <double>[];
  final seenNodes = <FocusNode>{};
  FocusNode? cycleStart;
  for (var i = 0; i < 80; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final focused = FocusManager.instance.primaryFocus;
    if (!isPrimary(focused) || focused == null) continue;
    cycleStart ??= focused;
    // Returned to the cycle's first control → one full loop recorded.
    if (focused == cycleStart && seenNodes.isNotEmpty) break;
    if (seenNodes.add(focused)) {
      final top = topOf(focused);
      if (top != null) visitedTops.add(top);
    }
  }

  // Tab reached a meaningful number of distinct controls (proves the group is
  // actually traversable, not stuck on one field)…
  final distinctTops = visitedTops.toSet();
  expect(
    distinctTops.length,
    greaterThanOrEqualTo(minControls),
    reason:
        '$viewName: Tab should walk through at least $minControls controls; '
        'only reached ${distinctTops.length} distinct positions. A stuck '
        'traversal means the keyboard user cannot move through the form. '
        'Visited: $visitedTops',
  );

  // …strictly top-to-bottom within that single cycle — the BUT-701 reading-order
  // contract. Because the positions are scroll-independent document coordinates,
  // the recorded sequence must be monotonically non-decreasing: any backwards
  // step means Tab jumped up the document mid-form (a custom policy with wrong
  // indices, or a removed wrapper that let Flutter pick a surprising order), so
  // keyboard / external-keyboard / switch-access users would jump around
  // unpredictably. Equal positions are allowed (same-row siblings).
  final sortedTops = [...visitedTops]..sort();
  expect(
    visitedTops,
    sortedTops,
    reason:
        '$viewName: Tab must visit controls in visual (reading) order over '
        'one traversal cycle, but the order was not top-to-bottom (BUT-701 '
        'regression). Visited: $visitedTops',
  );
}

void main() {
  group('FocusTraversalGroup keyboard tab-order (BUT-1307 / BUT-1309 / BUT-701)', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      production.ServiceLocator.initialize(DIContainer());
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      // The views resolve services from the ServiceLocator on construction:
      // AccountSecurityView/EmailVerificationView build their own VMs that need
      // AuthService; EditRecipeView builds a real RecipeFormViewModel +
      // CollaborativeStatusViewModel needing UnifiedRecipeService (registered by
      // default), SocialRecipeService, and PermissionService.
      TestServiceLocator.registerMock<AuthService>(
        MockFactory.createAuthService(
          isAuthenticated: true,
          userId: 'test-user-123',
        ),
      );
      TestServiceLocator.registerMock<PermissionService>(
        MockFactory.createPermissionService(currentUserId: 'test-user-123'),
      );
      TestServiceLocator.registerMock<SocialRecipeService>(
        MockFactory.createSocialRecipeService(),
      );
      // EditRecipeView resolves CollaborativeStatusViewModel from the locator in
      // initState; the test GetIt doesn't carry the production ui_module
      // registration, so register the real (no-arg) VM here — its deps
      // (SocialRecipeService, PermissionService) are mocked above.
      TestServiceLocator.registerFactory<CollaborativeStatusViewModel>(
        () => CollaborativeStatusViewModel(),
      );
      // RecipeFormViewModel's image manager resolves ImageUploadService on
      // construction; the real (no-arg) service resolves the already-registered
      // mock StorageService, so it's safe to register without uploading.
      TestServiceLocator.registerMock<ImageUploadService>(
        ImageUploadService(),
      );
      // EditRecipeView's body resolves these from the locator while building:
      // the offline indicator reads OfflineService (real no-arg singleton —
      // isOnline defaults true, so no banner), and PersonalTagSelector builds a
      // PersonalTagViewModel Consumer. The selector renders from the VM's
      // default (empty) state without calling the service during a static
      // render, so a mocked PersonalTagService is sufficient.
      final mockTagService = mocks.MockPersonalTagService();
      TestServiceLocator.registerMock<PersonalTagService>(mockTagService);
      // OfflineService is a singleton that otherwise builds a real
      // FirestoreRepository (→ Firebase.instance, which isn't initialised in
      // unit tests). Inject the test-registered mock repos so it constructs
      // against fakes; isOnline then defaults true so no offline banner renders.
      TestServiceLocator.registerMock<OfflineService>(
        OfflineService(
          firestoreRepository: TestServiceLocator.get<FirestoreRepository>(),
          authRepository: TestServiceLocator.get<AuthRepository>(),
        ),
      );
      TestServiceLocator.registerFactory<PersonalTagViewModel>(
        () => PersonalTagViewModel(service: mockTagService),
      );

      // NotificationPreferencesView.initState() calls
      // NotificationService.getPreferences(); the default registered mock
      // returns null for it, which would push the view into its error state
      // (only the retry button focusable). Stub it to return defaults so the
      // real toggles/pickers render and the harness can walk them.
      final mockNotificationService = mocks.MockNotificationService();
      when(() => mockNotificationService.getPreferences()).thenAnswer(
        (_) async => NotificationPreferences.defaults(),
      );
      TestServiceLocator.registerMock<NotificationService>(
        mockNotificationService,
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
      'Tab walks the account-security form controls in visual (reading) order',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AccountSecurityView(),
            // AccountSecurityView ships its own Scaffold.
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();

        // Five TextFields (current/new/confirm password, email-current-password,
        // new-email) plus interleaved show/hide IconButtons — all walked.
        await expectTabWalksControlsTopToBottom(
          tester,
          viewName: 'account_security',
        );
      },
    );

    testWidgets(
      'Tab walks the edit-recipe form controls in visual (reading) order',
      (tester) async {
        final Recipe recipe = RecipeFactory.build(
          id: 'recipe-but-1309',
          title: 'Testrecept',
          description: 'Beskrivning',
          ingredients: const ['Mjöl', 'Socker'],
          instructions: const ['Blanda', 'Grädda'],
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: EditRecipeView(recipe: recipe),
            // EditRecipeView ships its own Scaffold.
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();

        // The edit form is a ListView of TextFormFields (title, description,
        // portions, time, rating, source-url, dynamic ingredient/instruction
        // rows) plus buttons. Tab must walk the rendered controls top-to-bottom.
        await expectTabWalksControlsTopToBottom(
          tester,
          viewName: 'edit_recipe',
        );
      },
    );

    testWidgets(
      'Tab walks the email-verification controls in visual (reading) order',
      (tester) async {
        // BUT-1314: pin the clock so the minControls=2 floor is deterministic.
        // The screen's resend button is enabled iff clock.now() is past the
        // 60s resend cooldown since _lastResendTime; on a fresh mount
        // _lastResendTime is null so resend is enabled and BOTH buttons are
        // focusable. By running under a fixed clock, a future change that
        // starts the cooldown ON MOUNT (resend disabled at t=0, only the
        // continue button focusable) makes this case fail meaningfully on the
        // 2-control floor instead of depending on wall-clock timing.
        await withClock(Clock.fixed(DateTime(2026, 6, 15, 12)), () async {
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: const EmailVerificationView(email: 'test@example.com'),
              // EmailVerificationView ships its own Scaffold.
              wrapInScaffold: false,
            ),
          );
          // Not pumpAndSettle: the view runs a 5s verification poll Timer, so
          // the tree never reaches a steady state. A bounded pump renders the
          // controls without waiting on the recurring timer.
          await tester.pump();

          // This screen has no text fields — its focusable controls are the two
          // buttons (resend verification, continue). The shared harness asserts
          // the same reading-order contract over buttons.
          await expectTabWalksControlsTopToBottom(
            tester,
            viewName: 'email_verification',
          );
        });
      },
    );

    testWidgets(
      'Tab walks the notification-preferences controls in visual (reading) '
      'order',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const NotificationPreferencesView(),
            // NotificationPreferencesView ships its own Scaffold.
            wrapInScaffold: false,
          ),
        );
        // getPreferences() is stubbed to resolve immediately with defaults, so
        // settle lets the loading StateWidget swap for the rendered form.
        await tester.pumpAndSettle();

        // This settings form is a column of SwitchListTiles (master enable +
        // per-category toggles + sound/vibration) plus a digest dropdown — no
        // text fields, so the harness's button-fallback branch walks the
        // switches. The reading-order contract must hold over the toggles.
        await expectTabWalksControlsTopToBottom(
          tester,
          viewName: 'notification_preferences',
        );
      },
    );

    testWidgets(
      'Tab walks the skriv-sjalv (manual recipe) form controls in visual '
      '(reading) order',
      (tester) async {
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const SkrivSjalvReceptView(),
            // SkrivSjalvReceptView ships its own Scaffold.
            wrapInScaffold: false,
          ),
        );
        await tester.pumpAndSettle();

        // The manual recipe-entry form is a ListView of TextFormFields (title,
        // description, portions, time, dynamic ingredient/instruction rows,
        // rating, source-url) inside a FocusTraversalGroup. Tab must walk the
        // rendered text fields top-to-bottom.
        await expectTabWalksControlsTopToBottom(
          tester,
          viewName: 'skriv_sjalv_recept',
        );
      },
    );
  });
}
