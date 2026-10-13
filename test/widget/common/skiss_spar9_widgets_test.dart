// The shared pieces the detail, admin and diff screens of skiss-spår 9 are
// built from: each draws what it is given and nothing it is not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/admin/widgets/admin_stat_card.dart';
import 'package:butlery/widgets/admin/admin_table.dart';
import 'package:butlery/widgets/common/bold_in_text.dart';
import 'package:butlery/widgets/common/diff_field_row.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';
import 'package:butlery/widgets/common/stat_row.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('StatRow draws each value above its label', (tester) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const StatRow(
          items: [
            StatRowItem(value: '12', label: 'recept'),
            StatRowItem(value: 'A–Ö', label: 'sortering'),
          ],
        ),
      ),
    );

    for (final text in ['12', 'recept', 'A–Ö', 'sortering']) {
      expect(find.text(text), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.text('12')).dy,
      lessThan(tester.getTopLeft(find.text('recept')).dy),
    );
    expect(
      tester.getTopLeft(find.text('12')).dx,
      lessThan(tester.getTopLeft(find.text('A–Ö')).dx),
    );
  });

  group('AdminTable', () {
    Widget table({List<AdminTableColumn>? columns, VoidCallback? onTap}) =>
        createLocalizedTestApp(
          child: AdminTable(
            columns:
                columns ??
                const [
                  AdminTableColumn(label: 'Tid', flex: 2),
                  AdminTableColumn(label: 'Händelse', alignEnd: true),
                ],
            rows: [
              AdminTableRow(cells: const ['08:00', 'Städning'], onTap: onTap),
            ],
          ),
        );

    testWidgets('draws headers in capitals and one text per cell', (
      tester,
    ) async {
      await tester.pumpWidget(table());

      expect(find.text('TID'), findsOneWidget);
      expect(find.text('HÄNDELSE'), findsOneWidget);
      expect(find.text('08:00'), findsOneWidget);
      expect(find.text('Städning'), findsOneWidget);
    });

    testWidgets('has no header when every column label is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        table(
          columns: const [
            AdminTableColumn(label: '', flex: 2),
            AdminTableColumn(label: ''),
          ],
        ),
      );

      expect(find.text('TID'), findsNothing);
      expect(find.text('08:00'), findsOneWidget);
    });

    testWidgets(
      'a header label too wide for its column stays on one line',
      (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          createLocalizedTestApp(
            child: const AdminTable(
              columns: [
                AdminTableColumn(label: 'Domän', flex: 3),
                AdminTableColumn(label: 'Misslyckade', alignEnd: true),
                AdminTableColumn(label: 'Borttaget', alignEnd: true),
              ],
              rows: [
                AdminTableRow(cells: ['ica.se', '4', '12']),
              ],
            ),
          ),
        );

        for (final label in ['MISSLYCKADE', 'BORTTAGET']) {
          final box = tester.getSize(find.text(label));
          expect(box.height, lessThan(AppTextStyles.overline.fontSize! * 1.6));
        }
      },
    );

    testWidgets('a row with onTap is tappable and one without is not', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(table(onTap: () => taps++));
      await tester.tap(find.text('Städning'));
      expect(taps, 1);

      await tester.pumpWidget(table());
      expect(find.byType(InkWell), findsNothing);
    });
  });

  group('DiffFieldRow', () {
    Widget row(List<DiffVersion> versions) => createLocalizedTestApp(
      child: DiffFieldRow(
        title: 'Titel',
        emptyText: '(tomt)',
        versions: versions,
      ),
    );

    testWidgets('names the field in capitals and each version by name', (
      tester,
    ) async {
      await tester.pumpWidget(
        row(const [
          DiffVersion(
            name: 'Erik',
            text: '1 citron',
            marker: Colors.orange,
            emphasised: true,
            badge: 'Gäller',
          ),
          DiffVersion(name: 'Din', text: '2 citroner', marker: Colors.black),
        ]),
      );

      expect(find.text('TITEL'), findsOneWidget);
      expect(find.text('Erik'), findsOneWidget);
      expect(find.text('Din'), findsOneWidget);
      expect(find.text('GÄLLER'), findsOneWidget);
    });

    testWidgets('an empty version reads as the empty text, in italics', (
      tester,
    ) async {
      await tester.pumpWidget(
        row(const [
          DiffVersion(name: 'Erik', text: null, marker: Colors.orange),
          DiffVersion(name: 'Din', text: '', marker: Colors.black),
        ]),
      );

      expect(find.text('(tomt)'), findsNWidgets(2));
      expect(
        tester.widget<Text>(find.text('(tomt)').first).style?.fontStyle,
        FontStyle.italic,
      );
    });

    testWidgets('the version that applies is set in the stronger style', (
      tester,
    ) async {
      await tester.pumpWidget(
        row(const [
          DiffVersion(
            name: 'Erik',
            text: 'Gäller',
            marker: Colors.orange,
            emphasised: true,
          ),
          DiffVersion(name: 'Din', text: 'Gäller inte', marker: Colors.black),
        ]),
      );

      final strong = tester.widget<Text>(find.text('Gäller').first).style;
      final plain = tester.widget<Text>(find.text('Gäller inte')).style;
      expect(strong?.fontWeight, AppTextStyles.titleMedium.fontWeight);
      expect(plain?.fontWeight, AppTextStyles.bodyLarge.fontWeight);
    });
  });

  group('BoldInText', () {
    testWidgets('sets each named part in the stronger style', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const BoldInText(
            'Anna föreslår en ändring i Linsgryta.',
            bold: ['Anna', 'Linsgryta'],
          ),
        ),
      );

      final span = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((w) => w.text)
          .whereType<TextSpan>()
          .firstWhere((t) => t.toPlainText().startsWith('Anna'));
      // Text wraps the given span in one of its own.
      final given = span.children!.single as TextSpan;
      final strong = [
        for (final child in given.children!.cast<TextSpan>())
          if (child.style != null) child.text,
      ];
      expect(strong, ['Anna', 'Linsgryta']);
      expect(span.toPlainText(), 'Anna föreslår en ändring i Linsgryta.');
    });

    testWidgets('an empty name is ignored instead of matching everywhere', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const BoldInText('Hela meningen.', bold: ['', 'Hela']),
        ),
      );

      final span = tester
          .widgetList<RichText>(find.byType(RichText))
          .map((w) => w.text)
          .whereType<TextSpan>()
          .firstWhere((t) => t.toPlainText().startsWith('Hela'));
      final given = span.children!.single as TextSpan;
      final strong = [
        for (final child in given.children!.cast<TextSpan>())
          if (child.style != null) child.text,
      ];
      expect(strong, ['Hela']);
    });
  });

  group('StarRatingRow', () {
    Widget stars({double? slot, bool solidEmpty = false}) =>
        createLocalizedTestApp(
          child: StarRatingRow(
            rating: 2,
            slot: slot,
            solidEmpty: solidEmpty,
          ),
        );

    testWidgets('an unrated star is an outline unless solidEmpty', (
      tester,
    ) async {
      await tester.pumpWidget(stars());
      expect(find.byIcon(ButleryIcons.starOutline), findsNWidgets(3));

      await tester.pumpWidget(stars(solidEmpty: true));
      expect(find.byIcon(ButleryIcons.starOutline), findsNothing);
      expect(find.byIcon(ButleryIcons.star), findsNWidgets(5));
    });

    testWidgets('a slot gives every star a full cell', (tester) async {
      await tester.pumpWidget(stars(slot: 48));

      final cells = find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 48 && w.height == 48,
      );
      expect(cells, findsNWidgets(5));
    });
  });

  testWidgets('AdminStatCards in a Wrap sit side by side, not one per line', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: const Wrap(
          children: [
            AdminStatCard(label: 'Olästa', value: '14'),
            AdminStatCard(label: 'Importer', value: '312'),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('OLÄSTA')).dy,
      tester.getTopLeft(find.text('IMPORTER')).dy,
    );
  });
}
