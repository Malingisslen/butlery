# Production Service Mocks Documentation

## Overview
This document describes the comprehensive mock implementations created for the core production services in the Butlery application. These mocks provide accurate interfaces matching the production services exactly, enabling thorough unit testing and integration testing.

## Created Mock Implementations

### 1. MockAuthService
**Location**: `test/helpers/mocks/production_service_mocks.dart`

**Production Service**: `lib/services/auth_service.dart`

**Key Features**:
- Full implementation of `AuthService` interface with all mixins (`StateNotifierMixin`, `AsyncOperationMixin`, `StreamManagementMixin`)
- Complete state management for authentication status
- Stream-based auth state changes
- Configuration methods for different test scenarios
- Error simulation capabilities

**Interface Properties**:
- `User? currentUser` - Current Firebase user
- `String? currentUserId` - Current user ID
- `bool isAuthenticated` - Authentication status
- `String? errorMessage` - Error message (alias to error)
- `bool isLoading` - Loading state
- `String? error` - Error state

**Key Methods**:
- `registerWithEmail()` - User registration
- `signInWithEmail()` - User login
- `signOut()` - User logout
- `sendPasswordResetEmail()` - Password reset
- `deleteAccount()` - Account deletion
- `clearError()` - Error clearing

**Configuration Helper**: `MockAuthServiceConfig`
- `configureAuthenticated()` - Set up authenticated state
- `configureUnauthenticated()` - Set up unauthenticated state
- `createMockUser()` - Create mock Firebase User

### 2. MockUserService
**Location**: `test/helpers/mocks/production_service_mocks.dart`

**Production Service**: `lib/services/user_service.dart`

**Key Features**:
- Full implementation with mixins (`ErrorHandlingMixin`, `FirebaseServiceMixin`, `StreamManagementMixin`)
- Profile caching simulation
- Search results management
- FCM token handling
- Notification settings management

**Interface Properties**:
- `UserProfile? currentUserProfile` - Current user profile
- `bool isLoading` - Loading state
- `String? error` - Error state
- `bool hasError` - Error presence check
- `String? currentUserId` - Current user ID

**Key Methods**:
- `initialize()` - Service initialization
- `createOrUpdateProfile()` - Profile management
- `searchUsers()` - User search
- `getUserProfile()` - Get single profile
- `getUserProfiles()` - Get multiple profiles
- `updateOnlineStatus()` - Online status update
- `updateProfileStats()` - Statistics update
- `updateFCMToken()` - FCM token management
- `updateNotificationSettings()` - Notification preferences
- `clearCache()` - Cache management

**Configuration Helper**: `MockUserServiceConfig`
- `configureWithProfile()` - Set up with user profile
- `configureWithSearchResults()` - Set up search results

### 3. MockAnalyticsService
**Location**: `test/helpers/mocks/production_service_mocks.dart`

**Production Service**: `lib/services/analytics_service.dart`

**Key Features**:
- Full Firebase Analytics interface implementation
- Event tracking and verification
- User properties management
- Event history for test assertions
- Singleton pattern support

**Interface Properties**:
- `FirebaseAnalyticsObserver? observer` - Analytics observer
- `FirebaseAnalytics analytics` - Analytics instance
- `String serviceName` - Service name identifier

**Key Methods**:
- `logImportStarted()` - Track import start
- `logImportSuccess()` - Track import success
- `logExtractionError()` - Track extraction errors
- `logRecipeCreated()` - Track recipe creation
- `logRecipeShared()` - Track recipe sharing
- `logRecipeCooked()` - Track recipe cooking
- `logMenuGenerated()` - Track menu generation
- `logRecipeDeleted()` - Track recipe deletion
- `logLogin()` - Track user login
- `logSignUp()` - Track user signup
- `logAccountDeleted()` - Track account deletion
- `setUserProperties()` - Set user properties

