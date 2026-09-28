/// P8-U01 hosts: import, cooking mode and profile/settings.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/models/notification_preferences.dart';
import 'package:butlery/services/auth/auth_mfa_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/cooking/step_timer_service.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/notifications/notification_permission_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/persistence_service.dart';
import 'package:butlery/services/voice/tts_service.dart';
import 'package:butlery/services/voice/voice_capture_service.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/views/cooking_mode_view.dart';
import 'package:butlery/views/photo_import/heirloom_section.dart';
import 'package:butlery/views/settings/account_security_view.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';
import 'package:butlery/views/smart_import_view.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';

class _MockImportManager extends Mock implements ImportManager {}

class _MockPhotoImportViewModel extends Mock implements PhotoImportViewModel {}

class _MockPersistence extends Mock implements PersistenceService {}

class _MockAuthMfa extends Mock implements AuthMfaService {}

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

/// No rotation, no wake lock, no system UI change under test.
class _NoEffects implements CookingSessionEffects {
  const _NoEffects();

  @override
  void lockLandscape() {}

  @override
  void releaseOrientation() {}

  @override
  void keepScreenAwake({required bool on}) {}

  @override
  void edgeToEdge() {}
}

/// The clipboard answers empty, so the import view proposes nothing.
void _emptyClipboard(HostContext ctx) {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return <String, dynamic>{'text': ''};
    }
    return null;
  });
  ctx.disposers.add(
    () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
  );
}

Widget _smartImport(HostContext ctx, {Future<ImportManagerResult>? pending}) {
  _emptyClipboard(ctx);
  final manager = _MockImportManager();
  if (pending != null) {
    when(
      () => manager.autoImport(
        any(),
        preferredStrategy: any(named: 'preferredStrategy'),
        options: any(named: 'options'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer((_) => pending);
  }
  TestServiceLocator.registerMock<ImportManager>(manager);
  return const SmartImportView();
}

Widget _heirloomOffline() {
  final vm = _MockPhotoImportViewModel();
  when(() => vm.isHeirloom).thenReturn(true);
  when(() => vm.isOfflineQueued).thenReturn(true);
  when(() => vm.heirloomWriterName).thenReturn('Mormor Ingrid');
  when(() => vm.heirloomYear).thenReturn(1962);
  when(() => vm.heirloomNote).thenReturn('Skrivet på baksidan av en kalender');
  // As photo_import_view.dart:386-389 and :520-523 place it: in the photo
  // import page ("Importera från foto") and its scrolling column, under the
  // chosen photo.
  return Scaffold(
    appBar: ButleryTopBar.undersida(title: sv.importFromPhoto),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: HeirloomSection(viewModel: vm),
    ),
  );
}

Widget _cooking() {
  final persistence = _MockPersistence();
  when(() => persistence.getInt(any())).thenAnswer((_) async => null);
  when(() => persistence.setInt(any(), any())).thenAnswer((_) async {});
  when(() => persistence.getBool(any())).thenAnswer((_) async => true);
  when(() => persistence.setBool(any(), any())).thenAnswer((_) async {});
  TestServiceLocator.registerMock<PersistenceService>(persistence);
  TestServiceLocator.registerMock<TtsService>(_FakeTts());
  TestServiceLocator.registerMock<VoiceCaptureService>(_FakeCapture());
  TestServiceLocator.registerMock<StepTimerService>(StepTimerService());
  TestServiceLocator.registerMock<SubstitutionSuggestionService>(
    _FakeSubstitutions(),
  );
  return CookingModeView(
    recipe: RecipeFactory.build(
      id: 'r1',
      title: 'Krämig svamppasta med timjan',
      ingredients: ['400 g svamp', '350 g pasta', '2 dl grädde'],
      instructions: [
        'Skiva svampen och stek den gyllene i smör.',
        'Koka pastan al dente i saltat vatten.',
        'Rör ner grädden och timjan, och vänd ner pastan.',
      ],
      portions: 4,
    ),
    effects: const _NoEffects(),
  );
}

MockAuthService _securityAuth({Future<bool> Function()? reauth}) {
  final auth = MockAuthService()..setAuthState(isAuthenticated: true);
  when(
    () => auth.reauthenticateWithPassword(any()),
  ).thenAnswer((_) => reauth?.call() ?? Future.value(true));
  TestServiceLocator.registerMock<AuthService>(auth);
  final mfa = _MockAuthMfa();
  when(mfa.getEnrolledFactors).thenAnswer((_) async => []);
  when(mfa.hasMfaEnabled).thenAnswer((_) async => false);
  TestServiceLocator.registerMock<AuthMfaService>(mfa);
  return auth;
}

final taskHosts = <String, StateHost>{
  'import-av-recept::DEFAULT': StateHost(
    build: (ctx) async => _smartImport(ctx),
  ),
  'import-av-recept::LOADING': StateHost(
    build: (ctx) async =>
        _smartImport(ctx, pending: Completer<ImportManagerResult>().future),
    reach: (tester, ctx) async {
      await tester.enterText(
        find.byType(TextField).first,
        'https://www.koket.se/kramig-svamppasta',
      );
      await tester.pump();
      final button = find.byKey(const ValueKey('test-smart-import-url'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    },
  ),
  'import-av-recept::OFFLINE': StateHost(
    online: false,
    build: (ctx) async => _heirloomOffline(),
  ),
  'matlagningsläge::DEFAULT': StateHost(
    landscape: true,
    build: (ctx) async => _cooking(),
  ),
  'matlagningsläge::OFFLINE': StateHost(
    landscape: true,
    online: false,
    build: (ctx) async => _cooking(),
  ),
  'profil-inställningar::DEFAULT': StateHost(
    build: (ctx) async {
      _securityAuth();
      return const AccountSecurityView();
    },
  ),
  'profil-inställningar::LOADING': StateHost(
    build: (ctx) async {
      _securityAuth(reauth: () => Completer<bool>().future);
      return const AccountSecurityView();
    },
    reach: (tester, ctx) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(3), 'hemligt-losenord');
      await tester.enterText(fields.at(4), 'malin@example.com');
      await tester.pump();
      final button = find.widgetWithText(
        FilledButton,
        sv.accountSecurityChangeEmail,
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
    },
  ),
  'profil-inställningar::OFFLINE': StateHost(
    online: false,
    build: (ctx) async {
      final notifications = MockNotificationService();
      when(
        notifications.getPreferences,
      ).thenAnswer((_) async => NotificationPreferences.defaults());
      TestServiceLocator.registerMock<NotificationService>(notifications);
      final permission = MockNotificationPermissionService();
      when(permission.blockedInSystem).thenAnswer((_) async => false);
      TestServiceLocator.registerMock<NotificationPermissionService>(
        permission,
      );
      return const NotificationPreferencesView();
    },
  ),
};
