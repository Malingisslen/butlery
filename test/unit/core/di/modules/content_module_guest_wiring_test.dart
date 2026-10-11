/// BUT-920: the user scope hands the AI service the guest's import session
/// and the signed-in user's guest status, so a guest's recipe import carries
/// the import id the server counts. Resolved through the real module and the
/// real FirebaseFunctions front, with only the platform underneath replaced.
library;

// FirebaseFunctions' platform seam is not exported by cloud_functions.
// ignore_for_file: depend_on_referenced_packages

import 'package:cloud_functions_platform_interface/cloud_functions_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_import_session.dart';
import 'package:butlery/services/import/import_rate_limiter.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/services/llm/llm_service.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';

import '../../../../widget/guest/guest_test_support.dart';

class _MockIngredientRepository extends Mock implements IngredientRepository {}

class _Limiter extends Fake implements ImportRateLimiter {
  @override
  Future<RateLimitResult> checkLimit(ImportOperation operation) async =>
      const RateLimitAllowed(
        remainingInWindow: 999,
        limitType: LimitType.perMinute,
      );

  @override
  Future<void> recordUsage(ImportOperation operation) async {}
}

class _Consent extends Fake implements ConsentService {
  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async => true;
}

class _Callable extends HttpsCallablePlatform {
  _Callable(
    super.functions,
    super.origin,
    super.name,
    super.options,
    super.uri,
  );

  @override
  Future<dynamic> call([dynamic parameters]) async {
    (functions as _FunctionsPlatform).sent.add(parameters);
    return <String, dynamic>{'success': true, 'estimatedCost': 0.001};
  }
}

class _FunctionsPlatform extends FirebaseFunctionsPlatform
    with MockPlatformInterfaceMixin {
  _FunctionsPlatform() : super(null, 'europe-west1');

  final sent = <dynamic>[];

  @override
  FirebaseFunctionsPlatform delegateFor({
    FirebaseApp? app,
    required String region,
  }) => this;

  @override
  HttpsCallablePlatform httpsCallable(
    String? origin,
    String name,
    HttpsCallableOptions options,
  ) => _Callable(this, origin, name, options, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = _FunctionsPlatform();
  late GetIt userScope;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseFunctionsPlatform.instance = platform;
  });

  Future<void> signInAs({required bool anonymous}) async {
    SharedPreferences.setMockInitialValues({});
    platform.sent.clear();
    final repo = _MockIngredientRepository();
    when(() => repo.getByGroup(any())).thenAnswer((_) async => []);
    GetIt.instance
      ..registerSingleton<IngredientRegistryService>(
        IngredientRegistryService(ingredientRepository: repo),
      )
      ..registerSingleton<ImportRateLimiter>(_Limiter());
    userScope = GetIt.asNewInstance()
      ..registerSingleton<AuthService>(
        FakeAuthService(FakeUser(isAnonymous: anonymous)),
      )
      ..registerSingleton<ConsentService>(_Consent());
    await ContentModule().configureUserScope(userScope);
    await pumpEventQueue();
  }

  tearDown(() async {
    await userScope.reset();
    await GetIt.instance.reset();
  });

  test('a guest\'s structureRecipe carries the id of the session the user '
      'scope registers', () async {
    await signInAs(anonymous: true);
    final session = userScope<GuestImportSession>();
    session.begin();

    await userScope<LlmService>().structureRecipe(text: 'Pannkakor');

    final sent = platform.sent.single as Map;
    expect(sent['guestImportId'], session.currentId);
    expect(sent['guestImportId'], hasLength(20));
  });

  test('a signed-in user\'s structureRecipe carries no import id', () async {
    await signInAs(anonymous: false);

    await userScope<LlmService>().structureRecipe(text: 'Pannkakor');

    expect(platform.sent.single as Map, isNot(contains('guestImportId')));
  });
}
