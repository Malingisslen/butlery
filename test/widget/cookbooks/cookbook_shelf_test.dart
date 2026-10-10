import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/services/tagging/cookbook_service.dart';
import 'package:butlery/services/tagging/personal_tag_service.dart';
import 'package:butlery/viewmodels/cookbook_viewmodel.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/views/cookbooks/cookbook_detail_view.dart';
import 'package:butlery/views/cookbooks/cookbook_edit_sheet.dart';
import 'package:butlery/views/cookbooks/cookbook_shelf.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';
import 'package:butlery/views/personal_tags_view.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';
import '../../test_support/cookbook_fixtures.dart';

class _MockCookbookService extends Mock implements CookbookService {}

void main() {
  final l10n = AppLocalizationsSv();
  late _MockCookbookService service;
  late StreamController<List<PersonalTag>> tagStream;
  late CookbookViewModel vm;

  final soppor = cookbookTag(
    id: 'soppor',
    name: 'Soppor',
    cookbook: const CookbookDetails(),
  );
  final bakning = cookbookTag(
    id: 'bakning',
    name: 'Bakning',
    sortOrder: 1,
    cookbook: const CookbookDetails(description: 'Bullar och bröd'),
  );
  final frukost = cookbookTag(id: 'frukost', name: 'Frukost', sortOrder: 2);

  setUpAll(() {
    registerFallbackValue(cookbookTag());
    registerFallbackValue(const CookbookDetails());
  });

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    service = _MockCookbookService();
    tagStream = StreamController<List<PersonalTag>>.broadcast();
    when(() => service.watchTags()).thenAnswer((_) => tagStream.stream);
    when(() => service.libraryChanges).thenAnswer((_) => const Stream.empty());
    when(() => service.libraryRecipes).thenAnswer(
      (_) => <Recipe>[
        cookbookRecipe('r1', 'Ärtsoppa', tagIds: ['soppor']),
        cookbookRecipe('r2', 'Tomatsoppa', tagIds: ['soppor']),
      ],
    );
    vm = CookbookViewModel(service: service)..start();
  });

  tearDown(() async {
    vm.dispose();
    await tagStream.close();
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  Future<void> pumpShelf(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Scaffold(
          body: ChangeNotifierProvider<CookbookViewModel>.value(
            value: vm,
            child: HemLibraryScroll(
              pinned: const SizedBox(height: 8),
              body: const CookbookShelf(),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> pumpShelfWith(
    WidgetTester tester,
    List<PersonalTag> tags,
  ) async {
    await pumpShelf(tester);
    tagStream.add(tags);
    await tester.pumpAndSettle();
  }

  group('before there is a shelf', () {
    testWidgets('says it is fetching while the tags have not arrived', (
      tester,
    ) async {
      await pumpShelf(tester);
      await tester.pump();

      expect(find.text(l10n.cookbookLoading), findsOneWidget);
      expect(find.text(l10n.cookbookShelfEmpty), findsNothing);
      expect(find.byKey(CookbookShelf.addTileKey), findsNothing);
    });

    testWidgets('shows the load error, not an empty shelf, when the tag '
        'stream fails with no books', (tester) async {
      await pumpShelf(tester);
      tagStream.addError(Exception('offline'));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookLoadFailed), findsOneWidget);
      expect(find.text(l10n.cookbookShelfEmpty), findsNothing);
      expect(find.text(l10n.cookbookNoTags), findsNothing);
    });
  });

  group('no cookbooks yet', () {
    testWidgets('with tags, offers to make a cookbook from one of them', (
      tester,
    ) async {
      await pumpShelfWith(tester, [frukost]);

      expect(find.text(l10n.cookbookShelfEmpty), findsOneWidget);
      expect(find.text(l10n.cookbookNoTags), findsNothing);
      expect(find.text(l10n.cookbookManageTags), findsNothing);

      await tester.tap(find.text(l10n.cookbookMakeFromTag));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookChooseTagTitle), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Frukost'), findsOneWidget);
    });

    testWidgets('with no tags at all, sends the user to the tag manager', (
      tester,
    ) async {
      final tags = MockPersonalTagService();
      when(tags.getAllTags).thenAnswer((_) async => []);
      when(tags.getAllGroups).thenAnswer((_) async => []);
      when(tags.watchTagsWithGroups).thenAnswer((_) => const Stream.empty());
      TestServiceLocator.registerMock<PersonalTagService>(tags);
      TestServiceLocator.registerMock<PersonalTagViewModel>(
        PersonalTagViewModel(service: tags),
      );
      await pumpShelfWith(tester, const []);

      expect(find.text(l10n.cookbookNoTags), findsOneWidget);
      expect(find.text(l10n.cookbookShelfEmpty), findsNothing);
      expect(find.text(l10n.cookbookMakeFromTag), findsNothing);
      expect(find.byType(PersonalTagsView), findsNothing);

      await tester.tap(find.text(l10n.cookbookManageTags));
      await tester.pumpAndSettle();

      expect(find.byType(PersonalTagsView), findsOneWidget);
      expect(find.text(l10n.cookbookChooseTagTitle), findsNothing);
    });
  });

  group('the shelf', () {
    testWidgets('counts the books and shows one tile per cookbook with its '
        'recipe count, leaving plain tags off it', (tester) async {
      await pumpShelfWith(tester, [soppor, bakning, frukost]);

      expect(find.text(l10n.cookbookShelfCount(2)), findsOneWidget);
      expect(find.text('Soppor'), findsOneWidget);
      expect(find.text('Bakning'), findsOneWidget);
      expect(find.text('Frukost'), findsNothing);
      // Two recipes carry "soppor", none carry "bakning".
      expect(find.text(l10n.cookbookRecipeCount(2)), findsOneWidget);
      expect(find.text(l10n.cookbookRecipeCount(0)), findsOneWidget);
    });

    testWidgets('a book tile is a button whose label starts with '
        '"Öppna kokbok"', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpShelfWith(tester, [soppor, bakning]);

      final node = tester.getSemantics(find.text('Soppor'));

      expect(node.flagsCollection.isButton, isTrue);
      expect(node.label, startsWith(l10n.a11yOpenCookbook));
      // The book's own name is read once, from the visible text.
      expect('Soppor'.allMatches(node.label).length, 1);
      handle.dispose();
    });

    testWidgets('tapping a book opens that book, not the first one', (
      tester,
    ) async {
      await pumpShelfWith(tester, [soppor, bakning]);

      await tester.tap(find.text('Bakning'));
      await tester.pumpAndSettle();

      final detail = tester.widget<CookbookDetailView>(
        find.byType(CookbookDetailView),
      );
      expect(detail.tagId, 'bakning');
      expect(find.text('Bullar och bröd'), findsOneWidget);
    });
  });

  group('the add tile', () {
    testWidgets('lists only tags that are not cookbooks yet', (tester) async {
      await pumpShelfWith(tester, [soppor, bakning, frukost]);

      await tester.tap(find.byKey(CookbookShelf.addTileKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookChooseTagTitle), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Frukost'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Soppor'), findsNothing);
      expect(find.widgetWithText(ListTile, 'Bakning'), findsNothing);
      expect(find.text(l10n.cookbookAllTagsAreCookbooks), findsNothing);
    });

    testWidgets('says so when every tag already is a cookbook', (tester) async {
      await pumpShelfWith(tester, [soppor, bakning]);

      await tester.tap(find.byKey(CookbookShelf.addTileKey));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookAllTagsAreCookbooks), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('choosing a tag opens the cookbook sheet for it', (
      tester,
    ) async {
      await pumpShelfWith(tester, [soppor, frukost]);

      await tester.tap(find.byKey(CookbookShelf.addTileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Frukost'));
      await tester.pumpAndSettle();

      expect(find.byType(CookbookEditSheet), findsOneWidget);
      expect(find.text(l10n.cookbookChooseTagTitle), findsNothing);
    });

    testWidgets('dismissing the chooser opens nothing', (tester) async {
      await pumpShelfWith(tester, [soppor, frukost]);
      await tester.tap(find.byKey(CookbookShelf.addTileKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.cookbookChooseTagTitle), findsOneWidget);

      // The barrier covers everything above the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text(l10n.cookbookChooseTagTitle), findsNothing);
      expect(find.byType(CookbookEditSheet), findsNothing);
      expect(find.byType(CookbookDetailView), findsNothing);
      verifyNever(() => service.save(any(), any()));
    });
  });
}
