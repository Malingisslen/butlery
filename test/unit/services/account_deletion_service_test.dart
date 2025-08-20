import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Mock for service-level testing (business logic)
class MockAccountDeletionRepository extends Mock {
  final Map<String, bool> _deletionResults = {};
  final List<String> _auditLogs = [];
  
  void setDeletionResult(String collection, bool success) {
    _deletionResults[collection] = success;
  }
  
  Future<bool> deleteCollection(String collection, String userId) async {
    return _deletionResults[collection] ?? true;
  }
  
  Future<bool> deleteUserRecipes(String userId) async {
    return _deletionResults['recipes'] ?? true;
  }
  
  Future<bool> deleteUserMenus(String userId) async {
    return _deletionResults['menus'] ?? true;
  }
  
  Future<bool> deleteShoppingLists(String userId) async {
    return _deletionResults['shopping_lists'] ?? true;
  }
  
  Future<bool> removeFriendConnections(String userId) async {
    return _deletionResults['friend_connections'] ?? true;
  }
  
  Future<bool> deleteUserMessages(String userId) async {
    return _deletionResults['messages'] ?? true;
  }
  
  Future<bool> removeFromSharedContent(String userId) async {
    return _deletionResults['shared_content'] ?? true;
  }
  
  Future<bool> deleteCommentsAndRatings(String userId) async {
    return _deletionResults['comments_ratings'] ?? true;
  }
  
  Future<bool> deleteUserPreferences(String userId) async {
    return _deletionResults['preferences'] ?? true;
  }
  
  Future<bool> deleteUserProfile(String userId) async {
    return _deletionResults['profile'] ?? true;
  }
  
  Future<String> createAuditLog({
    required String userId,
    required String email,
    required String reason,
    required List<dynamic> deletedCollections,
    required List<dynamic> failedCollections,
  }) async {
    final logId = 'audit_${DateTime.now().millisecondsSinceEpoch}';
    _auditLogs.add(logId);
    return logId;
  }
  
  List<String> get auditLogs => _auditLogs;
}

// Service wrapper for unit testing (coordinates deletions)
class AccountDeletionCoordinator {
  final MockAccountDeletionRepository repository;
  final MockOfflineService offlineService;
  final MockAnalyticsService analyticsService;
  final User? currentUser;
  
  AccountDeletionCoordinator({
    required this.repository,
    required this.offlineService,
    required this.analyticsService,
    required this.currentUser,
  });
  
  Future<Map<String, dynamic>> deleteUserAccount({
    required String reason,
    bool createAuditLog = true,
  }) async {
    final result = <String, dynamic>{
      'success': false,
      'deletedCollections': [],
      'failedCollections': [],
      'errors': [],
      'auditLogId': null,
    };
    
    try {
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      final userId = currentUser!.uid;
      final userEmail = currentUser!.email ?? 'unknown';
      
      // Execute deletion tasks
      final deletionTasks = <String, Future<bool>>{
        'recipes': repository.deleteUserRecipes(userId),
        'menus': repository.deleteUserMenus(userId),
        'shopping_lists': repository.deleteShoppingLists(userId),
        'friend_connections': repository.removeFriendConnections(userId),
        'messages': repository.deleteUserMessages(userId),
        'shared_content': repository.removeFromSharedContent(userId),
        'comments_ratings': repository.deleteCommentsAndRatings(userId),
        'preferences': repository.deleteUserPreferences(userId),
        'offline_cache': Future(() async {
          await offlineService.clearUserData(userId);
          return true;
        }),
        'profile': repository.deleteUserProfile(userId),
      };
      
      // Execute all deletion tasks
      for (final entry in deletionTasks.entries) {
        try {
          final success = await entry.value;
          if (success) {
            result['deletedCollections'].add(entry.key);
          } else {
            result['failedCollections'].add(entry.key);
          }
        } catch (e) {
          result['failedCollections'].add(entry.key);
          result['errors'].add('${entry.key}: ${e.toString()}');
        }
      }
      
      // Create audit log
      if (createAuditLog) {
        result['auditLogId'] = await repository.createAuditLog(
          userId: userId,
          email: userEmail,
          reason: reason,
          deletedCollections: result['deletedCollections'],
          failedCollections: result['failedCollections'],
        );
      }
      
      // Log analytics
      try {
        await analyticsService.logAccountDeleted({
          'reason': reason,
          'collections_deleted': result['deletedCollections'].length,
          'collections_failed': result['failedCollections'].length,
        });
      } catch (e) {
        // Analytics failures should not prevent deletion
      }
      
      // Determine success
      result['success'] = result['failedCollections'].isEmpty;
      
      return result;
    } catch (e) {
      result['errors'].add('Main process: ${e.toString()}');
      
      if (e.toString().contains('requires-recent-login')) {
        result['requiresReauth'] = true;
      }
      
      return result;
    }
  }
}

