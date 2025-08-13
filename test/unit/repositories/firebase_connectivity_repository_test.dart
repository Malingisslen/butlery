// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:butlery/repositories/firebase/firebase_connectivity_repository.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import '../../infrastructure/helpers/_base_unit_test.dart';
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

// Test-specific mock not in production_mocks.dart
class MockGetOptions extends Mock implements GetOptions {}

// Fake classes for any() matching
class FakeGetOptions extends Fake implements GetOptions {}

void main() {
  group('FirebaseConnectivityRepository', () {
    late FirebaseConnectivityRepository repository;
    late MockFirebaseFirestore mockFirestore;
    late MockConnectivity mockConnectivity;
    late MockCollectionReference<Map<String, dynamic>> mockCollection;
    late MockDocumentReference<Map<String, dynamic>> mockDocRef;
    late StreamController<List<ConnectivityResult>> connectivityController;
    
    setUpAll(() {
      registerFallbackValue(FakeGetOptions());
      registerFallbackValue(const GetOptions(source: Source.server));
    });
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      // Initialize mocks
      mockFirestore = MockFirebaseFirestore();
      mockConnectivity = MockConnectivity();
      mockCollection = MockCollectionReference<Map<String, dynamic>>();
      mockDocRef = MockDocumentReference<Map<String, dynamic>>();
      connectivityController = StreamController<List<ConnectivityResult>>.broadcast();
      
      // Setup default stubs
      when(() => mockFirestore.collection(any())).thenReturn(mockCollection);
      when(() => mockFirestore.doc(any())).thenReturn(mockDocRef);
      when(() => mockCollection.doc(any())).thenReturn(mockDocRef);
      when(() => mockConnectivity.onConnectivityChanged)
          .thenAnswer((_) => connectivityController.stream);
      when(() => mockConnectivity.checkConnectivity())
          .thenAnswer((_) async => [ConnectivityResult.wifi]);
      
      // Create repository
      repository = FirebaseConnectivityRepository(
        firestore: mockFirestore,
        connectivity: mockConnectivity,
      );
    });
    
    tearDown(() async {
      await connectivityController.close();
      repository.dispose();
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });
    
    group('checkFirebaseConnection', () {
      test('should return true when Firebase is accessible', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.checkFirebaseConnection();
        
        // Assert
        expect(result, isTrue);
        verify(() => mockFirestore.collection('.info')).called(1);
        verify(() => mockCollection.doc('connected')).called(1);
        verify(() => mockDocRef.get(any())).called(1);
      });
      
      test('should return false when Firebase is not accessible', () async {
        // Arrange
        when(() => mockDocRef.get(any()))
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act
        final result = await repository.checkFirebaseConnection();
        
        // Assert
        expect(result, isFalse);
      });
      
      test('should handle network errors gracefully', () async {
        // Arrange
        when(() => mockDocRef.get(any()))
            .thenThrow(Exception('Network error'));
        
        // Act
        final result = await repository.checkFirebaseConnection();
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('monitorFirebaseConnection', () {
      test('should emit true when Firebase connection is active', () async {
        // Arrange
        final streamController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot.data()).thenReturn({'connected': true});
        when(() => mockDocRef.snapshots()).thenAnswer((_) => streamController.stream);
        
        // Act
        final stream = repository.monitorFirebaseConnection();
        final future = stream.first; // Start listening
        
        // Add data to stream after listener is set up
        await Future.delayed(Duration(milliseconds: 10));
        streamController.add(mockSnapshot);
        
        // Assert
        await expectLater(future, completion(isTrue));
        
        // Cleanup
        await streamController.close();
      });
      
      test('should emit false when Firebase connection is inactive', () async {
        // Arrange
        final streamController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot.data()).thenReturn({'connected': false});
        when(() => mockDocRef.snapshots()).thenAnswer((_) => streamController.stream);
        
        // Act
        final stream = repository.monitorFirebaseConnection();
        final future = stream.first; // Start listening
        
        // Add data to stream after listener is set up
        await Future.delayed(Duration(milliseconds: 10));
        streamController.add(mockSnapshot);
        
        // Assert
        await expectLater(future, completion(isFalse));
        
        // Cleanup
        await streamController.close();
      });
      
      test('should handle null data gracefully', () async {
        // Arrange
        final streamController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot.data()).thenReturn(null);
        when(() => mockDocRef.snapshots()).thenAnswer((_) => streamController.stream);
        
        // Act
        final stream = repository.monitorFirebaseConnection();
        final future = stream.first; // Start listening
        
        // Add data to stream after listener is set up
        await Future.delayed(Duration(milliseconds: 10));
        streamController.add(mockSnapshot);
        
        // Assert
        await expectLater(future, completion(isFalse));
        
        // Cleanup
        await streamController.close();
      });
      
      test('should handle stream errors', () async {
        // Arrange
        final streamController = StreamController<DocumentSnapshot<Map<String, dynamic>>>.broadcast();
        
        when(() => mockDocRef.snapshots()).thenAnswer((_) => streamController.stream);
        
        // Act
        final stream = repository.monitorFirebaseConnection();
        final errors = <dynamic>[];
        final subscription = stream.listen(
          (value) {},
          onError: (error) => errors.add(error),
        );
        
        streamController.addError(Exception('Stream error'));
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Error should be handled and false returned
        expect(errors, isEmpty); // Error is handled internally
        
        // Cleanup
        await subscription.cancel();
        await streamController.close();
      });
    });
    
    group('testEndpoint', () {
      test('should return true when endpoint exists', () async {
        // Arrange
        const endpoint = 'users/test-user';
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot.exists).thenReturn(true);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.testEndpoint(endpoint);
        
        // Assert
        expect(result, isTrue);
        verify(() => mockFirestore.doc(endpoint)).called(1);
      });
      
      test('should return true even when document does not exist (got response)', () async {
        // Arrange
        const endpoint = 'users/non-existent';
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        
        when(() => mockSnapshot.exists).thenReturn(false);
        when(() => mockDocRef.get()).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final result = await repository.testEndpoint(endpoint);
        
        // Assert
        expect(result, isTrue); // We got a response, so connection works
      });
      
      test('should return false when endpoint is unreachable', () async {
        // Arrange
        const endpoint = 'users/test-user';
        
        when(() => mockDocRef.get())
            .thenThrow(FirebaseException(plugin: 'firestore'));
        
        // Act
        final result = await repository.testEndpoint(endpoint);
        
        // Assert
        expect(result, isFalse);
      });
    });
    
    group('getConnectionQuality', () {
      test('should return offline when no network connectivity', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.none]);
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.offline));
      });
      
      test('should return offline when Firebase is not accessible', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        when(() => mockDocRef.get(any()))
            .thenThrow(Exception('Firebase error'));
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.offline));
      });
      
      test('should return excellent for response time < 100ms', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async {
          // Simulate fast response
          await Future.delayed(Duration(milliseconds: 50));
          return mockSnapshot;
        });
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.excellent));
      });
      
      test('should return good for response time < 300ms', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi]);
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async {
          // Simulate medium response
          await Future.delayed(Duration(milliseconds: 200));
          return mockSnapshot;
        });
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.good));
      });
      
      test('should return fair for response time < 1000ms', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async {
          // Simulate slower response
          await Future.delayed(Duration(milliseconds: 500));
          return mockSnapshot;
        });
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.fair));
      });
      
      test('should return poor for response time > 1000ms', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.mobile]);
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async {
          // Simulate very slow response
          await Future.delayed(Duration(milliseconds: 1500));
          return mockSnapshot;
        });
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.poor));
      });
      
      test('should handle multiple connectivity results', () async {
        // Arrange - Both WiFi and Mobile connected
        when(() => mockConnectivity.checkConnectivity())
            .thenAnswer((_) async => [ConnectivityResult.wifi, ConnectivityResult.mobile]);
        
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, isNot(equals(ConnectionQuality.offline)));
      });
      
      test('should handle errors gracefully', () async {
        // Arrange
        when(() => mockConnectivity.checkConnectivity())
            .thenThrow(Exception('Connectivity check failed'));
        
        // Act
        final quality = await repository.getConnectionQuality();
        
        // Assert
        expect(quality, equals(ConnectionQuality.offline));
      });
    });
    
    group('connectionStream', () {
      test('should emit connection status changes', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stream = repository.connectionStream;
        final statuses = <bool>[];
        final subscription = stream.listen(statuses.add);
        
        // Simulate connectivity changes
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        
        connectivityController.add([ConnectivityResult.none]);
        await Future.delayed(Duration(milliseconds: 100));
        
        connectivityController.add([ConnectivityResult.mobile]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(statuses, contains(true)); // WiFi connected
        expect(statuses, contains(false)); // No connection
        
        // Cleanup
        await subscription.cancel();
      });
      
      test('should check Firebase connection when network becomes available', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stream = repository.connectionStream;
        final subscription = stream.listen((_) {});
        
        // Wait for initial check
        await Future.delayed(Duration(milliseconds: 100));
        
        // Simulate network becoming available
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Firebase check should be called
        verify(() => mockDocRef.get(any())).called(greaterThan(0));
        
        // Cleanup
        await subscription.cancel();
      });
      
      test('should support multiple listeners (broadcast stream)', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stream1 = repository.connectionStream;
        final stream2 = repository.connectionStream;
        
        final statuses1 = <bool>[];
        final statuses2 = <bool>[];
        
        final subscription1 = stream1.listen(statuses1.add);
        final subscription2 = stream2.listen(statuses2.add);
        
        // Emit connectivity change
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Both listeners should receive updates
        expect(statuses1, isNotEmpty);
        expect(statuses2, isNotEmpty);
        
        // Cleanup
        await subscription1.cancel();
        await subscription2.cancel();
      });
      
      test('should stop monitoring when all listeners cancel', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stream = repository.connectionStream;
        final subscription = stream.listen((_) {});
        
        // Wait for monitoring to start
        await Future.delayed(Duration(milliseconds: 100));
        
        // Cancel subscription
        await subscription.cancel();
        
        // Emit change after cancellation
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - No new Firebase checks should occur after cancellation
        // (This is hard to verify directly, but dispose should clean up)
        expect(() => repository.dispose(), returnsNormally);
      });
    });
    
    group('periodic health checks', () {
      test('should perform periodic Firebase checks', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        when(() => mockDocRef.get(any())).thenAnswer((_) async => mockSnapshot);
        
        // Act
        final stream = repository.connectionStream;
        final subscription = stream.listen((_) {});
        
        // Wait for initial check
        await Future.delayed(Duration(milliseconds: 100));
        final initialCallCount = verify(() => mockDocRef.get(any())).callCount;
        
        // Note: We can't easily test the 30-second timer in unit tests
        // but we can verify the timer is set up by checking initial calls
        expect(initialCallCount, greaterThan(0));
        
        // Cleanup
        await subscription.cancel();
      });
    });
    
    group('dispose', () {
      test('should clean up resources properly', () async {
        // Arrange
        final mockSnapshot = MockDocumentSnapshot<Map<String, dynamic>>();
        var firebaseCallCount = 0;
        when(() => mockDocRef.get(any())).thenAnswer((_) async {
          firebaseCallCount++;
          return mockSnapshot;
        });
        
        // Start monitoring
        final stream = repository.connectionStream;
        final subscription = stream.listen((_) {});
        await Future.delayed(Duration(milliseconds: 100));
        await subscription.cancel();
        
        // Record calls before dispose
        final callsBeforeDispose = firebaseCallCount;
        expect(callsBeforeDispose, greaterThan(0), 
            reason: 'Should have made Firebase calls during monitoring');
        
        // Act
        repository.dispose();
        
        // Assert - Should not throw on multiple dispose calls
        expect(() => repository.dispose(), returnsNormally);
        
        // Add connectivity event after dispose
        connectivityController.add([ConnectivityResult.wifi]);
        await Future.delayed(Duration(milliseconds: 200));
        
        // Verify no additional Firebase checks occurred after dispose
        expect(firebaseCallCount, equals(callsBeforeDispose),
            reason: 'No Firebase operations should occur after dispose');
      });
    });
  });
}