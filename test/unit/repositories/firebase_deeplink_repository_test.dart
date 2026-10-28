/// Comprehensive unit tests for FirebaseDeepLinkRepository.
///
/// Tests deep link management functionality including URL shortening,
/// link resolution, metadata storage, click tracking, and permission validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import 'package:butlery/core/utils/timestamp_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseDeepLinkRepository - Deep Link System', () {
    late FirebaseDeepLinkRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = FakeAuthRepository();
      mockUser = FakeUser(uid: 'user-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'user-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore and test timestamp provider
      repository = FirebaseDeepLinkRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
        timestampProvider: const TestTimestampProvider(),
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow user to create deeplink for themselves', () async {
        // Arrange
        final linkData = {
          'createdBy': 'user-123',
          'longUrl': 'https://example.com',
        };

        // Act
        final canCreate = await repository.validateCreatePermission(
          'user-123',
          linkData,
        );

        // Assert
        expect(canCreate, isTrue);
      });

      test(
        'should allow user to create deeplink without createdBy field',
        () async {
          // Arrange - When createdBy is not specified, it's allowed (will be set to current user)
          final linkData = {'longUrl': 'https://example.com'};

          // Act
          final canCreate = await repository.validateCreatePermission(
            'user-123',
            linkData,
          );

          // Assert
          expect(canCreate, isTrue);
        },
      );

      test(
        'should reject user from creating deeplink for another user',
        () async {
          // Arrange
          final linkData = {
            'createdBy': 'other-user',
            'longUrl': 'https://example.com',
          };

          // Act
          final canCreate = await repository.validateCreatePermission(
            'user-123',
            linkData,
          );

          // Assert
          expect(canCreate, isFalse);
        },
      );

      test('should allow anyone to read deeplinks (public sharing)', () async {
        // Arrange
        final linkData = {
          'createdBy': 'other-user',
          'longUrl': 'https://example.com',
        };

        // Act
        final canRead = await repository.validateReadPermission(
          'user-123',
          'link-1',
          linkData,
        );

        // Assert
        expect(canRead, isTrue);
      });

      test('should allow anonymous users to read deeplinks', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );
        final linkData = {
          'createdBy': 'user-123',
          'longUrl': 'https://example.com',
        };

        // Act
        final canRead = await repository.validateReadPermission(
          'anonymous',
          'link-1',
          linkData,
        );

        // Assert
        expect(canRead, isTrue);
      });

      test('should allow creator to update their deeplink', () async {
        // Arrange
        final linkData = {
          'createdBy': 'user-123',
          'longUrl': 'https://example.com',
        };

        // Act
        final canUpdate = await repository.validateUpdatePermission(
          'user-123',
          'link-1',
          linkData,
        );

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject non-creator from updating deeplink', () async {
        // Arrange
        final linkData = {
          'createdBy': 'other-user',
          'longUrl': 'https://example.com',
        };

        // Act
        final canUpdate = await repository.validateUpdatePermission(
          'user-123',
          'link-1',
          linkData,
        );

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow creator to delete their deeplink', () async {
        // Arrange
        const linkId = 'link-1';
        final linkData = {
          'id': linkId,
          'createdBy': 'user-123',
          'longUrl': 'https://example.com',
        };
        await _seedDeepLink(fakeFirestore, linkId, linkData);

        // Act
        final canDelete = await repository.validateDeletePermission(
          'user-123',
          linkId,
        );

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject non-creator from deleting deeplink', () async {
        // Arrange
        const linkId = 'link-1';
        final linkData = {
          'id': linkId,
          'createdBy': 'other-user',
          'longUrl': 'https://example.com',
        };
        await _seedDeepLink(fakeFirestore, linkId, linkData);

        // Act
        final canDelete = await repository.validateDeletePermission(
          'user-123',
          linkId,
        );

        // Assert
        expect(canDelete, isFalse);
      });

      test('should reject delete when deeplink does not exist', () async {
        // Act
        final canDelete = await repository.validateDeletePermission(
          'user-123',
          'nonexistent',
        );

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Create Short URL', () {
      // NOTE: This test is skipped due to FakeFirebaseFirestore limitations
      // with FieldValue.serverTimestamp(). The createShortUrl() method uses server timestamps.
      // These operations are tested in integration tests with real Firebase.

      test('should create short URL successfully', () async {
        // Arrange
        const longUrl = 'https://butlery.se/recipe/12345';
        final metadata = {'title': 'Amazing Recipe', 'type': 'recipe'};

        // Act
        final shortCode = await repository.createShortUrl(longUrl, metadata);

        // Assert
        expect(shortCode, isNotEmpty);
        expect(shortCode.length, equals(8));

        // Verify data was stored
        final doc = await fakeFirestore
            .collection('deep_links')
            .doc(shortCode)
            .get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['longUrl'], equals(longUrl));
        expect(data['metadata'], equals(metadata));
        expect(data['createdBy'], equals('user-123'));
      });
    });

    group('Get Long URL', () {
      test('should resolve short URL to long URL', () async {
        // Arrange
        const shortCode = 'abc12345';
        const longUrl = 'https://butlery.se/recipe/12345';
        await _seedDeepLink(fakeFirestore, shortCode, {
          'id': shortCode,
          'longUrl': longUrl,
          'createdBy': 'user-123',
          'clickCount': 0,
        });

        // Act
        final result = await repository.getLongUrl(shortCode);

        // Assert
        expect(result, equals(longUrl));
      });

      test('should return null for non-existent short URL', () async {
        // Act
        final result = await repository.getLongUrl('nonexistent');

        // Assert
        expect(result, isNull);
      });

      test('should handle malformed short codes gracefully', () async {
        // Act
        final result = await repository.getLongUrl('');

        // Assert
        expect(result, isNull);
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Seed deep link into fake Firestore
Future<void> _seedDeepLink(
  FakeFirebaseFirestore firestore,
  String linkId,
  Map<String, dynamic> linkData,
) async {
  await firestore.collection('deep_links').doc(linkId).set(linkData);
}
