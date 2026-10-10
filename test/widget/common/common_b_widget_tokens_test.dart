// BUT-2183 5m: the menu, permission, empty-state, search-stats and
// service widgets under lib/widgets/common leave the old opacity steps.
// Fills are the raised surface, borders are outlineVariant, the notice boxes
// (no access, service error) are the danger tint with
// no border and the error on-colour, and the grab handles and the empty-state
// glyph are text.disabled. Each test runs in both modes and asserts glyph and
// text colours as well as fills, so a value that is shared by one mode is
// still caught by the other.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';
import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_load_dialog.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_save_dialog.dart';
import 'package:butlery/widgets/common/permissions/permission_widgets.dart';
import 'package:butlery/widgets/common/scaffolds/empty_state_scaffold.dart';
import 'package:butlery/widgets/common/search_filter/search_stats_widget.dart';
import 'package:butlery/widgets/common/service/service_widgets.dart';

class _FakeMenuViewModel extends Mock implements MenuViewModel {}

class _FakeRecipeService extends Mock implements UnifiedRecipeService {}

final AppLocalizations _sv = lookupAppLocalizations(const Locale('sv'));

const _modes = <String, bool>{'light': false, 'dark': true};

ThemeData _theme(bool dark) => dark ? AppTheme.darkTheme : AppTheme.lightTheme;

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget home) async {
  tester.view.physicalSize = const Size(420, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  // The test font is wider than the production one, so rows overflow the
  // viewport; these tests read colours, not layout.
  final originalHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    originalHandler?.call(details);
  };
  addTearDown(() => FlutterError.onError = originalHandler);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: const Locale('sv', 'SE'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

BoxDecoration _boxAbove(WidgetTester tester, Finder of) {
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: of,
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is BoxDecoration,
          ),
        )
        .first,
  );
  return box.decoration as BoxDecoration;
}

