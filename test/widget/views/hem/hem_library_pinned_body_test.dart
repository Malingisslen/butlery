// A box body under a pinned library header starts below it: the empty state
// (#hemtom) is a boxBody, and without the overlap injector it would be laid
// out from the top of the body, under the pinned header.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/hem/hem_empty_state.dart';
import 'package:butlery/views/hem/hem_library_scroll.dart';

void main() {
  testWidgets('the empty state sits below the pinned header', (tester) async {
    const pinned = ValueKey('pinned');
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: HemLibraryScroll(
            header: const SizedBox(height: 100, child: Text('Hej Malin')),
            pinned: const SizedBox(key: pinned, height: 120),
            body: HemLibraryScroll.boxBody(const HemEmptyState()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pinnedRect = tester.getRect(find.byKey(pinned));
    final emptyRect = tester.getRect(find.byType(HemEmptyState));
    expect(emptyRect.top, greaterThanOrEqualTo(pinnedRect.bottom));
  });
}
