/// BUT-1508: FCMService and NotificationService get the services they use by
/// constructor, and `MessagingModule` is where they are bound.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/material.dart'
    show MaterialApp, MaterialPageRoute, RouteSettings, SizedBox;
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/di/modules/messaging_module.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/repositories/firebase/firebase_shared_menu_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/device_repository.dart';
import 'package:butlery/repositories/interfaces/notification_analytics_repository.dart';
import 'package:butlery/repositories/interfaces/notification_batch_repository.dart';
import 'package:butlery/repositories/interfaces/notification_history_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart'
    show NotificationPreferences, NotificationsRepository;
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/notifications/fcm_service.dart';
import 'package:butlery/services/notifications/notification_service.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/widgets/common/feedback_fab.dart' show appNavigatorKey;

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

class _MockUserService extends Mock implements UserService {}

class _MockRecipeRepository extends Mock implements RecipeRepository {}

class _MockSharedMenuRepo extends Mock
    implements FirebaseSharedMenuRepository {}

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockPermission extends Mock implements PermissionService {}

class _MockHistoryRepo extends Mock implements NotificationHistoryRepository {}

class _MockBatchRepo extends Mock implements NotificationBatchRepository {}

class _MockDeviceRepo extends Mock implements DeviceRepository {}

class _MockAnalyticsRepo extends Mock
    implements NotificationAnalyticsRepository {}

class _FakeSharedMenu extends Fake implements SharedMenu {}

class _MockAuth extends Mock implements AuthRepository {}

/// Captures the listener FCMService registers, so a test can fire a consent
/// change.
class _Consent extends Mock implements ConsentService {
  VoidCallback? listener;
  bool granted = true;

  @override
  void addListener(VoidCallback l) => listener = l;

  @override
  void removeListener(VoidCallback l) {
    if (identical(listener, l)) listener = null;
  }

  @override
  Future<bool> hasConsent(ConsentPurpose purpose) async => granted;
}

/// What NotificationService hands FCMService, recorded.
class _SpyFcm extends Fake implements FCMService {
  ConsentService? initializedWith;
  Function(RemoteMessage)? onForeground;
  final List<RemoteMessage> shown = [];

  @override
  Future<void> initialize({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    ConsentService? consentService,
  }) async {
    initializedWith = consentService;
    onForeground = onMessageReceived;
  }

  @override
  Future<void> bindUserContext({
    Function(RemoteMessage)? onMessageReceived,
    Function(RemoteMessage)? onMessageOpenedApp,
    ConsentService? consentService,
  }) async {}

  @override
  void showForegroundNotification(RemoteMessage message) => shown.add(message);

  @override
  Future<void> dispose() async {}
}

final _getIt = GetIt.instance;

void put<T extends Object>(T instance) {
  if (_getIt.isRegistered<T>()) _getIt.unregister<T>();
  _getIt.registerSingleton<T>(instance);
}

class _Fcm {
  _Fcm({
    required this.userService,
    required this.recipeRepo,
    required this.menuRepo,
    required this.recipes,
    required this.permission,
  });

  final _MockUserService userService;
  final _MockRecipeRepository recipeRepo;
  final _MockSharedMenuRepo menuRepo;
  final _MockRecipeService recipes;
  final _MockPermission permission;
}

