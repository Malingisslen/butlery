// The bulk-export sheet, the bulk tag picker and the two Mina recept banners:
// what each choice, button and callback does, not how the sheet is laid out.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/empty_state_widgets.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/helpers/mina_recept_selection_bar.dart';
import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/base_unit_test.dart';
import '../recipe/fake_personal_tag_viewmodel.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

final _sv = AppLocalizationsSv();

Recipe _recipe() =>
    (RecipeBuilder()
          ..id = 'r1'
          ..title = 'Pannbiffar'
          ..imageUrls = [])
        .build();

void main() {
  late _MockRecipeListViewModel vm;

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    vm = _MockRecipeListViewModel();
    final recipes = [_recipe(), _recipe()];
    when(() => vm.selectedCount).thenReturn(2);
    when(() => vm.selectedRecipes).thenReturn(recipes);
    when(() => vm.recipes).thenReturn(recipes);
    when(() => vm.matchingCount).thenReturn(recipes.length);
    when(() => vm.libraryTotal).thenReturn(recipes.length);
    when(() => vm.allSelected).thenReturn(false);
    when(() => vm.clearSelection()).thenReturn(null);
    when(() => vm.dismissOnboardingBanner()).thenReturn(null);
    when(() => vm.dismissWelcomeBanner()).thenReturn(null);
  });

  tearDown(() async => TestServiceLocator.reset());

  Future<void> pumpBar(WidgetTester tester) async {
    // A phone-sized surface: the picker sheet opens at half the height.
    tester.view.physicalSize = const Size(412, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Scaffold(body: Text('route ${settings.name}')),
        ),
        child: Builder(
          builder: (context) => Scaffold(
            appBar: buildMinaReceptSelectionAppBar(context, vm),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('bulk tag picker', () {
    late FakePersonalTagViewModel tagVm;

    setUp(() {
      tagVm = FakePersonalTagViewModel();
      TestServiceLocator.registerMock<PersonalTagViewModel>(tagVm);
    });

    Future<void> openPicker(WidgetTester tester) async {
      await pumpBar(tester);
      await tester.tap(find.byKey(const ValueKey('mina-recept-bulk-tag')));
      await tester.pumpAndSettle();
    }

    testWidgets('Avbryt closes the sheet and tags nothing', (tester) async {
      tagVm.setState(tags: [PersonalTag.create(name: 'Vardag')]);
      await openPicker(tester);
      expect(find.text(_sv.bulkTagDialogTitle(2)), findsOneWidget);

      await tester.tap(find.text(_sv.commonCancel).last);
      await tester.pumpAndSettle();

      expect(find.text(_sv.bulkTagDialogTitle(2)), findsNothing);
      verifyNever(
        () => vm.bulkApplyPersonalTag(
          tagId: any(named: 'tagId'),
          tagName: any(named: 'tagName'),
        ),
      );
      verifyNever(() => vm.clearSelection());
    });

    testWidgets('picking a tag applies exactly that tag to the selection', (
      tester,
    ) async {
      final tag = PersonalTag.create(name: 'Vardag');
      tagVm.setState(
        tags: [
          tag,
          PersonalTag.create(name: 'Fest'),
        ],
      );
      when(
        () => vm.bulkApplyPersonalTag(
          tagId: any(named: 'tagId'),
          tagName: any(named: 'tagName'),
        ),
      ).thenAnswer((_) async => 2);
      await openPicker(tester);

      await tester.tap(find.text('Vardag'));
      await tester.pumpAndSettle();

      verify(
        () => vm.bulkApplyPersonalTag(tagId: tag.id, tagName: 'Vardag'),
      ).called(1);
      verify(() => vm.clearSelection()).called(1);
      expect(find.text(_sv.bulkTagSuccess(2)), findsOneWidget);
    });

    testWidgets('with no tags, the create button closes the sheet and opens '
        'the tag settings', (tester) async {
      tagVm.setState(tags: const []);
      await openPicker(tester);
      expect(find.text(_sv.bulkTagNoTagsAvailable), findsOneWidget);

      await tester.tap(find.text(_sv.taggingCreateTag));
      await tester.pumpAndSettle();

      expect(find.text('route ${Routes.settingsPersonalTags}'), findsOneWidget);
      verifyNever(
        () => vm.bulkApplyPersonalTag(
          tagId: any(named: 'tagId'),
          tagName: any(named: 'tagName'),
        ),
      );
    });
  });

  group('bulk export sheet', () {
    late List<MethodCall> platformCalls;

    setUp(() {
      platformCalls = [];
    });

    void recordPlatform(WidgetTester tester) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          platformCalls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    Future<void> openExportSheet(WidgetTester tester) async {
      await pumpBar(tester);
      await tester.tap(find.byKey(const ValueKey('mina-recept-bulk-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.bulkExport));
      await tester.pumpAndSettle();
    }

    testWidgets('copy puts every selected recipe on the clipboard and leaves '
        'selection mode', (tester) async {
      recordPlatform(tester);
      await openExportSheet(tester);
      expect(find.text(_sv.bulkExportShareFile), findsOneWidget);

      await tester.tap(find.text(_sv.bulkExportCopyClipboard));
      await tester.pumpAndSettle();

      final copied = platformCalls.singleWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      final text = (copied.arguments as Map)['text'] as String;
      expect(
        '# Pannbiffar'.allMatches(text).length,
        2,
        reason: 'one section per selected recipe',
      );
      expect(find.text(_sv.bulkExportCopied(2)), findsOneWidget);
      verify(() => vm.clearSelection()).called(1);
    });

    testWidgets('dismissing the sheet exports nothing and keeps the '
        'selection', (tester) async {
      recordPlatform(tester);
      await openExportSheet(tester);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.text(_sv.bulkExportCopyClipboard), findsNothing);
      expect(
        platformCalls.where((c) => c.method == 'Clipboard.setData'),
        isEmpty,
      );
      verifyNever(() => vm.clearSelection());
    });
  });

  group('banners', () {
    Future<void> pumpBanner(WidgetTester tester, Widget banner) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          onGenerateRoute: (settings) => MaterialPageRoute<void>(
            settings: settings,
            builder: (_) => Scaffold(body: Text('route ${settings.name}')),
          ),
          child: banner,
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('onboarding banner: the action dismisses it and opens '
        'allergen settings', (tester) async {
      await pumpBanner(tester, MinaReceptOnboardingBanner(viewModel: vm));

      await tester.tap(find.text(_sv.onboardingSkippedBannerAction));
      await tester.pumpAndSettle();

      verify(() => vm.dismissOnboardingBanner()).called(1);
      expect(find.text('route ${Routes.settingsAllergens}'), findsOneWidget);
    });

    testWidgets('onboarding banner: the close button only dismisses', (
      tester,
    ) async {
      await pumpBanner(tester, MinaReceptOnboardingBanner(viewModel: vm));

      await tester.tap(find.byType(ButleryCloseButton));
      await tester.pumpAndSettle();

      verify(() => vm.dismissOnboardingBanner()).called(1);
      expect(find.text('route ${Routes.settingsAllergens}'), findsNothing);
    });

    testWidgets('welcome banner: the close button only dismisses', (
      tester,
    ) async {
      await pumpBanner(tester, MinaReceptWelcomeBanner(viewModel: vm));

      await tester.tap(find.byType(ButleryCloseButton));
      await tester.pumpAndSettle();

      verify(() => vm.dismissWelcomeBanner()).called(1);
      expect(find.text(_sv.onboardingWelcomeBannerAction), findsOneWidget);
    });
  });
}
