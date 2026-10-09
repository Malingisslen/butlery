/// BUT-907: the trash's production wiring.
///
/// `TrashRegistrations` hands the restore its device-side collaborators
/// through the production `ServiceLocator`. These tests resolve the real
/// `TrashService` from a container the registrations filled, so a restore
/// runs through the lambdas production uses.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/di/modules/trash_registrations.dart';
import 'package:butlery/core/providers/application_provider.dart' as prod;
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/firebase/firebase_trash_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/trash/trash_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../test_support/base_unit_test.dart';

const _me = 'user-me';

void main() {
  late FakeFirebaseFirestore firestore;
  late FirebaseTrashRepository repository;
  late GetIt container;
  late MockOfflineService offline;
  late MockUnifiedRecipeService recipes;
  late MockUserRepository users;
  late TrashService service;

  // The production ServiceLocator and TestServiceLocator share GetIt.instance.
  void replaceGlobal<T extends Object>(T instance) {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<T>()) getIt.unregister<T>();
    getIt.registerSingleton<T>(instance);
  }

  Future<TrashItem> trashed(String id) async {
    final recipe = RecipeFactory.buildPersonal(
      id: id,
      title: 'Gryta $id',
      createdBy: _me,
    ).copyWith(rev: 2);
    await firestore
        .collection(FirestoreCollections.users)
        .doc(_me)
        .collection(FirestoreCollections.recipes)
        .doc(id)
        .set(RecipeSerialization.toFirestore(recipe));
    await repository.moveRecipeToTrash(recipe);
    return (await repository.listTrash()).singleWhere((i) => i.id == id);
  }

  setUpAll(() => registerFallbackValue(RecipeFactory.build()));

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    final auth = prod.ServiceLocator.get<AuthRepository>() as FakeAuthRepository
      ..setAuthState(
        user: FakeUser(uid: _me),
        userId: _me,
        isAuthenticated: true,
      );
    replaceGlobal<PermissionService>(
      FakePermissionService()..setPermissionState(currentUserId: _me),
    );

    offline = MockOfflineService();
    when(() => offline.isOnline).thenReturn(true);
    when(
      () => offline.hasUnsentRecipeWrite(any(), any()),
    ).thenAnswer((_) async => false);
    replaceGlobal<OfflineService>(offline);

    recipes = MockUnifiedRecipeService();
    when(() => recipes.adoptRestoredRecipe(any())).thenAnswer((_) async {});
    replaceGlobal<UnifiedRecipeService>(recipes);

    users = MockUserRepository();
    when(
      () => users.incrementPublicRecipeCount(any()),
    ).thenAnswer((_) async {});
    replaceGlobal<UserRepository>(users);

    firestore = FakeFirebaseFirestore();
    repository = FirebaseTrashRepository(
      firestore: firestore,
      authRepository: auth,
    );
    container = GetIt.asNewInstance()..registerSingleton<AuthRepository>(auth);
    TrashRegistrations.register(container);
    container
      ..unregister<TrashRepository>()
      ..registerSingleton<TrashRepository>(repository);
    service = container<TrashService>();
  });

  tearDown(() async {
    await container.reset();
    await TestServiceLocator.reset();
  });

  test('a restore leaves a device copy with an unsent write to the queue, '
      'asking the queue about this recipe and this user', () async {
    final item = await trashed('r1');
    when(
      () => offline.hasUnsentRecipeWrite('r1', _me),
    ).thenAnswer((_) async => true);

    final outcome = await service.restore([item]);

    expect(outcome.isComplete, isTrue);
    verifyNever(() => recipes.adoptRestoredRecipe(any()));
  });

  test('a restore puts the restored recipe on the device through the '
      'recipe service', () async {
    final item = await trashed('r1');

    final outcome = await service.restore([item]);

    expect(outcome.doneIds, ['r1']);
    final adopted = verify(
      () => recipes.adoptRestoredRecipe(captureAny()),
    ).captured;
    expect(adopted, hasLength(1));
    expect((adopted.single as Recipe).id, 'r1');
  });
}
