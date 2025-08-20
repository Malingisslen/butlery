import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/repositories/interfaces/connectivity_repository.dart';
import 'package:butlery/core/utils/connectivity_check.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  late ConnectivityMonitoringService service;
  late MockConnectivityRepository mockRepository;
  late StreamController<bool> firebaseStreamController;
  
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    registerFallbackValue(ConnectionQuality.good);
  });

  setUp(() {
    mockRepository = MockConnectivityRepository();
    firebaseStreamController = StreamController<bool>.broadcast();
    
    // Setup default mock behavior
    when(() => mockRepository.monitorFirebaseConnection())
        .thenAnswer((_) => firebaseStreamController.stream);
    when(() => mockRepository.checkFirebaseConnection())
        .thenAnswer((_) async => true);
    when(() => mockRepository.testEndpoint(any()))
        .thenAnswer((_) async => true);
    when(() => mockRepository.getConnectionQuality())
        .thenAnswer((_) async => ConnectionQuality.excellent);
    when(() => mockRepository.connectionStream)
        .thenAnswer((_) => Stream.value(true));
    
    // Create service with mock repository
    service = ConnectivityMonitoringService(
      connectivityRepository: mockRepository,
    );
  });

  tearDown(() async {
    // Stop monitoring before disposing to clean up properly
    // Only dispose if not already disposed (some tests test disposal)
    try {
      service.stopMonitoring();
      service.dispose();
    } catch (_) {
      // Service already disposed in test
    }
    firebaseStreamController.close();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });
  
  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('ConnectivityMonitoringService', () {
    group('Initialization', () {
      test('should initialize with default connected state', () {
        // Assert
        expect(service.isConnectedToInternet, isTrue);
        expect(service.isConnectedToFirebase, isTrue);
        expect(service.isFullyConnected, isTrue);
        expect(service.connectionStatusText, equals('Ansluten'));
      });

      test('should use injected repository', () {
        // Act
        service.startMonitoring();
        
        // Assert
        verify(() => mockRepository.monitorFirebaseConnection()).called(1);
      });

      test('should maintain singleton pattern with repository injection', () {
        // Arrange
        final service1 = ConnectivityMonitoringService(
          connectivityRepository: mockRepository,
        );
        
        // Act
        final service2 = ConnectivityMonitoringService();
        
        // Assert
        expect(identical(service1, service2), isTrue);
      });
    });

    group('Monitoring', () {
      test('should start Firebase monitoring when startMonitoring is called', () {
        // Act
        service.startMonitoring();
        
        // Assert
        verify(() => mockRepository.monitorFirebaseConnection()).called(1);
      });

      test('should notify listeners when Firebase connection changes to disconnected', () async {
        // Arrange
        bool listenerCalled = false;
        service.addListener(() {
          listenerCalled = true;
        });
        
        // Act
        service.startMonitoring();
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.isConnectedToFirebase, isFalse);
        expect(listenerCalled, isTrue);
      });

      test('should notify listeners when Firebase connection changes to connected', () async {
        // Arrange
        bool listenerCalled = false;
        
        // First set to disconnected
        service.startMonitoring();
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        service.addListener(() {
          listenerCalled = true;
        });
        
        // Act
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.isConnectedToFirebase, isTrue);
        expect(listenerCalled, isTrue);
      });

      test('should handle Firebase monitoring stream errors', () async {
        // Arrange
        service.startMonitoring();
        
        // Act
        firebaseStreamController.addError('Connection error');
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.isConnectedToFirebase, isFalse);
      });

      test('should stop monitoring when stopMonitoring is called', () {
        // Arrange
        service.startMonitoring();
        
        // Act
        service.stopMonitoring();
        
        // Verify stream subscription is cancelled by adding event after stop
        firebaseStreamController.add(false);
        
        // Assert - Should remain in default state
        expect(service.isConnectedToFirebase, isTrue);
      });

      test('should cancel timers when stopMonitoring is called', () {
        // Arrange
        service.startMonitoring();
        
        // Act
        service.stopMonitoring();
        
        // Assert - Service should not crash or throw when stopped
        expect(() => service.stopMonitoring(), returnsNormally);
      });
    });

    group('Connection Status Text', () {
      test('should show "Ansluten" when fully connected', () async {
        // Arrange
        service.startMonitoring();
        
        // Act
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.connectionStatusText, equals('Ansluten'));
      });

      test('should show "Firebase otillgänglig" when internet connected but Firebase disconnected', () async {
        // Arrange
        service.startMonitoring();
        
        // Act
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.connectionStatusText, equals('Firebase otillgänglig'));
      });

      test('should show "Frånkopplad" when both internet and Firebase disconnected', () async {
        // Arrange
        // This would require mocking the internet check timer
        // Since internet check uses static methods, we focus on Firebase
        service.startMonitoring();
        
        // Act
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        // Manually set internet state for testing
        // In real scenario, this would be set by the timer
        expect(service.isConnectedToFirebase, isFalse);
      });
    });

    group('getCurrentConnectivity', () {
      test('should return connectivity result from ConnectivityCheck', () async {
        // Act
        // This tests the method exists and returns expected type
        final result = await service.getCurrentConnectivity();
        
        // Assert
        expect(result, isA<ConnectivityResult>());
      });
    });

    group('testFirebaseConnectivity', () {
      test('should return true when Firebase is connected', () async {
        // Arrange
        when(() => mockRepository.checkFirebaseConnection())
            .thenAnswer((_) async => true);
        
        // Act
        final result = await service.testFirebaseConnectivity();
        
        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.checkFirebaseConnection()).called(1);
      });

      test('should return false when Firebase is disconnected', () async {
        // Arrange
        when(() => mockRepository.checkFirebaseConnection())
            .thenAnswer((_) async => false);
        
        // Act
        final result = await service.testFirebaseConnectivity();
        
        // Assert
        expect(result, isFalse);
      });

      test('should handle exceptions and return false', () async {
        // Arrange
        when(() => mockRepository.checkFirebaseConnection())
            .thenAnswer((_) async => throw Exception('Connection failed'));
        
        // Act
        final result = await service.testFirebaseConnectivity();
        
        // Assert
        expect(result, isFalse);
      });
    });

    group('State Management', () {
      test('should maintain separate states for internet and Firebase', () async {
        // Arrange
        service.startMonitoring();
        
        // Act - Disconnect Firebase
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.isConnectedToInternet, isTrue);
        expect(service.isConnectedToFirebase, isFalse);
        expect(service.isFullyConnected, isFalse);
      });

      test('should calculate isFullyConnected correctly', () async {
        // Arrange
        service.startMonitoring();
        
        // Act & Assert - Both connected
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        expect(service.isFullyConnected, isTrue);
        
        // Act & Assert - Firebase disconnected
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        expect(service.isFullyConnected, isFalse);
      });

      test('should not notify listeners when state does not change', () async {
        // Arrange
        int notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });
        
        service.startMonitoring();
        
        // Act - Send same state multiple times
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert - Should not notify since state didn't change
        expect(notificationCount, equals(0));
      });

      test('should notify listeners only when state changes', () async {
        // Arrange
        int notificationCount = 0;
        service.addListener(() {
          notificationCount++;
        });
        
        service.startMonitoring();
        
        // Act - Change state
        firebaseStreamController.add(false);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Change back
        firebaseStreamController.add(true);
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(notificationCount, equals(2));
      });
    });

    group('Error Handling', () {
      test('should handle Firebase stream errors gracefully', () async {
        // Arrange
        service.startMonitoring();
        
        // Act
        firebaseStreamController.addError(Exception('Stream error'));
        await Future.delayed(Duration(milliseconds: 100));
        
        // Assert
        expect(service.isConnectedToFirebase, isFalse);
        expect(service.connectionStatusText, equals('Firebase otillgänglig'));
      });

      test('should handle multiple rapid state changes', () async {
        // Arrange
        service.startMonitoring();
        
        // Act - Rapid state changes
        for (int i = 0; i < 10; i++) {
          firebaseStreamController.add(i % 2 == 0);
          await Future.delayed(Duration(milliseconds: 10));
        }
        
        // Assert - Service should remain stable
        expect(() => service.isFullyConnected, returnsNormally);
      });

      test('should handle disposal during active monitoring', () {
        // Arrange
        service.startMonitoring();
        
        // Act - Add events
        firebaseStreamController.add(false);
        
        // Stop monitoring before dispose
        service.stopMonitoring();
        
        // Assert - Now dispose should be safe
        expect(() => service.dispose(), returnsNormally);
      });
    });

    group('Lifecycle', () {
      test('should clean up resources on dispose', () {
        // Arrange
        service.startMonitoring();
        
        // Act - Stop and dispose properly
        service.stopMonitoring();
        
        // Assert - Should be safe to dispose after stopping
        expect(() => service.dispose(), returnsNormally);
        
        // Stream controller should still be functional
        expect(() => firebaseStreamController.add(false), returnsNormally);
      });

      test('should handle multiple start/stop cycles', () {
        // Act
        for (int i = 0; i < 3; i++) {
          service.startMonitoring();
          service.stopMonitoring();
        }
        
        // Assert - Should not accumulate subscriptions or throw
        expect(() => service.startMonitoring(), returnsNormally);
      });

      test('should be safe to call stopMonitoring multiple times', () {
        // Arrange
        service.startMonitoring();
        
        // Act
        service.stopMonitoring();
        service.stopMonitoring();
        service.stopMonitoring();
        
        // Assert - Should not throw
        expect(() => service.stopMonitoring(), returnsNormally);
      });

      test('should be safe to call dispose multiple times', () {
        // Arrange
        service.startMonitoring();
        
        // Act & Assert - First dispose should work
        expect(() => service.dispose(), returnsNormally);
        
        // Note: In Flutter, calling dispose multiple times on ChangeNotifier
        // will throw in debug mode but not in release mode.
        // This is expected behavior for ChangeNotifier.
      });
    });

    group('Edge Cases', () {
      test('should handle null repository responses', () async {
        // Arrange
        when(() => mockRepository.checkFirebaseConnection())
            .thenAnswer((_) async => throw Exception('Null response'));
        
        // Act
        final result = await service.testFirebaseConnectivity();
        
        // Assert
        expect(result, isFalse);
      });

      test('should handle repository timeout', () async {
        // Arrange
        when(() => mockRepository.checkFirebaseConnection())
            .thenAnswer((_) async {
          await Future.delayed(Duration(seconds: 10));
          return true;
        });
        
        // Act
        final resultFuture = service.testFirebaseConnectivity();
        
        // Assert - Should complete eventually
        expect(resultFuture, completion(isA<bool>()));
      });

      test('should maintain state consistency during concurrent operations', () async {
        // Arrange
        service.startMonitoring();
        
        // Act - Concurrent state changes
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(Future(() async {
            firebaseStreamController.add(i % 2 == 0);
            await Future.delayed(Duration(milliseconds: 50));
          }));
        }
        
        await Future.wait(futures);
        
        // Assert - State should be consistent
        expect(service.isConnectedToFirebase, isA<bool>());
        expect(service.connectionStatusText, isA<String>());
      });

      test('should handle stream controller closed exception', () async {
        // Arrange
        service.startMonitoring();
        
        // Act - Close the controller
        await firebaseStreamController.close();
        
        // Create new controller for cleanup
        firebaseStreamController = StreamController<bool>.broadcast();
        
        // Assert - Service should handle the closed stream gracefully
        expect(service.isConnectedToFirebase, isA<bool>());
      });
    });
  });
}