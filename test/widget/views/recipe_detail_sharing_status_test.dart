/// BUT-1785 / BUT-1797 — the copy on the sharing panel must describe what the
/// button actually does.
///
/// History, because the assertions only make sense with it. Removing a MEMBER
/// always revoked. Removing a GROUP did not: access lives in
/// `socialData.memberPermissions`, a group share expanded into individual
/// entries, and `removeGroup` only dropped the group id from
/// `socialData.categoryIds` — a display field. So the copy was deliberately
/// split, and the group dialog refused to promise a revocation it could not
/// perform.
///
/// BUT-1797 gave the document the provenance it lacked (`socialData.grants`),
/// and the group branch now genuinely revokes. The copy split SURVIVES, for a
/// new reason: a member who also holds a direct share keeps access (Malin,
/// 2026-08-03), so the group dialog must still say something the member dialog
/// does not.
///
/// Nothing else under `test/` renders this widget, so the whole copy split
/// could revert with every suite green. That is what this file exists to stop.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_sharing_status.dart';

import '../../infrastructure/mocks/production_mocks.dart';

const _ownerId = 'owner_1';
const _memberId = 'member_1';
const _groupId = 'group_1';

Recipe _sharedRecipe() => Recipe(
  core: RecipeCore(
    id: 'recipe_1',
    title: 'Delad middag',
    description: '',
    ingredients: const [],
    instructions: const [],
    mealType: 'Middag',
    createdBy: _ownerId,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  ),
  type: RecipeType.collaborative,
  socialData: const RecipeSocialData(
    ownerId: _ownerId,
    memberPermissions: {_memberId: ResourcePermission.editor},
    categoryIds: [_groupId],
  ),
);

/// The revoke button inside the row that renders [name].
///
/// `find.byIcon(Icons.close)` is not enough: the panel renders a third close
/// icon outside the two sharee rows, and `.first`/`.last` on it silently
/// depends on paint order. Scoping by the row's own text makes the two rows
/// individually addressable and the test independent of layout.
Finder _revokeButtonInRowNamed(String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
  matching: find.byType(IconButton),
);

