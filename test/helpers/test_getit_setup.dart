/// GetIt setup helper for tests to ensure proper dependency registration.
///
/// This helper ensures that GetIt.instance is properly configured with all
/// required dependencies, preventing "not registered" errors during tests.

import 'package:get_it/get_it.dart';
import 'test_service_locator.dart';

// Import interfaces
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/interfaces/comments_repository.dart';
import 'package:butlery/repositories/interfaces/ratings_repository.dart';
import 'package:butlery/repositories/interfaces/notifications_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/firebase/firebase_messaging_repository.dart';
import 'package:butlery/repositories/firebase/firebase_shopping_repository.dart';
import 'package:butlery/repositories/firebase/firebase_user_repository.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';

// Import services
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';

/// Setup GetIt instance with test mocks.
///
/// This function registers all required mocks directly with GetIt.instance
/// to handle cases where code uses GetIt directly instead of ServiceLocator.
void setupTestGetIt() {
  final getIt = GetIt.instance;
  
  // Reset GetIt to clean state
  getIt.reset();
  
  // Register repositories with their interface types
  getIt.registerSingleton<RecipeRepository>(TestServiceLocator.mockRecipeRepository);
  getIt.registerSingleton<FirebaseAuthRepository>(TestServiceLocator.mockAuthRepository);
  getIt.registerSingleton<CommentsRepository>(TestServiceLocator.mockCommentsRepository);
  getIt.registerSingleton<RatingsRepository>(TestServiceLocator.mockRatingsRepository);
  getIt.registerSingleton<NotificationsRepository>(TestServiceLocator.mockNotificationsRepository);
  getIt.registerSingleton<FirestoreRepository>(TestServiceLocator.mockFirestoreRepository);
  getIt.registerSingleton<FirebaseMessagingRepository>(TestServiceLocator.mockMessagingRepository);
  getIt.registerSingleton<FirebaseShoppingRepository>(TestServiceLocator.mockShoppingRepository);
  getIt.registerSingleton<FirebaseUserRepository>(TestServiceLocator.mockUserRepository);
  getIt.registerSingleton<FirebaseFriendsRepository>(TestServiceLocator.mockFriendsRepository);
  
  // Register services with their interface types
  getIt.registerSingleton<UnifiedRecipeService>(TestServiceLocator.mockRecipeService);
  getIt.registerSingleton<AuthService>(TestServiceLocator.mockAuthService);
  getIt.registerSingleton<MessagingService>(TestServiceLocator.mockMessagingService);
  getIt.registerSingleton<AnalyticsService>(TestServiceLocator.mockAnalyticsService);
  getIt.registerSingleton<UserService>(TestServiceLocator.mockUserService);
  getIt.registerSingleton<PermissionService>(TestServiceLocator.mockPermissionService);
  getIt.registerSingleton<StorageService>(TestServiceLocator.mockStorageService);
  getIt.registerSingleton<UnifiedShoppingService>(TestServiceLocator.mockShoppingService);
  getIt.registerSingleton<UnifiedFriendsService>(TestServiceLocator.mockFriendsService);
  
  // Register view models
  getIt.registerSingleton<AuthViewModel>(TestServiceLocator.mockAuthViewModel);
}

/// Cleanup GetIt after tests.
void tearDownTestGetIt() {
  GetIt.instance.reset();
}