/// The recipe's pictures as a row of tiles: what a tap on each part asks for,
/// and when the plus tile is offered. Replaces the pins the old grid's
/// widgets carried, which now guard classes nothing draws.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/image/components/image_tile_row.dart';
import 'package:butlery/widgets/image/image_config.dart';

void main() {
  const urls = ['https://example.test/a.jpg', 'https://example.test/b.jpg'];

  Future<void> pump(
    WidgetTester tester, {
    List<String> imageUrls = urls,
    int maxImages = 5,
    bool isAdding = false,
    required List<String> calls,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: ImageTileRow(
            imageUrls: imageUrls,
            config: ImageConfig.recipeEdit(maxImages: maxImages),
            primaryIndex: 0,
            isAdding: isAdding,
            onAdd: () => calls.add('add'),
            onRemove: (i) => calls.add('remove $i'),
            onSetPrimary: (i) => calls.add('primary $i'),
            onOpen: (i) => calls.add('open $i'),
          ),
        ),
      ),
    );
  }

  testWidgets('the primary tile opens, another tile becomes primary', (
    tester,
  ) async {
    final calls = <String>[];
    await pump(tester, calls: calls);

    await tester.tap(find.byKey(const ValueKey('image-tile-0')));
    await tester.tap(find.byKey(const ValueKey('image-tile-1')));

    expect(calls, ['open 0', 'primary 1']);
  });

  testWidgets('the cross removes exactly its own picture', (tester) async {
    final calls = <String>[];
    await pump(tester, calls: calls);

    final cross = find.descendant(
      of: find.byKey(const ValueKey('image-tile-1')),
      matching: find.byType(InkWell),
    );
    await tester.tap(cross);

    expect(calls, ['remove 1']);
  });

  testWidgets('only the first tile carries the primary marker', (
    tester,
  ) async {
    await pump(tester, calls: []);

    expect(find.text('primär'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('image-tile-0')),
        matching: find.text('primär'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the plus tile asks to add, and is gone at the limit', (
    tester,
  ) async {
    final calls = <String>[];
    await pump(tester, calls: calls);

    final plus = find.bySemanticsLabel('Bild');
    final handle = tester.ensureSemantics();
    await tester.pump();
    await tester.tap(plus);
    expect(calls, ['add']);

    await pump(tester, maxImages: 2, calls: calls);
    await tester.pump();
    expect(find.bySemanticsLabel('Bild'), findsNothing);
    handle.dispose();
  });

  testWidgets('while a picture is added the plus tile waits and says so', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final calls = <String>[];
    await pump(tester, isAdding: true, calls: calls);
    await tester.pump();

    final node = tester.getSemantics(find.bySemanticsLabel('Bild'));
    expect(node.flagsCollection.isLiveRegion, isTrue);
    await tester.tap(find.bySemanticsLabel('Bild'), warnIfMissed: false);
    expect(calls, isEmpty);
    handle.dispose();
  });
}
