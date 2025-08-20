// ignore_for_file: subtype_of_sealed_class

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_deeplink_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Local mocks for sealed Firebase classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference<T> extends Mock implements CollectionReference<T> {}
class MockDocumentReference<T> extends Mock implements DocumentReference<T> {}
class MockDocumentSnapshot<T> extends Mock implements DocumentSnapshot<T> {}
class MockQuery<T> extends Mock implements Query<T> {}
class MockQuerySnapshot<T> extends Mock implements QuerySnapshot<T> {}
class MockQueryDocumentSnapshot<T> extends Mock implements QueryDocumentSnapshot<T> {}
class MockWriteBatch extends Mock implements WriteBatch {}

// Fake classes for any() matching
class FakeSetOptions extends Fake implements SetOptions {}
class FakeFieldValue extends Fake implements FieldValue {}
class FakeDocumentReference extends Fake implements DocumentReference<Object?> {}

void main() {
  group('FirebaseDeepLinkRepository', () {
    late FirebaseDeepLinkRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockCollectionReference<Map<String, dynamic>> mockSubCollection;
    late MockAuthRepository mockAuthRepository;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late MockQuery<Map<String, dynamic>> mockQuery;
    late MockWriteBatch mockBatch;
    
    setUpAll(() {
      registerFallbackValue(FakeSetOptions());
      registerFallbackValue(FakeFieldValue());
      registerFallbackValue(FakeDocumentReference());
      registerFallbackValue(DateTime.now());
      registerFallbackValue(1);
      registerFallbackValue(SetOptions(merge: true));
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockSubCollection = MockCollectionReference<Map<String, dynamic>>();
      mockAuthRepository = MockAuthRepository();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      mockQuery = MockQuery<Map<String, dynamic>>();
      mockBatch = MockWriteBatch();
      
      // Configure auth state
      mockAuthRepository.setAuthState(
        userId: 'test-user-123',
        isAuthenticated: true,
      );
      
      // Setup Firestore mocks
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockFirestore.batch()).thenReturn(mockBatch);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockDocRef.collection(any())).thenReturn(mockSubCollection);
      when(() => mockSubCollection.add(any())).thenAnswer((_) async => mockDocRef);
      when(() => mockCollection.where(any(), isLessThan: any(named: 'isLessThan')))
          .thenReturn(mockQuery);
      when(() => mockQuery.get()).thenAnswer((_) async => MockQuerySnapshot<Map<String, dynamic>>());
      // Note: WriteBatch.delete returns void, no stubbing needed
      when(() => mockBatch.commit()).thenAnswer((_) async {});
      
      // Create repository
      repository = FirebaseDeepLinkRepository(
        firestore: mockFirestore,
        authRepository: mockAuthRepository,
      );
    });
    
    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('createShortUrl', () {
      test('should create short URL with metadata and return short code', () async {
        // Arrange
        const longUrl = 'https://butlery.app/recipe/12345';
        final metadata = {
          'title': 'Amazing Recipe',
          'type': 'recipe',
          'recipeId': '12345',
        };
        
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        final shortCode = await repository.createShortUrl(longUrl, metadata);
        
        // Assert
        expect(shortCode, isNotEmpty);
        expect(shortCode.length, equals(8)); // Generated code should be 8 chars
        
        final captured = verify(() => mockDocRef.set(captureAny())).captured.single;
        expect(captured['longUrl'], equals(longUrl));
        expect(captured['metadata'], equals(metadata));
        expect(captured['clickCount'], equals(0));
        expect(captured['createdBy'], equals('test-user-123'));
        expect(captured.containsKey('createdAt'), isTrue);
      });
      
      test('should handle errors when creating short URL', () async {
        // Arrange
        const longUrl = 'https://butlery.app/recipe/12345';
        final metadata = {'title': 'Recipe'};
        
        when(() => mockDocRef.set(any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.createShortUrl(longUrl, metadata),
          throwsException,
        );
      });
      
      test('should generate unique short codes', () async {
        // Arrange
        const longUrl = 'https://butlery.app/recipe/';
        final metadata = {'type': 'recipe'};
        
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act - Create multiple short URLs
        final codes = <String>[];
        for (int i = 0; i < 5; i++) {
          final code = await repository.createShortUrl('$longUrl$i', metadata);
          codes.add(code);
          // Small delay to ensure different timestamps
          await Future.delayed(Duration(milliseconds: 1));
        }
        
        // Assert - All codes should be unique
        expect(codes.toSet().length, equals(codes.length));
      });
    });
    
    group('getLongUrl', () {
      test('should return long URL for valid short code', () async {
        // Arrange
        const shortCode = 'abc123XY';
        const expectedUrl = 'https://butlery.app/recipe/12345';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'longUrl': expectedUrl,
          'metadata': {'title': 'Recipe'},
          'clickCount': 5,
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getLongUrl(shortCode);
        
        // Assert
        expect(result, equals(expectedUrl));
        verify(() => mockCollection.doc(shortCode)).called(1);
      });
      
      test('should return null for non-existent short code', () async {
        // Arrange
        const shortCode = 'invalid';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getLongUrl(shortCode);
        
        // Assert
        expect(result, isNull);
      });
      
      test('should handle errors gracefully and return null', () async {
        // Arrange
        const shortCode = 'error123';
        
        when(() => mockDocRef.get())
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act
        final result = await repository.getLongUrl(shortCode);
        
        // Assert
        expect(result, isNull);
      });
    });
    
    group('trackUrlClick', () {
      test('should increment click count and update last clicked time', () async {
        // Arrange
        const shortCode = 'track123';
        
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.trackUrlClick(shortCode);
        
        // Assert
        final captured = verify(() => mockDocRef.update(captureAny())).captured.single;
        expect(captured['clickCount'], isA<FieldValue>());
        expect(captured.containsKey('lastClickedAt'), isTrue);
      });
      
      test('should add click history to subcollection', () async {
        // Arrange
        const shortCode = 'track456';
        
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.trackUrlClick(shortCode);
        
        // Assert
        verify(() => mockDocRef.collection('clicks')).called(1);
        final captured = verify(() => mockSubCollection.add(captureAny())).captured.single;
        expect(captured.containsKey('timestamp'), isTrue);
        expect(captured['userId'], equals('test-user-123'));
      });
      
      test('should handle tracking errors gracefully', () async {
        // Arrange
        const shortCode = 'error789';
        
        when(() => mockDocRef.update(any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert - Should not throw
        await expectLater(
          repository.trackUrlClick(shortCode),
          completes,
        );
      });
      
      test('should track clicks for anonymous users', () async {
        // Arrange
        const shortCode = 'anon123';
        mockAuthRepository.setAuthState(
          userId: null,
          isAuthenticated: false,
        );
        
        when(() => mockDocRef.update(any())).thenAnswer((_) async {});
        
        // Act
        await repository.trackUrlClick(shortCode);
        
        // Assert
        final captured = verify(() => mockSubCollection.add(captureAny())).captured.single;
        expect(captured['userId'], isNull);
      });
    });
    
    group('storeDeepLinkMetadata', () {
      test('should store metadata with merge option', () async {
        // Arrange
        const linkId = 'meta123';
        final metadata = {
          'title': 'Updated Recipe',
          'description': 'A delicious recipe',
          'imageUrl': 'https://example.com/image.jpg',
        };
        
        when(() => mockDocRef.set(any(), any())).thenAnswer((_) async {});
        
        // Act
        await repository.storeDeepLinkMetadata(linkId, metadata);
        
        // Assert
        final capturedData = verify(() => mockDocRef.set(
          captureAny(),
          captureAny(),
        )).captured;
        
        final data = capturedData[0];
        final options = capturedData[1] as SetOptions;
        
        expect(data['id'], equals(linkId));
        expect(data['metadata'], equals(metadata));
        expect(data['updatedBy'], equals('test-user-123'));
        expect(data.containsKey('updatedAt'), isTrue);
        expect(options.merge, isTrue);
      });
      
      test('should handle errors when storing metadata', () async {
        // Arrange
        const linkId = 'error123';
        final metadata = {'title': 'Recipe'};
        
        when(() => mockDocRef.set(any(), any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.storeDeepLinkMetadata(linkId, metadata),
          throwsException,
        );
      });
    });
    
    group('getDeepLinkMetadata', () {
      test('should return metadata for existing link', () async {
        // Arrange
        const linkId = 'get123';
        final expectedMetadata = {
          'title': 'Recipe Title',
          'type': 'recipe',
          'recipeId': '12345',
        };
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockSnapshot.data()).thenReturn({
          'id': linkId,
          'metadata': expectedMetadata,
          'longUrl': 'https://example.com',
        });
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getDeepLinkMetadata(linkId);
        
        // Assert
        expect(result, equals(expectedMetadata));
      });
      
      test('should return null for non-existent link', () async {
        // Arrange
        const linkId = 'missing';
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.getDeepLinkMetadata(linkId);
        
        // Assert
        expect(result, isNull);
      });
      
      test('should handle errors gracefully and return null', () async {
        // Arrange
        const linkId = 'error123';
        
        when(() => mockDocRef.get())
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act
        final result = await repository.getDeepLinkMetadata(linkId);
        
        // Assert
        expect(result, isNull);
      });
    });
    
    group('deleteExpiredLinks', () {
      test('should delete links created before specified date', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(Duration(days: 30));
        
        final mockDoc1 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc2 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        final mockDoc3 = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockDoc1.reference).thenReturn(mockDocRef);
        when(() => mockDoc2.reference).thenReturn(mockDocRef);
        when(() => mockDoc3.reference).thenReturn(mockDocRef);
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc1, mockDoc2, mockDoc3]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        await repository.deleteExpiredLinks(cutoffDate);
        
        // Assert
        verify(() => mockCollection.where(
          'createdAt',
          isLessThan: any(named: 'isLessThan'),
        )).called(1);
        verify(() => mockBatch.delete(any())).called(3);
        verify(() => mockBatch.commit()).called(1);
      });
      
      test('should not commit batch if no expired links found', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(Duration(days: 30));
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        
        // Act
        await repository.deleteExpiredLinks(cutoffDate);
        
        // Assert
        verifyNever(() => mockBatch.delete(any()));
        verifyNever(() => mockBatch.commit());
      });
      
      test('should handle deletion errors', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(Duration(days: 30));
        
        when(() => mockQuery.get())
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.deleteExpiredLinks(cutoffDate),
          throwsException,
        );
      });
      
      test('should handle batch commit errors', () async {
        // Arrange
        final cutoffDate = DateTime.now().subtract(Duration(days: 30));
        
        final mockDoc = MockQueryDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDoc.reference).thenReturn(mockDocRef);
        
        final mockQuerySnapshot = MockQuerySnapshot<Map<String, dynamic>>();
        when(() => mockQuerySnapshot.docs).thenReturn([mockDoc]);
        when(() => mockQuery.get()).thenAnswer((_) async => mockQuerySnapshot);
        when(() => mockBatch.commit())
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act & Assert
        expect(
          () => repository.deleteExpiredLinks(cutoffDate),
          throwsException,
        );
      });
    });
    
    group('shortCode generation', () {
      test('should generate 8-character codes', () async {
        // Arrange
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        final shortCode = await repository.createShortUrl(
          'https://example.com',
          {'test': true},
        );
        
        // Assert
        expect(shortCode.length, equals(8));
        expect(RegExp(r'^[a-zA-Z0-9]+$').hasMatch(shortCode), isTrue);
      });
      
      test('should generate different codes for rapid successive calls', () async {
        // Arrange
        when(() => mockDocRef.set(any())).thenAnswer((_) async {});
        
        // Act
        final codes = <String>[];
        for (int i = 0; i < 3; i++) {
          final code = await repository.createShortUrl(
            'https://example.com/$i',
            {'index': i},
          );
          codes.add(code);
          // Ensure different timestamps
          await Future.delayed(Duration(milliseconds: 2));
        }
        
        // Assert - Codes should be unique (though collision is theoretically possible)
        expect(codes.toSet().length, equals(codes.length));
      });
    });
    
    group('inherited from BaseFirebaseRepository', () {
      test('should use correct collection name', () {
        // Assert
        expect(repository.collectionName, equals('deep_links'));
      });
      
      test('should handle fromFirestore correctly', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.data()).thenReturn({
          'id': 'test123',
          'longUrl': 'https://example.com',
        });
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result['id'], equals('test123'));
        expect(result['longUrl'], equals('https://example.com'));
      });
      
      test('should handle null data in fromFirestore', () {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockSnapshot.data()).thenReturn(null);
        
        // Act
        final result = repository.fromFirestore(mockSnapshot);
        
        // Assert
        expect(result, isEmpty);
      });
      
      test('should use toFirestore as identity function', () {
        // Arrange
        final entity = {
          'id': 'test123',
          'longUrl': 'https://example.com',
          'metadata': {'title': 'Test'},
        };
        
        // Act
        final result = repository.toFirestore(entity);
        
        // Assert
        expect(result, same(entity));
      });
      
      test('should extract ID from entity', () {
        // Arrange
        final entity = {'id': 'test123', 'other': 'data'};
        
        // Act
        final id = repository.getId(entity);
        
        // Assert
        expect(id, equals('test123'));
      });
      
      test('should return empty string for missing ID', () {
        // Arrange
        final entity = {'other': 'data'};
        
        // Act
        final id = repository.getId(entity);
        
        // Assert
        expect(id, equals(''));
      });
    });
  });
}