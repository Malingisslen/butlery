// test/widget/a11y/photo_import_announce_test.dart
//
// BUT-1210: the highest-value announce assertion in the family — the OCR
// announce-once guard (`_announcedOcr`) in PhotoImportView. This pumps the REAL
// view (so the REAL VM listener + production SemanticsService.announce run) over
// a thin fake VM seam, and proves the announce-once / re-arm behavioural
// contract the ticket calls out.

library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as app_provider;
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import_view.dart';

import '../../infrastructure/helpers/announce_channel.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

/// Thin fake of [PhotoImportViewModel] exposing only the surface the view reads
/// in its OCR-complete (no-image) render path. `extends ChangeNotifier` so the
/// real `_announceOcrCompletion` listener fires on [notifyListeners]; everything
/// the view doesn't touch routes through [noSuchMethod] and would surface as an
/// error if a refactor started reading it.
///
/// Keeping `hasImage == false` keeps the HeirloomSection / image-preview
/// branches out of the render tree, so the test isolates the announce contract.
class _FakePhotoImportViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  bool _hasOcrResult = false;
  bool _isProcessing = false;

  /// Drive the extract → review transition the way the OCR pipeline would,
  /// firing the single notification the view listens on.
  void emit({required bool hasOcrResult, required bool isProcessing}) {
    _hasOcrResult = hasOcrResult;
    _isProcessing = isProcessing;
    notifyListeners();
  }

  @override
  bool get hasOcrResult => _hasOcrResult;

  @override
  bool get isProcessing => _isProcessing;

  @override
  bool get hasImage => false;

  @override
  bool get hasError => false;

  @override
  String? get error => null;

  @override
  bool get canRetryOcr => false;

  @override
  double? get qualityScore => null;

  @override
  double? get confidence => null;

  @override
  bool get hasMultipleRecipes => false;

  @override
  List<Recipe> get parsedRecipes => const <Recipe>[];

  @override
  List<String>? get recommendations => null;

  @override
  String get ocrText => 'tolkad text';

  @override
  Uint8List? get imageBytes => null;

  // The view's dispose() calls removeListener + dispose() on the VM it resolved.
  // ChangeNotifier provides both; nothing else of the VM is invoked.

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePhotoImportViewModel fakeVm;

  setUp(() {
    // PhotoImportView.initState resolves the VM via the production
    // ServiceLocator (application_provider → DIContainer → GetIt.instance).
    // Register our fake there so the real view drives it.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoImportViewModel>()) {
      getIt.unregister<PhotoImportViewModel>();
    }
    fakeVm = _FakePhotoImportViewModel();
    getIt.registerFactory<PhotoImportViewModel>(() => fakeVm);

    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
  });

  tearDown(() async {
    app_provider.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoImportViewModel>()) {
      getIt.unregister<PhotoImportViewModel>();
    }
  });

  Future<AppLocalizations> pumpView(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(createLocalizedTestApp(
      wrapInScaffold: false,
      child: Builder(builder: (context) {
        l10n = context.l10n;
        return const PhotoImportView();
      }),
    ));
    await tester.pump();
    return l10n;
  }

  testWidgets(
      'announces a11yOcrComplete exactly once when OCR completes (extract → review)',
      (tester) async {
    // Proves: the extract→review transition announces the OCR-complete message
    // to screen readers — the one assertion the ticket flags as highest value.
    final announces = AnnounceChannel.arm(tester);
    final l10n = await pumpView(tester);

    fakeVm.emit(hasOcrResult: true, isProcessing: false);
    await tester.pump();

    expect(announces.messages, [l10n.a11yOcrComplete]);
  });

  testWidgets('does NOT re-announce on a second notification with same state',
      (tester) async {
    // Proves: the `_announcedOcr` guard holds — a screen reader is not spammed
    // every time the VM notifies while the result stays on screen.
    final announces = AnnounceChannel.arm(tester);
    final l10n = await pumpView(tester);

    fakeVm.emit(hasOcrResult: true, isProcessing: false);
    await tester.pump();
    expect(announces.messages, [l10n.a11yOcrComplete]);

    // Same terminal state notified again (e.g. an unrelated rebuild).
    fakeVm.emit(hasOcrResult: true, isProcessing: false);
    await tester.pump();

    expect(announces.messages, [l10n.a11yOcrComplete],
        reason: 'guard must suppress the duplicate announce');
  });

  testWidgets('re-announces after a new extraction (guard re-arms)',
      (tester) async {
    // Proves: the guard re-arms when processing restarts — a retry / new photo
    // announces again, so the announce-once is per-extraction, not per-lifetime.
    final announces = AnnounceChannel.arm(tester);
    final l10n = await pumpView(tester);

    fakeVm.emit(hasOcrResult: true, isProcessing: false);
    await tester.pump();
    expect(announces.count, 1);

    // New extraction starts: isProcessing flips back true → guard resets.
    fakeVm.emit(hasOcrResult: false, isProcessing: true);
    await tester.pump();

    // Second extraction completes.
    fakeVm.emit(hasOcrResult: true, isProcessing: false);
    await tester.pump();

    expect(announces.messages, [l10n.a11yOcrComplete, l10n.a11yOcrComplete],
        reason: 're-arm must allow a fresh announce for the new extraction');
  });

  testWidgets('does not announce while still processing', (tester) async {
    // Proves: the guard's `!isProcessing` condition — mid-extraction must stay
    // silent so the announcement coincides with the visible result appearing.
    final announces = AnnounceChannel.arm(tester);
    await pumpView(tester);

    fakeVm.emit(hasOcrResult: true, isProcessing: true);
    await tester.pump();

    expect(announces.messages, isEmpty);
  });
}
