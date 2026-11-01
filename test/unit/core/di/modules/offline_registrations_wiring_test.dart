/// BUT-1508: the offline store and the "Väntar på synk" source get their
/// services from `ContentModule`, as lookups on the container the user signed
/// in under. Every service sits only in that container (never in
/// `GetIt.instance`), so a link that reaches for the global locator or for a
/// different service finds nothing, or the wrong object.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/modules/content_module.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/cook_snap_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/messaging_repository.dart';
import 'package:butlery/services/cook_snap_service.dart';
import 'package:butlery/services/offline/sync_queue_source.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/parsing/ingredient_registry_service.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/user_service.dart';

class _Storage extends Mock implements StorageService {}

class _Users extends Mock implements UserService {}

class _Auth extends Mock implements AuthRepository {}

class _Messaging extends Mock implements MessagingRepository {}

class _Comments extends Mock implements CommentsRepository {}

class _CookSnaps extends Mock implements CookSnapRepository {}

class _CookSnapService extends Mock implements CookSnapService {}

class _Tagging extends Mock implements TaggingService {}

class _Realtime extends Mock implements RealtimeSyncService {}

class _IngredientRepo extends Mock implements IngredientRepository {}

void main() {
  late GetIt userScope;
  late _Storage storage;
  late _Users users;
  late _Auth auth;
  late _Messaging messaging;
  late _Comments comments;
  late _CookSnaps cookSnaps;
  late _CookSnapService cookSnapService;
  late _Tagging tagging;
  late IngredientRegistryService registry;

  setUp(() {
    final ingredients = _IngredientRepo();
    when(() => ingredients.getByGroup(any())).thenAnswer((_) async => []);
    registry = IngredientRegistryService(ingredientRepository: ingredients);
    final app = GetIt.instance;
    app.registerSingleton<IngredientRegistryService>(registry);
    // OfflineService takes this one from the app container.
    app.registerSingleton<AuthRepository>(_Auth());

    userScope = GetIt.asNewInstance();
    storage = _Storage();
    users = _Users();
    auth = _Auth();
    messaging = _Messaging();
    comments = _Comments();
    cookSnaps = _CookSnaps();
    cookSnapService = _CookSnapService();
    tagging = _Tagging();
    userScope
      ..registerSingleton<StorageService>(storage)
      ..registerSingleton<UserService>(users)
      ..registerSingleton<AuthRepository>(auth)
      ..registerSingleton<MessagingRepository>(messaging)
      ..registerSingleton<CommentsRepository>(comments)
      ..registerSingleton<CookSnapRepository>(cookSnaps)
      ..registerSingleton<CookSnapService>(cookSnapService)
      ..registerSingleton<TaggingService>(tagging);
  });

  tearDown(() async {
    OfflineService.resetForTesting();
    SyncQueueSource.appSource = const OfflineSyncQueueSource.unwired();
    await userScope.reset();
    await GetIt.instance.reset();
  });

  Future<OfflineService> offlineService() async {
    await ContentModule().configureUserScope(userScope);
    return userScope<OfflineService>();
  }

  test('each link of the offline store reaches the service of the signed-in '
      'container', () async {
    final links = (await offlineService()).links!;

    expect(links.storage(), same(storage));
    expect(links.users(), same(users));
    expect(links.auth(), same(auth));
    expect(links.messaging(), same(messaging));
    expect(links.comments(), same(comments));
    expect(links.cookSnaps(), same(cookSnaps));
    expect(links.cookSnapService(), same(cookSnapService));
    expect(links.tagging(), same(tagging));
  });

  test('a recipe conflict has no receiver until the realtime service is '
      'registered, and then reaches it', () async {
    final links = (await offlineService()).links!;
    expect(links.realtimeSync(), isNull);

    final realtime = _Realtime();
    userScope.registerSingleton<RealtimeSyncService>(realtime);

    expect(links.realtimeSync(), same(realtime));
  });

  test('the sync queue source reads the offline store, the signed-in account '
      'and the chat repository of the signed-in container', () async {
    final offline = await offlineService();

    final source = SyncQueueSource.appSource as OfflineSyncQueueSource;
    expect(source.offlineService(), same(offline));
    expect(source.authRepository(), same(auth));
    expect(source.messaging(), same(messaging));
  });

  test('a user who signs in again gives the offline store their own '
      'container', () async {
    final first = await offlineService();
    final firstLinks = first.links;

    final second = GetIt.asNewInstance();
    addTearDown(second.reset);
    final otherStorage = _Storage();
    second
      ..registerSingleton<StorageService>(otherStorage)
      ..registerSingleton<AuthRepository>(_Auth());
    await ContentModule().configureUserScope(second);
    final again = second<OfflineService>();

    expect(again, same(first));
    expect(again.links, isNot(same(firstLinks)));
    expect(again.links!.storage(), same(otherStorage));
  });
}
