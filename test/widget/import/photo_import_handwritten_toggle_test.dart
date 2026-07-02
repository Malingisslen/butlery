// test/widget/import/photo_import_handwritten_toggle_test.dart
//
// BUT-684 (client half): the handwritten-recipe toggle on the photo-import
// screen. Proves the control renders, defaults OFF, and that flipping it flows
// straight into PhotoImportViewModel.setHandwritten — the VM state that the
// import pipeline reads to pass isHandwritten:true to the OCR call. The
// VM→autoImport→ocrRecipeImage half is pinned in
// test/unit/viewmodels/photo_import_viewmodel_test.dart and the LLM/service
// tests; this pins the UI→VM wiring.

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
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/views/photo_import_view.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

/// Minimal fake exposing just the surface PhotoImportView reads when there's
/// no image yet, plus a REAL isHandwritten field + setHandwritten so a tap on
/// the switch actually mutates state (the behaviour under test).
class _FakePhotoImportViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  _FakePhotoImportViewModel({this.canToggleHandwritten = true});

  bool _isHandwritten = false;

  /// Mirrors the real VM: canToggleHandwritten == !isProcessing (false only
  /// while an import is in flight — no capture-lock).
  @override
  final bool canToggleHandwritten;

  @override
  bool get isHandwritten => _isHandwritten;

  @override
  void setHandwritten(bool value) {
    if (_isHandwritten == value || !canToggleHandwritten) return;
    _isHandwritten = value;
    notifyListeners();
  }

  @override
  bool get hasImage => false;

  @override
  bool get hasOcrResult => false;

  @override
  bool get isProcessing => false;

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
  String get ocrText => '';

  @override
  Uint8List? get imageBytes => null;

  // Post-frame draft-restore check: no draft in this scenario.
  @override
  Future<PhotoImportDraft?> loadPersistedDraft() async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakePhotoImportViewModel fakeVm;

  void registerFake(_FakePhotoImportViewModel vm) {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoImportViewModel>()) {
      getIt.unregister<PhotoImportViewModel>();
    }
    getIt.registerFactory<PhotoImportViewModel>(() => vm);
    app_provider.ServiceLocator.reset();
    app_provider.ServiceLocator.initialize(DIContainer());
  }

  tearDown(() async {
    app_provider.ServiceLocator.reset();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoImportViewModel>()) {
      getIt.unregister<PhotoImportViewModel>();
    }
  });

  Future<AppLocalizations> pumpView(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) {
            l10n = context.l10n;
            return const PhotoImportView();
          },
        ),
      ),
    );
    await tester.pump(); // render
    await tester.pump(); // post-frame draft check
    return l10n;
  }

  testWidgets('toggle renders, defaults OFF', (tester) async {
    fakeVm = _FakePhotoImportViewModel();
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    expect(find.text(l10n.importHandwrittenToggle), findsOneWidget);
    final switchWidget = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchWidget.value, isFalse);
    expect(fakeVm.isHandwritten, isFalse);
  });

  testWidgets('flipping the toggle sets VM.isHandwritten true', (tester) async {
    fakeVm = _FakePhotoImportViewModel();
    registerFake(fakeVm);
    await pumpView(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();

    expect(
      fakeVm.isHandwritten,
      isTrue,
      reason: 'tapping the toggle must flow through to setHandwritten',
    );
    final switchWidget = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchWidget.value, isTrue);
  });

  testWidgets('BUT-1460: toggle is disabled while an import is processing', (
    tester,
  ) async {
    // canToggleHandwritten == !isProcessing. A false value models an import in
    // flight — flipping mid-pipeline would race it, so the switch is disabled.
    // (There is no capture-lock anymore: a completed capture stays switchable.)
    fakeVm = _FakePhotoImportViewModel(canToggleHandwritten: false);
    registerFake(fakeVm);
    await pumpView(tester);

    final switchWidget = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(
      switchWidget.onChanged,
      isNull,
      reason: 'a processing import must not be interruptible via the toggle',
    );
  });
}
