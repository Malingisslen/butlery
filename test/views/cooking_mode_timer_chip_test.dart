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
import '../infrastructure/mocks/production_mocks.dart';

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
}