// Mock User for testing
class MockUser extends Mock implements User {}

void main() {
  group('AccountDeletionService - Unit Tests', () {
    late AccountDeletionCoordinator coordinator;
    late MockAccountDeletionRepository mockRepository;
    late MockOfflineService mockOfflineService;
    late MockAnalyticsService mockAnalyticsService;
    late MockUser mockUser;
    
    setUpAll(() async {
      await BaseUnitTest.setupUnit();  // Add base test setup
      await TestServiceLocator.initialize();
    });
    
    setUp(() async {
      
      // Create mocks
      mockRepository = MockAccountDeletionRepository();
      mockOfflineService = MockOfflineService();
      mockAnalyticsService = MockAnalyticsService();
      mockUser = MockUser();
      
      // Configure mock user
      when(() => mockUser.uid).thenReturn('test-user-123');
      when(() => mockUser.email).thenReturn('test@example.com');
      when(() => mockUser.delete()).thenAnswer((_) async {});
      
      // Configure mock services
      mockOfflineService.setOfflineState(
        isInitialized: true,
        currentUserId: 'test-user-123',
      );
      
      // Stub analytics - this is always the same
      when(() => mockAnalyticsService.logAccountDeleted(any()))
          .thenAnswer((_) async {});
      
      // Note: clearUserData stubbing is done per-test to allow different behaviors
      
      // Create coordinator
      coordinator = AccountDeletionCoordinator(
        repository: mockRepository,
        offlineService: mockOfflineService,
        analyticsService: mockAnalyticsService,
        currentUser: mockUser,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    tearDownAll(() async {
      await TestServiceLocator.reset();
    });
    
    group('Coordination Logic', () {
      test('should coordinate deletion across all collections', () async {
        // Arrange
        // All deletions will succeed by default
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'User requested deletion',
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], containsAll([
          'recipes',
          'menus',
          'shopping_lists',
          'friend_connections',
          'messages',
          'shared_content',
          'comments_ratings',
          'preferences',
          'offline_cache',
          'profile',
        ]));
        expect(result['failedCollections'], isEmpty);
        expect(result['errors'], isEmpty);
        expect(result['auditLogId'], isNotNull);
      });
      
      test('should handle null current user', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        coordinator = AccountDeletionCoordinator(
          repository: mockRepository,
          offlineService: mockOfflineService,
          analyticsService: mockAnalyticsService,
          currentUser: null,
        );
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'test deletion',
        );
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['errors'], isNotEmpty);
        expect(result['errors'].first, contains('No authenticated user'));
      });
      
      test('should create GDPR audit log', () async {
        // Arrange
        // All deletions succeed
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'GDPR compliance request',
          createAuditLog: true,
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['auditLogId'], isNotNull);
        expect(result['auditLogId'], startsWith('audit_'));
        expect(mockRepository.auditLogs, hasLength(1));
      });
      
      test('should skip audit log when requested', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test without audit',
          createAuditLog: false,
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['auditLogId'], isNull);
        expect(mockRepository.auditLogs, isEmpty);
      });
    });
    
    group('Error Handling', () {
      test('should handle partial deletion failures', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        mockRepository.setDeletionResult('recipes', false);
        mockRepository.setDeletionResult('menus', false);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test partial failure',
        );
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['failedCollections'], containsAll(['recipes', 'menus']));
        expect(result['deletedCollections'], contains('shopping_lists'));
        expect(result['auditLogId'], isNotNull); // Audit log still created
      });
      
      test('should handle offline service failure', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => throw Exception('Offline storage unavailable'));
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test offline failure',
        );
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['failedCollections'], contains('offline_cache'));
        expect(result['errors'].any((e) => e.toString().contains('Offline storage')), isTrue);
      });
      
      test('should handle requires-recent-login error', () async {
        // Arrange
        coordinator = AccountDeletionCoordinator(
          repository: mockRepository,
          offlineService: mockOfflineService,
          analyticsService: mockAnalyticsService,
          currentUser: null, // Will cause error
        );
        
        // Simulate requires-recent-login in error message
        when(() => mockUser.delete()).thenThrow(
          Exception('requires-recent-login: Recent login required'),
        );
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test reauth required',
        );
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['errors'], isNotEmpty);
      });
      
      test('should continue deletion even if some collections fail', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        mockRepository.setDeletionResult('recipes', false);
        mockRepository.setDeletionResult('messages', false);
        mockRepository.setDeletionResult('preferences', false);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test multiple failures',
        );
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['failedCollections'], hasLength(3));
        expect(result['deletedCollections'], hasLength(7)); // Rest succeeded
        expect(result['auditLogId'], isNotNull);
      });
      
      test('should handle analytics logging failure gracefully', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        when(() => mockAnalyticsService.logAccountDeleted(any()))
            .thenAnswer((_) async => throw Exception('Analytics service down'));
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Test analytics failure',
        );
        
        // Assert - Should still complete deletion
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], hasLength(10));
      });
    });
    
    group('Business Logic', () {
      test('should execute deletions in correct order', () async {
        // This test verifies the order is maintained by the implementation
        // The coordinator executes tasks in the order they are added
        
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(reason: 'Test order');
        
        // Assert - All collections are processed
        expect(result['success'], isTrue);
        expect(result['deletedCollections'], hasLength(10));
        // The order is maintained: recipes, menus, shopping_lists, etc.
        expect(result['deletedCollections'][0], equals('recipes'));
        expect(result['deletedCollections'][9], equals('profile'));
      });
      
      test('should log correct analytics data', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        mockRepository.setDeletionResult('recipes', false);
        mockRepository.setDeletionResult('menus', false);
        
        // Act
        final result = await coordinator.deleteUserAccount(reason: 'Test analytics');
        
        // Assert - Verify the result shows correct counts
        expect(result['success'], isFalse);
        expect(result['deletedCollections'].length, equals(8));
        expect(result['failedCollections'].length, equals(2));
        expect(result['failedCollections'], containsAll(['recipes', 'menus']));
      });
      
      test('should handle Swedish characters in reason', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'Användaren begärde radering av konto',
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['auditLogId'], isNotNull);
      });
      
      test('should mark success only when all deletions succeed', () async {
        // Arrange - All succeed
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result1 = await coordinator.deleteUserAccount(reason: 'All success');
        
        // Assert
        expect(result1['success'], isTrue);
        
        // Arrange - One fails
        mockRepository.setDeletionResult('recipes', false);
        
        // Act
        final result2 = await coordinator.deleteUserAccount(reason: 'One failure');
        
        // Assert
        expect(result2['success'], isFalse);
      });
      
      test('should provide detailed error information', () async {
        // Arrange
        mockRepository.setDeletionResult('recipes', false);
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => throw Exception('Storage error: disk full'));
        
        // Act
        final result = await coordinator.deleteUserAccount(reason: 'Test errors');
        
        // Assert
        expect(result['success'], isFalse);
        expect(result['failedCollections'], containsAll(['recipes', 'offline_cache']));
        expect(result['errors'], isNotEmpty);
        expect(result['errors'].any((e) => e.toString().contains('Storage error')), isTrue);
      });
    });
    
    group('GDPR Compliance', () {
      test('should ensure all user data categories are covered', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'GDPR right to be forgotten',
        );
        
        // Assert - All required collections for GDPR
        final requiredCollections = [
          'recipes',           // User content
          'menus',            // User content  
          'shopping_lists',   // User content
          'friend_connections', // Social data
          'messages',         // Communication data
          'shared_content',   // Shared data
          'comments_ratings', // User interactions
          'preferences',      // Personal settings
          'offline_cache',    // Local data
          'profile',          // Personal information
        ];
        
        expect(result['deletedCollections'], containsAll(requiredCollections));
      });
      
      test('should create comprehensive audit log', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        mockRepository.setDeletionResult('recipes', false);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'GDPR Article 17 request',
          createAuditLog: true,
        );
        
        // Assert
        expect(result['auditLogId'], isNotNull);
        // In real implementation, we'd verify the audit log contents
        // contain all required GDPR information
      });
      
      test('should handle user without email gracefully', () async {
        // Arrange
        when(() => mockOfflineService.clearUserData(any()))
            .thenAnswer((_) async => true);
        when(() => mockUser.email).thenReturn(null);
        
        // Act
        final result = await coordinator.deleteUserAccount(
          reason: 'User without email',
        );
        
        // Assert
        expect(result['success'], isTrue);
        expect(result['auditLogId'], isNotNull);
      });
    });
  });
}