**Test Helpers**:
- `wasEventLogged()` - Check if event was logged
- `getEventsOfType()` - Get specific event types
- `loggedEvents` - Access all logged events
- `userProperties` - Access user properties

**Configuration Helper**: `MockAnalyticsServiceConfig`
- `configureInitialized()` - Set up initialized state
- `addTestEvents()` - Add sample events for testing

### 4. MockPersistenceService
**Location**: `test/helpers/mocks/p1_service_mocks_extended.dart` (existing)

**Production Service**: `lib/services/persistence_service.dart`

**Key Features**:
- Local storage simulation
- Recipe persistence
- Menu persistence
- Storage metadata
- Failure simulation

**Key Methods**:
- `saveRecipes()` - Save recipe collection
- `loadRecipes()` - Load recipe collection
- `clearRecipes()` - Clear recipes
- `saveCurrentMenu()` - Save menu
- `loadCurrentMenu()` - Load menu
- `clearCurrentMenu()` - Clear menu
- `getLastUpdated()` - Get last update time
- `clearAllData()` - Clear all data
- `getStorageInfo()` - Get storage information

## Usage Examples

### Basic Authentication Test
```dart
test('should handle authentication', () {
  final mockAuthService = MockAuthService();
  
  // Configure for authenticated user
  MockAuthServiceConfig.configureAuthenticated(
    mockAuthService,
    userId: 'user_123',
    email: 'test@example.com',
  );
  
  // Test authentication state
  expect(mockAuthService.isAuthenticated, isTrue);
  expect(mockAuthService.currentUserId, equals('user_123'));
});
```

### User Profile Management Test
```dart
test('should manage user profiles', () {
  final mockUserService = MockUserService();
  
  final profile = UserProfile(
    uid: 'user_123',
    displayName: 'Test User',
    email: 'test@example.com',
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
  );
  
  mockUserService.setCurrentUserProfile(profile);
  
  expect(mockUserService.currentUserProfile, equals(profile));
  expect(mockUserService.currentUserId, equals('user_123'));
});
```

### Analytics Tracking Test
```dart
test('should track analytics events', () async {
  final mockAnalyticsService = MockAnalyticsService();
  
  // Configure and track event
  MockAnalyticsServiceConfig.configureInitialized(mockAnalyticsService);
  
  mockAnalyticsService.addLoggedEvent('recipe_created', {
    'source': 'manual',
    'has_image': true,
  });
  
  // Verify event was logged
  expect(mockAnalyticsService.wasEventLogged('recipe_created'), isTrue);
  
  final events = mockAnalyticsService.getEventsOfType('recipe_created');
  expect(events.length, equals(1));
  expect(events[0]['parameters']['source'], equals('manual'));
});
```

### Persistence Test
```dart
test('should persist data', () async {
  final mockPersistenceService = MockPersistenceService();
  
  final recipes = [
    Recipe.personal(
      title: 'Test Recipe',
      description: 'Test description',
      ingredients: ['Ingredient 1'],
      instructions: ['Step 1'],
      mealType: 'dinner',
      createdBy: 'user_123',
    ),
  ];
  
  mockPersistenceService.setupDefaultStubs();
  
  when(() => mockPersistenceService.saveRecipes(any()))
      .thenAnswer((_) async => true);
  when(() => mockPersistenceService.loadRecipes())
      .thenAnswer((_) async => recipes);
  
  final saveResult = await mockPersistenceService.saveRecipes(recipes);
  expect(saveResult, isTrue);
  
  final loadedRecipes = await mockPersistenceService.loadRecipes();
  expect(loadedRecipes.length, equals(1));
});
```

## Integration Testing
The mocks can be used together for integration testing:

