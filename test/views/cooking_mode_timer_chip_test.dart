// BUT-2183 5o: the timer chip inside a cooking-mode step fills with the raised
// surface on ink, in both modes. The chip's text is paper, so the page's own
// raised surface (a pale tint in light mode) would put paper on paper.

library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/cooking_mode_view.dart';
import 'package:butlery/widgets/cooking/inline_timer_text.dart';

import '../infrastructure/factories/recipe_factory.dart';
import '../infrastructure/helpers/ink_fill.dart';
import '../infrastructure/mocks/production_mocks.dart';
import '../test_support/semantics_announcement.dart';

class _MockPersistenceService extends Mock implements PersistenceService {}

class _NoEffects implements CookingSessionEffects {
  @override
  void lockLandscape() {}

  @override
  void releaseOrientation() {}

  @override
  void keepScreenAwake({required bool on}) {}

  @override
  void edgeToEdge() {}
}

class _FakeTts extends Fake implements TtsService {
  @override
  bool get isAvailable => false;

  @override
  bool get isSpeaking => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeCapture extends Fake implements VoiceCaptureService {
  @override
  bool get isRecording => false;

  @override
  Future<void> cancelRecording() async {}
}

class _FakeSubstitutions extends Fake implements SubstitutionSuggestionService {
  @override
  Future<List<IngredientSubstitution>> suggestFor(
    String ingredientName,
  ) async => const [];
}

void main() {
  late StepTimerService timers;

  setUp(() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PersistenceService>()) {
      getIt.unregister<PersistenceService>();
    }
    if (getIt.isRegistered<OfflineService>()) {
      getIt.unregister<OfflineService>();
    }
    if (getIt.isRegistered<TtsService>()) getIt.unregister<TtsService>();
    if (getIt.isRegistered<VoiceCaptureService>()) {
      getIt.unregister<VoiceCaptureService>();
    }
    if (getIt.isRegistered<StepTimerService>()) {
      getIt.unregister<StepTimerService>();
    }
    if (getIt.isRegistered<SubstitutionSuggestionService>()) {
      getIt.unregister<SubstitutionSuggestionService>();
    }
    production.ServiceLocator.initialize(DIContainer());
    final persistence = _MockPersistenceService();
    when(() => persistence.getInt(any())).thenAnswer((_) async => null);
    when(() => persistence.setInt(any(), any())).thenAnswer((_) async {});
    when(() => persistence.getBool(any())).thenAnswer((_) async => true);
    when(() => persistence.setBool(any(), any())).thenAnswer((_) async {});
    getIt.registerSingleton<PersistenceService>(persistence);
    final offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(() => offline.addListener(any())).thenReturn(null);
    when(() => offline.removeListener(any())).thenReturn(null);
    getIt.registerSingleton<OfflineService>(offline);
    getIt.registerSingleton<TtsService>(_FakeTts());
    getIt.registerSingleton<VoiceCaptureService>(_FakeCapture());
    timers = StepTimerService();
    getIt.registerSingleton<StepTimerService>(timers);
    getIt.registerSingleton<SubstitutionSuggestionService>(
      _FakeSubstitutions(),
    );
  });

  tearDown(() {
    timers.dispose();
  });

  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('the step timer chip fills with the on-ink raised surface '
        '($mode)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CookingModeView(
            recipe: RecipeFactory.build(
              id: 'r1',
              title: 'Köttbullar',
              ingredients: ['500 g blandfärs'],
              instructions: ['Stek bollarna i 10 min.'],
              portions: 4,
            ),
            effects: _NoEffects(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final chip = tester.widget<InlineTimerText>(find.byType(InlineTimerText));
      expect(chip.chipFill, AppModeColors.surfaceRaisedOnInk());
    });
  }

  testWidgets('a step and an ingredient row announce nothing twice', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CookingModeView(
          recipe: RecipeFactory.build(
            id: 'r1',
            title: 'Köttbullar',
            ingredients: ['500 g blandfärs'],
            instructions: ['Stek bollarna i 10 min.'],
            portions: 4,
          ),
          effects: _NoEffects(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final step = find.bySemanticsLabel(
      RegExp('Långtryck för att starta timer'),
    );
    expect(step, findsWidgets);
    expect(announcedLines(tester, step.first), [
      'Steg',
      '1',
      'Långtryck för att starta timer',
    ]);
    expectNothingAnnouncedTwice(tester, step.first);

    final ingredient = find.bySemanticsLabel('500 g blandfärs');
    expect(ingredient, findsOneWidget);
    expect(announcedLines(tester, ingredient), ['500 g blandfärs']);
    handle.dispose();
  });

  // BUT-1601: the view must hand the view model's step amounts to the step
  // text; each layer passes on its own, so only this pins the join.
  testWidgets('a step shows the ingredient amount and follows the stepper', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CookingModeView(
          recipe: RecipeFactory.build(
            id: 'r1',
            title: 'Tomatsås',
            ingredients: ['4 tomater'],
            instructions: ['Tärna tomaterna.'],
            portions: 4,
          ),
          effects: _NoEffects(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    String stepText() => tester
        .widget<RichText>(
          find
              .descendant(
                of: find.byType(InlineTimerText),
                matching: find.byType(RichText),
              )
              .first,
        )
        .text
        .toPlainText();

    expect(stepText(), 'Tärna tomaterna (4).');
    await tester.tap(find.bySemanticsLabel('Öka portioner'));
    await tester.pumpAndSettle();
    expect(stepText(), 'Tärna tomaterna (5).');
  });

  // BUT-2205: the cooking base is ink in light mode and the dark page in
  // dark mode, so the portion button presses to the step on ink in light
  // and to surface.raised in dark.
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('a pressed portion button takes the fill of the cooking '
        'base ($mode)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          locale: const Locale('sv'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CookingModeView(
            recipe: RecipeFactory.build(
              id: 'r1',
              title: 'Köttbullar',
              ingredients: ['500 g blandfärs'],
              instructions: ['Stek bollarna i 10 min.'],
              portions: 4,
            ),
            effects: _NoEffects(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final target = find.descendant(
        of: find.bySemanticsLabel('Öka portioner'),
        matching: find.byType(InkWell),
      );
      final gesture = await holdPress(tester, target);
      final fill = theme.brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainerHighest
          : ModeColors.of(theme.brightness).pressedOnInk;
      expect(paintsInkFill(tester, target, fill), isTrue);
      await gesture.cancel();
    });
  }
}
