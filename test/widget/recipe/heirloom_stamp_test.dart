// BUT-410: smoke tests for HeirloomStamp — ensures it renders correctly
// across writer/year permutations without localization mocking (the widget
// resolves `heirloomFrom` via context.l10n, so we wrap in MaterialApp with
// the real generated AppLocalizations delegate).

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe/heirloom_metadata.dart';
import 'package:butlery/widgets/recipe/heirloom_stamp.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

HeirloomMetadata _fixture({
  String? writerName,
  int? year,
  String? note,
}) {
  return HeirloomMetadata(
    sourceImageUrl: 'https://example.com/scan.jpg',
    writerName: writerName,
    year: year,
    note: note,
    addedAt: DateTime.utc(2026, 1, 1),
    addedByUserId: 'user-1',
  );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('sv'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('HeirloomStamp', () {
    testWidgets('renders "Från farmor, 1978" when both writer and year exist',
        (tester) async {
      await tester.pumpWidget(_wrap(
        HeirloomStamp(
          heirloom: _fixture(writerName: 'farmor', year: 1978),
        ),
      ));
      expect(find.text('Från farmor, 1978'), findsOneWidget);
    });

    testWidgets('renders writer alone when year is null', (tester) async {
      await tester.pumpWidget(_wrap(
        HeirloomStamp(heirloom: _fixture(writerName: 'farmor')),
      ));
      expect(find.text('farmor'), findsOneWidget);
    });

    testWidgets('renders year alone when writer is null', (tester) async {
      await tester.pumpWidget(_wrap(
        HeirloomStamp(heirloom: _fixture(year: 1978)),
      ));
      expect(find.text('1978'), findsOneWidget);
    });

    testWidgets('renders nothing when writer and year are both null',
        (tester) async {
      await tester.pumpWidget(_wrap(
        HeirloomStamp(heirloom: _fixture()),
      ));
      // No stamp text present → SizedBox.shrink path.
      expect(find.byType(Text), findsNothing);
    });
  });
}
