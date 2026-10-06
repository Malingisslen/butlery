import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/widgets/social/groups/group_shared_content_section.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/social_factory.dart';

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
    final recipesTab = '${sv.groupContentTypeRecipe} (1)';

    await pump(tester, service);
    expect(find.text(recipesTab), findsNothing);

    await pump(tester, service, shown: other);

    expect(service.recipeGroups.last, other.id);
    expect(find.text(recipesTab), findsOneWidget);
  });
}
