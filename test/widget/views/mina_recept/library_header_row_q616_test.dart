// Q6-16 = B (fas2/produktbeslut-2026-09-27b.json): Hem has no "Mina recept"
// top bar. "Välj", the ingredient search and the grid/list toggle stand in
// the library's header row, "Dina recept · N"; in selection mode the row
// shows the counter and Avbryt instead, without changing height
// (produktregler.md; B-46 on Hem). Drawn label: Skarmar v12
// del 1 #hemrecept :152-155.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/views/mina_recept/library_header_row.dart';
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/section_heading.dart';

import '../../../infrastructure/builders/recipe_builder.dart';
import '../../../test_support/base_unit_test.dart';

class _MockRecipeListViewModel extends Mock implements RecipeListViewModel {}

Recipe _recipe(String id) =>
    (RecipeBuilder()
          ..id = id
          ..title = 'Recept $id'
          ..imageUrls = [])
        .build();

void main() {
  late _MockRecipeListViewModel viewModel;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    viewModel = _MockRecipeListViewModel();
    when(
      () => viewModel.recipes,
    ).thenReturn([_recipe('r1'), _recipe('r2'), _recipe('r3')]);
    when(() => viewModel.selectedIds).thenReturn(const {});
    when(() => viewModel.selectedCount).thenReturn(0);
    when(() => viewModel.isSelectionMode).thenReturn(false);
    when(() => viewModel.isGridView).thenReturn(false);
    when(() => viewModel.allSelected).thenReturn(false);
  });

  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    double width = 412,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                MinaReceptLibraryHeader(
                  viewModel: viewModel,
                  actions: minaReceptRootActions(context, viewModel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row() => find.byKey(MinaReceptLibraryHeader.rowKey);

  /// Both contents are laid out so the row keeps one height; only one is
  /// shown and reachable.
  bool shown(WidgetTester tester, Finder f) => tester
      .widget<Visibility>(
        find.ancestor(of: f, matching: find.byType(Visibility)).first,
      )
      .visible;

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the row: Dina recept · N, then Välj, search and the toggle '
        '($mode)', (tester) async {
      await pump(tester, theme: theme);
      expect(
        shown(tester, find.byKey(MinaReceptLibraryHeader.headingKey)),
        isTrue,
      );
      expect(
        shown(tester, find.byKey(MinaReceptLibraryHeader.counterKey)),
        isFalse,
      );

      // The shared section heading, not a style of its own.
      expect(
        tester
            .widget<SectionHeading>(
              find.byKey(MinaReceptLibraryHeader.headingKey),
            )
            .text,
        'Dina recept · 3',
      );
      final heading = tester.widget<Text>(
        find.descendant(
          of: find.byKey(MinaReceptLibraryHeader.headingKey),
          matching: find.byType(Text),
        ),
      );
      expect(heading.data, 'DINA RECEPT · 3');
      expect(heading.style?.color, theme.colorScheme.onSurfaceVariant);
      // Read out as a heading; the selection-mode test below expects this
      // same label gone.
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        find.semantics.byLabel('DINA RECEPT · 3'),
        findsOne,
      );
      expect(
        tester.getSemantics(find.text('DINA RECEPT · 3')),
        matchesSemantics(label: 'DINA RECEPT · 3', isHeader: true),
      );
      semantics.dispose();
      expect(
        find.descendant(of: row(), matching: find.byType(ButlerySelectButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: row(),
          matching: find.byIcon(ButleryIcons.refrigerator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row(), matching: find.byIcon(ButleryIcons.grid)),
        findsOneWidget,
      );
      // Välj stands first among the actions (B-46).
      final select = tester.getTopLeft(find.byType(ButlerySelectButton)).dx;
      final search = tester
          .getTopLeft(find.byIcon(ButleryIcons.refrigerator))
          .dx;
      expect(select, lessThan(search));
      // Välj takes text.primary: no bar gives it a colour here.
      final selectText = tester.widget<Text>(
        find.descendant(
          of: find.byType(ButlerySelectButton),
          matching: find.byType(Text),
        ),
      );
      final selectColor = DefaultTextStyle.of(
        tester.element(find.byWidget(selectText)),
      ).style.color;
      expect(selectColor, theme.colorScheme.onSurface);
    });
  }

  testWidgets('no Välj under two recipes', (tester) async {
    when(() => viewModel.recipes).thenReturn([_recipe('r1')]);
    await pump(tester);
    expect(find.byType(ButlerySelectButton), findsNothing);
    expect(find.text('DINA RECEPT · 1'), findsOneWidget);
  });

  testWidgets('Välj enters selection mode', (tester) async {
    when(() => viewModel.startSelection()).thenReturn(null);
    await pump(tester);
    await tester.tap(find.byType(ButlerySelectButton));
    verify(() => viewModel.startSelection()).called(1);
  });

  for (final width in [412.0, 320.0]) {
    testWidgets('selection mode: the counter and Avbryt, at the same height '
        '(${width.toInt()} dp)', (tester) async {
      await pump(tester, width: width);
      final before = tester.getSize(row()).height;

      when(() => viewModel.isSelectionMode).thenReturn(true);
      when(() => viewModel.selectedCount).thenReturn(2);
      when(() => viewModel.clearSelection()).thenReturn(null);
      await pump(tester, width: width);

      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<Text>(find.byKey(MinaReceptLibraryHeader.counterKey))
            .data,
        '2 valda',
      );
      expect(
        shown(tester, find.byKey(MinaReceptLibraryHeader.counterKey)),
        isTrue,
      );
      expect(
        shown(tester, find.byKey(MinaReceptLibraryHeader.headingKey)),
        isFalse,
      );
      expect(shown(tester, find.byType(ButlerySelectButton)), isFalse);
      expect(
        shown(
          tester,
          find.byKey(const ValueKey('mina-recept-bulk-add-to-menu')),
        ),
        isTrue,
      );
      expect(
        shown(tester, find.byKey(const ValueKey('mina-recept-bulk-more'))),
        isTrue,
      );
      // The hidden heading is not read out.
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(find.semantics.byLabel('DINA RECEPT · 3'), findsNothing);
      expect(find.semantics.byLabel('2 valda'), findsOne);
      semantics.dispose();
      expect(tester.getSize(row()).height, before, reason: 'no height jump');

      await tester.tap(
        find.byKey(const ValueKey('mina-recept-selection-cancel')),
      );
      verify(() => viewModel.clearSelection()).called(1);
    });
  }
}
