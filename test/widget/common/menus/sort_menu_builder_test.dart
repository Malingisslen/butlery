/// Widget tests for SortMenuBuilder — verifies that the popup menu items
/// it produces have the correct value, labels, selection indicator, and
/// ascending/descending arrow.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/search_service.dart';
import 'package:butlery/widgets/common/menus/sort_menu_builder.dart';

/// Builds a host that opens a PopupMenu seeded with [criteria]/[ascending].
Widget _menuHost({
  required SortCriteria currentSort,
  required bool sortAscending,
  ValueChanged<SortCriteria>? onSelected,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(
      body: Builder(
        builder: (context) => PopupMenuButton<SortCriteria>(
          itemBuilder: (ctx) => SortMenuBuilder.buildItems(
            context: ctx,
            currentSort: currentSort,
            sortAscending: sortAscending,
          ),
          onSelected: onSelected,
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  group('SortMenuBuilder.buildItems', () {
    testWidgets('produces exactly 8 entries — one per shipped SortCriteria',
        (tester) async {
      late List<PopupMenuItem<SortCriteria>> items;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              items = SortMenuBuilder.buildItems(
                context: context,
                currentSort: SortCriteria.title,
                sortAscending: true,
              );
              return const SizedBox();
            },
          ),
        ),
      ));
      expect(items.length, 8);
    });

    testWidgets('items carry the expected SortCriteria values', (tester) async {
      late List<PopupMenuItem<SortCriteria>> items;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: Builder(
            builder: (context) {
              items = SortMenuBuilder.buildItems(
                context: context,
                currentSort: SortCriteria.title,
                sortAscending: true,
              );
              return const SizedBox();
            },
          ),
        ),
      ));

      final values = items.map((i) => i.value).toList();
      expect(values, [
        SortCriteria.title,
        SortCriteria.time,
        SortCriteria.rating,
        SortCriteria.mealType,
        SortCriteria.lastCooked,
        SortCriteria.cookCount,
        SortCriteria.newest,
        SortCriteria.random,
      ]);
    });
  });

  group('SortMenuBuilder — rendered menu', () {
    testWidgets('opening menu shows all Swedish labels', (tester) async {
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.title,
        sortAscending: true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Titel'), findsOneWidget);
      expect(find.text('Tid'), findsOneWidget);
      expect(find.text('Betyg'), findsOneWidget);
      expect(find.text('Måltidstyp'), findsOneWidget);
      expect(find.text('Senast lagad'), findsOneWidget);
      expect(find.text('Antal tillagningar'), findsOneWidget);
      expect(find.text('Nyaste'), findsOneWidget);
      expect(find.text('Slumpa'), findsOneWidget);
    });

    testWidgets('ascending=true → selected row has arrow_upward',
        (tester) async {
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.rating,
        sortAscending: true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });

    testWidgets('ascending=false → selected row has arrow_downward',
        (tester) async {
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.rating,
        sortAscending: false,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
    });

    testWidgets('only the selected criterion gets a direction arrow',
        (tester) async {
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.newest,
        sortAscending: true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Exactly one direction-arrow icon, regardless of how many entries.
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    });

    testWidgets('tapping an item invokes onSelected with that criterion',
        (tester) async {
      SortCriteria? picked;
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.title,
        sortAscending: true,
        onSelected: (c) => picked = c,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Betyg'));
      await tester.pumpAndSettle();

      expect(picked, SortCriteria.rating);
    });

    testWidgets('each row shows its leading icon', (tester) async {
      await tester.pumpWidget(_menuHost(
        currentSort: SortCriteria.title,
        sortAscending: true,
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.title), findsOneWidget);
      expect(find.byIcon(Icons.access_time), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.history), findsOneWidget);
      expect(find.byIcon(Icons.repeat), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.shuffle), findsOneWidget);
    });
  });
}
