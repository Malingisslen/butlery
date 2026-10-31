// BUT-920: the import screens a guest can reach by more than one way. Opening
// one starts a new counted import, and the server's limit opens the account
// sheet there.

import 'dart:typed_data';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_ai_offer_mixin.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/photo_import_view.dart';
import 'package:butlery/widgets/guest/guest_import_limit_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/helpers/offline_banner_support.dart';
import 'guest_test_support.dart';

final _sv = AppLocalizationsSv();

/// The getters PhotoImportView reads on an empty screen.
class _EmptyPhotoImportViewModel extends ChangeNotifier
    implements PhotoImportViewModel {
  @override
  Future<PhotoImportDraft?> loadPersistedDraft() async => null;
  @override
  bool get hasImage => false;
  @override
  bool get hasOcrResult => false;
  @override
  bool get isProcessing => false;
  @override
  PhotoAiOfferReason? get aiOffer => null;

  @override
  bool get aiConsentAlreadyGiven => false;

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
  bool get isHandwritten => false;
  @override
  bool get canToggleHandwritten => true;
  @override
  Uint8List? get imageBytes => null;
  @override
  List<Uint8List> get pageImages => const [];
  @override
  int get pageCount => 0;
  @override
  bool get hasMultiplePages => false;
  @override
  bool get canAddPage => false;
  @override
  bool get isHeirloom => false;
  @override
  String get heirloomWriterName => '';
  @override
  int? get heirloomYear => null;
  @override
  String get heirloomNote => '';
  @override
  PhotoPermissionResolver? permissionResolver;
  @override
  PhotoPermissionNotice? get permissionNotice => null;
  @override
  int get unreadPageCount => 0;
  @override
  bool get canReadPages => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late GuestImportSession session;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerAuth(FakeAuthService(FakeUser(isAnonymous: true)));
    session = GuestImportSession(uid: () => 'uid-1');
    GetIt.instance.registerSingleton<GuestImportSession>(session);
  });
  tearDown(resetLocator);

  testWidgets('opening an import screen starts a new import', (tester) async {
    final before = session.currentId;

    await tester.pumpWidget(
      guestApp(const GuestImportLimitListener(child: SizedBox())),
    );

    expect(session.currentId, isNot(before));
  });

  group('photo import screen', () {
    setUp(() {
      ensureOfflineService();
      GetIt.instance.registerFactory<PhotoImportViewModel>(
        _EmptyPhotoImportViewModel.new,
      );
    });

    Future<void> pumpPhotoImport(WidgetTester tester) async {
      await tester.pumpWidget(guestApp(const PhotoImportView()));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('opening it starts a new import', (tester) async {
      final before = session.currentId;

      await pumpPhotoImport(tester);

      expect(session.currentId, isNot(before));
    });

    testWidgets('the server limit opens the account sheet on it', (
      tester,
    ) async {
      await pumpPhotoImport(tester);

      await session.recordLimitReached();
      await tester.pumpAndSettle();

      expect(find.text(_sv.guestSheetImportLimitTitle), findsOneWidget);
    });
  });
}
