// test/widget/import/photo_import_draft_restore_test.dart
//
// BUT-1221 (BUT-910 follow-up): the draft-restore dialog's choice wiring in
// PhotoImportView._maybeOfferDraftRestore. The VM halves of each branch are
// pinned in test/unit/viewmodels/photo_import/photo_import_draft_test.dart;
// these tests pin the dialog→VM wiring itself:
//   accept  → restoreDraft() only;
//   decline → discardPersistedDraft() only (a regression re-prompts forever);
//   back-press (null) → NEITHER — a reflexive back must not destroy the draft
//                       (fixed in BUT-910 review, previously comment-only);
//   hasImage/hasOcrResult → no dialog at all.

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

/// Thin fake mirroring the one in photo_import_announce_test.dart, extended
/// per BUT-1221 with a configurable persisted draft and recorded
/// restore/discard calls.
class _FakePhotoImportViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  _FakePhotoImportViewModel({
    this.draft,
    bool hasImage = false,
    bool hasOcrResult = false,
  })  : _hasImage = hasImage,
        _hasOcrResult = hasOcrResult;

  final PhotoImportDraft? draft;
  final bool _hasImage;
  final bool _hasOcrResult;

  bool loadPersistedDraftCalled = false;
  bool restoreDraftCalled = false;
  bool discardPersistedDraftCalled = false;

  @override
  Future<PhotoImportDraft?> loadPersistedDraft() async {
    loadPersistedDraftCalled = true;
    return draft;
  }

  @override
  Future<bool> restoreDraft() async {
    restoreDraftCalled = true;
    return true;
  }

  @override
  Future<void> discardPersistedDraft() async {
    discardPersistedDraftCalled = true;
  }

  @override
  bool get hasImage => _hasImage;

  @override
  bool get hasOcrResult => _hasOcrResult;

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

  /// Valid 1x1 transparent PNG so ImagePreview can decode when hasImage.
  static final Uint8List _onePixelPng = Uint8List.fromList(const [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x48,
    0x44,
    0x52,
    0x00,
    0x00,
    0x00,
    0x01,
    0x00,
    0x00,
    0x00,
    0x01,
    0x08,
    0x06,
    0x00,
    0x00,
    0x00,
    0x1F,
    0x15,
    0xC4,
    0x89,
    0x00,
    0x00,
    0x00,
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x62,
    0x00,
    0x01,
    0x00,
    0x00,
    0x05,
    0x00,
    0x01,
    0x0D,
    0x0A,
    0x2D,
    0xB4,
    0x00,
    0x00,
    0x00,
    0x00,
    0x49,
    0x45,
    0x4E,
    0x44,
    0xAE,
    0x42,
    0x60,
    0x82,
  ]);

  @override
  Uint8List? get imageBytes => _hasImage ? _onePixelPng : null;

  // HeirloomSection renders whenever hasImage — give it the form surface.
  @override
  bool get isHeirloom => false;

  @override
  String get heirloomWriterName => '';

  @override
  int? get heirloomYear => null;

  @override
  String get heirloomNote => '';

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

  const draft = PhotoImportDraft(ocrText: 'sparad tolkad text');

  Future<AppLocalizations> pumpView(WidgetTester tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(createLocalizedTestApp(
      wrapInScaffold: false,
      child: Builder(builder: (context) {
        l10n = context.l10n;
        return const PhotoImportView();
      }),
    ));
    // First pump renders; second runs the post-frame draft check + dialog.
    await tester.pump();
    await tester.pump();
    return l10n;
  }

  testWidgets('accept → restoreDraft() called, discard NOT called',
      (tester) async {
    fakeVm = _FakePhotoImportViewModel(draft: draft);
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    expect(find.text(l10n.draftRecovery), findsOneWidget,
        reason: 'a persisted draft must surface the recovery dialog');
    await tester.tap(find.text(l10n.draftRestore));
    await tester.pumpAndSettle();

    expect(fakeVm.restoreDraftCalled, isTrue);
    expect(fakeVm.discardPersistedDraftCalled, isFalse);
  });

  testWidgets(
      'decline ("Börja om") → discardPersistedDraft() called, '
      'restore NOT called', (tester) async {
    fakeVm = _FakePhotoImportViewModel(draft: draft);
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    await tester.tap(find.text(l10n.draftStartFresh));
    await tester.pumpAndSettle();

    expect(fakeVm.discardPersistedDraftCalled, isTrue,
        reason: 'declining must drop the draft or it re-prompts forever');
    expect(fakeVm.restoreDraftCalled, isFalse);
  });

  testWidgets('back-press (dialog pops null) → NEITHER called; draft survives',
      (tester) async {
    fakeVm = _FakePhotoImportViewModel(draft: draft);
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    expect(find.text(l10n.draftRecovery), findsOneWidget);
    // System back pops the dialog with null (barrierDismissible is false,
    // but back navigation still pops the route).
    final dynamic state = tester.state(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();

    expect(find.text(l10n.draftRecovery), findsNothing,
        reason: 'back must close the dialog');
    expect(fakeVm.restoreDraftCalled, isFalse);
    expect(fakeVm.discardPersistedDraftCalled, isFalse,
        reason: 'a reflexive back-press must not destroy the draft');
  });

  testWidgets('no dialog when the VM already has an image', (tester) async {
    fakeVm = _FakePhotoImportViewModel(draft: draft, hasImage: true);
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    expect(find.text(l10n.draftRecovery), findsNothing);
    expect(fakeVm.loadPersistedDraftCalled, isFalse,
        reason: 'the guard must short-circuit before touching persistence');
  });

  testWidgets('no dialog when the VM already has an OCR result',
      (tester) async {
    fakeVm = _FakePhotoImportViewModel(draft: draft, hasOcrResult: true);
    registerFake(fakeVm);
    final l10n = await pumpView(tester);

    expect(find.text(l10n.draftRecovery), findsNothing);
    expect(fakeVm.loadPersistedDraftCalled, isFalse);
  });
}
