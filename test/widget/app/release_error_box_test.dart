import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/main.dart' show releaseErrorBox;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A part of a screen that fails to build in a release build says so and
/// names the error, and leaves the rest of the screen in place.
void main() {
  FlutterErrorDetails details() => FlutterErrorDetails(
    exception: StateError('Bad state: no element\nsecond line'),
  );

  testWidgets('inside a scroll view it takes only its own height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: releaseErrorBox(details())),
              const SliverToBoxAdapter(child: Text('Dina recept')),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Den här delen kunde inte visas.'), findsOneWidget);
    expect(
      find.text('StateError: Bad state: Bad state: no element'),
      findsOneWidget,
    );
    // Flutter's own release box would push the next sliver off screen.
    expect(find.text('Dina recept').hitTestable(), findsOneWidget);
  });

  testWidgets('above MaterialApp it falls back to the Swedish text', (
    tester,
  ) async {
    await tester.pumpWidget(releaseErrorBox(details()));
    expect(find.text('Den här delen kunde inte visas.'), findsOneWidget);
  });
}
