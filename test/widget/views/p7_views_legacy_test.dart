// P7 track A: the legacy surface leaves lib/views.
//
// - A1: a failure says what failed, never the exception, in the ink failure
//   snackbar with the alert role and "Stäng" (content-style-guide.md:87-97;
//   Komponentark v1:750; tillganglighetshandoff:172).
// - A2: the category swatches read ModeColors and keep the generated values
//   of their mode (NULAGE.md:71-74; tokens.json:522).
// - A3: busy buttons draw the plate line, work in progress is the plate line
//   with its text, never a spinner (produktregler.md:163, :304; B-18).
// - A4: state is a token, never an opacity (tokens.json:41).
// - A5: a dialog button that only closes says "Stäng", never "OK"
//   (content-style-guide.md:77, :96).
// - A6: the offline banner is Hem's one offline signal (package-3 answers
//   A-03 and A-09).

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_specific_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/personal_tag_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/selection_app_bar.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_blocked_view.dart';
import 'package:butlery/views/personal_tags/personal_tag_dialogs.dart';
import 'package:butlery/views/tag_detail_view.dart';
import 'package:butlery/views/unified_shopping/widgets/shopping_list_content.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

import '../../infrastructure/builders/recipe_builder.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';
import 'recipe/fake_personal_tag_viewmodel.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

/// The create-tag dialog's VM: validation and the name check are scripted.
class _TagDialogVm extends FakePersonalTagViewModel {
  _TagDialogVm({this.validation, Future<bool>? exists})
    : _exists = exists ?? Future.value(false);

  final String? validation;
  final Future<bool> _exists;

  @override
  String? validateTagName(String? name) => validation;

  @override
  Future<bool> tagNameExists(String name, {String? excludeId}) => _exists;
}

/// Tag detail's VM, whose rule run waits on [run].
class _ApplyingVm extends FakePersonalTagViewModel {
  final run = Completer<BatchApplyResult>();

  @override
  Future<BatchApplyResult> applyRulesToExistingRecipes({
    void Function(int completed, int total)? onProgress,
  }) => run.future;
}

final _sv = AppLocalizationsSv();