void main() {
  setUpAll(() {
    production.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() {
    for (final unregister in [
      () => GetIt.instance.unregister<PermissionService>(),
      () => GetIt.instance.unregister<UnifiedFriendsService>(),
      () => GetIt.instance.unregister<UnifiedRecipeService>(),
    ]) {
      try {
        unregister();
      } catch (_) {
        // not registered by this test
      }
    }
  });

  /// Returns the panel's OWN `AppLocalizations`, so a test can assert against
  /// the string the app would render instead of a copy of it pasted into the
  /// test. A reworded button label then does not redden a test about routing.
  Future<AppLocalizations> pumpPanel(
    WidgetTester tester, {
    String asUser = _ownerId,
    bool revokeSucceeds = true,
  }) async {
    final permissions = FakePermissionService();
    permissions.setPermissionState(
      currentUserId: asUser,
      userDisplayName: 'Malin',
    );
    if (GetIt.instance.isRegistered<PermissionService>()) {
      GetIt.instance.unregister<PermissionService>();
    }
    GetIt.instance.registerSingleton<PermissionService>(permissions);

    final friends = MockUnifiedFriendsService();
    if (GetIt.instance.isRegistered<UnifiedFriendsService>()) {
      GetIt.instance.unregister<UnifiedFriendsService>();
    }
    GetIt.instance.registerSingleton<UnifiedFriendsService>(friends);

    // Its `social` is FakeSocialRecipeOperations. The asymmetry is deliberate
    // and load-bearing: `removeGroup` answers this flag while `removeMember` is
    // hardcoded true, which is the ONLY thing that lets a routing test tell the
    // two apart. Do not "harmonise" them.
    final recipes = MockUnifiedRecipeService();
    recipes.mockSocial.setSocialState(shouldSucceed: revokeSucceeds);
    if (GetIt.instance.isRegistered<UnifiedRecipeService>()) {
      GetIt.instance.unregister<UnifiedRecipeService>();
    }
    GetIt.instance.registerSingleton<UnifiedRecipeService>(recipes);

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    late AppLocalizations l10n;

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
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context);
              return SingleChildScrollView(
                child: RecipeDetailSharingStatus(
                  recipe: _sharedRecipe(),
                  onSharingChanged: () {},
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return l10n;
  }

  testWidgets('the GROUP row keeps its own copy, distinct from a member row', (
    tester,
  ) async {
    final l10n = await pumpPanel(tester);

    // Scope the tap to the GROUP row specifically. Neither friend nor group is
    // registered in the mock, so each row falls back to rendering its raw id —
    // which makes the two rows individually addressable.
    await tester.tap(_revokeButtonInRowNamed(_groupId));
    await tester.pumpAndSettle();

    expect(
      find.text('Ta bort gruppens åtkomst'),
      findsWidgets,
      reason:
          'the group dialog must name what it actually does — the title and '
          'the confirm button are what the user reads while deciding',
    );
    expect(
      find.text('Ta bort delning'),
      findsNothing,
      reason:
          'a member row and a group row do different things; one label for '
          'both hides the difference at the moment of deciding',
    );
    // The confirm body must carry the carve-out AT THE DECISION POINT — the
    // same argument this widget makes about its own title: a snackbar afterwards
    // cannot undo a promise already made. Resolved from the panel's own
    // localization so rewording is free; what is pinned is that the group branch
    // renders the group confirm string and not the member one.
    expect(
      find.text(l10n.recipeSharingRevokeGroupConfirm(_groupId)),
      findsOneWidget,
    );
    expect(find.text(l10n.recipeSharingRevokeConfirm(_groupId)), findsNothing);

    // What this test pins, precisely: revert the COPY and it reddens. Revert the
    // CODE and it does not — it opens the dialog and never confirms, so
    // `removeGroup` is never called. The code half is pinned in
    // recipe_share_grants_test.dart and recipe_member_manager_test.dart; the two
    // halves meet in the success-message test below, which does confirm. (An
    // earlier version of this comment claimed one assertion caught both
    // directions. It never could.)
  });

  testWidgets(
    'the GROUP success message reports through the group key, and never '
    'claims its members keep access',
    (tester) async {
      // The snackbar is the ONLY place the app says what the revoke actually
      // did. Until BUT-1797 that sentence told the user the group's members
      // still had access — true then, false now — and nothing under `test/`
      // rendered it, so the retracted claim could come back green.
      final l10n = await pumpPanel(tester);

      await tester.tap(_revokeButtonInRowNamed(_groupId));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.recipeSharingRemoveGroup),
      );
      await tester.pumpAndSettle();

      // Resolved from the panel's own localization, so rewording the sentence
      // does not redden this. What it pins is the routing: the group branch
      // must report with the GROUP key, not the member one.
      expect(
        find.text(l10n.recipeSharingRevokeGroupSuccess(_groupId)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.recipeSharingRevokeSuccess(_groupId)),
        findsNothing,
        reason:
            'the member message says only that sharing stopped; using it here '
            'would hide that someone with a direct share still has access',
      );

      // This file hardcodes five Swedish literals. Four ('Ta bort gruppens åtkomst' and
      // 'Ta bort delning', each positive and negative) pin the LABELS, and are
      // meant to redden on a rename — the copy split is the thing they guard.
      //
      // This one is different, and it is the only one aimed at RETRACTED copy
      // rather than current copy: the sentence may be rewritten freely, but it
      // may not go back to promising that the group's members keep access.
      expect(
        find.textContaining('fortfarande åtkomst'),
        findsNothing,
        reason:
            'BUT-1785 copy — the revoke is real now, so this sentence would be '
            'a lie about what just happened',
      );
    },
  );

  testWidgets(
    'the GROUP row routes to removeGroup, not the user-keyed removeMember',
    (tester) async {
      // BUT-1785 was exactly this mis-route: a group id sent to the user-keyed
      // `removeMember`, which fails every time. Nothing here could catch its
      // return, because the panel picks BOTH the call and the snackbar key from
      // the same `isGroup` flag — so a mis-routed call still rendered the group
      // success copy.
      //
      // Arming the fake to FAIL is what discriminates: only `removeGroup`
      // answers `shouldSucceed`, while `removeMember` is hardcoded true. If the
      // group row is re-routed, the success copy appears and this reddens.
      final l10n = await pumpPanel(tester, revokeSucceeds: false);

      await tester.tap(_revokeButtonInRowNamed(_groupId));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, l10n.recipeSharingRemoveGroup),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.commonUnknownError), findsOneWidget);
      expect(
        find.text(l10n.recipeSharingRevokeGroupSuccess(_groupId)),
        findsNothing,
        reason: 'a failed revoke must never report success',
      );
    },
  );

  testWidgets('a non-owner sees no sharee roster and no revoke buttons', (
    tester,
  ) async {
    // The panel is built unconditionally by both call sites, so this early
    // return is the only thing keeping a SHAREE from seeing everyone else the
    // recipe is shared with — and a revoke button for each of them.
    await pumpPanel(tester, asUser: _memberId);

    expect(find.text(_memberId), findsNothing);
    expect(find.text(_groupId), findsNothing);
    expect(find.byIcon(Icons.share_outlined), findsNothing);
    // The title says "no revoke buttons", so assert them rather than implying
    // them from the roster being absent.
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('the MEMBER row still says "remove sharing"', (tester) async {
    await pumpPanel(tester);

    await tester.tap(_revokeButtonInRowNamed(_memberId));
    await tester.pumpAndSettle();

    expect(
      find.text('Ta bort delning'),
      findsWidgets,
      reason:
          'removing a member DOES revoke access — the asymmetry between the '
          'two rows is the decision, so a blanket rename would be just as '
          'wrong as no rename at all',
    );
    expect(find.text('Ta bort gruppens åtkomst'), findsNothing);
  });
}
