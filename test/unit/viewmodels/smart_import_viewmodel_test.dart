import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/viewmodels/import_progress_tracker.dart';

class MockImportManager extends Mock implements ImportManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SmartImportViewModel viewModel;
  late MockImportManager mockImportManager;

  setUp(() {
    mockImportManager = MockImportManager();
    viewModel = SmartImportViewModel(
      importManager: mockImportManager,
    );
  });

  tearDown(() {
    viewModel.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void setClipboardContent(String? text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.hasStrings') {
        return <String, dynamic>{'value': text != null && text.isNotEmpty};
      }
      if (methodCall.method == 'Clipboard.getData') {
        if (text == null) return null;
        return <String, dynamic>{'text': text};
      }
      return null;
    });
  }

  void setClipboardError() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform,
            (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.hasStrings') {
        return <String, dynamic>{'value': true};
      }
      if (methodCall.method == 'Clipboard.getData') {
        throw PlatformException(
            code: 'ERROR', message: 'Clipboard unavailable');
      }
      return null;
    });
  }

  group('checkClipboardForUrl', () {
    test('sets clipboardUrl when clipboard contains a URL', () async {
      setClipboardContent('https://www.ica.se/recept/pasta-carbonara/');

      await viewModel.checkClipboardForUrl();

      expect(
          viewModel.clipboardUrl, 'https://www.ica.se/recept/pasta-carbonara/');
    });

    test('does not set clipboardUrl for plain text', () async {
      setClipboardContent('Just some plain text about cooking');

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('does not set clipboardUrl for empty clipboard', () async {
      setClipboardContent(null);

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('does not set clipboardUrl for empty string', () async {
      setClipboardContent('');

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('handles clipboard error gracefully', () async {
      setClipboardError();

      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('does not re-prompt for same URL on second call', () async {
      setClipboardContent('https://www.ica.se/recept/pasta/');

      await viewModel.checkClipboardForUrl();
      expect(viewModel.clipboardUrl, 'https://www.ica.se/recept/pasta/');

      // Clear and check again — same URL should not re-trigger
      viewModel.clearClipboardSuggestion();
      await viewModel.checkClipboardForUrl();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('notifies listeners when URL is found', () async {
      setClipboardContent('https://www.recept.se/test');

      var notified = false;
      viewModel.addListener(() => notified = true);

      await viewModel.checkClipboardForUrl();

      expect(notified, isTrue);
    });

    test('does not notify listeners when no URL found', () async {
      setClipboardContent('plain text');

      var notified = false;
      viewModel.addListener(() => notified = true);

      await viewModel.checkClipboardForUrl();

      expect(notified, isFalse);
    });
  });

  group('clearClipboardSuggestion', () {
    test('resets clipboardUrl to null', () async {
      setClipboardContent('https://www.ica.se/recept/test/');

      await viewModel.checkClipboardForUrl();
      expect(viewModel.clipboardUrl, isNotNull);

      viewModel.clearClipboardSuggestion();

      expect(viewModel.clipboardUrl, isNull);
    });

    test('notifies listeners', () async {
      setClipboardContent('https://www.ica.se/recept/test/');
      await viewModel.checkClipboardForUrl();

      var notified = false;
      viewModel.addListener(() => notified = true);

      viewModel.clearClipboardSuggestion();

      expect(notified, isTrue);
    });
  });

  group('elapsed timer', () {
    test('elapsed is Duration.zero before import', () {
      expect(viewModel.elapsed, Duration.zero);
    });

    test('elapsed getter is available on viewModel', () {
      // Verifies the getter exists and returns a Duration
      expect(viewModel.elapsed, isA<Duration>());
    });
  });

  group('ImportProgressTracker', () {
    late ImportProgressTracker tracker;
    late int notifyCount;
    late List<ImportPhase> phaseChanges;

    setUp(() {
      notifyCount = 0;
      phaseChanges = [];
      tracker = ImportProgressTracker(
        notifyListeners: () => notifyCount++,
        setPhase: (phase) => phaseChanges.add(phase),
        isDisposed: () => false,
      );
    });

    tearDown(() {
      tracker.dispose();
    });

    test('elapsed is Duration.zero before start', () {
      expect(tracker.elapsed, Duration.zero);
      expect(tracker.isRunning, isFalse);
    });

    test('start begins tracking', () {
      tracker.start();
      expect(tracker.isRunning, isTrue);
    });

    test('stop ends tracking', () {
      tracker.start();
      tracker.stop();
      expect(tracker.isRunning, isFalse);
    });

    test('reset clears elapsed and stops', () {
      tracker.start();
      tracker.reset();
      expect(tracker.isRunning, isFalse);
      expect(tracker.elapsed, Duration.zero);
    });

    test('onProgress maps fetching to ImportPhase.fetching', () {
      tracker.onProgress('fetching');
      expect(phaseChanges, [ImportPhase.fetching]);
    });

    test('onProgress maps analyzing to ImportPhase.analyzing', () {
      tracker.onProgress('analyzing');
      expect(phaseChanges, [ImportPhase.analyzing]);
    });

    test('onProgress maps creating to ImportPhase.creating', () {
      tracker.onProgress('creating');
      expect(phaseChanges, [ImportPhase.creating]);
    });

    test('onProgress maps unknown string to ImportPhase.analyzing', () {
      tracker.onProgress('unknown_phase');
      expect(phaseChanges, [ImportPhase.analyzing]);
    });

    test('onProgress skips when disposed', () {
      final disposedTracker = ImportProgressTracker(
        notifyListeners: () {},
        setPhase: (phase) => phaseChanges.add(phase),
        isDisposed: () => true,
      );
      disposedTracker.onProgress('fetching');
      expect(phaseChanges, isEmpty);
      disposedTracker.dispose();
    });

    test('dispose cancels timer without error', () {
      tracker.start();
      expect(tracker.isRunning, isTrue);
      tracker.dispose();
      // After dispose, the timer is cancelled
      // (no way to check timer directly, but no error thrown)
    });
  });
}