Widget _app(Widget home, {ThemeData? theme}) => MaterialApp(
  theme: theme ?? AppTheme.lightTheme,
  locale: const Locale('sv'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Finder _alertNode() => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.role == SemanticsRole.alert,
);

/// Source without whole-line comments, for the structural gates.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  group('A1: a failure names what failed, never the exception', () {
    testWidgets('a failed bulk export says so, without the exception', (
      tester,
    ) async {
      final viewModel = _MockRecipeListViewModel();
      final recipe =
          (RecipeBuilder()
                ..id = 'r1'
                ..title = 'Pannbiffar'
                ..imageUrls = [])
              .build();
      when(() => viewModel.selectedCount).thenReturn(1);
      when(() => viewModel.selectedRecipes).thenReturn(<Recipe>[recipe]);
      when(() => viewModel.recipes).thenReturn(<Recipe>[recipe, recipe]);
      when(() => viewModel.allSelected).thenReturn(false);

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'boom', message: 'clipboard gone');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => Scaffold(
              appBar: AppBar(
                actions: buildMinaReceptSelectionActions(context, viewModel),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('mina-recept-bulk-more')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.bulkExport));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.bulkExportCopyClipboard));
      await tester.pumpAndSettle();

      expect(find.text(_sv.bulkExportFailed), findsOneWidget);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.textContaining('clipboard gone'), findsNothing);
      expect(_alertNode(), findsOneWidget);
      expect(find.text(_sv.commonClose), findsOneWidget);
    });

    testWidgets('a refused tag name is an alert with Stäng, never OK', (
      tester,
    ) async {
      final vm = _TagDialogVm(validation: _sv.tagAlreadyExists);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider<PersonalTagViewModel>.value(
            value: vm,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      PersonalTagDialogs.showCreateTagDialog(context),
                  child: const Text('öppna'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Vardag');
      await tester.tap(find.text(_sv.commonCreate));
      await tester.pumpAndSettle();

      expect(find.text(_sv.tagAlreadyExists), findsOneWidget);
      expect(_alertNode(), findsOneWidget);
      expect(find.text(_sv.commonClose), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });
  });

  group('A2: category swatches keep their generated values', () {
    // The value per mode before the move (ButleryColors.light/.dark with no
    // theme extension), written out as the generated members themselves.
    final expected = <Brightness, Map<String, Color>>{
      Brightness.light: {
        ShoppingCategory.meatFish: AppColors.categoryMeatFish,
        ShoppingCategory.dairy: AppColors.categoryDairy,
        ShoppingCategory.fruitVeg: AppColors.categoryVegetables,
        ShoppingCategory.breadGrain: AppColors.categoryBreadGrains,
        ShoppingCategory.frozen: AppColors.categoryFrozen,
        ShoppingCategory.pantry: AppColors.categoryDryGoods,
        ShoppingCategory.canned: AppSpecificColors.categoryCanned,
        ShoppingCategory.drinks: AppSpecificColors.categoryDrinks,
        ShoppingCategory.snacks: AppSpecificColors.categorySnacks,
        ShoppingCategory.cleaning: AppSpecificColors.categoryCleaning,
        'okänd': AppColors.categoryOther,
      },
      Brightness.dark: {
        ShoppingCategory.meatFish: AppColors.categoryMeatFish,
        ShoppingCategory.dairy: AppColors.categoryDairy,
        ShoppingCategory.fruitVeg: AppColors.categoryVegetables,
        ShoppingCategory.breadGrain: AppColors.categoryBreadGrains,
        ShoppingCategory.frozen: AppColors.categoryFrozen,
        ShoppingCategory.pantry: AppColors.categoryDryGoods,
        ShoppingCategory.canned: AppSpecificColors.categoryCannedDark,
        ShoppingCategory.drinks: AppSpecificColors.categoryDrinksDark,
        ShoppingCategory.snacks: AppSpecificColors.categorySnacksDark,
        ShoppingCategory.cleaning: AppSpecificColors.categoryCleaningDark,
        'okänd': AppColors.categoryOther,
      },
    };

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: every category swatch', (tester) async {
        late BuildContext ctx;
        await tester.pumpWidget(
          _app(
            Builder(
              builder: (context) {
                ctx = context;
                return const SizedBox.shrink();
              },
            ),
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
          ),
        );
        for (final entry in expected[brightness]!.entries) {
          expect(
            ShoppingListContentWidget.getCategoryColor(ctx, entry.key),
            entry.value,
            reason: entry.key,
          );
        }
      });
    }
  });

  group('A3: work in progress is the plate line, never a spinner', () {
    testWidgets('a busy Skapa draws the plate line and keeps its name', (
      tester,
    ) async {
      final pending = Completer<bool>();
      final vm = _TagDialogVm(exists: pending.future);
      await tester.pumpWidget(
        _app(
          ChangeNotifierProvider<PersonalTagViewModel>.value(
            value: vm,
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      PersonalTagDialogs.showCreateTagDialog(context),
                  child: const Text('öppna'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Vardag');
      await tester.tap(find.text(_sv.commonCreate));
      await tester.pump();

      expect(find.byType(ButtonPlateLine), findsOneWidget);
      expect(find.text(_sv.commonCreate), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      pending.complete(true);
      await tester.pump();
    });

    testWidgets('running the rules shows the plate line with its text', (
      tester,
    ) async {
      final getIt = GetIt.instance;
      final vm = _ApplyingVm();
      final tag = PersonalTag.create(name: 'Vardagsmat');
      vm.setState(tags: [tag]);
      final offline = MockOfflineService();
      when(() => offline.isOnline).thenReturn(true);
      when(() => offline.addListener(any())).thenReturn(null);
      when(() => offline.removeListener(any())).thenReturn(null);
      for (final type in [PersonalTagViewModel, OfflineService]) {
        if (type == PersonalTagViewModel &&
            getIt.isRegistered<PersonalTagViewModel>()) {
          getIt.unregister<PersonalTagViewModel>();
        }
        if (type == OfflineService && getIt.isRegistered<OfflineService>()) {
          getIt.unregister<OfflineService>();
        }
      }
      getIt.registerSingleton<PersonalTagViewModel>(vm);
      getIt.registerSingleton<OfflineService>(offline);
      production.ServiceLocator.reset();
      production.ServiceLocator.initialize(DIContainer());
      addTearDown(() {
        production.ServiceLocator.reset();
        if (getIt.isRegistered<PersonalTagViewModel>()) {
          getIt.unregister<PersonalTagViewModel>();
        }
        if (getIt.isRegistered<OfflineService>()) {
          getIt.unregister<OfflineService>();
        }
      });
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_app(TagDetailView(tagId: tag.id)));
      await tester.pump();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.tagDetailApplyRules));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PlateLine), findsOneWidget);
      expect(find.text(_sv.tagDetailApplyingRules), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      vm.run.complete(
        const BatchApplyResult(
          recipesProcessed: 0,
          recipesModified: 0,
          tagsApplied: 0,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    test('no spinner and no old bar is left in lib/views (outside social '
        'and messaging)', () {
      final offenders = <String>[];
      for (final entity in Directory('lib/views').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path.contains('/social/') || path.contains('/messaging/')) {
          continue;
        }
        if (RegExp(r'\bLoadingIndicator\b|AdaptiveAppBar').hasMatch(
          _code(path),
        )) {
          offenders.add(path);
        }
      }
      expect(offenders, isEmpty);
    });
  });

  group('A4: state is a token, never an opacity (tokens.json:41)', () {
    // A state ternary over Opacity or an alpha is the old way. The on-ink
    // step plate in cooking mode is drawn at 0.6 (Skarmar v12 del 1 #laga
    // :277-288, tokens.json:47-51) and is the one allowed ladder step here.
    const files = [
      'lib/views/family/family_member_form_view.dart',
      'lib/views/family/who_is_eating_sheet.dart',
      'lib/views/personal_tags/personal_tag_widgets.dart',
      'lib/views/settings/notification_preferences_view.dart',
      'lib/views/onboarding/onboarding_view.dart',
      'lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart',
      'lib/views/importera_fran_arkiv_view.dart',
      'lib/views/menu_placement/placement_widgets.dart',
      'lib/views/cooking_mode_view.dart',
    ];
    final opacityState = RegExp(r'Opacity\(\s*(?://[^\n]*\n\s*)*opacity:\s*\w');
    final selectedAlpha = RegExp(
      r'(?:selectedColor|selected\s*\?)[^;]{0,80}?\.withValues\(\s*alpha',
    );

    for (final path in files) {
      test(path, () {
        final code = _code(path);
        expect(opacityState.hasMatch(code), isFalse, reason: 'Opacity');
        expect(selectedAlpha.hasMatch(code), isFalse, reason: 'alpha');
      });
    }

    test('the pattern catches the old form', () {
      expect(
        opacityState.hasMatch('Opacity(\n  opacity: selected ? 1 : 0.5,'),
        isTrue,
      );
      expect(
        selectedAlpha.hasMatch(
          'color: selected ? cs.error.withValues(alpha: 0.1) : cs.surface',
        ),
        isTrue,
      );
    });
  });

  group('A5: a button that only closes says Stäng', () {
    testWidgets('the age gate parent info closes with Stäng', (tester) async {
      await tester.pumpWidget(_app(const OnboardingAgeGateBlockedView()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_sv.onboardingAgeGateParentOption));
      await tester.pumpAndSettle();

      expect(find.text(_sv.onboardingAgeGateParentInfoTitle), findsOneWidget);
      expect(find.widgetWithText(TextButton, _sv.commonClose), findsOneWidget);
      expect(find.text('OK'), findsNothing);
    });

    test('no view in this track names a closing button OK', () {
      for (final path in const [
        'lib/views/onboarding/onboarding_age_gate_blocked_view.dart',
        'lib/views/onboarding/onboarding_view.dart',
        'lib/views/unified_shopping/widgets/shopping_dialogs.dart',
      ]) {
        expect(_code(path), isNot(contains('commonOk')), reason: path);
      }
    });
  });

  group('A6: the offline banner is the one offline signal on Hem', () {
    test('Hem draws the offline banner and no SyncIndicator', () {
      final code = _code('lib/views/mina_recept_view.dart');
      expect(RegExp(r'\bSyncIndicator\b').hasMatch(code), isFalse);
      expect(code, contains('LayoutComponents.offlineIndicator()'));
    });
  });
}
