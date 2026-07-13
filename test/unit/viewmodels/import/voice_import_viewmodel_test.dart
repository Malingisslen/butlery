/// VoiceImportViewModel tests (voice plan roadmap #2, direction B).
///
/// Intention: prove the checklist contract — sections record in any order,
/// re-dictation replaces only its own section, a failed transcription
/// leaves the section untouched (typing fallback), the import button
/// unlocks only when all three sections carry text, and importRecipe hands
/// the ASSEMBLED canonical text to the voice import path.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/import/voice_import_viewmodel.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _MockImportManager extends Mock implements ImportManager {}

class _MockVoiceCapture extends Mock implements VoiceCaptureService {}

void main() {
  late _MockImportManager importManager;
  late _MockVoiceCapture voice;
  late VoiceImportViewModel vm;

  setUp(() {
    importManager = _MockImportManager();
    voice = _MockVoiceCapture();
    when(() => voice.prepareModel()).thenAnswer((_) async => true);
    when(
      () => voice.startRecording(onAutoStopped: any(named: 'onAutoStopped')),
    ).thenAnswer((_) async => true);
    when(() => voice.cancelRecording()).thenAnswer((_) async {});
    vm = VoiceImportViewModel(
      importManager: importManager,
      voiceCapture: voice,
    );
  });

  tearDown(() => vm.dispose());

  group('recording lifecycle', () {
    test(
      'record → stop lands the transcript in the chosen section only',
      () async {
        when(
          () => voice.stopAndTranscribe(),
        ).thenAnswer((_) async => 'mormors köttbullar');

        await vm.startRecording(VoiceImportSection.title);
        expect(
          vm.stateOf(VoiceImportSection.title),
          VoiceSectionState.recording,
        );

        final ok = await vm.stopRecording();

        expect(ok, isTrue);
        expect(vm.textOf(VoiceImportSection.title), 'mormors köttbullar');
        expect(vm.textOf(VoiceImportSection.ingredients), isEmpty);
        expect(vm.isDone(VoiceImportSection.title), isTrue);
      },
    );

    test('failed transcription leaves the section untouched (typing '
        'fallback)', () async {
      when(() => voice.stopAndTranscribe()).thenAnswer((_) async => null);
      vm.updateText(VoiceImportSection.title, 'handskrivet');

      await vm.startRecording(VoiceImportSection.title);
      final ok = await vm.stopRecording();

      expect(ok, isFalse);
      expect(
        vm.textOf(VoiceImportSection.title),
        'handskrivet',
        reason: 'a failed re-dictation must never erase existing text',
      );
      expect(vm.stateOf(VoiceImportSection.title), VoiceSectionState.idle);
    });

    test('only one section records at a time', () async {
      await vm.startRecording(VoiceImportSection.ingredients);
      final second = await vm.startRecording(VoiceImportSection.steps);

      expect(second, isFalse);
      expect(
        vm.stateOf(VoiceImportSection.ingredients),
        VoiceSectionState.recording,
      );
      expect(vm.stateOf(VoiceImportSection.steps), VoiceSectionState.idle);
    });

    test('model unavailable degrades to false, section stays idle', () async {
      when(() => voice.prepareModel()).thenAnswer((_) async => false);

      final started = await vm.startRecording(VoiceImportSection.title);

      expect(started, isFalse);
      expect(vm.stateOf(VoiceImportSection.title), VoiceSectionState.idle);
      verifyNever(
        () => voice.startRecording(
          onAutoStopped: any(named: 'onAutoStopped'),
        ),
      );
    });

    test('the 3-min auto-stop callback behaves like a manual stop', () async {
      when(
        () => voice.stopAndTranscribe(),
      ).thenAnswer((_) async => 'lång uppläsning');

      await vm.startRecording(VoiceImportSection.steps);
      // Per-capture wiring: the callback travels WITH startRecording, so a
      // second viewmodel can never clobber it (review finding #4).
      final capturedCallback =
          verify(
                () => voice.startRecording(
                  onAutoStopped: captureAny(named: 'onAutoStopped'),
                ),
              ).captured.single
              as void Function();
      capturedCallback();
      await Future<void>.delayed(Duration.zero);

      expect(vm.textOf(VoiceImportSection.steps), 'lång uppläsning');
    });

    test('dispose cancels ONLY a capture this viewmodel owns', () async {
      // No active capture → dispose must not cancel the shared singleton's
      // capture (another surface may own it — review finding #4).
      final idleVm = VoiceImportViewModel(
        importManager: importManager,
        voiceCapture: voice,
      );
      idleVm.dispose();
      verifyNever(() => voice.cancelRecording());

      // Owns a capture → dispose abandons it.
      await vm.startRecording(VoiceImportSection.title);
      vm.dispose();
      verify(() => voice.cancelRecording()).called(1);
      // Re-create so tearDown's dispose has a live object.
      vm = VoiceImportViewModel(
        importManager: importManager,
        voiceCapture: voice,
      );
    });
  });

  group('canImport + importRecipe', () {
    test('unlocks only when all three sections have text', () {
      expect(vm.canImport, isFalse);
      vm.updateText(VoiceImportSection.title, 'Pannkakor');
      vm.updateText(VoiceImportSection.ingredients, 'tre ägg, mjölk');
      expect(vm.canImport, isFalse);
      vm.updateText(VoiceImportSection.steps, 'Vispa och stek.');
      expect(vm.canImport, isTrue);
    });

    test('importRecipe sends the ASSEMBLED canonical text to the voice '
        'path', () async {
      final recipe = RecipeFactory.build(id: 'r1', title: 'Pannkakor');
      when(
        () => importManager.importVoiceTranscript(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => ImportManagerResult.success(recipe));

      vm.updateText(VoiceImportSection.title, 'Pannkakor.');
      vm.updateText(
        VoiceImportSection.ingredients,
        'tre ägg och två deciliter mjölk',
      );
      vm.updateText(VoiceImportSection.steps, 'Vispa. Stek i smör.');

      final result = await vm.importRecipe();

      expect(result?.isSuccess, isTrue);
      final sent =
          verify(
                () => importManager.importVoiceTranscript(
                  captureAny(),
                  options: any(named: 'options'),
                ),
              ).captured.single
              as String;
      expect(sent, contains('Pannkakor\n'));
      expect(sent, contains('Ingredienser:'));
      expect(sent, contains('tre ägg\ntvå deciliter mjölk'));
      expect(sent, contains('Gör så här:'));
      expect(sent, contains('Vispa.\nStek i smör.'));
    });

    test('a failed import surfaces errorMessage and re-enables', () async {
      when(
        () => importManager.importVoiceTranscript(
          any(),
          options: any(named: 'options'),
        ),
      ).thenAnswer((_) async => ImportManagerResult.failure('trasigt'));

      vm.updateText(VoiceImportSection.title, 'x');
      vm.updateText(VoiceImportSection.ingredients, 'y');
      vm.updateText(VoiceImportSection.steps, 'z');

      final result = await vm.importRecipe();

      expect(result?.isSuccess, isFalse);
      expect(vm.errorMessage, 'trasigt');
      expect(vm.isImporting, isFalse);
      expect(vm.canImport, isTrue, reason: 'retry must stay possible');
    });
  });
}
