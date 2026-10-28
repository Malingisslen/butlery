/// The "!" wiggles once, and only when it lies over text.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/feedback_fab.dart';
import 'package:butlery/widgets/common/feedback_fab_hint.dart';

import '../../infrastructure/factories/mock_factory.dart';

Widget _app({required bool textUnderButton, bool reduceMotion = false}) =>
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Stack(
        children: [
          if (textUnderButton)
            for (final bottom in [
              AppDimensions.feedbackFabBottomOffset,
              AppDimensions.feedbackFabBottomOffset + 150,
            ])
              Positioned(
                right: 16,
                bottom: bottom,
                child: const SizedBox(
                  width: AppDimensions.minTouchTarget,
                  height: AppDimensions.minTouchTarget,
                  child: Text('Lunch'),
                ),
              ),
        ],
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: Stack(
          children: [
            RepaintBoundary(key: feedbackRepaintBoundaryKey, child: child!),
            const FeedbackFAB(),
          ],
        ),
      ),
    );

Future<bool> _shown() async =>
    (await SharedPreferences.getInstance()).getBool(
      feedbackFabHintShownKey,
    ) ??
    false;

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<AuthService>(
      MockFactory.createAuthService(isAuthenticated: true),
    );
    prod.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    prod.ServiceLocator.reset();
    await GetIt.instance.reset();
  });

  testWidgets('wiggles once when the button lies over text', (tester) async {
    await tester.pumpWidget(_app(textUnderButton: true));
    final resting = tester.getTopLeft(find.text('!')).dx;

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(find.text('!')).dx, isNot(resting));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('!')).dx, resting);
    expect(await _shown(), isTrue);

    // Later polls would find the same text and wiggle again.
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.getTopLeft(find.text('!')).dx, resting);
    }
  });

  testWidgets('stays still over an empty page', (tester) async {
    await tester.pumpWidget(_app(textUnderButton: false));
    final resting = tester.getTopLeft(find.text('!')).dx;

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(find.text('!')).dx, resting);
    expect(await _shown(), isFalse);
  });

  testWidgets('does not repeat once it has been shown', (tester) async {
    SharedPreferences.setMockInitialValues({feedbackFabHintShownKey: true});
    await tester.pumpWidget(_app(textUnderButton: true));
    final resting = tester.getTopLeft(find.text('!')).dx;

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(find.text('!')).dx, resting);
  });

  testWidgets('does not move when reduced motion is on', (tester) async {
    await tester.pumpWidget(_app(textUnderButton: true, reduceMotion: true));
    final resting = tester.getTopLeft(find.text('!')).dx;

    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.getTopLeft(find.text('!')).dx, resting);
    expect(await _shown(), isFalse);
  });

  testWidgets('a drag by the person cancels the hint', (tester) async {
    await tester.pumpWidget(_app(textUnderButton: true));

    await tester.drag(find.text('!'), const Offset(0, -150));
    await tester.pumpAndSettle(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 1500));

    expect(await _shown(), isFalse);
  });
}