```dart
test('should handle complete user flow', () async {
  final mockAuthService = MockAuthService();
  final mockUserService = MockUserService();
  final mockPersistenceService = MockPersistenceService();
  final mockAnalyticsService = MockAnalyticsService();
  
  // Configure all services
  MockAuthServiceConfig.configureAuthenticated(mockAuthService);
  MockAnalyticsServiceConfig.configureInitialized(mockAnalyticsService);
  
  // Simulate user flow
  final mockUser = MockAuthServiceConfig.createMockUser(
    uid: 'user_123',
    email: 'user@example.com',
    displayName: 'Test User',
  );
  
  mockAuthService.simulateSuccessfulLogin(mockUser);
  
  // Create user profile
  final userProfile = UserProfile(
    uid: 'user_123',
    displayName: 'Test User',
    email: 'user@example.com',
    joinedAt: DateTime.now(),
    lastActiveAt: DateTime.now(),
  );
  
  mockUserService.setCurrentUserProfile(userProfile);
  
  // Verify complete state
  expect(mockAuthService.isAuthenticated, isTrue);
  expect(mockUserService.currentUserProfile?.uid, equals('user_123'));
});
```

## File Locations

### Mock Implementations
- **Production Service Mocks**: `test/helpers/mocks/production_service_mocks.dart`
  - MockAuthService
  - MockUserService
  - MockAnalyticsService
  - Associated configuration helpers

- **Existing Service Mocks**: `test/helpers/mocks/critical_service_mocks.dart`
  - MockUnifiedRecipeService
  - MockMenuService
  - MockStorageService

- **Existing Persistence Mock**: `test/helpers/mocks/p1_service_mocks_extended.dart`
  - MockPersistenceService

### Example Test
- **Usage Examples**: `test/example_usage_production_mocks_test.dart`
  - Demonstrates all mock usage patterns
  - Shows configuration methods
  - Includes integration examples

## Best Practices

### 1. Configuration Methods vs Stubbing
- Use configuration methods (e.g., `setAuthState()`) for setting up state
- Use `when()` stubbing only for abstract methods that need specific behavior
- Avoid stubbing concrete getters that have internal state

### 2. State Management
- Mocks maintain internal state that can be verified in tests
- Use configuration methods to set initial state
- Call notifyListeners() when state changes (for ChangeNotifier implementations)

### 3. Stream Management
- Mocks that use streams should properly manage StreamControllers
- Always close streams in dispose() methods
- Use broadcast streams for multiple listeners

### 4. Error Simulation
- Use error configuration methods to simulate failures
- Test both success and failure paths
- Verify error messages and states

### 5. Reset and Cleanup
- Call reset() in tearDown when available
- Dispose of resources properly
- Clear state between tests for isolation

## Migration from Existing Mocks

If migrating from simpler mocks to these comprehensive implementations:

1. Replace mock imports with production_service_mocks.dart
2. Update configuration to use new helper methods
3. Remove redundant stubbing of concrete methods
4. Use internal state verification instead of verify() calls where appropriate
5. Leverage configuration helpers for common scenarios

## Troubleshooting

### Common Issues

1. **Import Conflicts**: If you see "imported from both" errors, ensure you're only importing from one mock file
2. **Missing Methods**: Check that you're using the correct mock class and it implements the full interface
3. **State Not Updating**: Ensure notifyListeners() is called after state changes
4. **Stream Errors**: Verify streams are properly initialized and disposed

### Type Conflicts
- Use namespace imports when types conflict (e.g., `as models`)
- Hide conflicting types with `hide` directive
- Prefer explicit type imports with `show` directive

## Future Enhancements

Potential improvements for the mock infrastructure:

1. **Mock State Persistence**: Add ability to save/restore mock state
2. **Mock Recording**: Record actual service calls for replay in tests
3. **Mock Validation**: Add validation for method call sequences
4. **Performance Mocks**: Add timing simulation for performance testing
5. **Network Condition Simulation**: Add network delay/failure simulation

## Conclusion

These comprehensive mock implementations provide a robust foundation for testing the Butlery application. They accurately reflect the production service interfaces while providing additional test utilities for verification and configuration. By following the patterns and best practices outlined in this document, developers can write reliable, maintainable tests that thoroughly validate application behavior.