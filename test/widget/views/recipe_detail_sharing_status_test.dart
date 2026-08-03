/// BUT-1785 / BUT-1797 — the copy on the sharing panel must not promise a
/// revocation that does not happen.
///
/// Removing a MEMBER really does revoke their access. Removing a GROUP does
/// not: access lives in `socialData.memberPermissions`, which a group share
/// expanded into individual entries, and `removeGroup` only drops the group id
/// from `socialData.categoryIds` — a display/filter field. The members keep
/// full access until they are removed one by one.
///
/// The body copy and the snackbar already said so. The dialog TITLE and the
/// CONFIRM BUTTON did not: both read "Ta bort delning" for either row, so the
/// user was told "remove sharing" twice at the moment of deciding and only
/// learned the truth afterwards, in a snackbar that disappears.
///
/// Nothing under `test/` rendered this widget, so the whole copy split could
/// revert with every suite green. That is what this file exists to stop.
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
    ]) {
      try {
        unregister();
      } catch (_) {
        // not registered by this test
      }
    }
  });

  Future<void> pumpPanel(WidgetTester tester) async {
    final permissions = FakePermissionService();
    permissions.setPermissionState(
      currentUserId: _ownerId,
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

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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
          body: SingleChildScrollView(
            child: RecipeDetailSharingStatus(
              recipe: _sharedRecipe(),
              onSharingChanged: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the GROUP row never offers to "remove sharing"', (tester) async {
    await pumpPanel(tester);

    // Scope the tap to the GROUP row specifically. Neither friend nor group is
    // registered in the mock, so each row falls back to rendering its raw id —
    // which makes the two rows individually addressable.
    await tester.tap(_revokeButtonInRowNamed(_groupId));
    await tester.pumpAndSettle();

    expect(
      find.text('Ta bort gruppen'),
      findsWidgets,
      reason:
          'the group dialog must name what it actually does — the title and '
          'the confirm button are what the user reads while deciding',
    );
    expect(
      find.text('Ta bort delning'),
      findsNothing,
      reason:
          'promising a revocation the code does not perform is worse than a '
          'visible failure, because the user stops looking',
    );
    // The body copy must still carry the caveat.
    expect(find.textContaining('från delningen'), findsOneWidget);
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
    expect(find.text('Ta bort gruppen'), findsNothing);
  });
}
