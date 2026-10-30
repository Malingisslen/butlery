import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/viewmodels/shared_content/shared_recipe_viewmodel.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/social_factory.dart';
import '../../infrastructure/mocks/fallback_values.dart';

class _MockSharedRecipeViewModel extends Mock
    implements SharedRecipeViewModel {}

/// Counts subscriptions per stream so a rebuild that re-subscribes shows up.
class _Service extends Fake implements GroupSharedContentService {
  _Service({this.fail = false, this.recipesByGroup = const {}});
  bool fail;
  int recipeCalls = 0;
  final Map<String, List<SharedContentItem>> recipesByGroup;
  final List<String> recipeGroups = [];

  Stream<List<SharedContentItem>> _stream() => fail
      ? Stream.error(Exception('permission-denied'))
      : Stream.value(const []);

  @override
  Stream<List<SharedContentItem>> streamSharedRecipes(FriendCategory group) {
    recipeCalls++;
    recipeGroups.add(group.id);
    final recipes = recipesByGroup[group.id];
    return recipes == null ? _stream() : Stream.value(recipes);
  }

  @override
  Stream<List<SharedContentItem>> streamSharedMenus(FriendCategory group) =>
      _stream();

  @override
  Stream<List<SharedContentItem>> streamSharedShoppingLists(
    FriendCategory group,
  ) => _stream();
}

void main() {
  final sv = AppLocalizationsSv();

  setUpAll(() => production.ServiceLocator.initialize(DIContainer()));
  setUp(TestServiceLocator.initialize);
  tearDown(TestServiceLocator.reset);

  final group = SocialFactory.createFriendCategory(name: 'Klubben');

  Future<void> pump(
    WidgetTester tester,
    _Service service, {
    FriendCategory? shown,
  }) async {
    TestServiceLocator.registerMock<GroupSharedContentService>(service);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              height: 700,
              child: GroupSharedContentSection(group: shown ?? group),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  // BUT-2271: a refused query used to read as "Laddar delat innehåll …"
  // forever, because an errored stream has no data.
  testWidgets('a failed load says so, and "Försök igen" asks again', (
    tester,
  ) async {
    final service = _Service(fail: true);
    await pump(tester, service);

    expect(find.text(sv.groupSharedContentLoadFailed), findsOneWidget);
    expect(find.text(sv.sharedLoadingContent), findsNothing);

    service.fail = false;
    final before = service.recipeCalls;
    await tester.tap(find.text(sv.commonRetry));
    await tester.pump();
    await tester.pump();

    expect(service.recipeCalls, before + 1);
    expect(find.text(sv.groupSharedContentLoadFailed), findsNothing);
  });

  testWidgets('a rebuild does not subscribe again', (tester) async {
    final service = _Service();
    await pump(tester, service);
    final calls = service.recipeCalls;

    await pump(tester, service);

    expect(service.recipeCalls, calls);
    expect(calls, 1, reason: 'premise: one subscription per stream');
  });

  testWidgets('switching to another group shows that group\'s content', (
    tester,
  ) async {
    final other = SocialFactory.createFriendCategory(
      id: 'grp-other',
      name: 'Grannarna',
    );
    expect(other.id, isNot(group.id), reason: 'premise: two groups');
    final service = _Service(
      recipesByGroup: {
        other.id: [
          SharedContentItem(
            id: 'r1',
            title: 'Kanelbullar',
            type: 'recipe',
            sharedByUserId: 'anna',
            sharedByDisplayName: 'Anna',
            sharedAt: DateTime(2026, 1, 1),
            data: const {},
          ),
        ],
      },
    );
    final recipesCount = find.text('1');

    await pump(tester, service);
    expect(recipesCount, findsNothing);

    await pump(tester, service, shown: other);

    expect(service.recipeGroups.last, other.id);
    expect(recipesCount, findsOneWidget);
    expect(find.text(sv.groupSharedRecipesLabel(1)), findsWidgets);
  });

  SharedContentItem item(String type) => SharedContentItem(
    id: '$type-1',
    title: 'Delat $type',
    type: type,
    sharedByUserId: 'anna',
    sharedByDisplayName: 'Anna',
    sharedAt: DateTime(2026, 1, 1),
    data: const {},
  );

  // A15: the import button answered "coming soon" or even "done" for menus
  // and lists, so only a recipe offers it.
  testWidgets('only a shared recipe offers Importera', (tester) async {
    final service = _Service(
      recipesByGroup: {
        group.id: [item('recipe')],
      },
    );
    await pump(tester, service);
    await tester.tap(find.text(sv.groupSharedRecipesLabel(1)));
    await tester.pumpAndSettle();

    expect(find.text(sv.groupImport), findsOneWidget);
  });

  testWidgets('an import that makes no copy says so, not "importerat"', (
    tester,
  ) async {
    final vm = _MockSharedRecipeViewModel();
    final shared = FakeSharedRecipe();
    when(() => vm.getSharedRecipeById(any())).thenAnswer((_) async => shared);
    when(() => vm.importSharedRecipe(shared)).thenAnswer((_) async => null);
    when(() => vm.error).thenReturn(null);
    TestServiceLocator.registerMock<SharedRecipeViewModel>(vm);
    final service = _Service(
      recipesByGroup: {
        group.id: [item('recipe')],
      },
    );
    await pump(tester, service);
    await tester.tap(find.text(sv.groupSharedRecipesLabel(1)));
    await tester.pumpAndSettle();

    await tester.tap(find.text(sv.groupImport));
    await tester.pump();
    await tester.pump();

    verify(() => vm.importSharedRecipe(shared)).called(1);
    expect(find.textContaining(sv.errorCouldNotImportRecipes), findsOneWidget);
    expect(
      find.text(sv.groupRecipeImportedSuccess('Delat recipe')),
      findsNothing,
    );
  });

  testWidgets('a shared menu offers no Importera', (tester) async {
    final service = _MenuService();
    await pump(tester, service);
    await tester.tap(find.text(sv.groupSharedMenusLabel(1)));
    await tester.pumpAndSettle();

    expect(find.text('Delat menu'), findsOneWidget);
    expect(find.text(sv.groupImport), findsNothing);
  });
}

class _MenuService extends _Service {
  @override
  Stream<List<SharedContentItem>> streamSharedMenus(FriendCategory group) =>
      Stream.value([
        SharedContentItem(
          id: 'menu-1',
          title: 'Delat menu',
          type: 'menu',
          sharedByUserId: 'anna',
          sharedByDisplayName: 'Anna',
          sharedAt: DateTime(2026, 1, 1),
          data: const {},
        ),
      ]);
}