Color? _textColor(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style?.color;

Color? _iconColor(WidgetTester tester, IconData icon) =>
    tester.widget<Icon>(find.byIcon(icon)).color;

Finder _handle(double width, double height) => find.byWidgetPredicate(
  (w) =>
      w is Container &&
      w.constraints == BoxConstraints.tightFor(width: width, height: height),
);

Color? _handleColor(WidgetTester tester, Finder handle) =>
    (tester.widget<Container>(handle).decoration! as BoxDecoration).color;

MenuViewModel _menuVm() {
  final vm = _FakeMenuViewModel();
  when(() => vm.totalRecipeCount).thenReturn(7);
  when(() => vm.menu).thenReturn({'cat': const <Recipe>[]});
  when(() => vm.error).thenReturn(null);
  when(() => vm.refreshSavedMenus()).thenAnswer((_) async {});
  when(() => vm.savedMenus).thenReturn(<SavedMenuInfo>[]);
  return vm;
}

void main() {
  for (final mode in _modes.entries) {
    final dark = mode.value;
    final theme = _theme(dark);
    final cs = theme.colorScheme;
    final modeColors = ModeColors.of(theme.brightness);

    group('common widgets, ${mode.key}', () {
      testWidgets('save dialog: the menu summary is a raised box', (
        tester,
      ) async {
        await _pump(tester, theme, SaveMenuDialog(viewModel: _menuVm()));

        final decoration = _boxAbove(tester, find.text(_sv.menuToSave));
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(decoration.border, isNull);
        expect(
          DefaultTextStyle.of(
            tester.element(find.text(_sv.menuToSave)),
          ).style.color,
          cs.onSurface,
        );
      });

      testWidgets('load sheet: the grab handle is text.disabled', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          Scaffold(body: LoadMenuBottomSheet(viewModel: _menuVm())),
        );

        final handle = _handle(
          AppDimensions.iconSizeDisplay,
          AppDimensions.spacingXs,
        );
        expect(handle, findsOneWidget);
        expect(
          _handleColor(tester, handle),
          AppModeColors.textDisabled(theme.brightness),
        );
      });

      testWidgets('no access: the danger tint with the error on-colour', (
        tester,
      ) async {
        await _pump(
          tester,
          theme,
          Scaffold(
            body: Builder(
              builder: (context) => PermissionWidgets.permissionsActionButtons(
                context: context,
                editMode: EditMode.noAccess,
              ),
            ),
          ),
        );

        final decoration = _boxAbove(tester, find.text(_sv.permissionNoAccess));
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(_textColor(tester, _sv.permissionNoAccess), cs.onErrorContainer);
        expect(_iconColor(tester, ButleryIcons.block), cs.onErrorContainer);
      });

      testWidgets('empty state: the glyph is text.disabled', (tester) async {
        await _pump(
          tester,
          theme,
          const EmptyStateScaffold(
            title: 'Tomt',
            emptyMessage: 'Inget här',
            emptyIcon: ButleryIcons.folder,
          ),
        );

        expect(
          _iconColor(tester, ButleryIcons.folder),
          AppModeColors.textDisabled(theme.brightness),
        );
      });

      testWidgets('search stats: a raised box with no border', (tester) async {
        await _pump(
          tester,
          theme,
          const Scaffold(
            body: SearchStatsWidget(
              searchQuery: 'soppa',
              hasActiveFilters: false,
              resultCount: 3,
            ),
          ),
        );

        final text = find.textContaining('soppa');
        final decoration = _boxAbove(tester, text);
        expect(decoration.color, cs.surfaceContainerHighest);
        expect(decoration.border, isNull);
        expect(
          tester.widget<Text>(text).style?.color,
          cs.onPrimaryContainer,
        );
        expect(_iconColor(tester, ButleryIcons.info), cs.onSurface);
      });

      testWidgets('service error: the danger tint with the error on-colour', (
        tester,
      ) async {
        final service = _FakeRecipeService();
        when(() => service.hasError).thenReturn(true);
        when(() => service.lastError).thenReturn('Något gick fel');
        when(() => service.isLoading).thenReturn(false);
        when(() => service.recipes).thenReturn(const <Recipe>[]);
        when(() => service.stateStream).thenAnswer((_) => const Stream.empty());
        GetIt.instance.registerSingleton<UnifiedRecipeService>(service);
        production.ServiceLocator.initialize(DIContainer());
        addTearDown(() async {
          production.ServiceLocator.reset();
          await GetIt.instance.reset();
        });

        await _pump(
          tester,
          theme,
          Scaffold(
            body: ServiceWidgets.serviceWidget(
              builder: (recipes) => const SizedBox.shrink(),
            ),
          ),
        );

        final decoration = _boxAbove(tester, find.text('Något gick fel'));
        expect(decoration.color, modeColors.surfaceTintDanger);
        expect(decoration.border, isNull);
        expect(_textColor(tester, 'Något gick fel'), cs.onErrorContainer);
      });

      testWidgets('service loading overlay is the ink overlay, not an '
          'on-surface tint', (tester) async {
        final service = _FakeRecipeService();
        when(() => service.hasError).thenReturn(false);
        when(() => service.lastError).thenReturn(null);
        when(() => service.isLoading).thenReturn(true);
        when(() => service.recipes).thenReturn(const <Recipe>[]);
        when(() => service.stateStream).thenAnswer((_) => const Stream.empty());
        GetIt.instance.registerSingleton<UnifiedRecipeService>(service);
        production.ServiceLocator.initialize(DIContainer());
        addTearDown(() async {
          production.ServiceLocator.reset();
          await GetIt.instance.reset();
        });

        await _pump(
          tester,
          theme,
          Scaffold(
            body: ServiceWidgets.serviceWidget(
              builder: (recipes) => const SizedBox.shrink(),
              showLoadingOverlay: true,
            ),
          ),
        );

        final scrim = tester.widget<ColoredBox>(
          find
              .ancestor(
                of: find.text(_sv.loadingGeneric),
                matching: find.byType(ColoredBox),
              )
              .first,
        );
        expect(scrim.color, AppColors.overlayBlack40);
      });
    });
  }
}
