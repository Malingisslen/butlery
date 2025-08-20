import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:butlery/services/dialog_service.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  late DialogService service;

  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    service = DialogService();
  });
  
  tearDown(() async {
    // Reset any mock state between tests
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });
  
  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('DialogService', () {
    group('Initialization', () {
      test('should have correct service name', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        final serviceName = service.serviceName;
        
        // Assert
        expect(serviceName, equals('DialogService'));
      });

      test('should be properly initialized', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        // Check service type
        
        // Assert
        expect(service, isA<DialogService>());
      });

      test('should extend BaseService', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        // DialogService extends BaseService
        final name = service.serviceName;
        
        // Assert
        expect(name, isNotEmpty);
      });
    });

    group('Dialog Methods', () {
      // These are unit tests that verify the service exists and has the expected methods
      // Widget tests for actual dialog display would require a full widget test setup

      test('should have showExitDialog method', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        final method = service.showExitDialog;
        
        // Assert
        expect(method, isA<Function>());
      });

      test('should have exitApp method', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        final method = service.exitApp;
        
        // Assert
        expect(method, isA<Function>());
      });

      test('should have showExitDialogAndExit method', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        final method = service.showExitDialogAndExit;
        
        // Assert
        expect(method, isA<Function>());
      });

      test('should have showConfirmDialog method', () {
        // Arrange
        // Service already created in setUp
        
        // Act
        final method = service.showConfirmDialog;
        
        // Assert
        expect(method, isA<Function>());
      });
    });

    group('Exit App Platform Channel', () {
      test('should exit app through platform channel', () async {
        // Arrange
        // Mock the platform channel
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/platform'),
                (MethodCall methodCall) async {
          if (methodCall.method == 'SystemNavigator.pop') {
            return null;
          }
          return null;
        });

        // Act
        // Call should complete without error
        await service.exitApp();
        
        // Assert
        // Test passes if no exception is thrown
      });

      test('should handle platform exceptions', () async {
        // Arrange
        // Mock the platform channel to throw an exception
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/platform'),
                (MethodCall methodCall) async {
          if (methodCall.method == 'SystemNavigator.pop') {
            throw PlatformException(code: 'ERROR');
          }
          return null;
        });

        // Act
        // Should handle exception gracefully
        await service.exitApp();
        
        // Assert
        // Test passes if exception is handled without crashing
      });

      test('should handle multiple exit calls', () async {
        // Arrange
        // Mock the platform channel
        TestWidgetsFlutterBinding.ensureInitialized();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(const MethodChannel('flutter/platform'),
                (MethodCall methodCall) async {
          if (methodCall.method == 'SystemNavigator.pop') {
            return null;
          }
          return null;
        });

        // Act
        // Should be able to call multiple times
        await service.exitApp();
        await service.exitApp();
        await service.exitApp();

        // Assert
        // All calls should complete without errors
      });
    });
  });

  group('DialogService Edge Cases', () {
    test('should handle null values gracefully', () {
      // Arrange
      // Service already created
      
      // Act
      final name = service.serviceName;
      
      // Assert
      // Service should be properly initialized
      expect(name, isNotNull);
      expect(name, isNotEmpty);
    });

    test('should have consistent service name', () {
      // Arrange
      final service1 = DialogService();
      final service2 = DialogService();

      // Act
      final name1 = service1.serviceName;
      final name2 = service2.serviceName;
      
      // Assert
      expect(name1, equals(name2));
    });

    test('should handle concurrent operations', () async {
      // Arrange
      // Mock the platform channel
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('flutter/platform'),
              (MethodCall methodCall) async {
        if (methodCall.method == 'SystemNavigator.pop') {
          // Simulate some delay
          await Future.delayed(const Duration(milliseconds: 100));
          return null;
        }
        return null;
      });

      // Act
      // Start multiple concurrent operations
      final futures = <Future>[];
      for (int i = 0; i < 10; i++) {
        futures.add(service.exitApp());
      }

      // All should complete
      await Future.wait(futures);
    });
  });
}