_Fcm _newFcmMocks() {
  final userService = _MockUserService();
  when(() => userService.updateFCMToken(any())).thenAnswer((_) async {});
  when(() => userService.clearFCMToken()).thenAnswer((_) async {});
  final recipeRepo = _MockRecipeRepository();
  final menuRepo = _MockSharedMenuRepo();
  final recipes = _MockRecipeService();
  final permission = _MockPermission();
  when(() => permission.currentUserId).thenReturn('me-uid');
  return _Fcm(
    userService: userService,
    recipeRepo: recipeRepo,
    menuRepo: menuRepo,
    recipes: recipes,
    permission: permission,
  );
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    // The module builds FCMService with the platform FirebaseMessaging.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    registerFallbackValue(RecipeFactory.build());
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<void> resetLocator() async {
    await TestServiceLocator.initialize();
    await _getIt.reset();
    prod.ServiceLocator.initialize(DIContainer());
  }

  /// Other instances of everything the services look up, so a lookup that
  /// goes to the locator finds these and not the wired ones.
  void putDecoys() {
    final decoy = _newFcmMocks();
    put<UserService>(decoy.userService);
    put<RecipeRepository>(decoy.recipeRepo);
    put<FirebaseSharedMenuRepository>(decoy.menuRepo);
    put<UnifiedRecipeService>(decoy.recipes);
    final permission = _MockPermission();
    when(() => permission.currentUserId).thenReturn('decoy-uid');
    put<PermissionService>(permission);
  }

  void defineFcmSuite(
    String label,
    Future<FCMService> Function(_Fcm wired, FirebaseMessaging messaging) build,
  ) {
    group(label, () {
      late _Fcm wired;
      late MockFirebaseMessaging messaging;
      late FCMService fcm;

      setUp(() async {
        await resetLocator();
        wired = _newFcmMocks();
        messaging = MockFirebaseMessaging();
        when(() => messaging.deleteToken()).thenAnswer((_) async {});
        fcm = await build(wired, messaging);
        putDecoys();
      });

      tearDown(() async {
        await fcm.dispose();
      });

      test('a token refresh is stored on the user service it was '
          'given', () async {
        await fcm.handleTokenRefreshForTest('tok-1');

        verify(() => wired.userService.updateFCMToken('tok-1')).called(1);
      });

      test('a consent revoke clears the token on the user service it '
          'was given', () async {
        final consent = _Consent();
        await fcm.bindUserContext(consentService: consent);

        // Revoke only undoes a grant the service has seen.
        consent.listener!();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        consent.granted = false;
        consent.listener!();
        await Future<void>.delayed(const Duration(milliseconds: 100));

        verify(() => wired.userService.clearFCMToken()).called(1);
      });

      Future<List<RouteSettings>> pumpNavigator(WidgetTester tester) async {
        final pushed = <RouteSettings>[];
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: appNavigatorKey,
            home: const SizedBox(),
            onGenerateRoute: (settings) {
              pushed.add(settings);
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SizedBox(),
              );
            },
          ),
        );
        return pushed;
      }

      RemoteMessage push(Map<String, dynamic> data) {
        final message = MockRemoteMessage();
        when(() => message.data).thenReturn(data);
        return message;
      }

      testWidgets('a shared recipe opens the recipe read from its recipe '
          'repository', (tester) async {
        final recipe = RecipeFactory.build(id: 'r1');
        when(() => wired.recipeRepo.read('r1')).thenAnswer((_) async => recipe);
        final pushed = await pumpNavigator(tester);

        await fcm.handleNotificationNavigation(
          push({
            'type': NotificationPayloadType.recipeShared,
            'recipeId': 'r1',
          }),
        );
        await tester.pumpAndSettle();

        expect(pushed.map((r) => r.name), [Routes.recipeDetail]);
        expect(pushed.single.arguments, same(recipe));
      });

      testWidgets('a collaboration invite to a recipe reads it from the '
          'recipe repository', (tester) async {
        final recipe = RecipeFactory.build(id: 'r2');
        when(() => wired.recipeRepo.read('r2')).thenAnswer((_) async => recipe);
        final pushed = await pumpNavigator(tester);

        await fcm.handleNotificationNavigation(
          push({
            'type': NotificationPayloadType.collaborationInvite,
            'resourceType': 'recipe',
            'resourceId': 'r2',
          }),
        );
        await tester.pumpAndSettle();

        expect(pushed.single.arguments, same(recipe));
      });

      testWidgets('a collaboration invite to a menu reads it from the shared '
          'menu repository', (tester) async {
        final menu = _FakeSharedMenu();
        when(
          () => wired.menuRepo.getSharedMenu('m1'),
        ).thenAnswer((_) async => menu);
        final pushed = await pumpNavigator(tester);

        await fcm.handleNotificationNavigation(
          push({
            'type': NotificationPayloadType.collaborationInvite,
            'resourceType': 'menu',
            'resourceId': 'm1',
          }),
        );
        await tester.pumpAndSettle();

        expect(pushed.map((r) => r.name), [Routes.menuPreview]);
        expect(pushed.single.arguments, same(menu));
      });

      testWidgets('a share request opens the owner\'s recipe from the recipe '
          'service and addresses the request to the permission service\'s '
          'user', (tester) async {
        final recipe = RecipeFactory.build(id: 'r3');
        when(() => wired.recipes.getRecipeById('r3')).thenReturn(recipe);
        final pushed = await pumpNavigator(tester);

        await fcm.handleNotificationNavigation(
          push({
            'type': NotificationPayloadType.recipeShareRequest,
            'recipeId': 'r3',
            'requestId': 'req-1',
            'fromUserId': 'friend-uid',
          }),
        );
        await tester.pumpAndSettle();

        final args = pushed.single.arguments! as Map<String, dynamic>;
        expect(args['recipe'], same(recipe));
        expect((args['shareRequest'] as SocialRequest).toUserId, 'me-uid');
      });
    });
  }

  defineFcmSuite(
    'FCMService built directly',
    (wired, messaging) async => FCMService(
      messaging: messaging,
      getUserService: () => wired.userService,
      getRecipeRepository: () => wired.recipeRepo,
      getSharedMenuRepository: () => wired.menuRepo,
      getRecipeService: () => wired.recipes,
      getPermissionService: () => wired.permission,
    ),
  );

  Future<void> consentFlowsToFcm({
    required NotificationService service,
    required _SpyFcm wiredFcm,
    required _Consent wiredConsent,
    required _SpyFcm decoyFcm,
  }) async {
    await service.initialize();

    expect(wiredFcm.initializedWith, same(wiredConsent));
    final message = MockRemoteMessage();
    when(() => message.notification).thenReturn(null);
    when(() => message.data).thenReturn(<String, dynamic>{});
    wiredFcm.onForeground!(message);
    expect(wiredFcm.shown, [message]);
    expect(decoyFcm.shown, isEmpty);
  }

  MockNotificationsRepository notificationRepo() {
    final repo = MockNotificationsRepository();
    when(
      () => repo.getNotificationPreferences(any()),
    ).thenAnswer((_) async => NotificationPreferences.defaults());
    return repo;
  }

  _MockAuth signedInAuth() {
    final auth = _MockAuth();
    when(() => auth.currentUserId).thenReturn('me-uid');
    return auth;
  }

  group('NotificationService built directly', () {
    test('it starts the FCM service it was given with the consent service '
        'it was given, and shows foreground pushes through it', () async {
      await resetLocator();
      final fcm = _SpyFcm();
      final consent = _Consent();
      final service = NotificationService(
        notificationsRepository: notificationRepo(),
        authRepository: signedInAuth(),
        historyRepository: _MockHistoryRepo(),
        batchRepository: _MockBatchRepo(),
        deviceRepository: _MockDeviceRepo(),
        analyticsRepository: _MockAnalyticsRepo(),
        fcmService: fcm,
        getConsentService: () => consent,
      );
      final decoyFcm = _SpyFcm();
      put<FCMService>(decoyFcm);
      put<ConsentService>(_Consent());

      await consentFlowsToFcm(
        service: service,
        wiredFcm: fcm,
        wiredConsent: consent,
        decoyFcm: decoyFcm,
      );
    });
  });

  group('NotificationService built by MessagingModule', () {
    test('it gets the FCM service and the user\'s consent service from the '
        'container', () async {
      await resetLocator();
      final fcm = _SpyFcm();
      final consent = _Consent();
      put<FCMService>(fcm);
      put<ConsentService>(consent);
      put<AuthRepository>(signedInAuth());
      put<NotificationsRepository>(notificationRepo());
      put<NotificationHistoryRepository>(_MockHistoryRepo());
      put<NotificationBatchRepository>(_MockBatchRepo());
      put<DeviceRepository>(_MockDeviceRepo());
      put<NotificationAnalyticsRepository>(_MockAnalyticsRepo());
      await MessagingModule().configureUserScope(_getIt);
      final service = _getIt<NotificationService>();

      await consentFlowsToFcm(
        service: service,
        wiredFcm: fcm,
        wiredConsent: consent,
        decoyFcm: _SpyFcm(),
      );
    });
  });

  group('FCMService built by MessagingModule', () {
    test('it reaches the container\'s user, recipe, menu and permission '
        'services', () async {
      await resetLocator();
      final wired = _newFcmMocks();
      put<UserService>(wired.userService);
      put<RecipeRepository>(wired.recipeRepo);
      put<FirebaseSharedMenuRepository>(wired.menuRepo);
      put<UnifiedRecipeService>(wired.recipes);
      put<PermissionService>(wired.permission);
      await MessagingModule().configure(_getIt);
      final fcm = _getIt<FCMService>();

      await fcm.handleTokenRefreshForTest('tok-m');
      verify(() => wired.userService.updateFCMToken('tok-m')).called(1);
    });

    testWidgets('its navigation reads from the container\'s repositories and '
        'services', (tester) async {
      await resetLocator();
      final wired = _newFcmMocks();
      final recipe = RecipeFactory.build(id: 'rm');
      when(() => wired.recipeRepo.read('rm')).thenAnswer((_) async => recipe);
      when(() => wired.recipes.getRecipeById('rm')).thenReturn(recipe);
      final menu = _FakeSharedMenu();
      when(
        () => wired.menuRepo.getSharedMenu('mm'),
      ).thenAnswer((_) async => menu);
      put<UserService>(wired.userService);
      put<RecipeRepository>(wired.recipeRepo);
      put<FirebaseSharedMenuRepository>(wired.menuRepo);
      put<UnifiedRecipeService>(wired.recipes);
      put<PermissionService>(wired.permission);
      await MessagingModule().configure(_getIt);
      final fcm = _getIt<FCMService>();
      final pushed = <RouteSettings>[];
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          home: const SizedBox(),
          onGenerateRoute: (settings) {
            pushed.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const SizedBox(),
            );
          },
        ),
      );

      Future<void> tap(Map<String, dynamic> data) async {
        final message = MockRemoteMessage();
        when(() => message.data).thenReturn(data);
        await fcm.handleNotificationNavigation(message);
        await tester.pumpAndSettle();
      }

      await tap({
        'type': NotificationPayloadType.recipeShared,
        'recipeId': 'rm',
      });
      await tap({
        'type': NotificationPayloadType.collaborationInvite,
        'resourceType': 'menu',
        'resourceId': 'mm',
      });
      await tap({
        'type': NotificationPayloadType.recipeShareRequest,
        'recipeId': 'rm',
        'requestId': 'req',
        'fromUserId': 'friend-uid',
      });

      expect(pushed.map((r) => r.name), [
        Routes.recipeDetail,
        Routes.menuPreview,
        Routes.recipeDetail,
      ]);
      expect(pushed[0].arguments, same(recipe));
      expect(pushed[1].arguments, same(menu));
      final request =
          (pushed[2].arguments! as Map<String, dynamic>)['shareRequest']
              as SocialRequest;
      expect(request.toUserId, 'me-uid');
    });
  });
}
